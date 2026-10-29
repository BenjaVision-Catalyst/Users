#!/usr/bin/env python3
"""Align native sample intervals with Users writer evidence; never split counters.

Produces an auditable interval report and numeric input for the native VSD chart
exporter. Time counters can overlap and must not be added as exclusive phases.
"""
import argparse
import json
import math
from pathlib import Path
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--statistics-tools', type=Path, required=True)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    sys.path.insert(0, str(args.statistics_tools.resolve(strict=True)))
    from native_statmonitor import identities, read_capture, stone_samples

    native = args.capture.resolve()
    manifest = json.loads((native / 'manifest.json').read_text())
    workload = native.parent / 'workload'
    qualification = json.loads((workload / 'qualification.json').read_text())
    assert manifest['passed'] and qualification['passed']
    _, _, rows = read_capture(native / 'native.out')
    stone = stone_samples(rows, manifest['stone'], manifest['stonePid'])
    serving_pid = next(w['process']['pid'] for w in qualification['started']['workers'] if w['hostIdentifier'] == 'application')
    gems = [(key, samples) for key, samples in identities(rows).items() if key[0] == 'Gem' and key[1] == serving_pid]
    # A process rename is a separate native identity; never concatenate incarnations.
    gem_key, gem = max(gems, key=lambda pair: len(pair[1]))
    before, after = manifest['beforeWorkload'], manifest['afterWorkload']
    offset = before['wallUs'] - before['monotonicUs']
    drift = (after['wallUs'] - after['monotonicUs']) - offset
    grid = math.gcd(*(b['Time'] - a['Time'] for a, b in zip(stone, stone[1:])))
    uncertainty = grid + abs(drift)
    origin = stone[0]['Time']
    writes = []
    for path in sorted(workload.glob('fanout_users_*/writer-result.json')):
        clients = int(path.parent.name.rsplit('_', 1)[1])
        for write in json.loads(path.read_text())['writes']:
            start, end = round(write['sentAt'] * 1e6) + offset, round(write['replyAt'] * 1e6) + offset
            writes.append(dict(write, clients=clients, startUs=start, endUs=end, rttMillis=(end-start)/1000))
    writes.sort(key=lambda w: w['startUs'])
    assert writes and stone[0]['Time'] <= writes[0]['startUs'] and stone[-1]['Time'] >= writes[-1]['endUs']
    assert gem[0]['Time'] <= writes[0]['startUs'] and gem[-1]['Time'] >= writes[-1]['endUs']

    def intervals(series, keys, start, end, margin=0):
        contained, boundary = [], []
        for a, b in zip(series, series[1:]):
            if b['Time'] <= start or a['Time'] >= end:
                continue
            row = dict(startUs=a['Time'], endUs=b['Time'], delta={key:b[key]-a[key] for key in keys})
            assert all(value >= 0 for value in row['delta'].values())
            if a['Time'] >= start + margin and b['Time'] <= end - margin:
                contained.append(row)
            else:
                boundary.append(row)
        return dict(coveredMillis=sum(r['endUs']-r['startUs'] for r in contained)/1000,
                    containedDelta={key:sum(r['delta'][key] for r in contained) for key in keys},
                    contained=contained, boundaryOrUncertain=boundary)

    stone_keys = ['StnAioTimeInFsyncMs', 'StnAioFsyncCount', 'TotalCommits', 'TimePerformingCommit']
    gem_keys = ['TimeStoneCommit', 'TimeWaitingForCommit', 'TimeProcessingCommit', 'TimeInScavenges',
                'TimeInMarkSweep', 'ScavengeCount', 'MarkSweepCount', 'CommitCount']
    slow = []
    for write in writes:
        if write['rttMillis'] < 500:
            continue
        slow.append(dict(write=write,
                         stone=intervals(stone, stone_keys, write['startUs'], write['endUs']),
                         servingGem=intervals(gem, gem_keys, write['startUs'], write['endUs']),
                         conservativeStone=intervals(stone, stone_keys, write['startUs'], write['endUs'], uncertainty),
                         conservativeGem=intervals(gem, gem_keys, write['startUs'], write['endUs'], uncertainty)))
    worst = max(writes, key=lambda w:w['rttMillis'])
    # Preserve an explicitly selected steady window, rather than describing it as a run-wide bound.
    steady = next((w for w in writes if w['clients'] == 60 and w['phase'] == 'burstB.json'), None)
    if steady is None:
        raise ValueError('No 60-observer second burst for the steady-window chart')
    steady_end = steady['startUs'] + 6_000_000
    steady_writes = [w for w in writes if steady['startUs'] <= w['startUs'] <= steady_end]
    assert steady_writes and max(w['rttMillis'] for w in steady_writes) < 500
    report = dict(stonePid=manifest['stonePid'], servingPid=serving_pid, servingIdentity=gem_key,
                  otherServingIdentities=[key for key, _ in gems if key != gem_key], captureOriginUs=origin,
                  wallMinusUptimeUs=offset, wallUptimeOffsetDriftUs=drift, observedTimestampGridUs=grid,
                  conservativeBoundaryMarginUs=uncertainty, slowRequests=slow,
                  steadyWindow=dict(startUs=steady['startUs'], endUs=steady_end,
                                    maximumWriterRTTMillis=max(w['rttMillis'] for w in steady_writes)),
                  notes=['Native time counters overlap; do not add them as exclusive phases.',
                         'Fully contained recorded intervals and boundary intervals remain separate.',
                         'Conservative totals exclude an extra observed timestamp grid plus measured clock drift at each boundary.',
                         'Stone counters cover the entire shared cache, including other active Gems.',
                         'Writer RTT is external application evidence; it is not a native VSD statistic.',
                         'No slow request is interpreted as one native fsync call.'])
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    (output / 'analysis.json').write_text(json.dumps(report, indent=2)+'\n')
    (output / 'writer-x.txt').write_text(' '.join(str((w['endUs']-origin)/1000) for w in writes))
    (output / 'writer-y.txt').write_text(' '.join(str(w['rttMillis']) for w in writes))
    (output / 'charts.tcl').write_text('\n'.join([
        f'set catalystStonePid {manifest["stonePid"]}', f'set catalystServingPid {serving_pid}',
        f'set catalystSlowStart {(worst["startUs"]-origin)/1000}',
        f'set catalystSlowEnd {(worst["endUs"]-origin)/1000}',
        f'set catalystZoomStart {(worst["startUs"]-origin)/1000-1500}',
        f'set catalystZoomEnd {(worst["endUs"]-origin)/1000+1500}',
        f'set catalystSteadyStart {(steady["startUs"]-origin)/1000}',
        f'set catalystSteadyEnd {(steady_end-origin)/1000}', '']))
    print(json.dumps(dict(slowRequests=len(slow), servingPid=serving_pid,
                          worstRTTMillis=worst['rttMillis'], observedTimestampGridUs=grid)))


if __name__ == '__main__':
    main()
