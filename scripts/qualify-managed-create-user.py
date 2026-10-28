#!/usr/bin/env python3
"""Opt-in, socket-free createUser qualification through a configured GemStone Runtime.

Requires the verified Runtime/Users production sources already loaded. Loads only
its two data-only test WorkUnits. Failed runs retain their Runtime and fixture.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import uuid


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, required=True)
    parser.add_argument('--deployment', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--bvc', type=Path, default=shutil.which('bvc'))
    args = parser.parse_args()
    assert args.bvc, 'Supply --bvc or put bvc on PATH'
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    project, bvc = args.project.resolve(), args.bvc.resolve()
    repository = Path(__file__).resolve().parents[1]
    runtime = 'users_runtime_' + uuid.uuid4().hex[:12]
    env = dict(os.environ, GEMSTONE_STONE_NAME=args.deployment,
               BVC_USERS_RUNTIME_NAME=runtime,
               BVC_USERS_TRANSACTION_ROOT=runtime + '_qualification',
               BVC_USERS_TRANSACTION_CONFIGURATION=str(output / 'runtime.ston'))
    evidence = dict(runtime=runtime, stone=args.deployment, phases={})

    def save():
        (output / 'qualification.json').write_text(json.dumps(evidence, indent=2) + '\n')

    def run(argv, label, extra_env=None):
        result = subprocess.run(list(map(str, argv)), cwd=project,
                                env=extra_env or env, text=True, capture_output=True, timeout=90)
        (output / (label + '.log')).write_text(result.stdout + result.stderr)
        assert result.returncode == 0, 'Inspect ' + str(output / (label + '.log'))
        return result.stdout

    def command(action, *extra):
        return json.loads(run([bvc, 'runtime', action, runtime, *extra], action + '-' + str(time.monotonic_ns())))

    def phase(name):
        phase_env = dict(env, BVC_USERS_TRANSACTION_PHASE=name,
                         BVC_USERS_TRANSACTION_REPORT=str(output / (name + '.json')))
        run([bvc, 'topaz', args.deployment, '--script', repository / 'scripts/qualify-create-user.topaz'],
            name, phase_env)
        evidence['phases'][name] = json.loads((output / (name + '.json')).read_text())
        save()
        print(name + ': passed', flush=True)

    save()
    prepare = output / 'prepare.topaz'
    source = str(repository / 'src').replace("'", "''")
    prepare.write_text("run\nGsDeployer deploy: [ | source definitions |\n"
                       "source := MetacelloPlatform current fileHandleOn: '" + source + "'.\n"
                       "definitions := (TonelMCReader on: source fileName: 'BVC-Users-Tests') snapshot definitions select: [:d | "
                       "(d isClassDefinition or: [d isMethodDefinition]) and: [#('CUUsersFailAfterCreateTestWorkUnit' 'CUUsersDeniedTestWorkUnit') includes: d className asString]].\n"
                       "(definitions select: [:d | d isClassDefinition]) do: [:d | d load].\n"
                       "(definitions select: [:d | d isMethodDefinition]) do: [:d | d load]]. true\n%\ncommit\n")
    run([bvc, 'topaz', args.deployment, '--script', prepare], 'prepare')
    phase('configure')
    evidence['configured'] = command('configure', output / 'runtime.ston')
    assert evidence['configured']['state'] == 'stopped'
    command('start')
    deadline = time.monotonic() + 30
    while True:
        state = command('status')
        if state['state'] == 'running':
            break
        assert time.monotonic() < deadline, state
        time.sleep(.2)
    evidence['started'] = state
    save()
    phase('execute')
    phase('verify')
    phase('deny')
    changed = command('status')
    before = {w['workerIdentifier']: w['process']['pid'] for w in state['workers'] if w['process']['live']}
    after = {w['workerIdentifier']: w['process']['pid'] for w in changed['workers'] if w['process']['live']}
    assert before == after, 'Live configuration replaced worker Gems'
    evidence['workerGemsPreserved'] = True
    phase('obsolete')
    evidence['stopped'] = command('stop')
    assert evidence['stopped']['state'] == 'stopped'
    evidence['removed'] = command('remove')
    assert evidence['removed']['state'] == 'removed'
    phase('cleanup')
    evidence['passed'] = True
    save()
    print('Configured Runtime createUser qualification passed: ' + str(output / 'qualification.json'), flush=True)


if __name__ == '__main__':
    main()
