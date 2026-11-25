"""Protocol fixtures for the shared read-only dependency checker; no network."""

import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock
from email.message import Message
from urllib.error import URLError
from urllib.request import BaseHandler, HTTPDefaultErrorHandler, HTTPErrorProcessor, OpenerDirector
from urllib.response import addinfourl


CHECKER_PATH = Path(__file__).with_name("check-deps.py")
if not CHECKER_PATH.is_file():
    CHECKER_PATH = Path(__file__).resolve().parents[1] / "scripts/check-deps.py"
SPEC = importlib.util.spec_from_file_location("dependency_checker", CHECKER_PATH)
CHECKER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECKER)


def metadata(**entry):
    return {"schema": 1, "dependencies": [{"name": "example", "current": "1.0", **entry}]}


class DependencyProtocolTests(unittest.TestCase):
    def test_github_stable_release_and_exact_source_pin(self):
        releases = {"draft": False, "prerelease": False, "tag_name": "v1.1"}
        with mock.patch.object(CHECKER, "fetch_json", return_value=releases):
            result = CHECKER.check(metadata(kind="github-release", repository="owner/repo"))[0]
            self.assertEqual((result["status"], result["latest"]), ("available", "v1.1"))
        with mock.patch.object(CHECKER, "fetch_json", side_effect=[releases, {"sha": "a" * 40}]):
            result = CHECKER.check(metadata(kind="github-release", repository="owner/repo", current="a" * 40))[0]
            self.assertEqual(result["status"], "current")
        with mock.patch.object(CHECKER, "fetch_json", return_value={**releases, "prerelease": True}):
            self.assertEqual(CHECKER.check(metadata(kind="github-release", repository="owner/repo"))[0]["status"], "error")

    def test_node_release_index_skips_alpha(self):
        releases = [{"version": v} for v in ("v27.0.0-alpha.1", "v26.9.9", "v26.13.1")]
        with mock.patch.object(CHECKER, "fetch", return_value=json.dumps(releases)):
            result = CHECKER.check(metadata(kind="nodejs", current="26.13.1"))[0]
        self.assertEqual(result["status"], "current")

    def test_github_source_head_uses_named_ref_and_full_sha(self):
        with mock.patch.object(CHECKER, "fetch_json", return_value={"sha": "b" * 40}) as fetch:
            result = CHECKER.check(metadata(kind="github-revision", repository="owner/repo",
                                            current="a" * 40, ref="branch/name"))[0]
            self.assertEqual(result["status"], "available")
            self.assertTrue(fetch.call_args[0][0].endswith("/commits/branch%2Fname"))
            self.assertEqual(CHECKER.check(metadata(kind="github-revision", repository="owner/repo",
                                                   current="short", ref="main"))[0]["status"], "error")

    def test_pypi_skips_prereleases_yanked_and_empty_releases(self):
        releases = {"1.1": [{"yanked": False}], "1.1.post1": [{"yanked": False}],
                    "2.0rc1": [{}], "3.0": [{"yanked": True}], "4.0": []}
        with mock.patch.object(CHECKER, "fetch_json", return_value={"releases": releases}):
            result = CHECKER.check(metadata(kind="pypi", package="example"))[0]
            self.assertEqual(result["latest"], "1.1.post1")
            result = CHECKER.check(metadata(kind="pypi", package="example", current="5.0"))[0]
            self.assertEqual(result["status"], "ahead")

    def test_npm_latest_must_be_stable_and_scoped_name_is_encoded(self):
        with mock.patch.object(CHECKER, "fetch_json", return_value={"version": "1.2.0"}) as fetch:
            result = CHECKER.check(metadata(kind="npm", package="@scope/package"))[0]
            self.assertEqual(result["latest"], "1.2.0")
            self.assertIn("%40scope%2Fpackage/latest", fetch.call_args[0][0])
        with mock.patch.object(CHECKER, "fetch_json", return_value={"version": "2.0.0-beta"}):
            self.assertEqual(CHECKER.check(metadata(kind="npm", package="example"))[0]["status"], "error")

    def test_malformed_pypi_payloads_fail_explicitly(self):
        for releases in (None, [], {"1.0": None}, {"1.0": [None]}, {"1.0": ["file"]}):
            with self.subTest(releases=releases), \
                 mock.patch.object(CHECKER, "fetch_json", return_value={"releases": releases}):
                result = CHECKER.check(metadata(kind="pypi", package="example"))[0]
                self.assertEqual(result["status"], "error")
                self.assertIn("PyPI releases", result["error"])

    def test_maven_stable_metadata_and_json_version_paths(self):
        document = b'<metadata><versioning><release>3.0-SNAPSHOT</release><versions><version>1.2</version><version>2.0.Final</version><version>3.0-rc1</version></versions></versioning></metadata>'
        with mock.patch.object(CHECKER, "fetch", return_value=document):
            result = CHECKER.check(metadata(kind="maven", url="https://example.invalid/metadata.xml"))[0]
            self.assertEqual(result["latest"], "2.0.Final")
        with mock.patch.object(CHECKER, "fetch_json", return_value={"mac": "1.4.363.1"}):
            result = CHECKER.check(metadata(kind="json-version", url="https://example.invalid/mac.json", path=["mac"]))[0]
            self.assertEqual(result["latest"], "1.4.363.1")
            for path in ([], "mac", ["missing"], [1]):
                with self.subTest(path=path):
                    self.assertEqual(CHECKER.check(metadata(kind="json-version", url="https://example.invalid/mac.json", path=path))[0]["status"], "error")
        with mock.patch.object(CHECKER, "fetch_json", return_value={"mac": 123}):
            self.assertEqual(CHECKER.check(metadata(kind="json-version", url="https://example.invalid/mac.json", path=["mac"]))[0]["status"], "error")

    def test_missing_unsupported_and_network_failures_are_errors(self):
        for invalid in ({"schema": 2, "dependencies": []}, {"schema": 1, "dependencies": []},
                        {"schema": True, "dependencies": metadata(kind="npm")["dependencies"]}):
            with self.assertRaises(ValueError):
                CHECKER.check(invalid)
        self.assertEqual(CHECKER.check(metadata(kind="unknown"))[0]["status"], "error")
        self.assertEqual(CHECKER.check(metadata(kind="maven", url="file:///not-a-source"))[0]["status"], "error")
        with mock.patch.object(CHECKER.OPENER, "open", side_effect=URLError("offline")):
            result = CHECKER.check(metadata(kind="pypi", package="example"))[0]
            self.assertEqual(result["status"], "error")
            self.assertIn("unavailable", result["error"])

    def test_cli_is_read_only_and_updates_do_not_silently_upgrade(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            share = root / "share"
            share.mkdir()
            path = share / "dependency-updates.json"
            path.write_text(json.dumps(metadata(kind="npm", package="example")))
            before = hashlib.sha256(path.read_bytes()).hexdigest()
            with mock.patch.dict(os.environ, PROJECT_NIX_ENVIRONMENT=str(root)), \
                 mock.patch.object(CHECKER, "fetch_json", return_value={"version": "2.0.0"}), \
                 contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(CHECKER.main(["--json"]), 0)
            self.assertEqual(json.loads(output.getvalue())["dependencies"][0]["status"], "available")
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), before)
            with mock.patch.dict(os.environ, PROJECT_NIX_ENVIRONMENT=str(root)), \
                 mock.patch.object(CHECKER, "fetch_json", side_effect=ValueError("offline")), \
                 contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(CHECKER.main(["--json"]), 2)
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), before)
        with mock.patch.dict(os.environ, {}, clear=True), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(CHECKER.main([]), 2)

    def test_stdin_metadata_preserves_old_environment_callers(self):
        document = json.dumps(metadata(kind="npm", package="example"))
        with mock.patch.dict(os.environ, {}, clear=True), \
             mock.patch("sys.stdin", io.StringIO(document)), \
             mock.patch.object(CHECKER, "fetch_json", return_value={"version": "1.2.0"}), \
             contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(CHECKER.main(["--metadata-stdin", "--json"]), 0)
        self.assertEqual(json.loads(output.getvalue())["dependencies"][0]["status"], "available")
        with mock.patch("sys.stdin", io.StringIO("not JSON")), \
             mock.patch.object(CHECKER, "fetch_json") as fetch, \
             contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(CHECKER.main(["--metadata-stdin"]), 2)
            fetch.assert_not_called()


class DependencyRedirectTests(unittest.TestCase):
    def test_runtime_opener_replaces_the_default_redirect_handler(self):
        handlers = [handler for handler in CHECKER.OPENER.handlers
                    if isinstance(handler, CHECKER.HTTPRedirectHandler)]
        self.assertEqual([type(handler) for handler in handlers], [CHECKER.OriginSafeRedirectHandler])

    def fetch_chain(self, first, redirects):
        requests = []

        class InertTransport(BaseHandler):
            def https_open(self, request):
                requests.append((request.full_url, dict(request.header_items())))
                headers = Message()
                target = redirects.get(request.full_url)
                if target:
                    headers["Location"] = target
                response = addinfourl(io.BytesIO(b"{}"), headers, request.full_url, 302 if target else 200)
                response.msg = "Found" if target else "OK"
                return response

            http_open = https_open

        # No real network/proxy handler exists in this opener.
        opener = OpenerDirector()
        for handler in (InertTransport(), CHECKER.OriginSafeRedirectHandler(),
                        HTTPDefaultErrorHandler(), HTTPErrorProcessor()):
            opener.add_handler(handler)
        with mock.patch.object(CHECKER, "OPENER", opener), \
             mock.patch.dict(os.environ, {"GITHUB_TOKEN": "inert-fixture-only"}, clear=True):
            self.assertEqual(CHECKER.fetch(first), b"{}")
        return requests

    def test_initial_auth_and_same_origin_redirects_are_preserved(self):
        first = "https://api.github.com/start"
        second = "https://API.GITHUB.COM:443/next"
        requests = self.fetch_chain(first, {first: second})
        self.assertEqual(len(requests), 2)
        for _, headers in requests:
            self.assertEqual(headers.get("Authorization"), "Bearer inert-fixture-only")
            self.assertEqual(headers.get("Accept"), "application/json")
        requests = self.fetch_chain(first, {first: "/relative"})
        self.assertEqual(requests[-1][0], "https://api.github.com/relative")
        self.assertEqual(requests[-1][1].get("Authorization"), "Bearer inert-fixture-only")

    def test_cross_origin_redirects_drop_auth(self):
        first = "https://api.github.com/start"
        for target in ("https://example.invalid/final", "https://api.github.com:444/final",
                       "http://api.github.com/final"):
            with self.subTest(target=target):
                requests = self.fetch_chain(first, {first: target})
                self.assertEqual(requests[0][1].get("Authorization"), "Bearer inert-fixture-only")
                self.assertNotIn("Authorization", requests[1][1])

    def test_chained_redirects_never_reattach_dropped_auth(self):
        first, same = "https://api.github.com/start", "https://api.github.com/same"
        other, onward, returned = ("https://example.invalid/other", "https://example.invalid/onward",
                                    "https://api.github.com/returned")
        requests = self.fetch_chain(first, {first: same, same: other, other: onward, onward: returned})
        self.assertEqual(len(requests), 5)
        self.assertTrue(all("Authorization" in headers for _, headers in requests[:2]))
        self.assertTrue(all("Authorization" not in headers for _, headers in requests[2:]))

    def test_initial_non_api_origins_do_not_receive_auth(self):
        for url in ("https://example.invalid/start", "http://api.github.com/start",
                    "https://api.github.com:444/start"):
            with self.subTest(url=url):
                self.assertNotIn("Authorization", self.fetch_chain(url, {})[0][1])


FIXTURE_PROGRAM = r'''
import json, os, pathlib, shutil, sys
root = pathlib.Path(os.environ['CHECKER_FIXTURE_PROJECT'])
state = json.loads((root / 'fixture-state.json').read_text())
args = sys.argv[1:]
mode = pathlib.Path(sys.argv[0]).name
entry = {'tool': mode, 'argv': args}
def event():
    with (root / 'events.jsonl').open('a') as stream:
        stream.write(json.dumps(entry) + '\n')
def publish(link, target):
    link = pathlib.Path(link)
    if link.exists() and not link.is_symlink():
        raise SystemExit(8)
    link.parent.mkdir(parents=True, exist_ok=True)
    temporary = link.with_name(link.name + '.tmp-' + str(os.getpid()))
    temporary.symlink_to(target)
    os.replace(temporary, link)
if mode == 'dev':
    event()
    assert args[0] == '--eval'
    attribute = args[1]
    if attribute.endswith('.metadata'):
        if state.get('fail_metadata'): raise SystemExit(7)
        print(json.dumps(state['metadata']))
    elif attribute.endswith('.python'):
        print(state['python'])
    elif attribute.endswith('.interpreter.drvPath'):
        print(state['derivation'])
    else:
        assert '--apply' in args
        print(state.get('preferredPython', ''))
elif mode == 'nix':
    event()
    assert args[:3] == ['--extra-experimental-features', 'nix-command flakes', 'build']
    assert args[args.index('--max-jobs') + 1] == '0'
    assert args[args.index('--builders') + 1] == ''
    assert args[-1] == state['derivation'] + '^out'
    if state.get('fail_download'): raise SystemExit(7)
    python = pathlib.Path(state['python'])
    python.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / 'fixture-program', python)
    publish(args[args.index('--out-link') + 1], python.parent.parent)
elif mode == 'nix-store':
    event()
    if args[:2] == ['--query', '--resolve']:
        target = pathlib.Path(args[2]).resolve()
        if not target.exists(): raise SystemExit(1)
        print(target.parent.parent if target.is_file() else target)
    elif args[0] == '--check-validity':
        if args[1] in state.get('invalid', []) or not pathlib.Path(args[1]).is_dir():
            raise SystemExit(1)
    else:
        assert args[0] == '--add-root'
        assert args[args.index('max-jobs') + 1] == '0'
        target = pathlib.Path(args[args.index('--realise') + 1])
        assert target.is_dir()
        publish(args[1], target)
elif mode == 'python3':
    entry['python'] = sys.argv[0]
    entry['metadata'] = json.load(sys.stdin)
    entry['lifetimes'] = {str(p): str(p.resolve()) for p in (root / '.work/nix').glob('check-deps.*/python')}
    cache = root / '.work/nix/check-deps-python'
    entry['cache_before'] = str(cache.resolve()) if cache.exists() else None
    event()
    if os.environ.get('CHECKER_FIXTURE_WAIT') == '1':
        print('ready', flush=True)
        with (root / 'release-fifo').open() as release: release.read(1)
    raise SystemExit(int(os.environ.get('CHECKER_FIXTURE_STATUS', '0')))
else:
    raise AssertionError(mode)
'''


class CheckerEntrypointTests(unittest.TestCase):
    def setUp(self):
        import sys
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve() / 'source archive with spaces'
        scripts = self.root / 'scripts'
        tools = self.root / 'bootstrap tools'
        scripts.mkdir(parents=True)
        tools.mkdir()
        self.entrypoint = scripts / 'check-deps'
        shutil.copy2(CHECKER_PATH.with_name('check-deps'), self.entrypoint)
        self.program = self.root / 'fixture-program'
        self.program.write_text('#!' + sys.executable + '\n' + FIXTURE_PROGRAM)
        self.program.chmod(0o755)
        for path in (scripts / 'dev', tools / 'nix', tools / 'nix-store'):
            shutil.copy2(self.program, path)
        self.fallback = self.root / 'public-python' / 'bin/python3'
        self.preferred = self.root / 'rebuilt-python' / 'bin/python3'
        self.cache = self.root / '.work/nix/check-deps-python'
        self.state = {'python': str(self.fallback), 'derivation': str(self.root / 'public-python.drv'),
                      'metadata': metadata(kind='npm', package='example')}
        self.exported = os.environ | {'PATH': str(tools) + os.pathsep + os.environ['PATH'],
                                     'CHECKER_FIXTURE_PROJECT': str(self.root)}
        self.save_state()

    def save_state(self):
        (self.root / 'fixture-state.json').write_text(json.dumps(self.state))

    def install(self, python):
        python.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(self.program, python)

    def run_checker(self, *args, extra=None):
        return subprocess.run(['sh', str(self.entrypoint), *args], cwd='/',
                              env=self.exported | (extra or {}), text=True,
                              capture_output=True, timeout=15)

    def events(self, tool):
        return [entry for line in (self.root / 'events.jsonl').read_text().splitlines()
                if (entry := json.loads(line))['tool'] == tool]

    def test_legacy_api_forwarding_status_and_metadata_failure(self):
        self.install(self.fallback)
        result = self.run_checker('--json')
        self.assertEqual(result.returncode, 0, result.stderr)
        invocation = self.events('python3')[-1]
        self.assertEqual(invocation['argv'], ['-I', str(self.root / 'scripts/check-deps.py'),
                                             '--metadata-stdin', '--json'])
        self.assertEqual(invocation['metadata'], self.state['metadata'])
        self.assertEqual(set(invocation['lifetimes'].values()), {str(self.fallback.parent.parent)})
        self.assertEqual(self.cache.resolve(), self.fallback.parent.parent)
        self.assertFalse(self.events('nix'))
        evaluations = self.events('dev')
        self.assertEqual(len(evaluations), 3)
        for evaluation in evaluations:
            self.assertEqual(evaluation['argv'][-3:],
                             ['--option', 'allow-import-from-derivation', 'false'])
            self.assertNotIn('dev-environment', ' '.join(evaluation['argv']))
        self.assertEqual(self.run_checker(extra={'CHECKER_FIXTURE_STATUS': '23'}).returncode, 23)
        self.state['fail_metadata'] = True
        self.save_state()
        result = self.run_checker()
        self.assertEqual(result.returncode, 2)
        self.assertIn('cannot evaluate dependency update metadata', result.stderr)
        self.assertEqual(self.cache.resolve(), self.fallback.parent.parent)
        self.assertEqual(list((self.root / '.work/nix').glob('check-deps.*')), [])

    def test_cold_fallback_never_builds_preferred_or_environment(self):
        self.state['preferredPython'] = str(self.preferred)
        self.save_state()
        result = self.run_checker()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.events('python3')[-1]['python'], str(self.fallback))
        self.assertEqual(len(self.events('nix')), 1)
        build = self.events('nix')[0]['argv']
        self.assertEqual(build[-1], self.state['derivation'] + '^out')
        self.assertEqual(build[build.index('--max-jobs') + 1], '0')
        self.assertEqual(build[build.index('--builders') + 1], '')
        self.assertIn('--no-update-lock-file', build)
        self.assertNotIn('dev-environment', ' '.join(build))
        self.assertFalse(self.preferred.exists())
        self.fallback.unlink()
        self.state['fail_download'] = True
        self.save_state()
        result = self.run_checker()
        self.assertEqual(result.returncode, 2)
        self.assertIn('cannot download the pinned Python binary', result.stderr)

    def test_preferred_requires_validity_and_success_before_cache_switch(self):
        self.install(self.fallback)
        self.assertEqual(self.run_checker().returncode, 0)
        self.state['preferredPython'] = str(self.preferred)
        self.install(self.preferred)
        self.state['invalid'] = [str(self.preferred.parent.parent)]
        self.save_state()
        self.assertEqual(self.run_checker().returncode, 0)
        self.assertEqual(self.events('python3')[-1]['python'], str(self.fallback))
        self.state['invalid'] = []
        self.save_state()
        failed = self.run_checker(extra={'CHECKER_FIXTURE_STATUS': '2'})
        self.assertEqual(failed.returncode, 2)
        self.assertEqual(self.cache.resolve(), self.fallback.parent.parent)
        result = self.run_checker()
        self.assertEqual(result.returncode, 0, result.stderr)
        invocation = self.events('python3')[-1]
        self.assertEqual(invocation['python'], str(self.preferred))
        self.assertEqual(invocation['cache_before'], str(self.fallback.parent.parent))
        self.assertEqual(self.cache.resolve(), self.preferred.parent.parent)
        self.assertFalse(self.events('nix'))
        self.cache.unlink()
        self.cache.write_text('existing project data')
        result = self.run_checker()
        self.assertEqual(result.returncode, 2)
        self.assertEqual(self.cache.read_text(), 'existing project data')

    def test_other_invocation_keeps_its_lifetime_root_during_preferred_switch(self):
        import selectors
        self.install(self.fallback)
        self.state['preferredPython'] = str(self.preferred)
        self.save_state()
        os.mkfifo(self.root / 'release-fifo')
        running = subprocess.Popen(['sh', str(self.entrypoint)], cwd='/',
                                   env=self.exported | {'CHECKER_FIXTURE_WAIT': '1',
                                                        'CHECKER_FIXTURE_STATUS': '23'},
                                   text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            with selectors.DefaultSelector() as ready:
                ready.register(running.stdout, selectors.EVENT_READ)
                self.assertTrue(ready.select(timeout=10), 'checker did not reach the fixture wait')
            self.assertEqual(running.stdout.readline().strip(), 'ready')
            old = self.events('python3')[-1]['lifetimes']
            self.install(self.preferred)
            result = self.run_checker()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(self.cache.resolve(), self.preferred.parent.parent)
            for link, target in old.items():
                self.assertEqual(Path(link).resolve(), Path(target))
                self.assertTrue(Path(link).is_symlink())
            with (self.root / 'release-fifo').open('w') as release: release.write('x')
            running.communicate(timeout=10)
            self.assertEqual(running.returncode, 23)
            self.assertEqual(self.cache.resolve(), self.preferred.parent.parent)
            self.assertEqual(list((self.root / '.work/nix').glob('check-deps.*')), [])
        finally:
            if running.poll() is None:
                running.kill()
                running.communicate()


if __name__ == "__main__":
    unittest.main()
