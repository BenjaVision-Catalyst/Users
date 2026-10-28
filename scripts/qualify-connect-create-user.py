#!/usr/bin/env python3
"""Opt-in GT client Runtime -> Connect -> configured GemStone Users qualification.

Requires verified production packages and the explicit qualification fixtures
already loaded in GT/GemStone. Preserves failed Runtime/evidence for inspection.
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


def st(value):
    return "'" + str(value).replace("'", "''") + "'"


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def wait_json(path, timeout=50):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if path.exists():
            try:
                return json.loads(path.read_text())
            except ValueError:
                pass
        time.sleep(.1)
    raise TimeoutError('Owner retains resources; inspect ' + str(path.parent))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for flag in ('project', 'bvc', 'library', 'output'):
        parser.add_argument('--' + flag, type=Path, required=True)
    parser.add_argument('--deployment', required=True)
    parser.add_argument('--mcp-url', default='http://127.0.0.1:3001/')
    args = parser.parse_args()
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=False)
    for field in ('project', 'bvc', 'library'):
        setattr(args, field, getattr(args, field).resolve())
    output = args.output
    runtime = 'users_connect_' + uuid.uuid4().hex[:12]
    prefix = runtime + '_user'
    report = dict(runtime=runtime, phases={})
    parameters = dict(runtime=runtime, prefix=prefix, library=str(args.library))
    write(output / 'parameters.json', parameters)
    env = dict(os.environ, GEMSTONE_STONE_NAME=args.deployment,
               BVC_USERS_CONNECT_DIRECTORY=str(output))

    def run(argv, label, extra_env=None):
        result = subprocess.run(list(map(str, argv)), cwd=args.project,
                                env=extra_env or env, text=True, capture_output=True, timeout=90)
        (output / (label + '.log')).write_text(result.stdout + result.stderr)
        assert result.returncode == 0, 'Inspect ' + str(output / (label + '.log'))
        return result.stdout

    def command(action, *extra):
        return json.loads(run([args.bvc, 'runtime', action, runtime, *extra],
                              action + '-' + str(time.monotonic_ns())))

    def phase(name):
        run([args.bvc, 'topaz', args.deployment, '--script',
             Path(__file__).with_suffix('.topaz')], name,
            dict(env, BVC_USERS_CONNECT_PHASE=name))
        report['phases'][name] = json.loads((output / (name + '.json')).read_text())
        write(output / 'qualification.json', report)
        print(name + ': passed', flush=True)

    def rpc(directory, label, code):
        request = dict(jsonrpc='2.0', id=1, method='tools/call', params=dict(
            name='smalltalkCodeEvaluation', arguments=dict(code=code)))
        write(directory / (label + '-request.json'), request)
        result = json.loads(urllib.request.urlopen(urllib.request.Request(
            args.mcp_url, json.dumps(request).encode(),
            {'Content-Type': 'application/json'}), timeout=60).read())
        write(directory / (label + '-response.json'), result)
        assert not result.get('error') and not result.get('result', {}).get('isError'), result
        for block in result.get('result', {}).get('content', []):
            if block.get('type') == 'text':
                assert 'errorDetails' not in json.loads(block['text']), block

    def client(label, cases):
        directory = output / label
        directory.mkdir()
        write(directory / 'cases.json', cases)
        name = 'CUUsersConnectRun' + uuid.uuid4().hex
        write(directory / 'owner.json', dict(globalName=name))
        rpc(directory, 'dispatch', f'''| run |
run := CCNativeInteropRun new start: [| lease cfg target scenario |
 lease := CCNativeMcpLease forRunningServers.
 [lease during: [
  target := CRServiceBindingConfiguration new identifier: #users; label: 'Users'; serviceIdentifier: #users;
   runtimeIdentifier: {st(report['started']['runtimeIdentifier'])}; connectServiceIdentifier: #connect; yourself.
  cfg := CCQuicConfiguration new identifier: #connect; label: 'Users client';
   nativeOptionsJson: {st(output / 'gt-options.json')} asFileReference contents;
   libraryPath: {st(args.library)}; principal: {st(report['started']['runtimeIdentifier'])};
   allowedOperations: #(1 65534); applicationClass: CUUsersObjectApplication; bindings: {{target}}; yourself.
  scenario := CUUsersConnectNativeScenario new.
  [scenario runConfiguration: cfg cases: (STONJSON fromString: {st(directory / 'cases.json')} asFileReference contents) directory: {st(directory)} asFileReference]
   on: Error, TestFailure do: [:error | CRPlatform current writeConnectEvidence: (Dictionary new at: 'error' put: error messageText asString; at: 'class' put: error class name asString; yourself) to: {st(directory / 'error.json')}].
  scenario evidence]] ensure: [CRPlatform current writeConnectEvidence: lease snapshot to: {st(directory / 'gt-mcp-gate.json')}]].
Smalltalk globals at: {st(name)} asSymbol put: run. run snapshot''')
        # Wait OUTSIDE GT; only the owner releases MCP admission after cleanup.
        gate = wait_json(directory / 'gt-mcp-gate.json')
        assert gate['state'] == 'released' and gate['originalRegistriesRestored'], gate
        rpc(directory, 'join', f'''| run | run := Smalltalk globals at: {st(name)} asSymbol.
run waitForMillis: 1000. self assert: run isFinished. Smalltalk globals removeKey: {st(name)} asSymbol. run snapshot''')
        assert not (directory / 'error.json').exists(), (directory / 'error.json').read_text() if (directory / 'error.json').exists() else ''
        evidence = wait_json(directory / 'evidence.json')
        assert evidence['createdFromConfiguration'] and evidence['converged'] and evidence['runtimeStopped'], evidence
        assert evidence['clientStoreUnchanged'] and evidence['service']['buffersReleased'], evidence
        report[label] = evidence
        report[label + 'McpGate'] = gate
        write(output / 'qualification.json', report)
        print(label + ': passed', flush=True)

    for peer in ('gt', 'gs'):
        run([args.library.parent / 'identity', output / 'identities' / peer], 'identity-' + peer)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(('127.0.0.1', 0))
        port = probe.getsockname()[1]
    for peer in ('gt', 'gs'):
        other = 'gs' if peer == 'gt' else 'gt'
        root = output / 'identities'
        options = dict(role='client' if peer == 'gt' else 'server', bind='127.0.0.1:' + str(0 if peer == 'gt' else port),
                       server_name='localhost', certificate=str(root / peer / 'certificate.der'),
                       private_key=str(root / peer / 'private-key.der'),
                       trusted_certificate=str(root / other / 'certificate.der'), capacity=4)
        if peer == 'gt':
            options['peer'] = '127.0.0.1:' + str(port)
        write(output / (peer + '-options.json'), options)
    phase('configure')
    report['configured'] = command('configure', output / 'runtime.ston')
    assert report['configured']['state'] == 'stopped'
    command('start')
    deadline = time.monotonic() + 45
    while True:
        status = command('status')
        ready = {s['identifier'] for w in status['workers'] for s in w['services']
                 if s['state'] == 'running' and s['appliedConfigurationVersion'] == status['configurationVersion']}
        if status['state'] == 'running' and {'connect', 'users'} <= ready:
            break
        assert time.monotonic() < deadline, status
        time.sleep(.2)
    report['started'] = status
    write(output / 'qualification.json', report)
    client('client', [dict(name=prefix + ':committed', superUser=False, expected='completed'),
                      dict(name=prefix + ':rollback', superUser=False, expected='unknown'),
                      dict(name=prefix + ':super', superUser=True, expected='unknown')])
    phase('verify')
    phase('deny')
    changed = command('status')
    assert {w['process']['pid'] for w in status['workers'] if w['process']['live']} == {
        w['process']['pid'] for w in changed['workers'] if w['process']['live']}
    report['workerGemsPreserved'] = True
    assert command('stop')['state'] == 'stopped'
    assert command('remove')['state'] == 'removed'
    phase('cleanup')
    report['passed'] = True
    write(output / 'qualification.json', report)
    print('Users createUser through Connect passed: ' + str(output / 'qualification.json'), flush=True)


if __name__ == '__main__':
    main()
