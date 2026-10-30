#!/usr/bin/env python3
"""Compare configuration-only Users qualifications; retain counters and timing limits."""
import argparse
from collections import Counter
import json
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--experiment', type=Path, required=True)
    parser.add_argument('--statistics-tools', type=Path, required=True)
    args = parser.parse_args()
    base = args.experiment.resolve()
    sys.path.insert(0, str(args.statistics_tools.resolve()))
    from native_statmonitor import read_capture, identities
    plan = json.loads((base/'plan.json').read_text())
    experiment = json.loads((base/'experiment.json').read_text())
    if not experiment.get('passed'):
        raise ValueError('All planned qualifications must finish through normal cleanup')
    cases, chart_cases, writer_points = [], [], []
    source_revisions = set()
    for spec in plan['cases']:
        directory = base/spec['name']
        qualification = json.loads((directory/'workload/qualification.json').read_text())
        native = json.loads((directory/'native/manifest.json').read_text())
        cadence = {key:spec[key] for key in ('idleMillis','reconcileIntervalMillis','heartbeatIntervalMillis')}
        parameters = json.loads((directory/'workload/parameters.json').read_text())
        if parameters.get('readinessEnabled', False) != spec.get('readinessEnabled', False) or qualification['persistence'].get('readinessEnabled',False) != spec.get('readinessEnabled',False):
            raise ValueError('Requested readiness mode mismatch')
        if not (qualification['passed'] and native['passed'] and qualification['persistence']['cadenceConfiguration'] == cadence):
            raise ValueError('Unqualified case or accepted configuration mismatch')
        source_revisions.add(json.dumps(qualification['sourceSHA256'], sort_keys=True))
        output = directory/'workunit-mix.json'
        subprocess.run([sys.executable, str(Path(__file__).with_name('analyze-user-workunits.py')),
                        '--capture', str(directory), '--output', str(output)], check=True)
        mix = json.loads(output.read_text())
        observation = json.loads((directory/'workload/workunits/records.json').read_text())
        _, _, rows = read_capture(directory/'native/native.out')
        processes = identities(rows)
        offset = native['beforeWorkload']['wallUs'] - native['beforeWorkload']['monotonicUs']
        profile = qualification['profiles'][0]
        if len(qualification['profiles']) != 1 or profile['clients'] != 60:
            raise ValueError('Matched single 60-observer profile required')
        workload = next((directory/'workload').glob('fanout_users_*_60'))
        writes = json.loads((workload/'writer-result.json').read_text())['writes']
        first_burst = [write for write in writes if write['phase'] == 'burstA.json']
        begin = round(min(write['sentAt'] for write in first_burst)*1e6)+offset
        end = round(max(write['replyAt'] for write in first_burst)*1e6)+offset
        writer_points.extend(dict(case=spec['name'], xMillis=(round(write['replyAt']*1e6)+offset-begin)/1000,
                                  rttMillis=(write['replyAt']-write['sentAt'])*1000) for write in first_burst)
        idle = mix['idleWindows'][0]
        workers = {worker['host']:worker for worker in mix['workers'].values()}
        application = workers['application']
        control = next(value for key,value in workers.items() if key != 'application')
        def primary(kind, pid):
            return max(((key, values) for key,values in processes.items() if key[0] == kind and key[1] == pid), key=lambda pair:len(pair[1]))
        worker_pids = {worker['hostIdentifier']:worker['process']['pid'] for worker in qualification['started']['workers']}
        app_pid = worker_pids['application']
        control_pid = next(pid for host,pid in worker_pids.items() if host != 'application')
        app_series = primary('Gem',app_pid)[1]
        idle_pairs = [(a,b) for a,b in zip(app_series,app_series[1:])
                      if a['Time'] >= idle['startMillis']*1000 and b['Time'] <= idle['endMillis']*1000]
        if not idle_pairs:
            raise ValueError('No fully contained native idle intervals')
        idle_us = sum(b['Time']-a['Time'] for a,b in idle_pairs)
        idle_commits = sum(b['CommitCount']-a['CommitCount'] for a,b in idle_pairs)
        units = Counter(row['workUnitClass'] for row in observation['records'])
        user_records = [row for row in observation['records'] if row['workUnitClass'].startswith('CU')]
        if not all(row['successful'] and row['requiresTransaction'] and row['transactionOutcome'] == 'committed' for row in user_records):
            raise ValueError('Users transactional completion invariant failed')
        if not all(instance['delta']['CommitCount'] == 0 for instance in mix['observerNativeIdentities']):
            raise ValueError('Observation Gem committed')
        combined = application['primaryNativeCommitDelta'] + control['primaryNativeCommitDelta']
        retained_profile = {key:value for key,value in profile.items() if key not in ['serverMemorySamples','clientMemorySamples','perHealthyClient']}
        case = dict(name=spec['name'], readinessEnabled=spec.get('readinessEnabled',False), cadence=cadence, profile=retained_profile,
            applicationCompletions=application['count'], controlCompletions=control['count'], classCounts=dict(units),
            applicationNonDriveClassCounts=dict(Counter(row['workUnitClass'] for row in observation['records']
                if row['host'] == 'application' and row['workUnitClass'] != 'CCQuicDriveWork')),
            primaryApplicationNativeCommits=application['primaryNativeCommitDelta'], primaryControlNativeCommits=control['primaryNativeCommitDelta'],
            primaryCombinedNativeCommits=combined, primaryCombinedCommitsPerConfirmedWrite=combined/profile['updates'],
            idle=idle, idleVisibleDriveCompletionsPerSecond=idle['completedVisibleRecords'].get('CCQuicDriveWork',0)*1000/idle['durationMillis'],
            nativeIdleApplication=dict(coveredMillis=idle_us/1000, commitDelta=idle_commits, commitsPerSecond=idle_commits*1e6/idle_us,
                intervals=[dict(startUs=a['Time'],endUs=b['Time'],commits=b['CommitCount']-a['CommitCount']) for a,b in idle_pairs]),
            wallUptimeOffsetDriftUs=(native['afterWorkload']['wallUs']-native['afterWorkload']['monotonicUs'])-offset,
            firstBurst=dict(startUs=begin,endUs=end), unsuccessfulRecords=[row for row in observation['records'] if not row['successful']],
            nativeIdentities=dict(application=primary('Gem',app_pid)[0],control=primary('Gem',control_pid)[0]),
            independentGemPersistence=qualification['persistence'], gate=qualification['mcpGate'], cleanup=qualification['cleanup'],
            developmentRuntimePreserved=qualification['developmentRuntimePreserved'], observerNativeCommits=0,
            nativeCleanDetach=native['cleanDetach'], nativeSampleGapMaxUs=native['sampleGapMaxUs'])
        cases.append(case)
        short_label = {'baseline-before':'Baseline A','baseline-after':'Baseline B','control-defaults':'Control',
                       'idle-50':'Idle 50','idle-100':'Idle 100'}.get(spec['name'],spec['name'])
        chart_cases.append(dict(name=spec['name'], capture=str(directory/'native/native.out'),
            legend=f'{short_label}: {cadence["idleMillis"]}/{cadence["reconcileIntervalMillis"]}/{cadence["heartbeatIntervalMillis"]} ms',
            applicationPid=app_pid, controlPid=control_pid, stonePid=native['stonePid'],
            firstApplicationUs=primary('Gem',app_pid)[1][0]['Time'], firstControlUs=primary('Gem',control_pid)[1][0]['Time'],
            firstStoneUs=primary('Stn',native['stonePid'])[1][0]['Time'], firstBurstStartUs=begin, firstBurstEndUs=end,
            idleStartUs=round(idle['startMillis']*1000),idleEndUs=round(idle['endMillis']*1000)))
    if len(source_revisions) != 1:
        raise ValueError('Compared qualifications must use identical controller/application source snapshots')
    before, after = cases[0], cases[-1]
    for case in cases:
        case['combinedCommitReductionFactorVsBefore'] = before['primaryCombinedNativeCommits']/case['primaryCombinedNativeCommits']
        case['combinedCommitReductionFactorVsAfter'] = after['primaryCombinedNativeCommits']/case['primaryCombinedNativeCommits']
    result = dict(cases=cases, chartCases=chart_cases, sourcesIdentical=True, plan=plan,
        applicationNonDriveClassCountsIdentical=len({json.dumps(case['applicationNonDriveClassCounts'],sort_keys=True) for case in cases}) == 1,
        notes=['All cases use fresh configured Runtimes, identical release clients and 60 observers; offer schedule and concurrency are recorded per case.',
            'Primary native named-series commit windows include setup/teardown and exclude process-name boundaries; they are not per-message transaction counts.',
            'Delivered-state percentiles must be read with coverage, writer admission lag and actual confirmed throughput.',
            'Idle journal counts are conservative visible completions; first-observation timestamps are not commit latency.',
            'Native time counters overlap and are not additive phases; Stone counters include other Gems.',
            'Baseline-before/after bounds expose temporal host variation; this sequential experiment is not a randomized causal estimate.',
            'Unsuccessful startup/teardown records are retained; exception details are not present in this journal.'])
    (base/'comparison.json').write_text(json.dumps(result,indent=2)+'\n')
    (base/'chart-cases.json').write_text(json.dumps(chart_cases,indent=2)+'\n')
    (base/'writer-first-burst.tsv').write_text('case\txMillis\trttMillis\n'+'\n'.join(
        f'{point["case"]}\t{point["xMillis"]}\t{point["rttMillis"]}' for point in writer_points)+'\n')
    # Numeric fields and controlled labels only; Tcl braces protect paths.
    lines = []
    for case in chart_cases:
        fields = [case['name'], case['capture']] + [str(case[key]) for key in ['applicationPid','controlPid','stonePid',
            'firstApplicationUs','firstControlUs','firstStoneUs','firstBurstStartUs','firstBurstEndUs','idleStartUs','idleEndUs']]
        fields.append(case['legend'])
        if any('}' in field or '{' in field for field in fields):
            raise ValueError('Unsupported Tcl path delimiter')
        lines.append('    {' + ' '.join('{'+field+'}' for field in fields) + '}')
    (base/'chart-cases.tcl').write_text('set cadenceCases {\n'+'\n'.join(lines)+'\n}\n')
    print(json.dumps([dict(name=case['name'], commits=case['primaryCombinedNativeCommits'], burstP99=case['profile']['burstLatencyMillis']['p99'],
        coverage=case['profile']['minimumHealthyCoverage']) for case in cases]))


if __name__ == '__main__':
    main()
