"""Offline bounded-writer evidence; admission backlog is not a server queue."""
import math
import statistics


def distribution(values):
    ordered = sorted(values)
    return dict(count=len(values), mean=statistics.mean(values),
                **{name: ordered[max(0, math.ceil(len(values)*q)-1)]
                   for name, q in [('p50', .5), ('p95', .95), ('p99', .99), ('max', 1)]})


def analyze_writer(writer, interval_millis):
    """Validate every recorded request and reconstruct offered/submitted/replied counts."""
    writes = writer['writes']
    if len(writes) != writer['count']:
        raise ValueError('Missing writer records')
    keys = [(w['user'], w['revision']) for w in writes]
    if len(set(keys)) != len(keys):
        raise ValueError('Duplicate User revisions')
    reports = []
    for phase in writer['phases']:
        rows = [w for w in writes if w['phase'] == phase['phase']]
        count = phase['requests']; lanes = phase['concurrency']
        if not rows or len(rows) != count or sorted(w['ordinal'] for w in rows) != list(range(count)):
            raise ValueError('Incomplete phase ordinals')
        if not 1 <= lanes <= 3 or phase['activeAtEnd'] != 0:
            raise ValueError('Invalid writer lane ownership')
        events = sorted([(w['sentAt'], 1) for w in rows] + [(w['replyAt'], -1) for w in rows])
        active = peak = 0
        for _, delta in events:
            active += delta; peak = max(peak, active)
            if not 0 <= active <= lanes:
                raise ValueError('Unbounded or reversed in-flight requests')
        if peak != phase['peakActive'] or active:
            raise ValueError('Peak in-flight evidence mismatch')
        for lane in range(lanes):
            selected = sorted((w for w in rows if w['lane'] == lane), key=lambda w: w['ordinal'])
            if lanes > 1 and len({w['user'] for w in selected}) != 1:
                raise ValueError('Concurrent lane changed User ownership')
            if any(b['sentAt'] < a['replyAt'] for a, b in zip(selected, selected[1:])):
                raise ValueError('A writer lane overlapped its own revision')
        for w in rows:
            if not phase['startedAt'] <= w['offeredAt'] <= w['sentAt'] <= w['replyAt'] <= phase['finishedAt']:
                raise ValueError('Reversed request timing')
        if not phase['phase'].startswith('burst'):
            continue
        begin = min(w['sentAt'] for w in rows); end = max(w['replyAt'] for w in rows)
        paced = interval_millis > 0
        if paced:
            for w in rows:
                expected = phase['startedAt'] + w['ordinal'] * interval_millis / 1000
                if abs(w['offeredAt'] - expected) > .000001:
                    raise ValueError('Offered schedule differs from requested rate')
        def at(moment):
            due = sum(w['offeredAt'] <= moment for w in rows)
            sent = sum(w['sentAt'] <= moment for w in rows)
            replied = sum(w['replyAt'] <= moment for w in rows)
            return dict(at=moment, offered=due, submitted=sent, completed=replied,
                        admissionBacklog=due-sent, inFlight=sent-replied, outstandingDemand=due-replied)
        sample_times = {phase['startedAt'], end}
        sample_times.update(phase['startedAt'] + i*.25 for i in range(math.floor((end-phase['startedAt'])/.25)+1))
        offered_end = max(w['offeredAt'] for w in rows)
        sample_times.add(offered_end)
        trace = [at(t) for t in sorted(sample_times)]
        ordered = sorted(rows, key=lambda w: w['ordinal'])
        quarter = max(1, len(rows)//4)
        lag = lambda selected: statistics.mean((w['sentAt']-w['offeredAt'])*1000 for w in selected)
        reports.append(dict(phase=phase['phase'], concurrency=lanes, requests=count,
            offeredMode='paced-bounded-admission' if paced else 'closed-loop',
            offeredRequestsPerSecond=1000/interval_millis if paced else None,
            completedRequestsPerSecond=count/(end-begin), elapsedSeconds=end-begin,
            roundTripMillis=distribution([(w['replyAt']-w['sentAt'])*1000 for w in rows]),
            admissionLagMillis=distribution([(w['sentAt']-w['offeredAt'])*1000 for w in rows]),
            firstQuarterMeanAdmissionLagMillis=lag(ordered[:quarter]),
            lastQuarterMeanAdmissionLagMillis=lag(ordered[-quarter:]),
            demandAtOfferedEnd=at(offered_end) if paced else None,
            peakInFlight=peak, maximumAdmissionBacklog=max(t['admissionBacklog'] for t in trace),
            queueTrace=trace))
    if len(reports) != 2:
        raise ValueError('Expected two bounded burst phases')
    return dict(phases=reports, requests=sum(x['requests'] for x in reports),
                completedRequestsPerSecond=sum(x['requests'] for x in reports)/sum(x['elapsedSeconds'] for x in reports),
                boundedWriter=True, noUncertainRequestReplay=True,
                queueScope='Admission backlog is offered but not yet submitted; inFlight includes transport, Runtime and reply delivery, not an isolated server queue.')
