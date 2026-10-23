#!/usr/bin/env python3
"""Fixture tests for analyze.py. Run: python3 -I test_analyze.py (from any directory)."""
import json, os, sys, tempfile, unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import analyze as A  # noqa: E402

HDR = 'Application,ProcessID,SwapChainAddress,PresentRuntime,SyncInterval,PresentFlags,AllowsTearing,PresentMode,CPUStartTime,MsBetweenSimulationStart,MsBetweenPresents,MsBetweenDisplayChange,MsInPresentAPI,MsRenderPresentLatency,MsUntilDisplayed,MsPCLatency,MsBetweenAppStart,MsCPUBusy,MsCPUWait,MsGPULatency,MsGPUTime,MsGPUBusy,MsGPUWait,MsAnimationError,AnimationTime,MsAllInputToPhotonLatency,MsClickToPhotonLatency'
COLS = HDR.split(',')
EXE = 'RSDragonwilds-Win64-Shipping.exe'


def row(pid=1234, swap='0x1', t=0.0, ft=7.0, cpu=6.0, gpu=4.0, extra=None):
    v = {c: '0' for c in COLS}
    v.update({'Application': EXE, 'ProcessID': str(pid), 'SwapChainAddress': swap, 'PresentRuntime': 'DXGI',
              'CPUStartTime': f'{t:.4f}', 'MsBetweenPresents': ft if isinstance(ft, str) else f'{ft:.4f}',
              'MsCPUBusy': cpu if isinstance(cpu, str) else f'{cpu:.4f}', 'MsGPUBusy': gpu if isinstance(gpu, str) else f'{gpu:.4f}'})
    if extra:
        v.update(extra)
    return v


def write(d, label, rows, header=COLS, receipt=None):
    with open(os.path.join(d, label + '.csv'), 'w', newline='') as f:
        f.write(','.join(header) + '\n')
        for r in rows:
            f.write(','.join(str(r.get(c, '')) for c in header) + '\n')
    rec = {'label': label, 'arm': 'B', 'case': 'idle', 'pid': 1234, 'schema': A.PM_SCHEMA, 'csvHeader': ','.join(header),
           'computer': 'BLADE', 'clientBuild': '26088737', 'exeHash': 'E1', 'aliveAfter': True,
           'presentMonArgs': f'--process_id 1234 --output_file C:\\x\\{label}.csv --timed 45 --terminate_after_timed',
           'presentMonExit': 0, 'payloadAfterOk': True,
           'activation': {'ok': True, 'BetterSpellWheel': 1, 'AllSpellsOneWheel': 0},
           'captureSettings': {'tool': 'PresentMon-2.6.0-x64.exe', 'seconds': 45, 'warmupS': 60,
                               'flags': ['--terminate_after_timed', '--no_console_stats']},
           'scene': 'MODTEST/spot1/yaw90', 'configDigest': 'CFG1', 'ue4ssConfig': {'UE4SS-settings.ini': 'U1'},
           'otherModsDigest': 'OM1', 'modsTxtNonWheel': ['Keybinds : 1'],
           'wheelHashes': {'Scripts\\main.lua': 'H1'}}
    rec.update(receipt or {})
    with open(os.path.join(d, label + '.receipt.json'), 'w') as f:
        json.dump(rec, f)
    return os.path.join(d, label + '.csv')


def steady(n=6430, ft=7.0, **kw):   # about 45 s at 7 ms
    return [row(t=i * ft, ft=ft, **kw) for i in range(n)]


class T(unittest.TestCase):
    def setUp(self):
        self.td = tempfile.TemporaryDirectory(prefix='bsw115-test.')
        self.d = self.td.name

    def tearDown(self):
        self.td.cleanup()

    def test_45s_duration_and_warmup_skip(self):
        r = A.run(write(self.d, 'a', steady()))
        self.assertAlmostEqual(r['duration_s'], 45.003, places=2)
        self.assertEqual(r['frames'], 6430)
        r5 = A.run(os.path.join(self.d, 'a.csv'), skip_s=5)
        self.assertEqual(r5['excluded']['warmup'], 715)        # t < 5000 ms: indices 0..714
        self.assertAlmostEqual(r5['duration_s'], 40.0, delta=0.01)

    def test_na_rows_excluded_and_counted(self):
        rows = steady(100)
        rows[0]['MsBetweenPresents'] = 'NA'
        rows[50]['MsCPUBusy'] = 'NA'
        rows[51]['MsGPUBusy'] = 'NA'
        r = A.run(write(self.d, 'na', rows))
        self.assertEqual(r['frames'], 99)
        self.assertEqual(r['excluded']['frametime_na'], 1)
        self.assertEqual(r['cpu_busy_ms']['n'], 99)
        self.assertEqual(r['gpu_busy_ms']['n'], 99)

    def test_actual_default_timestamp_alias_preserves_ms_and_warmup(self):
        hdr = [c if c != 'CPUStartTime' else 'CPUStartTimeInMs' for c in COLS]
        rows = steady()
        for r in rows:
            r['CPUStartTimeInMs'] = r.pop('CPUStartTime')
        actual = A.run(write(self.d, 'actual', rows, header=hdr), skip_s=5)
        documented = A.run(write(self.d, 'documented', steady()), skip_s=5)
        for k in ('duration_s', 'frames', 'excluded', 'frametime_ms', 'cpu_busy_ms', 'gpu_busy_ms'):
            self.assertEqual(actual[k], documented[k])
        self.assertEqual(actual['timestamp_column'], 'CPUStartTimeInMs')
        self.assertEqual(actual['timestamp_unit'], 'ms')
        # Raw headers still separate contexts; no silent CSV rewriting.
        self.assertNotEqual(actual['context'], documented['context'])

    def test_ambiguous_or_missing_timestamp_rejected(self):
        for hdr in (COLS + ['CPUStartTimeInMs'], COLS + ['CPUStartTime'],
                    [c for c in COLS if c != 'CPUStartTime']):
            with self.assertRaisesRegex(A.SchemaError, 'exactly one millisecond'):
                A.run(write(self.d, 'ambiguous', steady(10), header=hdr))

    def test_timestamp_units_not_guessed(self):
        for col in ('CPUStartTimeInSeconds', 'CPUStartQPCTimeInMs', 'CPUStartQPC', 'CPUStartDateTime'):
            hdr = [c if c != 'CPUStartTime' else col for c in COLS]
            with self.assertRaisesRegex(A.SchemaError, 'unexpected'):
                A.run(write(self.d, 'units', steady(10), header=hdr))

    def test_actual_timestamp_non_numeric_rejected(self):
        hdr = [c if c != 'CPUStartTime' else 'CPUStartTimeInMs' for c in COLS]
        with self.assertRaisesRegex(A.SchemaError, 'non-numeric CPUStartTimeInMs'):
            A.run(write(self.d, 'bad-time', steady(10), header=hdr))

    def test_all_gpu_na_is_unavailable(self):
        r = A.run(write(self.d, 'g', steady(50, gpu='NA')))
        self.assertEqual(r['gpu_busy_ms'], 'unavailable')

    def test_mixed_pids_filtered_to_receipt_pid(self):
        rows = steady(100) + [row(pid=999, t=i, ft=500.0) for i in range(40)]
        r = A.run(write(self.d, 'mp', rows))
        self.assertEqual(r['excluded']['other_pid'], 40)
        self.assertEqual(r['frametime_ms']['max'], 7.0)

    def test_no_rows_for_pid_rejected(self):
        with self.assertRaises(A.SchemaError):
            A.run(write(self.d, 'np', steady(10), receipt={'pid': 4321}))

    def test_secondary_swapchain_excluded(self):
        rows = steady(100) + [row(swap='0x2', t=i, ft=300.0) for i in range(5)]
        r = A.run(write(self.d, 'sc', rows))
        self.assertEqual(r['excluded']['other_swapchain'], 5)
        self.assertEqual(r['hitch_ge50'], 0)

    def test_generated_frames_excluded(self):
        hdr = COLS + ['FrameType']
        rows = [row(t=i * 7, extra={'FrameType': 'Application'}) for i in range(60)]
        rows += [row(t=i * 7 + 3, ft=3.5, extra={'FrameType': 'Intel XEFG'}) for i in range(60)]
        r = A.run(write(self.d, 'fg', rows, header=hdr))
        self.assertEqual(r['frames'], 60)
        self.assertEqual(r['excluded']['non_application_frametype'], 60)
        self.assertEqual(r['frametime_ms']['p50'], 7.0)

    def test_frametype_filter_empty_is_error_not_fallback(self):
        hdr = COLS + ['FrameType']
        rows = [row(t=i, extra={'FrameType': 'AMD AFMF'}) for i in range(10)]
        with self.assertRaises(A.SchemaError):
            A.run(write(self.d, 'fe', rows, header=hdr))

    def test_unknown_or_wrong_schema_rejected(self):
        with self.assertRaises(A.SchemaError):
            A.run(write(self.d, 'u1', steady(10), receipt={'schema': 'presentmon-2.3'}))
        v1 = [c if c != 'CPUStartTime' else 'TimeInSeconds' for c in COLS]
        with self.assertRaises(A.SchemaError):
            A.run(write(self.d, 'u2', [], header=v1))
        nogpu = [c for c in COLS if c != 'MsGPUBusy']
        with self.assertRaises(A.SchemaError):
            A.run(write(self.d, 'u3', steady(10), header=nogpu))

    def test_header_must_match_receipt(self):
        p = write(self.d, 'hm', steady(10), receipt={'csvHeader': 'Application,ProcessID'})
        with self.assertRaises(A.SchemaError):
            A.run(p)

    def test_missing_receipt_rejected(self):
        p = write(self.d, 'mr', steady(10))
        os.remove(os.path.join(self.d, 'mr.receipt.json'))
        with self.assertRaises(A.SchemaError):
            A.run(p)

    def test_hitch_and_percentiles(self):
        rows = steady(1000)
        rows[500]['MsBetweenPresents'] = '120.0'
        r = A.run(write(self.d, 'h', rows))
        self.assertEqual((r['hitch_ge50'], r['hitch_ge100'], r['frametime_ms']['max']), (1, 1, 120.0))
        self.assertEqual(r['frametime_ms']['p99'], 7.0)

    def test_table_separates_contexts_and_rejects_mixed_payloads(self):
        write(self.d, 'b1', steady(100))
        write(self.d, 'b2', steady(100, ft=8.0))
        write(self.d, 'b3', steady(100), receipt={'clientBuild': '99999'})   # other build: separate context
        res = A.table(self.d, quiet=True)
        self.assertEqual(len(res['summary']), 2)
        main = [s for s in res['summary'] if s['runs'] == 2][0]
        self.assertEqual(main['p50']['median'], 7.5)
        write(self.d, 'b4', steady(100), receipt={'wheelHashes': {'Scripts\\main.lua': 'OTHER'}})
        with self.assertRaises(A.SchemaError):
            A.table(self.d, quiet=True)

    def test_frameprobe_schema(self):
        p = os.path.join(self.d, 'fp.csv')
        with open(p, 'w') as f:
            f.write('frame,t_s,dt_ms\n' + ''.join(f'{i+1},{100 + i * 0.007:.3f},7.00\n' for i in range(1000)))
        with open(os.path.join(self.d, 'fp.receipt.json'), 'w') as f:
            json.dump({'label': 'fp', 'arm': 'S', 'case': 'idle', 'pid': 1, 'schema': A.FP_SCHEMA}, f)
        r = A.run(p)
        self.assertEqual((r['frames'], r['cpu_busy_ms'], r['gpu_busy_ms']), (1000, 'unavailable', 'unavailable'))

    def test_failed_capture_receipts_rejected(self):
        for i, bad in enumerate([{'presentMonExit': 1}, {'aliveAfter': False}, {'payloadAfterOk': False},
                                 {'activation': {'ok': False, 'BetterSpellWheel': 0}}, {'scene': None}]):
            with self.assertRaises(A.SchemaError, msg=str(bad)):
                A.run(write(self.d, f'bad{i}', steady(20), receipt=bad))

    def test_varied_settings_are_separate_contexts(self):
        write(self.d, 'c1', steady(50))
        write(self.d, 'c2', steady(50), receipt={'captureSettings': {'tool': 'PresentMon-2.6.0-x64.exe', 'seconds': 30,
                                                                     'warmupS': 60, 'flags': ['--terminate_after_timed', '--no_console_stats']}})
        write(self.d, 'c3', steady(50), receipt={'scene': 'MODTEST/spot2'})
        write(self.d, 'c4', steady(50), receipt={'configDigest': 'CFG2'})
        write(self.d, 'c5', steady(50), receipt={'otherModsDigest': 'OM2'})
        res = A.table(self.d, quiet=True)
        self.assertEqual(len({s['context'] for s in res['summary']}), 5)

    def test_pid_and_output_path_do_not_split_context(self):
        write(self.d, 'p1', steady(50))
        write(self.d, 'p2', [row(pid=4321, t=i * 7.0) for i in range(50)], receipt={'pid': 4321})
        res = A.table(self.d, quiet=True)
        self.assertEqual(len(res['summary']), 1)
        self.assertEqual(res['summary'][0]['pids'], ['1234', '4321'])

    def _fp(self, body, rec=None):
        p = os.path.join(self.d, 'fpx.csv')
        with open(p, 'w') as f:
            f.write('frame,t_s,dt_ms\n' + body)
        r = {'label': 'fpx', 'arm': 'S', 'case': 'idle', 'pid': 1, 'schema': A.FP_SCHEMA}
        r.update(rec or {})
        with open(os.path.join(self.d, 'fpx.receipt.json'), 'w') as f:
            json.dump(r, f)
        return p

    def test_frameprobe_bad_inputs_rejected_cleanly(self):
        for body in ['', 'x,NA,7.0\n2,1.0,7.0\n', '1,,7.0\n', '1,1.0\n']:
            with self.assertRaises(A.SchemaError, msg=repr(body)):
                A.run(self._fp(body))
        with self.assertRaises(A.SchemaError):
            A.run(self._fp('1,1.0,7.0\n', {'aliveAfter': False}))


if __name__ == '__main__':
    unittest.main(verbosity=1)
