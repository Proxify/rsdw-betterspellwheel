#!/usr/bin/env python3
"""BSW opening-hitch event-window analysis (session 115173b7). python3 -I; inputs are data only. Fails closed.

  opening_analyze.py run <dir> <label>          one run -> JSON
  opening_analyze.py table <dir> [--out f]      every <label>.events.json in dir -> per-context/arm/class table

Per run, in <dir>:
  <label>.csv            PresentMon-2.6.0-x64.exe default metrics + --qpc_time  (schema 'presentmon-2.6.0-qpc')
  <label>.receipt.json   bench capture receipt (case 'opening', '--qpc_time' in captureSettings.flags)
  <label>.events.json    opening-driver.ps1 log (status must be 'complete')
  <label>.opening.json   operator sidecar: {"coldProcess": bool, "noEarlierOpenProof": str|null,
                         "earlierOpenProof": str|null, "openingsObserved": bool, "openingsObservedProof": str|null,
                         "artCache": "present"|"absent-before-run", "preStateProof": str, "postStateProof": str}

Time base: PresentMon v2.6.0 CsvOutput.cpp writes CPUStartQPC/TimeInQPC as raw %llu QueryPerformanceCounter ticks
under --qpc_time. The driver's brackets are Stopwatch.GetTimestamp() ticks (high resolution = QPC). They share one
domain, so there is no UTC alignment. Ticks are parsed as integers, and ms = ticks * 1000 / driver qpcFrequency.
Two interval series, each analysed on its own intervals (row attribution verified on native C1, |diff| 0 over 2600):
  CPU (primary)  row i = [CPUStartQPC_i, CPUStartQPC_{i+1}), value MsBetweenAppStart_i   (same row)
  present        row i = [TimeInQPC_{i-1}, TimeInQPC_i),     value MsBetweenPresents_i   (preceding row)
One event = one logical Q tap: [down.qpcBefore, up.qpcAfter]. Its WINDOW is [down.qpcBefore, up.qpcAfter + POST_MS] and
includes, per series, EVERY interval overlapping it. Its BASELINE is that series' intervals lying wholly inside
[down.qpcBefore - GUARD_MS - BASE_MS, down.qpcBefore - GUARD_MS].
Reported: bracket widths, frame counts, max MsBetweenAppStart / MsBetweenPresents and the max CPU-start interval
derived from adjacent CPUStartQPC ticks in the window, baseline medians and excess, and >=50/100 ms flags. Per run,
'qpc_mapping' reports, per series, the tick-derived interval vs its metric (median/max |diff|, ms). It is
reported, not assumed, so the first native QPC run verifies row mapping/units. The table counts events AND distinct
process runs; events from one process are not independent repeats. These are frame times around a bounded intended input, NOT input-to-render latency
and NOT proof that the UI opened.
Labels: open #1 'first-in-process' only with coldProcess=true + noEarlierOpenProof; 'warm-proven' with
earlierOpenProof; otherwise 'first-unproven'. Later opens are 'warm-proven' only with openingsObserved=true + proof,
otherwise 'repeat-intended'. Closes are 'close-intended'.
"""
import csv, hashlib, json, math, os, statistics, sys

SCHEMA = 'presentmon-2.6.0-qpc'
REQUIRED = ['Application', 'ProcessID', 'SwapChainAddress', 'PresentRuntime', 'TimeInQPC', 'CPUStartQPC',
            'MsBetweenPresents', 'MsBetweenAppStart', 'MsCPUBusy', 'MsGPUBusy']
FORBIDDEN = ['TimeInMs', 'TimeInSeconds', 'TimeInDateTime', 'CPUStartTime', 'CPUStartTimeInMs', 'CPUStartTimeInSeconds',
             'CPUStartQPCTime', 'CPUStartQPCTimeInMs', 'CPUStartDateTime', 'FrameTime']
RECEIPT_REQUIRED = ('pid', 'procStartUtc', 'computer', 'clientBuild', 'exeHash', 'schema', 'case', 'arm', 'label',
                    'captureSettings', 'scene', 'configDigest', 'configDigestPolicy', 'ue4ssConfig', 'otherModsDigest',
                    'modsTxtNonWheel', 'presentMonExit', 'aliveAfter', 'payloadAfterOk', 'activation', 'csvHeader',
                    'wheelHashes')
CONTEXT_RECEIPT = ('computer', 'clientBuild', 'exeHash', 'schema', 'captureSettings', 'scene', 'configDigest',
                   'configDigestPolicy', 'ue4ssConfig', 'otherModsDigest', 'modsTxtNonWheel')
DRIVER_PARAMS = ('tool', 'version', 'driverSha256', 'mode', 'cycles', 'leadMs', 'holdMs', 'openDwellMs', 'closedGapMs')
POST_MS, GUARD_MS, BASE_MS = 750.0, 100.0, 1000.0


class InputError(ValueError):
    pass


def load_json(path, what):
    if not os.path.exists(path):
        raise InputError(f'{what} missing: {os.path.basename(path)}')
    with open(path, encoding='utf-8-sig') as f:
        return json.load(f)


def tick(v, where):
    if isinstance(v, bool) or not isinstance(v, int) or v < 0:
        raise InputError(f'{where}: QPC tick must be a non-negative integer, got {v!r}')
    return v


def fnum(v, where):
    try:
        x = float(v)
    except (TypeError, ValueError):
        raise InputError(f'{where}: required metric missing/non-numeric ({v!r})')
    if not math.isfinite(x) or x < 0:
        raise InputError(f'{where}: required metric not finite/non-negative ({v!r})')
    return x


def check_receipt(r, label):
    absent = [k for k in RECEIPT_REQUIRED if r.get(k) is None]
    if absent:
        raise InputError(f'{label}: receipt lacks {absent}')
    if r['schema'] != SCHEMA or r['case'] != 'opening' or r['label'] != label:
        raise InputError(f'{label}: receipt schema/case/label {r["schema"]}/{r["case"]}/{r["label"]}')
    flags = (r['captureSettings'] or {}).get('flags') or []
    if '--qpc_time' not in flags or any(f in flags for f in ('--qpc_time_ms', '--date_time', '--v1_metrics', '--v2_metrics')):
        raise InputError(f'{label}: capture flags {flags} are not the pinned --qpc_time default-metrics set')
    if r['presentMonExit'] != 0 or r['aliveAfter'] is not True or r['payloadAfterOk'] is not True:
        raise InputError(f'{label}: failed capture (exit/alive/payloadAfter)')
    if not (isinstance(r['activation'], dict) and r['activation'].get('ok') is True):
        raise InputError(f'{label}: arm activation not proven')


def check_events(e, r, label):
    if e.get('tool') != 'bsw115-opening-driver' or e.get('version') != 1:
        raise InputError(f'{label}: not an opening-driver v1 log')
    if e.get('status') != 'complete':
        raise InputError(f'{label}: driver status {e.get("status")!r}: {e.get("reason")}')
    for k in DRIVER_PARAMS + ('host', 'pid', 'procStartUtc', 'exeSha256', 'qpcFrequency', 'qpcHighResolution', 'goQpc'):
        if e.get(k) in (None, ''):
            raise InputError(f'{label}: driver log lacks {k}')
    if e['mode'] != 'Tap' or e['qpcHighResolution'] is not True:
        raise InputError(f'{label}: mode {e["mode"]} / high-resolution {e["qpcHighResolution"]}')
    freq = e['qpcFrequency']
    if isinstance(freq, bool) or not isinstance(freq, int) or freq <= 0:
        raise InputError(f'{label}: qpcFrequency {freq!r}')
    if isinstance(e['cycles'], bool) or not isinstance(e['cycles'], int) or not 1 <= e['cycles'] <= 4:
        raise InputError(f'{label}: cycles {e["cycles"]!r} not an integer 1..4')
    if (e['host'] != r['computer'] or e['pid'] != r['pid'] or e['procStartUtc'] != r['procStartUtc']
            or str(e['exeSha256']).upper() != str(r['exeHash']).upper()):
        raise InputError(f'{label}: driver identity (host/pid/procStart/exe) does not match the capture receipt')
    n = e['cycles']
    inj, evs = e.get('injections') or [], e.get('events') or []
    if len(inj) != 4 * n or len(evs) != 2 * n:
        raise InputError(f'{label}: {len(inj)} injections/{len(evs)} events for {n} cycles')
    last = tick(e['goQpc'], f'{label} goQpc')
    for i, x in enumerate(inj):
        want_kind = 'open' if (i // 2) % 2 == 0 else 'close'
        want_phase = 'down' if i % 2 == 0 else 'up'
        if x.get('kind') != want_kind or x.get('phase') != want_phase or x.get('cycle') != i // 4 + 1:
            raise InputError(f'{label}: injection {i} is {x.get("cycle")}/{x.get("kind")}/{x.get("phase")}')
        if x.get('sendInput') != 1:
            raise InputError(f'{label}: injection {i} SendInput={x.get("sendInput")}')
        a, b = tick(x.get('qpcBefore'), f'{label} inj {i}'), tick(x.get('qpcAfter'), f'{label} inj {i}')
        if not (last <= a <= b):
            raise InputError(f'{label}: injection {i} brackets not monotonic')
        last = b
    out = []
    for j, ev in enumerate(evs):
        d, u = inj[2 * j], inj[2 * j + 1]
        want = ('open' if j % 2 == 0 else 'close', j // 2 + 1)
        if (ev.get('kind'), ev.get('cycle')) != want:
            raise InputError(f'{label}: event {j} is {ev.get("kind")}/{ev.get("cycle")}')
        if (ev.get('downQpcBefore'), ev.get('downQpcAfter'), ev.get('upQpcBefore'), ev.get('upQpcAfter')) != \
                (d['qpcBefore'], d['qpcAfter'], u['qpcBefore'], u['qpcAfter']):
            raise InputError(f'{label}: event {j} brackets differ from its injections')
        out.append({'kind': want[0], 'cycle': want[1], 'a': d['qpcBefore'], 'downAfter': d['qpcAfter'],
                    'upBefore': u['qpcBefore'], 'b0': u['qpcAfter']})
    if e.get('safetyRelease'):
        raise InputError(f'{label}: safety key release happened in a complete run')
    return freq, out


def load_frames(path, r, label):
    with open(path, newline='', encoding='utf-8-sig') as f:
        rd = csv.reader(f)
        header = next(rd, None)
        rows = [x for x in rd if x]
    if not header:
        raise InputError(f'{label}: empty CSV')
    if str(r['csvHeader']).strip() != ','.join(header):
        raise InputError(f'{label}: CSV header differs from receipt')
    missing = [c for c in REQUIRED if c not in header]
    bad = [c for c in FORBIDDEN if c in header]
    if missing or bad:
        raise InputError(f'{label}: not {SCHEMA} (missing {missing}, unexpected {bad})')
    ix = {c: header.index(c) for c in header}
    if any(len(x) != len(header) for x in rows):
        raise InputError(f'{label}: malformed CSV row')
    mine = [x for x in rows if x[ix['ProcessID']].strip() == str(r['pid'])]
    if not mine:
        raise InputError(f'{label}: no rows for pid {r["pid"]}')
    counts = {}
    for x in mine:
        counts[x[ix['SwapChainAddress']]] = counts.get(x[ix['SwapChainAddress']], 0) + 1
    swap = max(counts, key=counts.get)
    sel = [x for x in mine if x[ix['SwapChainAddress']] == swap]
    excluded = {'other_pid': len(rows) - len(mine), 'other_swapchain': len(mine) - len(sel)}
    if 'FrameType' in ix:
        app = [x for x in sel if x[ix['FrameType']].strip() == 'Application']
        excluded['non_application_frametype'] = len(sel) - len(app)
        if not app:
            raise InputError(f'{label}: FrameType present but no Application frames')
        sel = app
    def ticks(x, col, k):
        raw = x[ix[col]].strip()
        if not raw.isdigit():
            raise InputError(f'{label}: {col} row {k} not an integer tick ({raw!r})')
        return int(raw)
    cs, tp, app, pre = [], [], [], []
    for k, x in enumerate(sel):
        cs.append(ticks(x, 'CPUStartQPC', k))
        tp.append(ticks(x, 'TimeInQPC', k))
        app.append(fnum(x[ix['MsBetweenAppStart']], f'{label} row {k} MsBetweenAppStart'))
        pre.append(fnum(x[ix['MsBetweenPresents']], f'{label} row {k} MsBetweenPresents'))
        if k and cs[k] <= cs[k - 1]:
            raise InputError(f'{label}: CPUStartQPC not strictly increasing at row {k}')
        if k and tp[k] <= tp[k - 1]:
            raise InputError(f'{label}: TimeInQPC not strictly increasing at row {k}')
    if len(cs) < 3:
        raise InputError(f'{label}: too few frames')
    # Two interval series with different row attribution (verified on the native C1 sample, 2600 frames, |diff| 0):
    #   CPU     row i: [CPUStartQPC_i, CPUStartQPC_{i+1})  value MsBetweenAppStart_i  (same row; last row has no end)
    #   present row i: [TimeInQPC_{i-1}, TimeInQPC_i)      value MsBetweenPresents_i  (preceding row; first row has no start)
    cpu = [{'s': cs[i], 'e': cs[i + 1], 'v': app[i]} for i in range(len(cs) - 1)]
    prs = [{'s': tp[i - 1], 'e': tp[i], 'v': pre[i]} for i in range(1, len(tp))]
    return cpu, prs, excluded, hashlib.sha256(','.join(header).encode()).hexdigest()[:16]


def add_intervals(series, freq, what):
    diffs = []
    for f in series:
        f['qpcMs'] = (f['e'] - f['s']) * 1000.0 / freq
        diffs.append(abs(f['qpcMs'] - f['v']))
    return {'intervals': len(diffs), 'median_abs_diff_ms': round(statistics.median(diffs), 4),
            'max_abs_diff_ms': round(max(diffs), 4), 'definition': what}


def classify(ev, side):
    if ev['kind'] == 'close':
        return 'close-intended'
    if ev['cycle'] == 1:
        if side.get('coldProcess') is True and side.get('noEarlierOpenProof'):
            return 'first-in-process'
        return 'warm-proven' if side.get('earlierOpenProof') else 'first-unproven'
    return 'warm-proven' if (side.get('openingsObserved') is True and side.get('openingsObservedProof')) else 'repeat-intended'


def run(d, label):
    r = load_json(os.path.join(d, label + '.receipt.json'), 'receipt')
    check_receipt(r, label)
    e = load_json(os.path.join(d, label + '.events.json'), 'driver events')
    freq, events = check_events(e, r, label)
    side = load_json(os.path.join(d, label + '.opening.json'), 'operator sidecar')
    for k in ('preStateProof', 'postStateProof', 'artCache'):
        if not side.get(k):
            raise InputError(f'{label}: sidecar lacks {k}')
    if side['artCache'] not in ('present', 'absent-before-run'):
        raise InputError(f'{label}: artCache {side["artCache"]!r}')
    cpu, prs, excluded, header_sha = load_frames(os.path.join(d, label + '.csv'), r, label)
    mapping = {'cpu': add_intervals(cpu, freq, 'CPUStartQPC[i+1]-CPUStartQPC[i] vs MsBetweenAppStart[i] (same row)'),
               'present': add_intervals(prs, freq, 'TimeInQPC[i]-TimeInQPC[i-1] vs MsBetweenPresents[i] (preceding row)')}
    ms = lambda ticks: ticks * 1000.0 / freq
    tk = lambda m: int(round(m * freq / 1000.0))
    spans = []
    for ev in events:
        ev['b'] = ev['b0'] + tk(POST_MS)
        ev['baseA'], ev['baseB'] = ev['a'] - tk(GUARD_MS + BASE_MS), ev['a'] - tk(GUARD_MS)
        spans.append((ev['baseA'], ev['b']))
    for i, (a1, b1) in enumerate(spans):   # an event's baseline+window must not touch another event's span
        for j, (a2, b2) in enumerate(spans):
            if i < j and a1 < b2 and a2 < b1:
                raise InputError(f'{label}: event {i} and {j} baseline/window spans overlap')
    for name, ser in (('CPU', cpu), ('present', prs)):
        if ser[0]['s'] > spans[0][0] or ser[-1]['e'] < spans[-1][1]:
            raise InputError(f'{label}: {name} intervals do not cover every baseline/window '
                             f'({ser[0]["s"]}..{ser[-1]["e"]}, needed {spans[0][0]}..{spans[-1][1]})')
    out_events = []
    for ev in events:
        sel = {}
        for name, ser in (('cpu', cpu), ('present', prs)):   # each series uses its OWN intervals
            win = [f for f in ser if f['s'] < ev['b'] and f['e'] > ev['a']]
            base = [f for f in ser if f['s'] >= ev['baseA'] and f['e'] <= ev['baseB']]
            if not win or len(base) < 5:
                raise InputError(f'{label}: event {ev["kind"]}#{ev["cycle"]} {name} window/baseline too sparse')
            sel[name] = (win, base)
        (win, base), (pwin, pbase) = sel['cpu'], sel['present']
        bA = statistics.median(f['v'] for f in base)
        bP = statistics.median(f['v'] for f in pbase)
        mA = max(f['v'] for f in win)
        mP = max(f['v'] for f in pwin)
        mQ = max(f['qpcMs'] for f in win)
        bQ = statistics.median(f['qpcMs'] for f in base)
        out_events.append({
            'kind': ev['kind'], 'cycle': ev['cycle'], 'class': classify(ev, side),
            'tapMs': round(ms(ev['b0'] - ev['a']), 3), 'downBracketMs': round(ms(ev['downAfter'] - ev['a']), 4),
            'upBracketMs': round(ms(ev['b0'] - ev['upBefore']), 4),
            'windowFrames': len(win), 'baselineFrames': len(base),
            'presentWindowIntervals': len(pwin), 'presentBaselineIntervals': len(pbase),
            'maxMsBetweenAppStart': mA, 'maxMsBetweenPresents': mP, 'maxQpcIntervalMs': round(mQ, 4),
            'baselineMedianQpcIntervalMs': round(bQ, 4), 'excessQpcInterval': round(mQ - bQ, 4),
            'baselineMedianAppStart': bA, 'baselineMedianPresents': bP,
            'excessAppStart': round(mA - bA, 4), 'excessPresents': round(mP - bP, 4),
            'hitch50': mA >= 50 or mP >= 50, 'hitch100': mA >= 100 or mP >= 100})
    ctx = {k: r[k] for k in CONTEXT_RECEIPT}
    ctx['header_sha'] = header_sha
    ctx['driver'] = {k: e[k] for k in DRIVER_PARAMS}
    ctx['artCache'] = side['artCache']
    ctx['qpcFrequency'] = freq
    wheel = hashlib.sha256(json.dumps(r['wheelHashes'], sort_keys=True).encode()).hexdigest()[:16]
    return {'label': label, 'arm': r['arm'], 'pid': r['pid'], 'procStartUtc': r['procStartUtc'],
            'context': hashlib.sha256(json.dumps(ctx, sort_keys=True).encode()).hexdigest()[:12], 'context_fields': ctx,
            'wheel_digest': wheel, 'excluded': excluded, 'qpcFrequency': freq, 'qpc_mapping': mapping,
            'window_definition': f'per series (CPU-start intervals; present intervals), every interval overlapping '
                                 f'[down.qpcBefore, up.qpcAfter + {POST_MS:g} ms]; baseline = intervals wholly inside '
                                 f'[down.qpcBefore - {GUARD_MS + BASE_MS:g} ms, down.qpcBefore - {GUARD_MS:g} ms]',
            'events': out_events}


def table(d, out=None):
    labels = sorted(n[:-len('.events.json')] for n in os.listdir(d) if n.endswith('.events.json'))
    if not labels:
        raise InputError('no runs')
    runs = [run(d, l) for l in labels]
    groups = {}
    for r in runs:
        for ev in r['events']:
            groups.setdefault((r['context'], r['arm'], ev['kind'], ev['class']), []).append((r, ev))
    summary = []
    for (ctx, arm, kind, cls), items in sorted(groups.items()):
        digests = {r['wheel_digest'] for r, _ in items}
        if len(digests) > 1:
            raise InputError(f'{ctx}/{arm}: runs with different wheel payloads {sorted(digests)}')
        ex = [ev['excessAppStart'] for _, ev in items]
        mx = [ev['maxMsBetweenAppStart'] for _, ev in items]
        procs = sorted({(r['pid'], r['procStartUtc']) for r, _ in items})
        summary.append({'context': ctx, 'arm': arm, 'kind': kind, 'class': cls, 'events': len(items),
                        'runs': sorted({r['label'] for r, _ in items}), 'process_runs': len(procs),
                        'note': 'events within one process are not independent repeats; compare process_runs',
                        'median_excess_appstart_ms': statistics.median(ex), 'max_excess_appstart_ms': max(ex),
                        'median_max_appstart_ms': statistics.median(mx), 'max_appstart_ms': max(mx),
                        'hitch50': sum(ev['hitch50'] for _, ev in items), 'hitch100': sum(ev['hitch100'] for _, ev in items)})
    res = {'runs': runs, 'summary': summary}
    if out:
        with open(out, 'w') as f:
            json.dump(res, f, indent=1)
    return res


if __name__ == '__main__':
    a = sys.argv[1:]
    try:
        if len(a) == 3 and a[0] == 'run':
            print(json.dumps(run(a[1], a[2]), indent=1))
        elif len(a) >= 2 and a[0] == 'table':
            res = table(a[1], a[a.index('--out') + 1] if '--out' in a else None)
            for s in res['summary']:
                print(f"{s['context']:<13}{s['arm']:<3}{s['kind']:<6}{s['class']:<17} events={s['events']:<3} procs={s['process_runs']:<2} "
                      f"excess med/max={s['median_excess_appstart_ms']:.2f}/{s['max_excess_appstart_ms']:.2f} ms "
                      f"max frame={s['max_appstart_ms']:.2f} ms h50={s['hitch50']} h100={s['hitch100']}")
        else:
            print(__doc__)
            sys.exit(2)
    except (InputError, json.JSONDecodeError) as e:
        print(f'REJECTED: {e}', file=sys.stderr)
        sys.exit(1)
