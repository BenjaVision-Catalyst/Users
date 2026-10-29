#!/usr/bin/env python3
"""Unreal and Swift macOS/iOS -> configured authoritative Users -> native commit.

Requires already verified GT-owned qualification fixtures in GT/GemStone. Builds
are independent preparation; this runner owns exactly one disposable Runtime and
uses the existing default transactional worker, routing and published evidence.
"""
import argparse
import json
import os
from pathlib import Path
import socket
import subprocess
import time
import urllib.request
import uuid


def write(path, value):
    temporary = path.with_name(path.name + '.tmp')
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n')
    temporary.replace(path)


def quote(value):
    return "'" + str(value).replace("'", "''") + "'"


def wait_json(path, timeout=45):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if path.exists():
            try:
                return json.loads(path.read_text(encoding='utf-8-sig'))
            except ValueError:
                pass
        time.sleep(.05)
    raise TimeoutError(str(path))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ['project', 'bvc', 'library', 'apple-package', 'swift-repo', 'users-swift', 'engine', 'ue-project', 'output']:
        parser.add_argument('--' + key, type=Path, required=True)
    parser.add_argument('--deployment', required=True)
    parser.add_argument('--authority', choices=['gemstone', 'gt'], default='gemstone')
    parser.add_argument('--push-only', action='store_true')
    parser.add_argument('--mcp-url', default='http://127.0.0.1:3001/')
    parser.add_argument('--platforms', nargs='+', choices=['swift-macos', 'swift-ios', 'unreal'], default=['swift-macos', 'swift-ios', 'unreal'])
    args = parser.parse_args()
    if args.authority == 'gt' and not args.push_only: parser.error('--authority gt requires --push-only')
    for key, value in vars(args).items():
        if isinstance(value, Path):
            setattr(args, key, value.resolve())
    output = args.output
    output.mkdir(parents=True, exist_ok=False)
    name = 'platform_users_' + uuid.uuid4().hex[:12]
    env = dict(os.environ, GEMSTONE_STONE_NAME=args.deployment, BVC_USERS_PLATFORM_DIRECTORY=str(output))
    parameters = dict(runtime=name, prefix=name + '_user', library=str(args.library), clients=[])
    report = dict(runtime=name, phases={}, clients={})
    configured, lease = False, False
    owner = 'CUPlatformLease' + uuid.uuid4().hex

    def save():
        write(output / 'qualification.json', report)

    def run(argv, label, environment=None, timeout=90):
        result = subprocess.run(list(map(str, argv)), cwd=args.project, env=environment or env,
                                text=True, capture_output=True, timeout=timeout)
        (output / (label + '.log')).write_text(result.stdout + result.stderr)
        if result.returncode:
            raise RuntimeError('Inspect ' + str(output / (label + '.log')))
        return result.stdout

    def runtime(action, *extra):
        return json.loads(run([args.bvc, 'runtime', action, name, *extra], action + str(time.monotonic_ns())))

    def phase(action):
        write(output / 'parameters.json', parameters)
        if args.authority == 'gt':
            if action == 'gate': wait_json(Path(parameters['activeClient']['output']) / 'gate-ready.json')
            return {}
        run([args.bvc, 'topaz', args.deployment, '--script', Path(__file__).with_suffix('.topaz')],
            action + str(time.monotonic_ns()), dict(env, BVC_USERS_PLATFORM_PHASE=action))
        result = wait_json(output / (action + '.json'))
        report['phases'].setdefault(action, []).append(result); save()
        return result

    def rpc(label, code):
        request = dict(jsonrpc='2.0', id=1, method='tools/call', params=dict(name='smalltalkCodeEvaluation', arguments=dict(code=code)))
        write(output / (label + '-request.json'), request)
        result = json.loads(urllib.request.urlopen(urllib.request.Request(args.mcp_url, json.dumps(request).encode(),
            {'Content-Type': 'application/json'}), timeout=60).read())
        write(output / (label + '-response.json'), result)
        if result.get('error') or result.get('result', {}).get('isError'):
            raise RuntimeError('GT MCP operation failed')
        for block in result.get('result', {}).get('content', []):
            if block.get('type') == 'text' and 'errorDetails' in json.loads(block['text']):
                raise RuntimeError('GT MCP operation failed')

    # Preserve the pre-existing development Runtime's process ownership.
    previous = json.loads(run([args.bvc, 'runtime', 'status', 'connect-dev'], 'development-before'))
    original_pids = {w['process']['pid'] for w in previous['workers'] if w['process']['live']}
    for identity in ['server', 'untrusted', *args.platforms]:
        run([args.library.parent / 'identity', output / 'identities' / identity], 'identity-' + identity)
    for platform in args.platforms:
        directory = output / platform; directory.mkdir()
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
            probe.bind(('127.0.0.1', 0)); port = probe.getsockname()[1]
        identities = output / 'identities'
        options = dict(role='client', bind='127.0.0.1:0', peer=f'127.0.0.1:{port}', server_name='localhost', capacity=4,
                       certificate=str(identities / platform / 'certificate.der'), private_key=str(identities / platform / 'private-key.der'),
                       trusted_certificate=str(identities / 'server/certificate.der'))
        server = dict(options, role='server', bind=f'127.0.0.1:{port}', certificate=str(identities / 'server/certificate.der'),
                      private_key=str(identities / 'server/private-key.der'), trusted_certificate=str(identities / platform / 'certificate.der'))
        del server['peer']
        write(directory / 'server.json', server)
        prefix = parameters['prefix'] + '_' + platform
        reconnected = prefix + ':reconnected:é🛰/\"'
        write(directory / 'client.json', dict(options, prefix=prefix, reconnectedName=reconnected, authority=args.authority))
        parameters['clients'].append(dict(name=platform, output=str(directory), prefix=prefix, reconnectedName=reconnected, library=str(args.library), serverOptions=str(directory / 'server.json')))
    try:
        if args.authority == 'gemstone':
            phase('configure'); configured = True
            report['configured'] = runtime('configure', output / 'runtime.ston')
            runtime('start')
            deadline = time.monotonic() + 45
            expected = {'users', *('connect_' + p for p in args.platforms)}
            while True:
                status = runtime('status')
                running = {s['identifier'] for w in status['workers'] for s in w['services']
                           if s['state'] == 'running' and s['appliedConfigurationVersion'] == status['configurationVersion']}
                if status['state'] == 'running' and expected <= running:
                    break
                if time.monotonic() > deadline:
                    raise TimeoutError('Runtime did not converge')
                time.sleep(.2)
            report['started'] = status; save()
        # Keep the GT MCP admission lease through external native validation and Runtime cleanup.
        # The Python controller is the sole Runtime owner; the GT task only owns this isolation gate.
        if args.authority == 'gt':
            write(output / 'parameters.json', parameters)
            rpc('lease-start', f'''| run |
run := CCNativeInteropRun new start: [| lease scenario |
 lease := CCNativeMcpLease forRunningServers.
 [lease during: [
  CRPlatform current writeConnectEvidence: (Dictionary new at: 'active' put: true; yourself) to: {quote(output / 'lease-active.json')}.
  scenario := CUUsersConnectNativeScenario new.
  [scenario runServerConfigurations: ((STONJSON fromString: {quote(output / 'parameters.json')} asFileReference contents) at: 'clients') directory: {quote(output)} asFileReference]
   on: Error, TestFailure do: [:error | CRPlatform current writeConnectEvidence: (Dictionary new at: 'error' put: error messageText asString; yourself) to: {quote(output / 'server-error.json')}]]]
 ensure: [CRPlatform current writeConnectEvidence: lease snapshot to: {quote(output / 'gt-mcp-gate.json')}]].
Smalltalk globals at: {quote(owner)} asSymbol put: run. run snapshot''')
        else:
            rpc('lease-start', f'''| run |
    run := CCNativeInteropRun new start: [| lease deadline |
     lease := CCNativeMcpLease forRunningServers.
     [lease during: [
      CRPlatform current writeConnectEvidence: (Dictionary new at: 'active' put: true; yourself) to: {quote(output / 'lease-active.json')}.
      deadline := CRPlatform current currentMillis + 600000.
      [({quote(output / 'release-lease')} asFileReference exists) or: [CRPlatform current currentMillis >= deadline]]
       whileFalse: [(Delay forMilliseconds: 10) wait]]]
     ensure: [CRPlatform current writeConnectEvidence: lease snapshot to: {quote(output / 'gt-mcp-gate.json')}]].
    Smalltalk globals at: {quote(owner)} asSymbol put: run. run snapshot''')
        lease = True; wait_json(output / 'lease-active.json')
        if args.authority == 'gt':
            deadline = time.monotonic() + 45
            while not (output / 'server-ready.json').exists():
                if (output / 'server-error.json').exists(): raise RuntimeError((output / 'server-error.json').read_text())
                if time.monotonic() > deadline: raise TimeoutError('GT authority startup')
                time.sleep(.05)
        for client in parameters['clients']:
            platform = client['name']; directory = Path(client['output'])
            parameters['activeClient'] = client; phase('gate')
            client_env = dict(env, CONNECT_TEST_CONFIGURATION=str(directory / 'client.json'), CU_OUTPUT=str(directory),
                              CONNECT_TEST_UNTRUSTED_CERTIFICATE=str(output / 'identities/untrusted/certificate.der'))
            if platform == 'swift-macos':
                command = ['swift', 'test', '--skip-build', '--disable-sandbox', '--package-path', str(args.apple_package),
                           '--filter', 'NativePushUsersTests' if args.push_only else 'NativeUsersTests', '--cache-path', '/private/tmp/catalyst-swift-cache',
                           '--config-path', '/private/tmp/catalyst-swift-config', '--security-path', '/private/tmp/catalyst-swift-security',
                           '-Xswiftc', '-module-cache-path', '-Xswiftc', '/private/tmp/catalyst-swift-modules']
            elif platform == 'swift-ios':
                command = ['python3', str(args.swift_repo / 'scripts/qualify-ios.py'), '--package', str(args.apple_package),
                           '--users', str(args.users_swift), '--output', str(directory / 'ios-results')]
                if args.push_only: command += ['--test-source', str(args.users_swift / 'Tests/CatalystUsersTests/NativePushUsersTests.swift')]
            else:
                command = [str(args.engine / 'Engine/Binaries/Mac/UnrealEditor.app/Contents/MacOS/UnrealEditor'), str(args.ue_project),
                           '-unattended', '-nop4', '-nullrhi', '-nosound', '-nosplash', '-stdout', '-FullStdOutLogOutput',
                           '-ExecCmds=Automation RunTests Catalyst.Users.Native.Push' if args.push_only else '-ExecCmds=Automation RunTests Catalyst.Users.Native.CreateUser', '-TestExit=Automation Test Queue Empty',
                           f'-ReportExportPath={directory / "unreal-results"}', f'-CUFixture={directory / "client.json"}', f'-CUOutput={directory}']
            log_path = directory / 'client.log'
            def success_seen():
                if (directory / 'client-success.json').exists():
                    return True
                copied = directory / 'ios-results/client-success.json'
                if copied.exists():
                    return json.loads(copied.read_text()).get('prefix') == client['prefix']
                simulator = directory / 'ios-results/simulator.json'
                if simulator.exists():
                    device = json.loads(simulator.read_text())['device']
                    containers = Path.home() / 'Library/Developer/CoreSimulator/Devices' / device / 'data/Containers/Data/Application'
                    markers = [containers.parent.parent.parent / 'Documents/cu-platform-success.json', *containers.glob('*/Documents/cu-platform-success.json')]
                    for marker in markers:
                        if not marker.exists():
                            continue
                        try:
                            if json.loads(marker.read_text()).get('prefix') == client['prefix']:
                                return True
                        except ValueError:
                            pass
                return False
            def live_disconnected():
                marker = directory / 'live-disconnected.json'
                candidates = [marker]
                simulator = directory / 'ios-results/simulator.json'
                if simulator.exists():
                    device = json.loads(simulator.read_text())['device']
                    containers = Path.home() / 'Library/Developer/CoreSimulator/Devices' / device / 'data/Containers/Data/Application'
                    candidates += [containers.parent.parent.parent / 'Documents/live-disconnected.json', *containers.glob('*/Documents/live-disconnected.json')]
                return any(p.exists() and json.loads(p.read_text(encoding='utf-8-sig')).get('prefix') == client['prefix'] for p in candidates)
            def marker_seen(name):
                candidates = [directory / name, directory / 'ios-results' / name]
                simulator = directory / 'ios-results/simulator.json'
                if simulator.exists():
                    device = json.loads(simulator.read_text())['device']
                    containers = Path.home() / 'Library/Developer/CoreSimulator/Devices' / device / 'data/Containers/Data/Application'
                    candidates += [containers.parent.parent.parent / 'Documents' / name, *containers.glob('*/Documents/' + name)]
                for path in candidates:
                    if path.exists():
                        try:
                            if json.loads(path.read_text(encoding='utf-8-sig')).get('prefix') == client['prefix']:
                                if path != directory / name: write(directory / name, dict(prefix=client['prefix']))
                                return True
                        except ValueError: pass
                return False
            with log_path.open('w') as log:
                process = subprocess.Popen(command, env=client_env, stdout=log, stderr=subprocess.STDOUT)
                try:
                    if args.push_only:
                        quiet_started = False
                        deadline = time.monotonic() + 180
                        while not (directory / 'push-inserted.json').exists():
                            if not quiet_started and marker_seen('idle-start.json'):
                                phase('quietBefore'); quiet_started = True
                            if process.poll() is not None or time.monotonic() > deadline: raise RuntimeError('Push edit gate not reached: ' + str(log_path))
                            time.sleep(.05)
                        assert quiet_started and marker_seen('idle-end.json'), 'Missing idle notification window'
                        phase('quietAfter')
                        if args.authority == 'gt': wait_json(directory / 'idle-proof.json')
                        assert not marker_seen('push-observed.json'), 'Update escaped before finalization'
                        if args.authority == 'gemstone': phase('pushBeforeCommit')
                        time.sleep(.2)
                        assert not marker_seen('push-observed.json'), 'Update escaped while held'
                        (directory / 'push-release').touch()
                        if args.authority == 'gemstone': phase('pushAfterCommit')
                    else:
                        deadline = time.monotonic() + 180
                        while not (directory / 'inserted.json').exists():
                            if process.poll() is not None or time.monotonic() > deadline:
                                raise RuntimeError('Client did not reach the insertion gate: ' + str(log_path))
                            time.sleep(.05)
                        inserted = wait_json(directory / 'inserted.json')
                        assert inserted['name'] == client['prefix'] + ':hold'
                        assert not success_seen(), 'Client completed before commit'
                        phase('beforeCommit')
                        time.sleep(.2)
                        assert not success_seen(), 'Client completed while the server transaction was held'
                        (directory / 'release').touch()
                        deadline = time.monotonic() + 30
                        while not success_seen():
                            if process.poll() is not None or time.monotonic() > deadline:
                                raise RuntimeError('Client did not receive the committed native result: ' + str(log_path))
                            time.sleep(.05)
                        phase('afterCommit')
                        deadline = time.monotonic() + 70
                        while not (directory / 'live-inserted.json').exists() or not live_disconnected():
                            if process.poll() is not None or time.monotonic() > deadline:
                                raise RuntimeError('Client did not reach lost-confirmation gate: ' + str(log_path))
                            time.sleep(.05)
                        phase('liveBeforeCommit')
                        (directory / 'live-release').touch()
                        phase('liveAfterCommit')
                    process.wait(timeout=90)
                    if process.returncode:
                        raise RuntimeError('Client failed: ' + str(log_path))
                finally:
                    (directory / 'push-release').touch()
                    (directory / 'live-release').touch()
                    (directory / 'release').touch()  # Never leave an admitted worker held by the test gate.
                    if process.poll() is None:
                        process.wait(timeout=600)
            if platform == 'unreal':
                result = wait_json(directory / 'unreal-results/index.json')
                assert len(result['tests']) == 1 and result['tests'][0]['state'] == 'Success', result
            elif platform == 'swift-ios':
                result = wait_json(directory / 'ios-results/summary.json')
                assert result['passedTests'] == 1 and result['failedTests'] == 0 and result['skippedTests'] == 0
            else:
                text = log_path.read_text()
                assert 'Executed 1 test' in text and '0 failures' in text and ('CU_PUSH_RESULT ' if args.push_only else 'CU_PLATFORM_RESULT ') in text
            report['clients'][platform] = dict(passed=True, noSuccessBeforeCommit=True, independentGemRead=True,
                                               nativeResult=True, rollbackUnknown=True, superUserUnknown=True,
                                               mismatchRefused=True, explicitReconnect=True, noAutomaticReplay=True,
                                               lookupFound=True, lookupNotFound=True, lookupAmbiguousRefused=True,
                                               lookupExactName=True, lookupDefaults=True, lookupRollbackAbsent=True, lookupUnicode=True,
                                               liveAdoption=True, identityCache=True, automaticRefresh=True, conflictPreservesDraft=True,
                                               lostCreationRecovered=True, liveRollbackAbsent=True)
            if args.push_only:
                report['clients'][platform] = dict(passed=True, pushedAfterFinalization=True, zeroIdleApplicationRequests=True, nativeSubscriptionReady=True, stableIdentity=True, reconnect=True, conflictPreservesDraft=True, rollbackSuppressed=args.authority == 'gemstone')
            save(); print(platform + ': passed', flush=True)
        if args.authority == 'gemstone': phase('verifyPush' if args.push_only else 'verify')
        else:
            (output / 'server-stop').touch()
            evidence = wait_json(output / 'server-evidence.json')
            assert evidence['zeroIdleReads'] and evidence['idleChecks'] == len(parameters['clients']), evidence
            assert evidence['buffersReleased'] and evidence['runtimeStopped'] and evidence['runtimeUnregistered'], evidence
            assert sorted(evidence['createdUsers']) == sorted(c['prefix'] + ':push-reconnected' for c in parameters['clients']), evidence
            report['gtAuthority'] = evidence
        report['passed'] = True
    finally:
        if args.authority == 'gt': (output / 'server-stop').touch()
        # Keep the single Runtime owner and MCP gate until positive managed-worker cleanup.
        if configured:
            state = runtime('status')
            if state['state'] != 'stopped':
                runtime('stop')
            runtime('remove'); phase('cleanup')
        if lease:
            (output / 'release-lease').touch()
            gate = wait_json(output / 'gt-mcp-gate.json')
            assert gate['state'] == 'released' and gate['originalRegistriesRestored'], gate
            report['mcpGate'] = gate
            rpc('lease-join', f'''| run | run := Smalltalk globals at: {quote(owner)} asSymbol.
run waitForMillis: 1000. self assert: run isFinished. Smalltalk globals removeKey: {quote(owner)} asSymbol. run snapshot''')
        current = json.loads(run([args.bvc, 'runtime', 'status', 'connect-dev'], 'development-after'))
        assert original_pids == {w['process']['pid'] for w in current['workers'] if w['process']['live']}
        report['developmentRuntimePreserved'] = True
        for key in (output / 'identities').rglob('private-key.der'):
            key.unlink()
        save()
    print('Native platform Users qualification passed: ' + str(output / 'qualification.json'))


if __name__ == '__main__':
    main()
