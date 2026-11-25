#!/usr/bin/env python3
"""Canonical launcher fixtures; fake Nix only, with no builds or native tools."""
import json
import importlib.util
import os
from pathlib import Path
import shutil
import selectors
import shlex
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parent


class LauncherTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='project-launcher-')
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name).resolve()
        self.project = self.directory / 'source archive # with spaces'
        (self.project / 'scripts').mkdir(parents=True)
        (self.project / 'nix').mkdir()
        for name in ('dev', 'environment-exec.py', 'retain-nix-environment'):
            shutil.copy2(SCRIPTS / name, self.project / 'scripts' / name)
        (self.project / 'flake.nix').write_text('{ /* fixture only */ }\n')
        (self.project / 'flake.lock').write_text('{"fixture":1}\n')
        (self.project / 'metadata with spaces').mkdir()
        (self.project / 'metadata with spaces/config.json').write_text('{"kept":true}\n')
        (self.project / 'code').mkdir()
        (self.project / 'code/input.txt').write_text('kept\n')
        (self.project / 'nix/source-files').write_text(
            '# project inputs\n\nmetadata with spaces/config.json\ncode\ncode/input.txt')
        for name in ('.work/cache', '.venv/lib', 'results/old'):
            (self.project / name).mkdir(parents=True)
            (self.project / name / 'excluded').write_text('never captured')
        self.environment = self.directory / 'immutable environment'
        (self.environment / 'bin').mkdir(parents=True)
        (self.environment / 'share').mkdir()
        (self.environment / 'bin/python3').symlink_to(sys.executable)
        self.manifest = {'schema': 1, 'variables': {'LOCKED_TOOL': '/nix/store/locked tool'},
                         'unset': ['REMOVE_ME', 'PYTHONPATH']}
        self.write_manifest()
        self.tools = self.directory / 'host tools without python'
        self.tools.mkdir()
        for name in ('dirname', 'basename', 'mkdir', 'mktemp', 'find', 'cp', 'rm', 'ln'):
            (self.tools / name).symlink_to(shutil.which(name))
        self.snapshot = self.directory / 'captured inputs'
        self.arguments = self.directory / 'nix arguments'
        self.publication_arguments = self.directory / 'nix publication arguments'
        self.store_arguments = self.directory / 'nix-store arguments'
        self.nix_directory = self.directory / 'actual nix bin'
        self.nix_directory.mkdir()
        self.fake_nix = self.nix_directory / 'nix'
        self.fake_nix.write_text('''#!/bin/sh
set -eu
for argument in "$@"; do last=$argument; done
log=$TEST_NIX_ARGUMENTS
if [ "${3:-}" = build ]; then
    case "$last" in /*) log=$TEST_NIX_PUBLICATION_ARGUMENTS ;; esac
fi
printf '%s\n' "$@" > "$log"
if [ "${TEST_NIX_FAILURE:-}" = 1 ]; then exit 7; fi
[ "$1" = --extra-experimental-features ]
[ "$2" = 'nix-command flakes' ]
shift 2
if [ "$1" = eval ]; then
    cp -R . "$TEST_NIX_SNAPSHOT"
    if [ "${TEST_NIX_ENFORCE_INPUT:-}" = 1 ]; then
        IFS= read -r requested < flake.nix
        IFS= read -r locked < flake.lock
        if [ "$requested" != "$locked" ]; then
            for argument in "$@"; do
                if [ "$argument" = --no-update-lock-file ]; then
                    printf '%s\\n' 'input requires a lock update' >&2
                    exit 8
                fi
            done
        fi
    fi
    printf '%s\n' 'fixture evaluation'
    exit 0
fi
[ "$1" = build ]
shift
while [ "$#" -gt 0 ]; do
    if [ "$1" = --out-link ]; then shift; link=$1; fi
    shift
done
case "$last" in
    /*)
        if [ -L "$link" ] && [ ! -e "$link" ]; then
            printf '%s\n' 'cannot replace a dangling root view' >&2
            exit 1
        fi
        if [ -e "$link" ] && [ ! -L "$link" ]; then
            printf '%s\n' 'refusing to replace a real path' >&2
            exit 1
        fi
        ln -sfn "$last" "$link"
        exit 0
        ;;
esac
case "$last" in 'path:.#dev-environment'|'path:.#analysis-environment') ;; *) exit 1 ;; esac
cp -R . "$TEST_NIX_SNAPSHOT"
ln -sfn "$TEST_NIX_ENVIRONMENT" "$link"
''')
        self.fake_nix.chmod(0o755)
        (self.tools / 'nix').symlink_to(self.fake_nix)
        (self.nix_directory / 'nix-store').write_text('''#!/bin/sh
set -eu
printf '%s\n' "$@" > "$TEST_NIX_STORE_ARGUMENTS"
[ "$1" = --add-root ]
if [ -L "$2" ] && [ ! -e "$2" ]; then
    printf '%s\n' 'cannot replace a dangling root view' >&2
    exit 1
fi
ln -sfn "$5" "$2"
''')
        (self.nix_directory / 'nix-store').chmod(0o755)
        (self.tools / 'nix-store').symlink_to(self.nix_directory / 'nix-store')
        self.undeclared = self.directory / 'undeclared host tools'
        self.undeclared.mkdir()
        rogue = self.undeclared / 'undeclared-tool'
        rogue.write_text('#!/bin/sh\nexit 0\n')
        rogue.chmod(0o755)
        self.exported = os.environ | {
            'PATH': str(self.tools) + os.pathsep + str(self.undeclared), 'REMOVE_ME': 'host value',
            'TEST_NIX_ARGUMENTS': str(self.arguments), 'TEST_NIX_SNAPSHOT': str(self.snapshot),
            'TEST_NIX_PUBLICATION_ARGUMENTS': str(self.publication_arguments),
            'TEST_NIX_STORE_ARGUMENTS': str(self.store_arguments),
            'TEST_NIX_ENVIRONMENT': str(self.environment),
        }

    def write_manifest(self):
        (self.environment / 'share/project-environment.json').write_text(json.dumps(self.manifest))

    def launch(self, *arguments, extra=None):
        command = [str(self.project / 'scripts/dev'), *arguments]
        return subprocess.run(command, cwd=self.directory, env=self.exported | (extra or {}),
                              text=True, capture_output=True, timeout=10)

    def test_explicit_profile_uses_separate_root(self):
        result = self.launch('--profile', 'analysis', 'python3', '-V')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('path:.#analysis-environment', self.arguments.read_text().splitlines())
        work = self.project / '.work/nix'
        self.assertEqual((work / 'analysis-environment').resolve(), self.environment)
        self.assertFalse((work / 'environment').exists())
        self.assertNotEqual(self.launch('--profile', '../escape', 'python3').returncode, 0)

    def test_archive_spaces_filtered_inputs_environment_and_arguments(self):
        result = self.launch('python3', '-I', '-c',
            'import json,os,sys; print(json.dumps({"cwd":os.getcwd(), "root":os.environ["PROJECT_ROOT"], '
            '"environment":os.environ["PROJECT_NIX_ENVIRONMENT"], "locked":os.environ["LOCKED_TOOL"], '
            '"removed":"REMOVE_ME" in os.environ, "path":os.environ["PATH"], "args":sys.argv[1:]}))',
            'two words', '$(literal)', '')
        self.assertEqual(result.returncode, 0, result.stderr)
        observed = json.loads(result.stdout)
        self.assertEqual(observed['cwd'], str(self.project))
        self.assertEqual(observed['root'], str(self.project))
        self.assertEqual(observed['environment'], str(self.environment))
        self.assertEqual(observed['locked'], '/nix/store/locked tool')
        self.assertFalse(observed['removed'])
        self.assertEqual(observed['path'].split(os.pathsep),
                         [str(self.environment / 'bin'), str(self.nix_directory),
                          '/usr/bin', '/bin', '/usr/sbin', '/sbin'])
        self.assertEqual(observed['args'], ['two words', '$(literal)', ''])
        self.assertFalse((self.snapshot / '.work').exists())
        self.assertFalse((self.snapshot / '.venv').exists())
        self.assertFalse((self.snapshot / 'results').exists())
        self.assertFalse((self.snapshot / 'scripts/dev').exists())
        self.assertEqual((self.snapshot / 'code/input.txt').read_text(), 'kept\n')
        self.assertEqual((self.snapshot / 'metadata with spaces/config.json').read_text(), '{"kept":true}\n')
        self.assertIn('--no-update-lock-file', self.arguments.read_text().splitlines())
        self.assertEqual(self.arguments.read_text().splitlines()[:2],
                         ['--extra-experimental-features', 'nix-command flakes'])
        self.assertIn('path:.#dev-environment', self.arguments.read_text().splitlines())
        self.assertEqual(self.publication_arguments.read_text().splitlines(),
                         ['--extra-experimental-features', 'nix-command flakes', 'build',
                          '--no-update-lock-file', '--out-link',
                          str(self.project / '.work/nix/environment'), str(self.environment)])
        self.assertFalse(self.store_arguments.exists())
        self.assertEqual(list((self.project / '.work/nix').glob('stage.*')), [])
        result = self.launch('undeclared-tool')
        self.assertEqual(result.returncode, 127, result.stderr)

    def test_inherited_markers_do_not_bypass_a_changed_lock(self):
        extra = {'PROJECT_ROOT': str(self.project), 'PROJECT_NIX_ENVIRONMENT': str(self.environment)}
        (self.project / 'flake.lock').write_text('{"fixture":2}\n')
        result = self.launch('python3', '-I', '-c', 'pass', extra=extra)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.snapshot / 'flake.lock').read_text(), '{"fixture":2}\n')

    def test_markers_are_set_before_any_environment_python_startup(self):
        startup = self.directory / 'interpreter startup markers'
        stale = self.directory / 'stale project'
        (stale / 'src').mkdir(parents=True)
        interpreter = self.environment / 'bin/python3'
        interpreter.unlink()
        interpreter.write_text('''#!/bin/sh
set -eu
printf '%s\\n' "${PROJECT_ROOT:-missing}" "${PROJECT_NIX_ENVIRONMENT:-missing}" >> "$TEST_STARTUP_MARKERS"
[ "${PROJECT_ROOT:-}" = "$TEST_EXPECTED_PROJECT_ROOT" ] || exit 91
[ "${PROJECT_NIX_ENVIRONMENT:-}" = "$TEST_EXPECTED_ENVIRONMENT" ] || exit 92
exec ''' + shlex.quote(sys.executable) + ''' "$@"
''')
        interpreter.chmod(0o755)
        result = self.launch('python3', '-I', '-c', 'pass', extra={
            'PROJECT_ROOT': str(stale), 'PROJECT_NIX_ENVIRONMENT': '/stale-environment',
            'TEST_STARTUP_MARKERS': str(startup),
            'TEST_EXPECTED_PROJECT_ROOT': str(self.project),
            'TEST_EXPECTED_ENVIRONMENT': str(self.environment),
        })
        self.assertEqual(result.returncode, 0, result.stderr)
        observed = startup.read_text().splitlines()
        self.assertGreaterEqual(len(observed), 4)
        self.assertEqual(len(observed) % 2, 0)
        self.assertEqual(observed, [str(self.project), str(self.environment)] * (len(observed) // 2))

    def test_eval_uses_the_same_allowlist_without_realizing_an_environment(self):
        result = self.launch('--eval', 'packages.fixture.version', '--raw')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, 'fixture evaluation\n')
        self.assertEqual(self.arguments.read_text().splitlines(),
                         ['--extra-experimental-features', 'nix-command flakes', 'eval',
                          '--no-update-lock-file', 'path:.#packages.fixture.version', '--raw'])
        self.assertEqual((self.snapshot / 'metadata with spaces/config.json').read_text(), '{"kept":true}\n')
        self.assertFalse((self.snapshot / '.work').exists())
        self.assertFalse((self.snapshot / '.venv').exists())
        self.assertFalse((self.snapshot / 'results').exists())
        self.assertFalse((self.project / '.work/nix/environment').exists())
        self.assertFalse(self.store_arguments.exists())
        self.assertFalse(self.publication_arguments.exists())
        self.assertEqual(list((self.project / '.work/nix').glob('stage.*')), [])

    def test_eval_refuses_changed_input_without_updating_reviewed_lock(self):
        reviewed = '{"input":"A"}\n'
        (self.project / 'flake.nix').write_text(reviewed)
        lock = self.project / 'flake.lock'
        lock.write_text(reviewed)
        for input_value, expected in ((reviewed, 0), ('{"input":"B"}\n', 8)):
            with self.subTest(input_value=input_value):
                (self.project / 'flake.nix').write_text(input_value)
                result = self.launch('--profile', 'analysis', '--eval', 'packages.fixture.version',
                                     '--raw', extra={'TEST_NIX_ENFORCE_INPUT': '1'})
                self.assertEqual(result.returncode, expected, result.stderr)
                self.assertEqual(lock.read_bytes(), reviewed.encode())
                self.assertEqual((self.snapshot / 'flake.lock').read_bytes(), reviewed.encode())
                self.assertIn('--no-update-lock-file', self.arguments.read_text().splitlines())
                self.assertFalse(self.publication_arguments.exists())
                self.assertFalse(self.store_arguments.exists())
                self.assertEqual(list((self.project / '.work/nix').glob('stage.*')), [])
                shutil.rmtree(self.snapshot)

    def test_failed_realization_preserves_previous_environment_root_and_cleans_stage(self):
        work = self.project / '.work/nix'
        work.mkdir()
        (work / 'environment').symlink_to(self.environment)
        result = self.launch('unused-command', extra={'TEST_NIX_FAILURE': '1'})
        self.assertEqual(result.returncode, 7)
        self.assertEqual((work / 'environment').resolve(), self.environment)
        self.assertEqual(list(work.glob('stage.*')), [])

    def test_dangling_environment_view_recovers_and_real_paths_are_preserved(self):
        work = self.project / '.work/nix'
        work.mkdir()
        view = work / 'environment'
        view.symlink_to(self.directory / 'missing environment')
        result = self.launch('python3', '-I', '-c', 'pass')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(view.resolve(), self.environment)
        self.assertEqual(list(work.glob('stage.*')), [])
        view.unlink()
        view.mkdir()
        (view / 'keep.txt').write_text('existing real directory contents')
        result = self.launch('unused-command')
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assertEqual((view / 'keep.txt').read_text(), 'existing real directory contents')
        self.assertFalse(self.store_arguments.exists())
        shutil.rmtree(view)
        view.write_text('existing real file')
        result = self.launch('unused-command')
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assertEqual(view.read_text(), 'existing real file')
        self.assertFalse(self.store_arguments.exists())
        self.assertEqual(list(work.glob('stage.*')), [])

    def test_source_traversal_symlinks_and_generated_trees_fail_before_nix(self):
        (self.project / 'outside-link').symlink_to(self.directory)
        for entry in ('../outside', '/absolute', '.', 'outside-link', '.work', 'results'):
            with self.subTest(entry=entry):
                (self.project / 'nix/source-files').write_text(entry + '\n')
                result = self.launch('unused-command')
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertFalse(self.arguments.exists())
                self.assertEqual(list((self.project / '.work/nix').glob('stage.*')), [])

    def test_project_reserved_inputs_are_rejected_directly_and_when_nested(self):
        for name in ('.private', '.local', '.vendor'):
            with self.subTest(name=name, location='root'):
                (self.project / 'nix/source-files').write_text(name + '\n')
                result = self.launch('unused-command')
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertFalse(self.arguments.exists())
            with self.subTest(name=name, location='nested'):
                nested = self.project / 'code' / name
                nested.mkdir()
                (self.project / 'nix/source-files').write_text('code\n')
                result = self.launch('unused-command')
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertFalse(self.arguments.exists())
                nested.rmdir()
                self.assertEqual(list((self.project / '.work/nix').glob('stage.*')), [])

    def test_private_instructions_are_rejected_directly_and_when_nested(self):
        for relative, source in (('AGENTS.md', 'AGENTS.md'),
                                 ('code/AGENTS.md', 'code'),
                                 ('nix/AGENTS.md', 'code')):
            with self.subTest(relative=relative):
                instruction = self.project / relative
                instruction.write_text('synthetic private instructions\n')
                self.addCleanup(instruction.unlink, missing_ok=True)
                (self.project / 'nix/source-files').write_text(source + '\n')
                result = self.launch('unused-command')
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertFalse(self.arguments.exists())
                self.assertEqual(list((self.project / '.work/nix').glob('stage.*')), [])
                instruction.unlink()

    def test_invalid_environment_manifests_are_rejected(self):
        for manifest in (
            {'schema': 2, 'variables': {}, 'unset': []},
            {'schema': True, 'variables': {}, 'unset': []},
            {'schema': 1, 'variables': {'PROJECT_ROOT': '/override'}, 'unset': []},
            {'schema': 1, 'variables': {'BAD-NAME': 'value'}, 'unset': []},
            {'schema': 1, 'variables': {'VALUE': 1}, 'unset': []},
            {'schema': 1, 'variables': {'VALUE': 'x'}, 'unset': ['VALUE']},
            {'schema': 1, 'variables': {'PATH': '/unlocked/tools'}, 'unset': []},
        ):
            with self.subTest(manifest=manifest):
                self.manifest = manifest
                self.write_manifest()
                result = subprocess.run([sys.executable, '-I', str(SCRIPTS / 'environment-exec.py'),
                    str(self.project), str(self.environment), str(self.fake_nix), 'unused-command'],
                    text=True, capture_output=True, timeout=10)
                self.assertEqual(result.returncode, 2, result.stderr)

    def test_command_exit_status_is_preserved(self):
        result = self.launch('python3', '-I', '-c', 'raise SystemExit(23)')
        self.assertEqual(result.returncode, 23, result.stderr)

    def test_new_capture_registers_indirect_root_without_replacing_existing_root(self):
        capture = self.directory / 'new capture'
        capture.mkdir()
        link = capture / 'nix-environment'
        command = [str(self.project / 'scripts/retain-nix-environment'), str(link)]
        environment = self.exported | {'PROJECT_NIX_ENVIRONMENT': str(self.environment)}
        result = subprocess.run(command, env=environment, text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(link.resolve(), self.environment)
        self.assertEqual(self.store_arguments.read_text().splitlines(),
                         ['--add-root', str(link), '--indirect', '--realise', str(self.environment)])
        result = subprocess.run(command, env=environment, text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(link.resolve(), self.environment)

    def test_concurrent_commands_keep_independent_roots_until_each_command_exits(self):
        second = self.directory / 'second immutable environment'
        shutil.copytree(self.environment, second, symlinks=True)
        command = [str(self.project / 'scripts/dev'), 'python3', '-I', '-c',
                   'import os,sys; print(os.environ["PROJECT_NIX_ENVIRONMENT"],flush=True); sys.stdin.read(1)']

        def start(environment, snapshot):
            process = subprocess.Popen(command, cwd=self.directory,
                env=self.exported | {'TEST_NIX_ENVIRONMENT': str(environment), 'TEST_NIX_SNAPSHOT': str(snapshot)},
                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            def stop():
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.communicate(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.communicate()
            self.addCleanup(stop)
            with selectors.DefaultSelector() as selector:
                selector.register(process.stdout, selectors.EVENT_READ)
                self.assertTrue(selector.select(timeout=5), 'child did not start')
            self.assertEqual(process.stdout.readline().strip(), str(environment))
            return process

        first = start(self.environment, self.directory / 'first input snapshot')
        work = self.project / '.work/nix'
        first_root = next(work.glob('stage.*/environment'))
        self.assertEqual(first_root.resolve(), self.environment)
        (work / 'environment').unlink()
        (work / 'environment').symlink_to(self.directory / 'missing project view')
        other = start(second, self.directory / 'second input snapshot')
        self.assertEqual((work / 'environment').resolve(), second)
        self.assertEqual({path.resolve() for path in work.glob('stage.*/environment')},
                         {self.environment, second})
        other.communicate(input='x', timeout=5)
        self.assertEqual(other.returncode, 0)
        self.assertTrue(first_root.is_symlink())
        first.terminate()
        first.communicate(timeout=5)
        self.assertEqual(first.returncode, 143)
        self.assertEqual(list(work.glob('stage.*')), [])
        self.assertEqual((work / 'environment').resolve(), second)


class PythonDispatchTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='python-dispatch-')
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name).resolve()
        self.root = self.directory / 'source archive with spaces'
        (self.root / 'scripts').mkdir(parents=True)
        self.runner = self.root / 'scripts/python-dev.py'
        self.runner.write_text('# inert runner; execution is intercepted\n')
        self.environment = self.directory / 'environment'
        (self.environment / 'share').mkdir(parents=True)
        self.store = self.directory / 'fixture-store'
        self.store.mkdir()
        self.config = self.store / 'python-development.json'
        self.config.write_text('{}\n')
        self.nix = self.directory / 'nix'
        self.nix.touch()
        spec = importlib.util.spec_from_file_location('fixture_environment_exec', SCRIPTS / 'environment-exec.py')
        self.executor = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.executor)
        self.executor.NIX_STORE = self.store

    def invoke(self, variables, ambient=None):
        (self.environment / 'share/project-environment.json').write_text(
            json.dumps({'schema': 1, 'variables': variables, 'unset': []}))
        arguments = ['environment-exec.py', str(self.root), str(self.environment), str(self.nix),
                     'command with spaces', '--literal', '$(no shell)', '']
        with patch.object(sys, 'argv', arguments), patch.dict(os.environ, ambient or {}), \
             patch.object(self.executor.os, 'execvpe') as execute, \
             patch.object(self.executor.os, 'chdir'), patch.object(self.executor.signal, 'signal'):
            self.executor.main()
        return execute.call_args

    def test_declared_config_prefixes_exact_argv_with_isolated_environment_python(self):
        call = self.invoke({'PROJECT_PYTHON_DEVELOPMENT_CONFIG': str(self.config)},
                           {'PROJECT_PYTHON_DEVELOPMENT_CONFIG': '/ambient/override'})
        expected = [str(self.environment / 'bin/python3'), '-I', str(self.runner),
                    'command with spaces', '--literal', '$(no shell)', '']
        self.assertEqual(call.args[:2], (expected[0], expected))
        self.assertEqual(call.args[2]['PROJECT_PYTHON_DEVELOPMENT_CONFIG'], str(self.config))
        self.assertEqual(call.args[2]['PROJECT_ROOT'], str(self.root))
        self.assertEqual(call.args[2]['PROJECT_NIX_ENVIRONMENT'], str(self.environment))

    def test_ambient_config_never_enables_dispatch(self):
        call = self.invoke({}, {'PROJECT_PYTHON_DEVELOPMENT_CONFIG': str(self.config)})
        self.assertEqual(call.args[:2], ('command with spaces',
                         ['command with spaces', '--literal', '$(no shell)', '']))
        self.assertNotIn('PROJECT_PYTHON_DEVELOPMENT_CONFIG', call.args[2])

    def test_config_requires_existing_regular_file_inside_store(self):
        outside = self.directory / 'outside.json'
        outside.write_text('{}\n')
        escape = self.store / 'escape.json'
        escape.symlink_to(outside)
        for config in ('relative.json', '', str(outside), str(self.store),
                       str(self.store / 'missing.json'), str(escape)):
            with self.subTest(config=config), self.assertRaisesRegex(ValueError, 'Nix-store file'):
                self.invoke({'PROJECT_PYTHON_DEVELOPMENT_CONFIG': config})

    def test_missing_directory_symlink_and_escaping_runners_are_refused(self):
        self.runner.unlink()
        with self.assertRaisesRegex(ValueError, 'regular file'):
            self.invoke({'PROJECT_PYTHON_DEVELOPMENT_CONFIG': str(self.config)})
        self.runner.mkdir()
        with self.assertRaisesRegex(ValueError, 'regular file'):
            self.invoke({'PROJECT_PYTHON_DEVELOPMENT_CONFIG': str(self.config)})
        self.runner.rmdir()
        outside = self.directory / 'outside.py'
        outside.write_text('# inert\n')
        self.runner.symlink_to(outside)
        with self.assertRaisesRegex(ValueError, 'regular file'):
            self.invoke({'PROJECT_PYTHON_DEVELOPMENT_CONFIG': str(self.config)})
        self.runner.unlink()
        (self.root / 'scripts').rmdir()
        (self.root / 'scripts').symlink_to(self.directory)
        (self.directory / 'python-dev.py').write_text('# inert\n')
        with self.assertRaisesRegex(ValueError, 'regular file'):
            self.invoke({'PROJECT_PYTHON_DEVELOPMENT_CONFIG': str(self.config)})


if __name__ == '__main__':
    unittest.main()
