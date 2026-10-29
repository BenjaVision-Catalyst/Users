#!/usr/bin/env python3
"""Account for existing durable completion records without treating body time as commit time."""
import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path


def summarize_records(observation):
    rows = observation['records']
    if len(rows) != observation['recordCount']:
        raise ValueError('Record count mismatch')
    workers = defaultdict(list)
    for row in rows:
        if row['completionRecordingOutcome'] != 'recorded':
            raise ValueError('Unqualified durable completion outcome')
        workers[row['worker']].append(row)
    if set(workers) != set(observation['heads']):
        raise ValueError('Worker/head coverage mismatch')
    result = {}
    for worker, records in workers.items():
        head = observation['heads'][worker]
        ordered = sorted(records, key=lambda row: row['sequence'])
        if [row['sequence'] for row in ordered] != list(range(1, head['sequence'] + 1)):
            raise ValueError('Duplicate, missing or truncated durable completion sequence')
        if len({row['generation'] for row in ordered}) != 1:
            raise ValueError('Worker generations must not be combined')
        if any(row['host'] != head['host'] for row in ordered):
            raise ValueError('Worker host changed')
        classes = defaultdict(list)
        for row in ordered:
            classes[row['workUnitClass']].append(row)
        groups = []
        for name, samples in sorted(classes.items(), key=lambda pair: -len(pair[1])):
            flags = {row['requiresTransaction'] for row in samples}
            if len(flags) != 1:
                raise ValueError('Transaction contract changed within a class capture')
            groups.append(dict(workUnitClass=name, count=len(samples), sharePercent=100*len(samples)/len(records),
                               requiresTransaction=flags.pop(), transactionOutcomes=dict(Counter(row['transactionOutcome'] for row in samples)),
                               successful=sum(row['successful'] for row in samples),
                               recordedBodyDurationMillis=sum(row['durationMillis'] for row in samples),
                               maximumBodyDurationMillis=max(row['durationMillis'] for row in samples)))
        result[worker] = dict(host=head['host'], generation=ordered[0]['generation'], count=len(records),
                              finalSequence=head['sequence'], retentionLimit=head['retentionLimit'], retainedAtEnd=head['retained'],
                              nontransactionalCompletionCount=sum(not row['requiresTransaction'] for row in records), classes=groups)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--vsd-analysis', type=Path, help='Existing analyze-user-vsd.py output; write verified commit-chart inputs')
    args = parser.parse_args()
    capture = args.capture.resolve()
    observation = json.loads((capture / 'workload/workunits/records.json').read_text())
    manifest = json.loads((capture / 'native/manifest.json').read_text())
    qualification = json.loads((capture / 'workload/qualification.json').read_text())
    if not qualification['passed'] or not manifest['passed']:
        raise ValueError('Qualified workload and native capture required')
    workers = summarize_records(observation)
    for worker in qualification['started']['workers']:
        summary = workers[worker['workerIdentifier']]
        if summary['generation'] != worker['process']['token']:
            raise ValueError('Durable records do not belong to the launched worker generation')
        instances = [p for p in manifest['processes'] if p['type'] == 'Gem' and p['pid'] == worker['process']['pid']]
        summary['nativeIdentities'] = instances
        primary = max(instances, key=lambda p:p['samples'])
        summary['primaryNativeCommitDelta'] = primary['delta']['CommitCount']
        summary['primaryNativeCommitMinusJournalCount'] = primary['delta']['CommitCount'] - summary['count']
    observer_instances = [p for p in manifest['processes'] if p['type'] == 'Gem' and p['pid'] == observation['pid']]
    if not observer_instances or any(p['delta']['CommitCount'] for p in observer_instances):
        raise ValueError('Read-only observer missing or issued native commits')
    offset = manifest['beforeWorkload']['wallUs'] - manifest['beforeWorkload']['monotonicUs']
    idle = []
    for case in sorted((capture / 'workload').glob('fanout_users_*')):
        if not case.is_dir():
            continue
        final = {state['userIdentifier']:state['revision'] for state in json.loads((case/'final.json').read_text())}
        clients = [client for path in case.glob('result-*.json') for client in json.loads(path.read_text())['observers']]
        ready = []
        for client in clients:
            if client['requestsAtFinalReadiness'] != client['requestsAtEnd']:
                raise ValueError('Idle window contains client application requests')
            for identity, revision in final.items():
                times = [event['at'] for event in client['arrivals'] if event['user'] == identity and event['revision'] == revision]
                if not times:
                    raise ValueError('Missing final arrival for idle-window qualification')
                ready.append(max(times))
        start = max(ready)*1000 + offset/1000 + 150
        end = min(path.stat().st_mtime*1000 for path in case.glob('result-*.json')) - 150
        if end <= start:
            raise ValueError('No conservative idle window')
        # End time is pre-outer-commit; require visibility by the end as well.
        records = [row for row in observation['records'] if row['host']=='application'
                   and row['endMillis'] >= start and row['firstObservedMillis'] <= end]
        counts = dict(Counter(row['workUnitClass'] for row in records))
        idle.append(dict(clients=len(clients), startMillis=start, endMillis=end, durationMillis=end-start,
                         completedVisibleRecords=counts, applicationRequests=0,
                         note='Boundaries exclude 150 ms; retained completions must end and be observed within the window.'))
    report = dict(workers=workers, idleWindows=idle, observerNativeIdentities=observer_instances,
                  sequenceComplete=True, repositoryRetentionUnchanged=True,
                  notes=['Every row is existing durable completion evidence, including nontransactional/inMemory work.',
                         'Class counts include agreement probes, reads, subscriptions and control work; they are not mutation counts.',
                         'Recorded body durations exclude the final outer completion commit and can contain native waits.',
                         'Primary native counter windows exclude process-name boundaries; residuals are not exact per-request commit attribution.',
                         'First-observation timestamps include observer polling and snapshot effects; they are not commit latency measurements.'])
    args.output.write_text(json.dumps(report, indent=2)+'\n')
    if args.vsd_analysis:
        analysis = json.loads((args.vsd_analysis / 'analysis.json').read_text())
        application = [w for w in qualification['started']['workers'] if w['hostIdentifier'] == 'application']
        control = [w for w in qualification['started']['workers'] if w['hostIdentifier'] != 'application']
        if len(application) != 1 or len(control) != 1 or application[0]['process']['pid'] != analysis['servingPid']:
            raise ValueError('Chart inputs require the same capture and one control/application worker')
        window = next(w for w in idle if w['clients'] == 60)
        origin = analysis['captureOriginUs']/1000
        (args.vsd_analysis / 'workunit-charts.tcl').write_text('\n'.join([
            f'set catalystControlPid {control[0]["process"]["pid"]}',
            f'set catalystIdleStart {window["startMillis"]-origin}',
            f'set catalystIdleEnd {window["endMillis"]-origin}', '']))
    print(json.dumps({row['host']:dict(records=row['count'], nativeCommitDelta=row['primaryNativeCommitDelta']) for row in workers.values()}))


if __name__ == '__main__':
    main()
