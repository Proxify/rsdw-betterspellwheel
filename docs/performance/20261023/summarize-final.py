"""Reproduce reviewed selection and descriptive summaries; no media processing."""
import hashlib,json,statistics
from pathlib import Path
P=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
a=json.loads((P/'primary-final.json').read_text());o=json.loads((P/'opening-final.json').read_text())
assert len(a['runs'])==27 and len(o['runs'])==7
roles={'main':'B','pr6':'D','pr7':'C'}
m={'version':1,'analyzerSha256':sha(P/'primary-final.json'),'openingAnalyzerSha256':sha(P/'opening-final.json'),'supplementary':['B1-closed','B1-open','B1-nav','C1-open','C1-nav','D1-open','D1-nav'],'cases':{},'openingCases':{}}
lines=['# Final native measurements — descriptive results','', 'PR7 is not faster overall in these runs. Its open-idle p99 is lower; closed-idle ranges overlap; navigation is worse than PR6, and opening Q-event frame gaps are longer than both baselines. No statistical significance or causal attribution is established.','', 'All times below are milliseconds. Cells are median [minimum–maximum] across independent cold processes. These are run ranges, not confidence intervals.','', 'Steady percentiles use MsBetweenPresents; Q-event gaps below use adjacent CPUStartQPC intervals.', '', '## Prespecified matched comparison','', '| Case (per-process p99) | Main | PR6 | PR7 | Processes Main/PR6/PR7 |','|---|---:|---:|---:|---|']
fmt=lambda v:f'{statistics.median(v):.3f} [{min(v):.3f}–{max(v):.3f}]'
for case in ('closed','open','nav'):
 sel={role:[r for r in a['runs'] if r['case']==case and r['arm']==arm and (case=='closed' or r['label'].split('-')[0] not in ('D1','C1'))] for role,arm in roles.items()}
 assert all(r['context']=='1cb23bf2f0b1' for rs in sel.values() for r in rs)
 m['cases'][case]={'context':'1cb23bf2f0b1','roles':{role:[r['label'] for r in rs] for role,rs in sel.items()}}
 lines.append('| '+case+' | '+' | '.join(fmt([r['frametime_ms']['p99'] for r in rs]) for rs in sel.values())+' | '+'/'.join(str(len(rs)) for rs in sel.values())+' |')
lines+=['','Open/nav exclude only C1/D1 per the predeclared preconditioning rule; every raw sample remains in the full table below. Closed uses all three runs per arm.','', '## Q-event windows','', 'The first event is first-in-process with generated artwork already cached, not first-ever drawing. Repeat value is the worse of open:2/open:3 in each process. Close value below is the worst of its three close events per process. These are longest CPU-start intervals around intended key presses, not input latency or visual open/close completion.','', '| Window statistic | Main | PR6 | PR7 | Processes |','|---|---:|---:|---:|---|']
sel={role:[r for r in o['runs'] if r['arm']==arm] for role,arm in roles.items()}
m['openingCases']['open-repeat']={'context':'552b7246d94d','roles':{role:[{'label':r['label'],'events':['open:2','open:3']} for r in rs] for role,rs in sel.items()}}
for cls,kind,label in [('first-in-process','open','First intended open'),('repeat-intended','open','Worst repeat open/process'),('close-intended','close','Worst intended close/process')]:
 vals={role:[max(e['maxQpcIntervalMs'] for e in r['events'] if e['class']==cls and e['kind']==kind) for r in rs] for role,rs in sel.items()}
 lines.append('| '+label+' | '+' | '.join(fmt(v) for v in vals.values())+' | 3/2/2 |')
lines+=['','Both CPU and presentation interval mappings have zero maximum absolute difference from their respective CSV metrics in all seven runs. No >=50 ms opening/closing window was observed. The asymmetric open/close gaps are observations, not an identified mechanism.','', '## All steady samples, without selection','', '| Label | p50 | p95 | p99 | p99.9 | Maximum | >=50 ms frames | >=100 ms frames |','|---|---:|---:|---:|---:|---:|---:|---:|']
for r in a['runs']:
 lines.append('| '+r['label']+' | '+' | '.join(f"{r['frametime_ms'][k]:.4f}" for k in ('p50','p95','p99','p999','max'))+f" | {r['hitch_ge50']} | {r['hitch_ge100']} |")
lines+=['','## Interpretation','', '- Matched open-idle median p99 is 4.4% lower than Main and 5.1% lower than PR6; observed run ranges do not overlap. This is a small single-PC sample.', '- Matched navigation median p99 is 6.1% higher than PR6 and essentially equal to Main. PR7 and PR6 run ranges do not overlap here.', '- Closed-idle ranges overlap; there is no clear closed-wheel advantage from this test.', '- Repeat-open worst-frame median is 24.444 ms for PR7 versus 14.332 Main and 15.076 PR6. PR7 had longer event-window frames. Conversely its worst close-event median was lower (15.212 versus 26.113/25.414 ms). Do not pool open and close or claim input latency.', '- The severe closed-wheel difference between these builds is not reproduced here. There is no mod-off arm in this final set, so it cannot quantify overhead versus the unmodified game or show the reporter’s issue fixed.', '- Casting reuse was not tested natively and is not included. No production merge/release is justified by this report alone.','', 'See NATIVE-COMPARISON-DRAFT.md for environment/method, PRECONDITIONING-NOTE.md for selection provenance, final JSON for CPU/GPU metrics and receipt fields, and the independent audit for recomputation. Functional acceptance and cleanup remain separately tracked.','']
(P/'accepted-runs.json').write_text(json.dumps(m,indent=2)+'\n')
(P/'NATIVE-RESULTS.md').write_text('\n'.join(lines))
print('manifest',sha(P/'accepted-runs.json'))
print('\n'.join(lines[:25]))
