#!/usr/bin/env python3
"""Fixture tests for opening_analyze.py: python3 -I test_opening_analyze.py"""
import copy, json, os, sys, tempfile, unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import opening_analyze as O  # noqa: E402

F = 10_000_000          # QPC ticks per second
MS = F // 1000
T0 = 5_000_000_000_000  # absolute QPC origin (large, like a real counter)
HDR = ['Application', 'ProcessID', 'SwapChainAddress', 'PresentRuntime', 'SyncInterval', 'PresentFlags', 'AllowsTearing',
       'PresentMode', 'TimeInQPC', 'MsBetweenSimulationStart', 'MsBetweenPresents', 'MsBetweenDisplayChange',
       'MsInPresentAPI', 'MsRenderPresentLatency', 'MsUntilDisplayed', 'CPUStartQPC', 'MsBetweenAppStart', 'MsCPUBusy',
       'MsCPUWait', 'MsGPULatency', 'MsGPUTime', 'MsGPUBusy', 'MsGPUWait', 'MsAnimationError', 'AnimationTime',
       'MsFlipDelay', 'MsAllInputToPhotonLatency', 'MsClickToPhotonLatency']


def driver(cycles=3, go=T0 + 1000 * MS):
    inj, evs, t = [], [], go + 4000 * MS
    for c in range(1, cycles + 1):
        for kind in ('open', 'close'):
            d = {'cycle': c, 'kind': kind, 'phase': 'down', 'qpcBefore': t, 'qpcAfter': t + 2 * MS // 10, 'sendInput': 1, 'lastError': 0}
            t += 120 * MS
            u = {'cycle': c, 'kind': kind, 'phase': 'up', 'qpcBefore': t, 'qpcAfter': t + MS // 10, 'sendInput': 1, 'lastError': 0}
            inj += [d, u]
            evs.append({'cycle': c, 'kind': kind, 'intended': 'intended ' + kind, 'downQpcBefore': d['qpcBefore'],
                        'downQpcAfter': d['qpcAfter'], 'upQpcBefore': u['qpcBefore'], 'upQpcAfter': u['qpcAfter']})
            t += (2000 if kind == 'open' else 2500) * MS
    return {'tool': 'bsw115-opening-driver', 'version': 1, 'status': 'complete', 'reason': None, 'host': 'SUDOBLADE',
            'pid': 1234, 'procStartUtc': '2026-10-23T20:05:40.2836288Z', 'exeSha256': 'ab' * 32, 'mode': 'Tap',
            'cycles': cycles, 'leadMs': 4000, 'holdMs': 120, 'openDwellMs': 2000, 'closedGapMs': 2500,
            'driverSha256': 'D' * 64, 'qpcFrequency': F, 'qpcHighResolution': True, 'setupDoneQpc': T0, 'goQpc': go,
            'injections': inj, 'events': evs, 'endQpc': t}


def receipt(label, **over):
    r = {'label': label, 'case': 'opening', 'arm': 'B', 'pid': 1234, 'procStartUtc': '2026-10-23T20:05:40.2836288Z',
         'computer': 'SUDOBLADE', 'clientBuild': '26162923', 'exeHash': 'AB' * 32, 'schema': O.SCHEMA,
         'captureSettings': {'tool': 'PresentMon-2.6.0-x64.exe', 'seconds': 30, 'warmupS': 60,
                             'flags': ['--terminate_after_timed', '--no_console_stats', '--qpc_time']},
         'scene': 'standard-temple-fixture-v1', 'configDigest': 'EFF', 'configDigestPolicy': 'exclude-top-level-CrashReportClient-only-v1',
         'ue4ssConfig': {'UE4SS-settings.ini': 'U'}, 'otherModsDigest': 'OM', 'modsTxtNonWheel': ['PlayerTrading : 1'],
         'presentMonExit': 0, 'aliveAfter': True, 'payloadAfterOk': True, 'activation': {'ok': True},
         'csvHeader': ','.join(HDR), 'wheelHashes': {'Scripts\\main.lua': 'H'}}
    r.update(over)
    return r


def sidecar(**over):
    s = {'coldProcess': False, 'noEarlierOpenProof': None, 'earlierOpenProof': None, 'openingsObserved': False,
         'openingsObservedProof': None, 'artCache': 'present', 'preStateProof': 'shot pre + scene probe closed',
         'postStateProof': 'shot post + scene probe closed'}
    s.update(over)
    return s


def frames(start=T0, end=T0 + 30_000 * MS, ft_ms=7, hitch_at=None, hitch_ms=60, pid=1234, swap='0x1',
           present_lag=None):
    """CPU starts every ft_ms (one hitch of hitch_ms); each present lags its CPU start by a VARYING 5..8 ms
    (+ optional extra lag {cpu_start_tick: ms}). MsBetweenAppStart = same-row CPU interval; MsBetweenPresents =
    interval from the PREVIOUS row's present, as PresentMon 2.6.0 writes them (verified on native C1)."""
    cs, t = [], start
    while t < end:
        cs.append(t)
        dt = hitch_ms if (hitch_at is not None and t <= hitch_at < t + ft_ms * MS) else ft_ms
        t += dt * MS
    cs.append(t)
    tp = [c + (5 + i % 4) * MS + (present_lag or {}).get(c, 0) * MS for i, c in enumerate(cs)]
    for i in range(1, len(tp)):   # presents stay ordered: a delayed present queues the following ones
        tp[i] = max(tp[i], tp[i - 1] + MS)
    rows = []
    for i in range(len(cs) - 1):
        v = dict.fromkeys(HDR, '0')
        v.update(Application='RSDragonwilds-Win64-Shipping.exe', ProcessID=str(pid), SwapChainAddress=swap,
                 PresentRuntime='DXGI', TimeInQPC=str(tp[i]), CPUStartQPC=str(cs[i]),
                 MsBetweenAppStart=f'{(cs[i + 1] - cs[i]) / MS:.4f}',
                 MsBetweenPresents=f'{((tp[i] - tp[i - 1]) / MS if i else ft_ms):.4f}',
                 MsCPUBusy='5.0', MsGPUBusy='4.0', MsBetweenSimulationStart='NA')
        rows.append(v)
    return rows


def write(d, label, rows=None, rec=None, drv=None, side=None, header=HDR):
    with open(os.path.join(d, label + '.csv'), 'w') as f:
        f.write(','.join(header) + '\n')
        for r in (frames() if rows is None else rows):
            f.write(','.join(str(r.get(c, '')) for c in header) + '\n')
    for suffix, obj in (('.receipt.json', rec or receipt(label)), ('.events.json', drv or driver()),
                        ('.opening.json', side or sidecar())):
        if obj is not False:
            with open(os.path.join(d, label + suffix), 'w') as f:
                json.dump(obj, f)


class T(unittest.TestCase):
    def setUp(self):
        self.t = tempfile.TemporaryDirectory(prefix='bsw115-open.')
        self.d = self.t.name

    def tearDown(self):
        self.t.cleanup()

    def rej(self, label='r'):
        with self.assertRaises(O.InputError):
            O.run(self.d, label)

    def test_mapping_hitch_in_window_and_overlap_inclusion(self):
        drv = driver()
        a = drv['events'][0]['downQpcBefore']
        # A 60 ms frame that STARTS 20 ms before the tap overlaps the window and must be counted.
        write(self.d, 'r', rows=frames(hitch_at=a - 20 * MS), drv=drv)
        res = O.run(self.d, 'r')
        e0 = res['events'][0]
        self.assertEqual((e0['kind'], e0['cycle'], e0['class']), ('open', 1, 'first-unproven'))
        self.assertEqual(e0['maxMsBetweenAppStart'], 60.0)
        self.assertAlmostEqual(e0['excessAppStart'], 53.0)
        self.assertTrue(e0['hitch50'] and not e0['hitch100'])
        self.assertAlmostEqual(e0['tapMs'], 120.1, places=3)   # down.before .. up.after
        self.assertEqual(res['events'][1]['excessAppStart'], 0.0)
        self.assertEqual([e['class'] for e in res['events']],
                         ['first-unproven', 'close-intended', 'repeat-intended', 'close-intended', 'repeat-intended', 'close-intended'])

    def test_frame_just_after_window_excluded_and_just_before_counted(self):
        drv = driver()
        e0 = drv['events'][0]
        win_end = e0['upQpcAfter'] + 750 * MS
        write(self.d, 'r', rows=frames(hitch_at=win_end + 3 * MS), drv=drv)   # frame starts after window end
        self.assertEqual(O.run(self.d, 'r')['events'][0]['maxMsBetweenAppStart'], 7.0)

    def test_first_and_warm_labels_need_proof(self):
        write(self.d, 'r', side=sidecar(coldProcess=True, noEarlierOpenProof='fresh PID, no Q before go'))
        self.assertEqual(O.run(self.d, 'r')['events'][0]['class'], 'first-in-process')
        write(self.d, 'r', side=sidecar(coldProcess=True))                      # cold claimed, no proof text
        self.assertEqual(O.run(self.d, 'r')['events'][0]['class'], 'first-unproven')
        write(self.d, 'r', side=sidecar(earlierOpenProof='D1 opened earlier (scene probe)', openingsObserved=True,
                                        openingsObservedProof='per-event screenshots'))
        self.assertEqual({e['class'] for e in O.run(self.d, 'r')['events'] if e['kind'] == 'open'}, {'warm-proven'})
        write(self.d, 'r', side=sidecar(openingsObserved=True))                  # observed claimed without proof
        self.assertEqual(O.run(self.d, 'r')['events'][2]['class'], 'repeat-intended')

    def test_aborted_or_failed_injection_refused(self):
        drv = driver(); drv['status'] = 'aborted'; drv['reason'] = 'foreground window pid 99 is not the game'
        write(self.d, 'r', drv=drv); self.rej()
        drv = driver(); drv['injections'][3]['sendInput'] = 0
        write(self.d, 'r', drv=drv); self.rej()
        drv = driver(); drv['injections'] = drv['injections'][:-2]; drv['events'] = drv['events'][:-1]
        write(self.d, 'r', drv=drv); self.rej()
        drv = driver(); drv['safetyRelease'] = {'sendInput': 1}
        write(self.d, 'r', drv=drv); self.rej()

    def test_identity_and_context_mismatch_refused(self):
        for over in ({'pid': 999}, {'procStartUtc': 'other'}, {'host': 'SUDODESK'}, {'exeSha256': 'cd' * 32}):
            drv = driver(); drv.update(over)
            write(self.d, 'r', drv=drv); self.rej()
        for over in ({'schema': 'presentmon-2.6.0-default'}, {'case': 'open'},
                     {'captureSettings': {'flags': ['--terminate_after_timed']}},
                     {'captureSettings': {'flags': ['--qpc_time', '--qpc_time_ms']}},
                     {'presentMonExit': 1}, {'aliveAfter': False}, {'payloadAfterOk': False},
                     {'activation': {'ok': False}}, {'configDigestPolicy': None}, {'csvHeader': 'x'}):
            write(self.d, 'r', rec=receipt('r', **over)); self.rej()
        write(self.d, 'r'); os.remove(os.path.join(self.d, 'r.opening.json')); self.rej()
        write(self.d, 'r', side=sidecar(postStateProof='')); self.rej()

    def test_bad_ticks_schema_na_and_monotonic(self):
        rows = frames(); rows[10]['CPUStartQPC'] = '12.5'
        write(self.d, 'r', rows=rows); self.rej()
        rows = frames(); rows[10]['CPUStartQPC'] = rows[9]['CPUStartQPC']
        write(self.d, 'r', rows=rows); self.rej()
        rows = frames(); rows[10]['TimeInQPC'] = 'NA'
        write(self.d, 'r', rows=rows); self.rej()
        rows = frames(); rows[10]['TimeInQPC'] = rows[9]['TimeInQPC']
        write(self.d, 'r', rows=rows); self.rej()
        rows = frames(); rows[10]['MsBetweenAppStart'] = 'NA'
        write(self.d, 'r', rows=rows); self.rej()
        ms_hdr = [c if c != 'CPUStartQPC' else 'CPUStartTimeInMs' for c in HDR]
        write(self.d, 'r', rows=[], header=ms_hdr, rec=receipt('r', csvHeader=','.join(ms_hdr))); self.rej()
        drv = driver(); drv['injections'][0]['qpcBefore'] = 1.5e12
        write(self.d, 'r', drv=drv); self.rej()
        drv = driver(); drv['qpcFrequency'] = 0
        write(self.d, 'r', drv=drv); self.rej()

    def test_coverage_and_overlap_refused(self):
        write(self.d, 'r', rows=frames(end=T0 + 15_000 * MS)); self.rej()       # capture ends before last window
        write(self.d, 'r', rows=frames(start=T0 + 5_500 * MS)); self.rej()      # starts after first baseline
        drv = driver()
        for ev, inj in ((drv['events'][1], drv['injections'][2:4]),):           # move close tap into open's window
            shift = (ev['downQpcBefore'] - drv['events'][0]['upQpcAfter']) - 300 * MS
            for x in inj:
                x['qpcBefore'] -= shift; x['qpcAfter'] -= shift
            ev.update(downQpcBefore=inj[0]['qpcBefore'], downQpcAfter=inj[0]['qpcAfter'],
                      upQpcBefore=inj[1]['qpcBefore'], upQpcAfter=inj[1]['qpcAfter'])
        write(self.d, 'r', drv=drv); self.rej()

    def test_mixed_pid_rows_and_swapchain_excluded(self):
        rows = frames() + frames(pid=777, hitch_at=T0 + 5_100 * MS) + frames(swap='0x2')[:50]
        rows.sort(key=lambda r: int(r['CPUStartQPC']))
        mine = [r for r in rows if r['ProcessID'] == '1234' and r['SwapChainAddress'] == '0x1']
        write(self.d, 'r', rows=mine + [r for r in rows if r not in mine])
        res = O.run(self.d, 'r')
        self.assertGreater(res['excluded']['other_pid'], 0)
        self.assertEqual(res['excluded']['other_swapchain'], 50)
        self.assertEqual(res['events'][0]['maxMsBetweenAppStart'], 7.0)

    def test_table_rejects_mixed_payload_and_separates_context(self):
        write(self.d, 'r1'); write(self.d, 'r2', rec=receipt('r2', configDigest='OTHER'))
        res = O.table(self.d)
        self.assertEqual(len({s['context'] for s in res['summary']}), 2)
        write(self.d, 'r3', rec=receipt('r3', wheelHashes={'Scripts\\main.lua': 'X'}))
        with self.assertRaises(O.InputError):
            O.table(self.d)

    def test_cycles_validated(self):
        for bad in (True, 0, 5, 2.0, '3'):
            drv = driver(); drv['cycles'] = bad
            write(self.d, 'r', drv=drv); self.rej()

    def test_qpc_interval_reported_and_mapping_checked(self):
        drv = driver()
        a = drv['events'][0]['downQpcBefore']
        write(self.d, 'r', rows=frames(hitch_at=a + 50 * MS), drv=drv)
        res = O.run(self.d, 'r')
        e0 = res['events'][0]
        self.assertAlmostEqual(e0['maxQpcIntervalMs'], 60.0)
        self.assertAlmostEqual(e0['excessQpcInterval'], 53.0)
        self.assertEqual((res['qpc_mapping']['cpu']['max_abs_diff_ms'], res['qpc_mapping']['present']['max_abs_diff_ms']), (0.0, 0.0))
        # Misaligned rows (MsBetweenAppStart shifted by one row) must show up in the mapping report.
        rows = frames(hitch_at=a + 50 * MS)
        vals = [r['MsBetweenAppStart'] for r in rows]
        for r, v in zip(rows, ['7.0000'] + vals[:-1]):
            r['MsBetweenAppStart'] = v
        write(self.d, 'r', rows=rows, drv=drv)
        self.assertGreaterEqual(O.run(self.d, 'r')['qpc_mapping']['cpu']['max_abs_diff_ms'], 50.0)

    def test_frequency_is_context_and_events_are_not_process_repeats(self):
        write(self.d, 'r1')
        write(self.d, 'r2')
        res = O.table(self.d)
        open1 = [s for s in res['summary'] if s['kind'] == 'open' and s['class'] == 'repeat-intended'][0]
        self.assertEqual((open1['events'], open1['process_runs']), (4, 1))   # same pid/procStart in both fixtures
        drv = driver(); drv['qpcFrequency'] = F * 2
        write(self.d, 'r3', drv=drv, rows=[{**r, 'CPUStartQPC': str(T0 + (int(r['CPUStartQPC']) - T0) * 2),
                                        'TimeInQPC': str(T0 + (int(r['TimeInQPC']) - T0) * 2)} for r in frames()])
        with open(os.path.join(self.d, 'r3.events.json')) as f:
            drv3 = json.load(f)
        for x in drv3['injections']:
            x['qpcBefore'] = T0 + (x['qpcBefore'] - T0) * 2; x['qpcAfter'] = T0 + (x['qpcAfter'] - T0) * 2
        for ev, k in ((ev, i) for i, ev in enumerate(drv3['events'])):
            d, u = drv3['injections'][2 * k], drv3['injections'][2 * k + 1]
            ev.update(downQpcBefore=d['qpcBefore'], downQpcAfter=d['qpcAfter'], upQpcBefore=u['qpcBefore'], upQpcAfter=u['qpcAfter'])
        drv3['goQpc'] = T0 + (drv3['goQpc'] - T0) * 2
        with open(os.path.join(self.d, 'r3.events.json'), 'w') as f:
            json.dump(drv3, f)
        res = O.table(self.d)
        self.assertEqual(len({s['context'] for s in res['summary']}), 2)
        r3 = O.run(self.d, 'r3')
        self.assertAlmostEqual(r3['events'][0]['tapMs'], 120.1, places=3)   # same ms after rescaling ticks

    def test_present_interval_attributed_by_its_own_interval(self):
        # The present interval ending at row j starts INSIDE the open window while row j's CPU interval starts AFTER
        # it. Selecting presents via CPU intervals (the old attribution) would miss the ~47 ms present interval.
        drv = driver()
        e0 = drv['events'][0]
        b = e0['upQpcAfter'] + 750 * MS
        for off in range(0, 7 * MS, MS // 2):     # shift the capture phase until the geometry holds
            cs = [int(r['CPUStartQPC']) for r in frames(start=T0 + off)]
            j = next(i for i, c in enumerate(cs) if c > b)
            rows = frames(start=T0 + off, present_lag={cs[j]: 40})
            tp = [int(r['TimeInQPC']) for r in rows]
            if tp[j - 1] < b < tp[j]:
                break
        self.assertTrue(cs[j] > b and tp[j - 1] < b < tp[j])     # fixture geometry
        write(self.d, 'r', rows=rows, drv=drv)
        ev = O.run(self.d, 'r')['events'][0]
        self.assertEqual(ev['maxMsBetweenAppStart'], 7.0)
        self.assertGreaterEqual(ev['maxMsBetweenPresents'], 45.0)
        # Reverse: a long CPU interval starting 20 ms before the tap counts for the CPU series.
        write(self.d, 'r', rows=frames(hitch_at=e0['downQpcBefore'] - 20 * MS), drv=drv)
        self.assertEqual(O.run(self.d, 'r')['events'][0]['maxMsBetweenAppStart'], 60.0)

    def test_native_c1_head_mapping_zero_and_wrong_orientation_nonzero(self):
        import csv
        path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'fixtures', 'c1-native-head.csv')
        with open(path, newline='', encoding='utf-8-sig') as f:
            rd = csv.DictReader(f)
            header = rd.fieldnames
            pid = int(next(rd)['ProcessID'])
        cpu, prs, _, _ = O.load_frames(path, {'csvHeader': ','.join(header), 'pid': pid}, 'c1head')
        m = {'cpu': O.add_intervals(cpu, 10_000_000, 'x'), 'present': O.add_intervals(prs, 10_000_000, 'x')}
        self.assertEqual((m['cpu']['max_abs_diff_ms'], m['present']['max_abs_diff_ms']), (0.0, 0.0))
        self.assertEqual((m['cpu']['intervals'], m['present']['intervals']), (79, 79))
        # Wrong orientation (present metric on the CPU-row interval, or AppStart on the preceding present interval)
        # does not match on native data.
        wrong_p = max(abs(c['qpcMs'] - p['v']) for c, p in zip(cpu[1:], prs))
        wrong_a = max(abs(p['qpcMs'] - c['v']) for c, p in zip(cpu[1:], prs))
        self.assertGreater(wrong_p, 0.1)   # native head is steady (~11 ms); exact orientation is 0.0
        self.assertGreater(wrong_a, 0.1)


if __name__ == '__main__':
    unittest.main(verbosity=1)
