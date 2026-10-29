"""Validate deferred Users diagnostics after the owning Runtime stops."""
import json
import math
from pathlib import Path


def percentile(values, fraction):
    values=sorted(values)
    return values[max(0, math.ceil(len(values)*fraction)-1)]


def validate_local_timings(output):
    evidence=json.loads((Path(output)/'worker-local-timings.json').read_text())
    rows=evidence['rows']
    if not evidence['worker'] or not 0<len(rows)<=evidence['maximumRows']<=50000:
        raise ValueError('Invalid worker-local timing bound or owner')
    if [r['sequence'] for r in rows]!=list(range(1,evidence['lastSequence']+1)):
        raise ValueError('Worker-local timing sequence gap')
    for row in rows:
        times=row['localTimings'] or {}
        for phase in ('outerCommit','resultFinalization'):
            keys=[phase+suffix for suffix in ('StartedMillis','FinishedMillis','Outcome')]
            if any(key in times for key in keys):
                if not all(key in times for key in keys) or times[keys[1]]<times[keys[0]]:
                    raise ValueError('Incomplete or reversed worker-local timing')
        if 'resultFinalizationStartedMillis' in times and 'outerCommitFinishedMillis' in times:
            if times['resultFinalizationStartedMillis']<times['outerCommitFinishedMillis']:
                raise ValueError('Result finalization preceded outer commit')
    return dict(worker=evidence['worker'],rows=len(rows),lastSequence=evidence['lastSequence'],sequenceComplete=True)


def validate_buffered_diagnostics(output, profiles):
    output=Path(output)
    exported=json.loads((output/'sampler-export.json').read_text())
    if not (exported['completed'] and exported['mode']=='buffered' and exported['ownerProcessVerified'] and exported['failure'] is None):
        raise ValueError('Sampler export failed or lost its owner')
    count=exported['sampleCount']
    startup=exported['startupSkips']
    if len(startup)>exported['maximumSamples'] or any(t>=min(p['diagnosticWindow']['startMillis'] for p in profiles) for t,reason in startup):
        raise ValueError('Startup diagnostics unavailable during timed workload')
    if not 0<count<=exported['maximumSamples'] or exported['sampleAttempts'] != count+exported['skippedNativeBusy']+len(startup):
        raise ValueError('Sampler overflow, missing snapshots or attempt accounting mismatch')
    paths=sorted(output.glob('native-[0-9]*.json'),key=lambda p:int(p.stem.split('-')[1]))
    if [int(p.stem.split('-')[1]) for p in paths] != list(range(1,count+1)):
        raise ValueError('Missing, duplicated or unexpected buffered sample')
    samples=[json.loads(path.read_text()) for path in paths]
    if exported['exportStartedMillis']<max(p['diagnosticWindow']['endMillis'] for p in profiles):
        raise ValueError('Diagnostics were exported before the timed workload ended')
    if exported['exportFinishedMillis']<exported['exportStartedMillis']:
        raise ValueError('Invalid export timestamps')
    previous=None
    for index,sample in enumerate(samples,1):
        begin=sample['snapshotStartedMillis'];end=sample['hookFinishedMillis']
        if sample['sample']!=index or sample['millis']!=begin or not begin<=sample['snapshotFinishedMillis']<=end:
            raise ValueError('Invalid buffered snapshot timing/sequence')
        if previous is not None and begin<previous:raise ValueError('Sampler time moved backwards')
        previous=begin
        if end>exported['exportStartedMillis']:raise ValueError('Sample was captured after export began')
        if not all(0<=f['pending']<=f['watched']<=3 for f in sample['feeds']):raise ValueError('Unbounded feed state')
        if sample['publishers']>64 or len(sample['feeds'])>64:raise ValueError('Unbounded publisher/feed count')
        if sample['native']['1']>128 or sample['native']['8']>128*4080:raise ValueError('Native capacity exceeded')
        limits=sample['driveLimits'];stats=sample['connectStatistics']
        if stats['callPeak']>limits['calls'] or stats['copyPeak']>limits['bytes']:raise ValueError('Drive budget exceeded')
    for profile in profiles:
        window=profile['diagnosticWindow']
        selected=[s for s in samples if window['startMillis']<=s['millis'] and s['hookFinishedMillis']<=window['endMillis']]
        if not selected:raise ValueError('No fully contained diagnostics in workload profile')
        stalled=[s for s in selected if window['stalledStartMillis']<=s['millis']<=window['stalledEndMillis']]
        if not stalled:raise ValueError('No diagnostic snapshot after healthy convergence and before slow-stream resume')
        last=stalled[-1]
        pending=sum(f['pending']>0 and f['publisher'] for f in last['feeds'])
        if pending<profile['slowConsumers']:raise ValueError('Slow feed retention evidence missing')
        directory=output/profile['directory']
        (directory/'stalled-server.json').write_text(json.dumps(last,indent=2)+'\n')
        durations=[s['hookFinishedMillis']-s['snapshotStartedMillis'] for s in selected]
        profile.update(nativeSampleRange=[selected[0]['sample'],selected[-1]['sample']],
            maximumPendingStatesPerFeed=max((f['pending'] for s in selected for f in s['feeds']),default=0),
            maximumNativeRecords=max(s['native']['1'] for s in selected),maximumNativePayloadBytes=max(s['native']['8'] for s in selected),
            slowFeedsRetainingStateAfterHealthyConvergence=pending,
            samplerSnapshotMillis={key:percentile(durations,q) for key,q in [('p50',.5),('p95',.95),('p99',.99),('max',1)]})
    durations=[s['hookFinishedMillis']-s['snapshotStartedMillis'] for s in samples]
    return dict(exported,localTimings=validate_local_timings(output),snapshotMillis={key:percentile(durations,q) for key,q in [('p50',.5),('p95',.95),('p99',.99),('max',1)]},
        allProfilesHaveCapacityAndSlowRetentionEvidence=True,exportAfterTimedWorkload=True)
