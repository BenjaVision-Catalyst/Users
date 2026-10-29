#!/usr/bin/env python3
"""Record native statistics around the existing, lifecycle-owned Users controller.

Reuse the established native reader, identity validation and owned collector cleanup.
The command after -- must be a bounded qualification controller that owns its cleanup.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('statistics-tools', 'statmonitor', 'project', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--stone', required=True)
    parser.add_argument('--stone-pid', type=int, required=True)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command or args.stone_pid <= 1:
        parser.error('A concrete Stone PID and qualification command are required')
    sys.path.insert(0, str(args.statistics_tools.resolve(strict=True)))
    from native_statmonitor import read_capture, stone_samples, summarize
    from statmonitor_profile import stop_collector

    directory = args.output.resolve()
    directory.mkdir(parents=True, exist_ok=False)
    raw = directory / 'native.out'
    collector_command = [str(args.statmonitor.resolve(strict=True)), args.stone,
                         '-I', '100', '-t', '6000', '-u', '0', '-T', '-f', str(raw)]
    manifest = dict(stone=args.stone, stonePid=args.stone_pid, collectorCommand=collector_command,
                    workloadCommand=command, intervalMs=100, maximumSamples=6000, monitoringGemLogins=0)

    def stamp():
        return dict(wallUs=time.time_ns() // 1000, monotonicUs=time.monotonic_ns() // 1000)

    try:
        with (directory / 'statmonitor.log').open('w') as log:
            collector = subprocess.Popen(collector_command, cwd=args.project, stdout=log,
                                         stderr=subprocess.STDOUT, start_new_session=True)
            manifest['collectorPid'] = collector.pid
            try:
                deadline = time.monotonic() + 15
                while True:
                    if collector.poll() is not None or time.monotonic() >= deadline:
                        raise RuntimeError('Collector did not attach to the expected Stone')
                    if raw.exists():
                        _, _, rows = read_capture(raw, live=True)
                        if rows and len(stone_samples(rows, args.stone, args.stone_pid)) >= 3:
                            break
                    time.sleep(.05)
                manifest['beforeWorkload'] = stamp()
                with (directory / 'workload.log').open('w') as output:
                    result = subprocess.run(command, cwd=args.project, stdout=output, stderr=subprocess.STDOUT)
                manifest['afterWorkload'] = stamp()
                manifest['workloadExit'] = result.returncode
                if result.returncode:
                    raise RuntimeError('Qualification failed; inspect preserved workload.log')
            finally:
                manifest['collectorExit'] = stop_collector(collector)
        if 'StatMon is detaching from shared cache.' not in (directory / 'statmonitor.log').read_text():
            raise RuntimeError('Missing positive native detach evidence')
        metadata, schemas, rows = read_capture(raw)
        # The controller writes its ordinary report in the sibling workload directory.
        report = json.loads((directory.parent / 'workload' / 'qualification.json').read_text())
        workers = report['started']['workers']
        serving = [w for w in workers if w['hostIdentifier'] == 'application']
        if len(serving) != 1 or not report.get('passed'):
            raise RuntimeError('Expected one successful configured Users authority')
        roles = dict(activation=dict(pid=serving[0]['process']['pid']),
                     workerLogs=[dict(pid=w['process']['pid'], worker=w['workerIdentifier']) for w in workers])
        manifest.update(summarize(rows, args.stone, args.stone_pid, roles), metadata=metadata,
                        schemas={name: columns for name, columns in schemas.values()},
                        cleanDetach=True, passed=True)
    except Exception as error:
        manifest['error'] = repr(error)
        raise
    finally:
        (directory / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('Native Users capture passed: ' + str(directory))


if __name__ == '__main__':
    main()
