#!/usr/bin/env python3
"""BSW native A/B analysis (session 115173b7). Run with python3 -I; the CSVs and receipts are data only.

  analyze.py run <csv> [--skip-s 5]                one run (needs <label>.receipt.json beside it) -> JSON
  analyze.py table <runs-dir> [--skip-s 5] [--out summary.json]

Accepted schemas (anything else is rejected):
  presentmon-2.6.0-default  PresentMon-2.6.0-x64.exe console app, default metrics, invoked by bench.ps1 capture
                            (no --v1_metrics/--v2_metrics/--qpc_time*/--date_time). Per its README-ConsoleApplication.md
                            at tag v2.6.0, all times are in ms. The actual default CSV uses CPUStartTimeInMs;
                            CPUStartTime is the README spelling. Accept exactly one; never infer units.
                            Frame time = MsBetweenPresents. CPU = MsCPUBusy. GPU = MsGPUBusy.
  frameprobe-1              rsdw-together/tools/perfprobe/FrameProbe CSV: frame,t_s,dt_ms (engine delta, ms).
Rows are filtered to the receipt's game PID and that PID's main swap chain. If a FrameType column is present
(--track_frame_type), only FrameType == Application rows count; generated/repeated frames are excluded and counted.
Accepted runs need a clean receipt: presentMonExit 0, aliveAfter true, payloadAfterOk true, activation.ok true.
Groups never mix the structured context (computer, client build, exe hash, schema, CSV header, capture settings incl.
seconds/flags/warmup, scene, Saved/Config digest, UE4SS ini hashes, other-mod digest, non-wheel mods.txt lines), and every
run in an arm/case group must have the same wheel payload digest.
"""
import csv, hashlib, json, math, os, statistics, sys

PM_SCHEMA = 'presentmon-2.6.0-default'
CONTEXT_KEYS = ('computer', 'clientBuild', 'exeHash', 'schema', 'captureSettings', 'scene', 'configDigest', 'ue4ssConfig',
                'otherModsDigest', 'modsTxtNonWheel')
PM_RECEIPT_REQUIRED = CONTEXT_KEYS + ('pid', 'presentMonExit', 'aliveAfter', 'payloadAfterOk', 'activation', 'csvHeader')
FP_SCHEMA = 'frameprobe-1'
PM_REQUIRED = ['Application', 'ProcessID', 'SwapChainAddress', 'PresentRuntime',
               'MsBetweenPresents', 'MsCPUBusy', 'MsGPUBusy']
PM_TIME_COLUMNS = ('CPUStartTimeInMs', 'CPUStartTime')
PM_FORBIDDEN = ['TimeInSeconds', 'CPUStartTimeInSeconds', 'CPUStartQPC', 'CPUStartQPCTime',
                'CPUStartQPCTimeInMs', 'CPUStartDateTime', 'FrameTime']
FP_HEADER = ['frame', 't_s', 'dt_ms']


class SchemaError(ValueError):
    pass


def num(v):
    try:
        x = float(v)
    except (TypeError, ValueError):
        return None
    return x if math.isfinite(x) else None


def pct(s, p):   # nearest rank on a sorted list
    return s[max(0, min(len(s) - 1, math.ceil(len(s) * p) - 1))] if s else None


def stats(vals):
    s = sorted(vals)
    if not s:
        return None
    return {'n': len(s), 'mean': round(statistics.fmean(s), 3), 'p50': pct(s, .5), 'p95': pct(s, .95),
            'p99': pct(s, .99), 'p999': pct(s, .999), 'max': s[-1]}


def load_receipt(csv_path):
    rp = os.path.splitext(csv_path)[0] + '.receipt.json'
    if not os.path.exists(rp):
        raise SchemaError(f'{csv_path}: receipt missing')
    with open(rp, encoding='utf-8-sig') as f:
        return json.load(f)


def analyze(csv_path, receipt, skip_s=0.0):
    with open(csv_path, newline='', encoding='utf-8-sig') as f:
        reader = csv.reader(f)
        header = next(reader, None)
        rows = [r for r in reader if r]
    if not header:
        raise SchemaError(f'{csv_path}: empty file')
    schema = receipt.get('schema')
    out = {'file': os.path.basename(csv_path), 'schema': schema,
           'header_sha': hashlib.sha256(','.join(header).encode()).hexdigest()[:16], 'excluded': {}}
    ex = out['excluded']
    if schema == PM_SCHEMA:
        absent = [k for k in PM_RECEIPT_REQUIRED if receipt.get(k) is None]
        if absent:
            raise SchemaError(f'{csv_path}: receipt lacks {absent}')
        if receipt['presentMonExit'] != 0:
            raise SchemaError(f'{csv_path}: PresentMon exit {receipt["presentMonExit"]}')
        if receipt['aliveAfter'] is not True:
            raise SchemaError(f'{csv_path}: game process exited during capture')
        if receipt['payloadAfterOk'] is not True:
            raise SchemaError(f'{csv_path}: wheel payload/arm changed during capture: {receipt.get("payloadAfterError")}')
        if not (isinstance(receipt['activation'], dict) and receipt['activation'].get('ok') is True):
            raise SchemaError(f'{csv_path}: arm activation not proven: {receipt["activation"]}')
        if receipt['csvHeader'].strip() != ','.join(header):
            raise SchemaError(f'{csv_path}: CSV header differs from the receipt')
        missing = [c for c in PM_REQUIRED if c not in header]
        bad = [c for c in PM_FORBIDDEN if c in header]
        if missing or bad:
            raise SchemaError(f'{csv_path}: not {PM_SCHEMA} (missing {missing}, unexpected {bad})')
        time_columns = [c for c in header if c in PM_TIME_COLUMNS]
        if len(time_columns) != 1:
            raise SchemaError(f'{csv_path}: expected exactly one millisecond CPU start column, found {time_columns}')
        time_column = time_columns[0]
        out['timestamp_column'] = time_column
        out['timestamp_unit'] = 'ms'
        ix = {c: header.index(c) for c in header}
        pid = receipt.get('pid')
        if pid is None:
            raise SchemaError(f'{csv_path}: receipt has no pid')
        mine = [r for r in rows if r[ix['ProcessID']].strip() == str(pid)]
        ex['other_pid'] = len(rows) - len(mine)
        if not mine:
            raise SchemaError(f'{csv_path}: no rows for pid {pid}')
        counts = {}
        for r in mine:
            counts[r[ix['SwapChainAddress']]] = counts.get(r[ix['SwapChainAddress']], 0) + 1
        swap = max(counts, key=counts.get)
        rows2 = [r for r in mine if r[ix['SwapChainAddress']] == swap]
        ex['other_swapchain'] = len(mine) - len(rows2)
        out['swapchain'] = swap
        if 'FrameType' in ix:
            app = [r for r in rows2 if r[ix['FrameType']].strip() == 'Application']
            ex['non_application_frametype'] = len(rows2) - len(app)
            if not app:
                raise SchemaError(f'{csv_path}: FrameType present but no Application frames')
            rows2 = app
            out['frame_type_filter'] = 'Application only'
        else:
            out['frame_type_filter'] = 'FrameType column absent (frame generation must be off; see run settings)'
        t = [num(r[ix[time_column]]) for r in rows2]
        if any(x is None for x in t):
            raise SchemaError(f'{csv_path}: non-numeric {time_column}')
        t0 = t[0]
        keep = [i for i, x in enumerate(t) if x - t0 >= skip_s * 1000.0]
        ex['warmup'] = len(rows2) - len(keep)
        rows2, t = [rows2[i] for i in keep], [t[i] for i in keep]
        col = lambda name: [num(r[ix[name]]) for r in rows2]
        ft_all = col('MsBetweenPresents')
        ft = [x for x in ft_all if x is not None and x > 0]
        ex['frametime_na'] = len(ft_all) - len(ft)
        out['duration_s'] = round((t[-1] - t[0]) / 1000.0, 3) if len(t) > 1 else 0.0
        cpu = [x for x in col('MsCPUBusy') if x is not None]
        gpu = [x for x in col('MsGPUBusy') if x is not None]
        out['cpu_busy_ms'] = stats(cpu) or 'unavailable'
        out['gpu_busy_ms'] = stats(gpu) or 'unavailable'
    elif schema == FP_SCHEMA:
        if header != FP_HEADER:
            raise SchemaError(f'{csv_path}: not {FP_SCHEMA}: {header}')
        for k in ('aliveAfter', 'payloadAfterOk'):
            if receipt.get(k) is False:
                raise SchemaError(f'{csv_path}: receipt {k} false')
        if any(len(r) != 3 for r in rows):
            raise SchemaError(f'{csv_path}: malformed FrameProbe row')
        t = [num(r[1]) for r in rows]
        ft_all = [num(r[2]) for r in rows]
        if not rows or any(x is None for x in t):
            raise SchemaError(f'{csv_path}: FrameProbe empty or non-numeric timestamp')
        keep = [i for i, x in enumerate(t) if x - t[0] >= skip_s]
        ex['warmup'] = len(rows) - len(keep)
        ft = [ft_all[i] for i in keep if ft_all[i] is not None and ft_all[i] > 0]
        ex['frametime_na'] = len(keep) - len(ft)
        tk = [t[i] for i in keep]
        out['duration_s'] = round(tk[-1] - tk[0], 3) if len(tk) > 1 else 0.0
        out['cpu_busy_ms'] = out['gpu_busy_ms'] = 'unavailable'
    else:
        raise SchemaError(f'{csv_path}: unknown schema {schema!r}')
    if not ft:
        raise SchemaError(f'{csv_path}: no usable frames')
    out.update({'frames': len(ft), 'frametime_ms': stats(ft), 'fps_mean': round(1000 * len(ft) / sum(ft), 1),
                'hitch_ge50': sum(1 for x in ft if x >= 50), 'hitch_ge100': sum(1 for x in ft if x >= 100)})
    wh = receipt.get('wheelHashes') or {}
    out.update({k: receipt.get(k) for k in ('label', 'arm', 'case', 'pid', 'procStartUtc', 'clientBuild', 'exeHash',
                                             'aliveAfter', 'computer', 'scene', 'generatedFiles', 'activation')})
    out['wheel_files'] = len(wh)
    out['wheel_digest'] = hashlib.sha256(json.dumps(wh, sort_keys=True).encode()).hexdigest()[:16] if wh else 'none'
    ctx = {k: receipt.get(k) for k in CONTEXT_KEYS}
    ctx['header_sha'] = out['header_sha']
    out['context_fields'] = ctx
    out['context'] = hashlib.sha256(json.dumps(ctx, sort_keys=True).encode()).hexdigest()[:12]
    return out


def run(csv_path, skip_s=0.0):
    return analyze(csv_path, load_receipt(csv_path), skip_s)


def table(d, skip_s=0.0, out=None, quiet=False):
    rows = [run(os.path.join(d, n), skip_s) for n in sorted(os.listdir(d)) if n.endswith('.csv')]
    groups = {}
    for r in rows:
        groups.setdefault((r['context'], r.get('case') or '?', r.get('arm') or '?'), []).append(r)
    summary = []
    for (ctx, case, arm), rs in sorted(groups.items()):
        digests = {r['wheel_digest'] for r in rs}
        if len(digests) > 1:
            raise SchemaError(f'context {ctx} case {case} arm {arm}: runs have different wheel payloads {sorted(digests)}')

        def agg(key):
            v = [r['frametime_ms'][key] for r in rs]
            return {'median': statistics.median(v), 'min': min(v), 'max': max(v)}

        def agg2(metric):
            v = [r[metric]['p99'] for r in rs if isinstance(r[metric], dict)]
            return {'median_p99': statistics.median(v), 'min': min(v), 'max': max(v)} if len(v) == len(rs) else 'unavailable'
        summary.append({'context': ctx, 'case': case, 'arm': arm, 'runs': len(rs), 'labels': [r['label'] for r in rs],
                        'pids': sorted({str(r['pid']) for r in rs}), 'wheel_digest': digests.pop(),
                        **{k: agg(k) for k in ('p50', 'p95', 'p99', 'p999', 'max', 'mean')},
                        'hitch_ge50': sum(r['hitch_ge50'] for r in rs),
                        'cpu_busy': agg2('cpu_busy_ms'), 'gpu_busy': agg2('gpu_busy_ms')})
    res = {'skip_s': skip_s, 'runs': rows, 'summary': summary}
    if out:
        with open(out, 'w') as f:
            json.dump(res, f, indent=1)
    if not quiet:
        fmt = lambda a: f"{a['median']:.2f}[{a['min']:.1f}-{a['max']:.1f}]"
        fmt2 = lambda a: a if isinstance(a, str) else f"{a['median_p99']:.2f}"
        print(f"{'context':<13}{'case':<14}{'arm':<4}{'n':>3}{'p50':>17}{'p95':>17}{'p99':>17}{'p99.9':>17}{'max':>17}  h50  cpu_p99  gpu_p99")
        for s in summary:
            print(f"{s['context']:<13}{s['case']:<14}{s['arm']:<4}{s['runs']:>3}" + ''.join(f"{fmt(s[k]):>17}" for k in ('p50', 'p95', 'p99', 'p999', 'max'))
                  + f"  {s['hitch_ge50']:>3}  {fmt2(s['cpu_busy']):>7}  {fmt2(s['gpu_busy']):>7}")
    return res


if __name__ == '__main__':
    a = sys.argv[1:]
    skip = float(a[a.index('--skip-s') + 1]) if '--skip-s' in a else 0.0
    try:
        if len(a) >= 2 and a[0] == 'run':
            print(json.dumps(run(a[1], skip), indent=1))
        elif len(a) >= 2 and a[0] == 'table':
            table(a[1], skip, a[a.index('--out') + 1] if '--out' in a else None)
        else:
            print(__doc__)
            sys.exit(2)
    except SchemaError as e:
        print(f'REJECTED: {e}', file=sys.stderr)
        sys.exit(1)
