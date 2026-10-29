#!/usr/bin/env python3
"""Opt-in shared-User fan-out qualification using ordinary configured Runtimes.

One controller owns the disposable Runtime and all native client processes through
cleanup. The existing MCP lease isolates the complete run. No work is replayed.
"""
import argparse
import importlib.util
import hashlib
import shutil
import json
import math
import os
from pathlib import Path
import socket
import subprocess
import time
import urllib.request
import uuid

spec = importlib.util.spec_from_file_location('platform_users', Path(__file__).with_name('qualify-platform-users.py'))
helpers = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helpers)
write, quote, wait_json = helpers.write, helpers.quote, helpers.wait_json


def percentile(values, fraction):
    ordered = sorted(values)
    return ordered[max(0, math.ceil(len(ordered) * fraction) - 1)] if ordered else None


def burst_evidence(directory):
    """Analyze immutable worker evidence; latency is for delivered revisions only."""
    writes = wait_json(directory / 'writer-result.json')['writes']
    offered = {(w['user'], w['revision']): w for w in writes if w['phase'] in ['burstA.json', 'burstB.json']}
    clients = [client for path in directory.glob('result-*.json') for client in wait_json(path)['observers']]
    healthy = [client for client in clients if not client['slow']]
    latencies = [(event['at'] - offered[(event['user'], event['revision'])]['sentAt'])*1000
                 for client in healthy for event in client['arrivals'] if (event['user'], event['revision']) in offered]
    per_client = []
    for client in healthy:
        arrivals = [event for event in client['arrivals'] if (event['user'], event['revision']) in offered]
        gaps = []
        for phase in ['burstA.json', 'burstB.json']:
            phase_writes = [w for w in writes if w['phase'] == phase]
            begin, end = phase_writes[0]['sentAt'], phase_writes[-1]['replyAt']
            for user in {w['user'] for w in phase_writes}:
                times = [begin] + sorted(event['at'] for event in arrivals if event['user'] == user and begin <= event['at'] <= end) + [end]
                gaps.extend((b-a)*1000 for a,b in zip(times,times[1:]))
        per_client.append(dict(index=client['index'], receivedBurstRevisions=len(arrivals),
            deliveredFraction=len(arrivals)/len(offered), maximumNoDeliveryGapDuringBurstMillis=max(gaps, default=0),
            deliveredBurstP99Millis=percentile([(event['at']-offered[(event['user'],event['revision'])]['sentAt'])*1000 for event in arrivals], .99)))
    drain = next((client for client in sorted(clients, key=lambda c:c['index']) if client['slow']), None)
    gap, previous = 0, {}
    if drain:
        for event in drain['arrivals']:
            gap = max(gap, event['revision'] - previous.get(event['user'], event['revision']))
            previous[event['user']] = event['revision']
        assert gap > 1, 'A held stream must demonstrate latest-state coalescing'
    burst_seconds = 0
    for phase in ['burstA.json', 'burstB.json']:
        phase_writes = [write for write in writes if write['phase'] == phase]
        burst_seconds += phase_writes[-1]['replyAt'] - phase_writes[0]['sentAt']
    reconnected = list(directory.glob('reconnected-*.json'))
    return dict(perHealthyClient=per_client, minimumHealthyCoverage=min(c['deliveredFraction'] for c in per_client), burstLatencyMillis={key:percentile(latencies,q) for key,q in [('p50',.5),('p95',.95),('p99',.99),('max',1)]},
        maximumWriterAdmissionLagMillis=max((w['sentAt']-w.get('offeredAt',w['sentAt']))*1000 for w in offered.values()),
        deliveredBurstStates=len(latencies), possibleBurstStates=len(offered)*len(healthy),
        deliveredIntermediateRevisionFraction=len(latencies)/(len(offered)*len(healthy)),
        confirmedBurstWritesPerSecond=len(offered)/burst_seconds,
        largestRevisionGapOnResumedSlowStream=gap,
        coordinatorObservedReconnectReadyMillis=(max(path.stat().st_mtime for path in reconnected)-(directory/'reconnect').stat().st_mtime)*1000)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ['project', 'bvc', 'library', 'apple-package', 'output']:
        parser.add_argument('--' + key, type=Path, required=True)
    parser.add_argument('--deployment', required=True)
    parser.add_argument('--authority', choices=['gt', 'gemstone'], required=True)
    parser.add_argument('--clients', nargs='+', type=int, choices=[1, 8, 32, 60], default=[1, 8, 32, 60])
    parser.add_argument('--build-configuration', choices=['debug', 'release'], default='debug')
    parser.add_argument('--write-interval-millis', type=float, default=0, help='Paced serial admission; record lag if replies prevent meeting the offered schedule')
    parser.add_argument('--mcp-url', default='http://127.0.0.1:3001/')
    args = parser.parse_args()
    for key, value in vars(args).items():
        if isinstance(value, Path): setattr(args, key, value.resolve())
    if any(count < 1 or count > 60 for count in args.clients): parser.error('client counts must be 1..60 (writer reserves one listener connection)')
    if not 0 <= args.write_interval_millis <= 1000: parser.error('write interval must be 0..1000 ms')
    output = args.output; output.mkdir(parents=True, exist_ok=False)
    name = 'fanout_users_' + uuid.uuid4().hex[:12]
    env = dict(os.environ, GEMSTONE_STONE_NAME=args.deployment, BVC_USERS_PLATFORM_DIRECTORY=str(output))
    parameters = dict(runtime=name, prefix=name, library=str(args.library), fanout=True, maximumFeeds=64, maximumUsersPerFeed=3, clients=[])
    report = dict(runtime=name, authority=args.authority, profiles=[], nativeCapacity=64, maximumFeeds=64, maximumUsersPerFeed=3, clientBuildConfiguration=args.build_configuration, offeredWriteIntervalMillis=args.write_interval_millis)
    snapshot = output / 'source-snapshot'; snapshot.mkdir()
    sources = dict(controller=Path(__file__), runtimeConfiguration=Path(__file__).with_name('qualify-platform-users.topaz'),
        swiftWorker=args.apple_package / 'Tests/CatalystUsersTests/NativeFanoutUsersTests.swift',
        swiftTransport=args.apple_package / 'Sources/CatalystConnect/CatalystConnect.swift')
    report['sourceSHA256'] = {key: hashlib.sha256(path.read_bytes()).hexdigest() for key,path in sources.items()}
    for key,path in sources.items(): shutil.copy2(path, snapshot / (key + path.suffix))
    owner = 'CUFanoutLease'  + uuid.uuid4().hex
    registered = lease = False
    processes, logs, memory = [], [], []
    current_directory = None

    def save(): write(output / 'qualification.json', report)
    def run(command, label, environment=None, timeout=90):
        result = subprocess.run(list(map(str, command)), cwd=args.project, env=environment or env, text=True, capture_output=True, timeout=timeout)
        (output / (label + '.log')).write_text(result.stdout + result.stderr)
        if result.returncode: raise RuntimeError('Inspect ' + str(output / (label + '.log')))
        return result.stdout
    def runtime(action): return json.loads(run([args.bvc, 'runtime', action, name], action + str(time.monotonic_ns())))
    def phase(action):
        write(output / 'parameters.json', parameters)
        run([args.bvc, 'topaz', args.deployment, '--script', Path(__file__).with_name('qualify-platform-users.topaz')],
            action + str(time.monotonic_ns()), dict(env, BVC_USERS_PLATFORM_PHASE=action))
        return wait_json(output / (action + '.json'))
    def rpc(label, code):
        request = dict(jsonrpc='2.0', id=1, method='tools/call', params=dict(name='smalltalkCodeEvaluation', arguments=dict(code=code)))
        write(output / (label + '-request.json'), request)
        response = json.loads(urllib.request.urlopen(urllib.request.Request(args.mcp_url, json.dumps(request).encode(), {'Content-Type': 'application/json'}), timeout=60).read())
        write(output / (label + '-response.json'), response)
        if response.get('error') or response.get('result', {}).get('isError'): raise RuntimeError('GT MCP failed: ' + label)
        for block in response.get('result', {}).get('content', []):
            if block.get('type') == 'text' and 'errorDetails' in json.loads(block['text']): raise RuntimeError('GT MCP failed: ' + label)
    def sample_memory():
        if not server_pids: return
        result = subprocess.run(['ps', '-o', 'pid=,rss=,pcpu=', '-p', ','.join(map(str, server_pids))], capture_output=True, text=True, errors='replace')
        for line in result.stdout.splitlines():
            pid, rss, cpu = line.split(); memory.append(dict(at=time.monotonic(), pid=int(pid), rssKiB=int(rss), cpuPercent=float(cpu)))
    def wait_files(paths, timeout=240):
        deadline = time.monotonic() + timeout
        while not all(path.exists() for path in paths):
            sample_memory()
            for process in processes:
                if process.poll() not in [None, 0]: raise RuntimeError('Client process failed; inspect preserved client logs')
            if (output / 'server-error.json').exists(): raise RuntimeError((output / 'server-error.json').read_text())
            if time.monotonic() >= deadline: raise TimeoutError(str(paths))
            time.sleep(.2)
        return [wait_json(path) for path in paths if path.suffix == '.json']
    def latest_native():
        deadline = time.monotonic() + 45
        while time.monotonic() < deadline:
            paths = sorted(output.glob('native-[0-9]*.json'), key=lambda path:int(path.stem.split('-')[1]), reverse=True)
            for path in paths:
                try: return json.loads(path.read_text())
                except ValueError: pass
            time.sleep(.1)
        raise TimeoutError('No complete native sample')
    def launch(directory, role, **extra):
        config = dict(client_options, role=role, directory=str(directory), prefix=directory.name, **extra)
        configuration = directory / (role + str(extra.get('shard', '')) + '-config.json'); write(configuration, config)
        log = (directory / (role + str(extra.get('shard', '')) + '.log')).open('w'); logs.append(log)
        process = subprocess.Popen(['xcrun', 'xctest', '-XCTest', 'CatalystUsersTests.NativeFanoutUsersTests/testFanoutWorker', str(test_bundle)],
            env=dict(env, CU_FANOUT_CONFIG=str(configuration)), stdout=log, stderr=subprocess.STDOUT)
        processes.append(process)
    def marker(directory, name): (directory / name).touch()

    before = json.loads(run([args.bvc, 'runtime', 'status', 'connect-dev'], 'development-before'))
    originals = {(w['process']['pid'], w['process']['token']) for w in before['workers'] if w['process']['live']}
    test_bundle = args.apple_package / ('.build/arm64-apple-macosx/' + args.build_configuration + '/CatalystConnectSwiftPackageTests.xctest')
    if not test_bundle.exists(): raise FileNotFoundError(test_bundle)
    for identity in ['server', 'bulk']:
        run([args.library.parent / 'identity', output / 'identities' / identity], 'identity-' + identity)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(('127.0.0.1', 0)); port = probe.getsockname()[1]
    identities = output / 'identities'
    client_options = dict(peer=f'127.0.0.1:{port}', certificate=str(identities / 'bulk/certificate.der'), private_key=str(identities / 'bulk/private-key.der'), trusted_certificate=str(identities / 'server/certificate.der'))
    server = dict(role='server', bind=f'127.0.0.1:{port}', server_name='localhost', capacity=64,
        certificate=str(identities / 'server/certificate.der'), private_key=str(identities / 'server/private-key.der'), trusted_certificate=str(identities / 'bulk/certificate.der'))
    write(output / 'server.json', server)
    parameters['clients'] = [dict(name='bulk', output=str(output), prefix=name, library=str(args.library), serverOptions=str(output / 'server.json'))]
    write(output / 'parameters.json', parameters)
    server_pids = []
    try:
        # The existing lease covers configured native startup, clients and cleanup.
        if args.authority == 'gt':
            rpc('lease-start', f'''| run | run := CCNativeInteropRun new start: [| lease scenario |
lease := CCNativeMcpLease forRunningServers.
[lease during: [CRPlatform current writeConnectEvidence: (Dictionary new at: 'active' put: true; yourself) to: {quote(output / 'lease-active.json')}.
scenario := CUUsersConnectNativeScenario new.
[scenario runServerConfigurations: ((STONJSON fromString: {quote(output / 'parameters.json')} asFileReference contents) at: 'clients') directory: {quote(output)} asFileReference]
on: Error, TestFailure do: [:error | CRPlatform current writeConnectEvidence: (Dictionary new at: 'error' put: error messageText asString; yourself) to: {quote(output / 'server-error.json')}]]]
ensure: [CRPlatform current writeConnectEvidence: lease snapshot to: {quote(output / 'gt-mcp-gate.json')}]].
Smalltalk globals at: {quote(owner)} asSymbol put: run. run snapshot''')
            lease = True; wait_json(output / 'lease-active.json'); wait_files([output / 'server-ready.json'])
            found = subprocess.run(['lsof', '-nP', '-iTCP:3001', '-sTCP:LISTEN', '-t'], capture_output=True, text=True)
            server_pids = [int(pid) for pid in found.stdout.split()]
        else:
            rpc('lease-start', f'''| run | run := CCNativeInteropRun new start: [| lease deadline |
lease := CCNativeMcpLease forRunningServers.
[lease during: [CRPlatform current writeConnectEvidence: (Dictionary new at: 'active' put: true; yourself) to: {quote(output / 'lease-active.json')}.
deadline := CRPlatform current currentMillis + 1800000.
[({quote(output / 'release-lease')} asFileReference exists) or: [CRPlatform current currentMillis >= deadline]] whileFalse: [(Delay forMilliseconds: 10) wait]]]
ensure: [CRPlatform current writeConnectEvidence: lease snapshot to: {quote(output / 'gt-mcp-gate.json')}]].
Smalltalk globals at: {quote(owner)} asSymbol put: run. run snapshot''')
            lease = True; wait_json(output / 'lease-active.json')
            phase('configure')
            run([args.bvc, 'runtime', 'configure', name, output / 'runtime.ston'], 'configure-runtime'); registered = True
            runtime('start')
            deadline = time.monotonic() + 45
            while True:
                status = runtime('status')
                if status['state'] == 'running': break
                if time.monotonic() > deadline: raise TimeoutError('Configured Runtime convergence')
                time.sleep(.2)
            report['started'] = status
            server_pids = [w['process']['pid'] for w in status['workers'] if w['process']['live']]
        save()
        for count in args.clients:
            directory = output / (name + '_' + str(count)); directory.mkdir(); current_directory = directory
            slow = 0 if count == 1 else (1 if count == 8 else 2)
            shards = math.ceil(count / 10); processes = []
            started = time.monotonic(); memory_start = len(memory)
            native_start = latest_native()['sample']
            launch(directory, 'writer', writeIntervalMillis=args.write_interval_millis); wait_files([directory / 'seed.json'])
            for shard in range(shards): launch(directory, 'observers', shard=shard, start=shard*10, count=min(10, count-shard*10), total=count, slow=slow)
            wait_files([directory / f'ready-{s}.json' for s in range(shards)])
            marker(directory, 'start'); wait_files([directory / f'baseline-{s}.json' for s in range(shards)])
            marker(directory, 'burst-go'); wait_files([directory / f'burstA-{s}.json' for s in range(shards)])
            # Keep slow consumers stopped across a second burst: retained state must
            # depend on watched identities and configured credits, not edit count.
            time.sleep(1); sample_memory(); marker(directory, 'burstB-go')
            wait_files([directory / f'burstB-{s}.json' for s in range(shards)])
            time.sleep(1); sample_memory()
            stalled = latest_native()
            stalled_pending = sum(feed['pending'] > 0 and feed['publisher'] for feed in stalled['feeds'])
            write(directory / 'stalled-server.json', stalled)
            marker(directory, 'resume')
            wait_files([directory / f'offline-ready-{s}.json' for s in range(shards)])
            marker(directory, 'offline-go'); wait_files([directory / 'offline.json'])
            marker(directory, 'reconnect'); wait_files([directory / f'reconnected-{s}.json' for s in range(shards)])
            marker(directory, 'final-go'); wait_files([directory / f'done-{s}.json' for s in range(shards)])
            marker(directory, 'stop'); wait_files([directory / 'writer-done.json'])
            for process in processes:
                if process.wait(timeout=60): raise RuntimeError('Client assertions failed; inspect preserved logs')
            results = [wait_json(directory / f'result-{s}.json') for s in range(shards)]
            writer = wait_json(directory / 'writer-result.json')
            offered = {(w['user'], w['revision']): w for w in writer['writes']}
            clients = [client for result in results for client in result['observers']]
            latency = [(arrival['at'] - offered[(arrival['user'], arrival['revision'])]['sentAt'])*1000 for client in clients if not client['slow'] for arrival in client['arrivals'] if (arrival['user'], arrival['revision']) in offered]
            assert latency and min(latency) >= 0
            for client in clients:
                assert not client['errors'] and client['stableObjectIdentity']
                assert client['requestsAtFinalReadiness'] == client['requestsAtEnd']
                if client['slow']: assert client['stalledNativeStatistics']['records'] == client['stalledNativeStatistics']['capacity']
            native_end = latest_native()['sample']
            samples = [wait_json(path) for path in output.glob('native-*.json') if path.name != 'native-latest.json' and native_start <= int(path.stem.split('-')[1]) <= native_end]
            for sample in samples:
                assert all(feed['pending'] <= feed['watched'] <= 3 for feed in sample['feeds'])
                assert sample['publishers'] <= 64 and len(sample['feeds']) <= 64
                assert sample['native']['1'] <= 128 and sample['native']['8'] <= 128*4080
                limits = sample.get('driveLimits', dict(calls=32, bytes=4096))
                assert sample['connectStatistics']['callPeak'] <= limits['calls'] and sample['connectStatistics']['copyPeak'] <= limits['bytes']
            profile = dict(clients=count, slowConsumers=slow, sharedUsers=3, updates=writer['count'], elapsedSeconds=time.monotonic()-started,
                deliveredHealthySamples=len(latency), latencyFromSubmissionMillis={key:percentile(latency, q) for key,q in [('p50',.5),('p95',.95),('p99',.99),('max',1)]},
                writerRTTMillis={key:percentile([(w['replyAt']-w['sentAt'])*1000 for w in writer['writes']],q) for key,q in [('p50',.5),('p95',.95),('p99',.99)]},
                maximumPendingStatesPerFeed=max((feed['pending'] for sample in samples for feed in sample['feeds']),default=0),
                maximumNativeRecords=max(sample['native']['1'] for sample in samples), maximumNativePayloadBytes=max(sample['native']['8'] for sample in samples),
                rpcWhileNotificationStalledMillis=[c['rpcWhileNotificationStalledMillis'] for c in clients if c['slow']],
                serverMemorySamples=memory[memory_start:], nativeSampleRange=[native_start,native_end],
                slowFeedsRetainingStateAfterHealthyConvergence=stalled_pending, slowNativeStatistics=[c['stalledNativeStatistics'] for c in clients if c['slow']], idleApplicationRequests=0, allClientsConverged=True, stableIdentities=True, reconnectRecovered=True, clientNativeCleanup=True)
            profile.update(burst_evidence(directory))
            report['profiles'].append(profile); save(); print(str(count) + ' observers: passed', flush=True)
        if args.authority == 'gemstone':
            parameters['expectedUsers'] = [state for profile in output.glob(name + '_*') for state in wait_json(profile / 'final.json')]
            report['persistence'] = phase('fanoutVerify')
        report['workloadPassed'] = True
    except Exception as error:
        report['error'] = repr(error); save(); raise
    finally:
        if current_directory: marker(current_directory, 'abort')
        # Client tests own positive native close, even on a failed assertion. No kill/restart/replay.
        for process in processes:
            try: process.wait(timeout=60)
            except subprocess.TimeoutExpired: report.setdefault('retainedClientPids', []).append(process.pid)
        try:
            if registered:
                runtime('stop'); report['stopped'] = runtime('status'); runtime('remove'); report['cleanup'] = phase('cleanup')
            elif args.authority == 'gt':
                marker(output, 'server-stop'); report['cleanup'] = wait_json(output / 'server-evidence.json')
        finally:
            if lease:
                marker(output, 'release-lease')
                # Read the completion marker outside GT before any join/inspection call.
                report['mcpGate'] = wait_json(output / 'gt-mcp-gate.json')
                assert report['mcpGate']['state'] == 'released' and report['mcpGate']['originalRegistriesRestored']
                rpc('lease-join', f'''| run | run := Smalltalk globals at: {quote(owner)} asSymbol. run waitForMillis: 1000.
self assert: run isFinished. Smalltalk globals removeKey: {quote(owner)} asSymbol. run snapshot''')
            after = json.loads(run([args.bvc, 'runtime', 'status', 'connect-dev'], 'development-after'))
            assert originals == {(w['process']['pid'],w['process']['token']) for w in after['workers'] if w['process']['live']}
            report['developmentRuntimePreserved'] = True
            write(output / 'server-memory.json', memory)
            for log in logs: log.close()
            for key in (output / 'identities').rglob('private-key.der'): key.unlink()
            save()
    report['passed'] = True; save()
    print('Fan-out qualification passed: ' + str(output / 'qualification.json'))


if __name__ == '__main__': main()
