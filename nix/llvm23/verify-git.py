"""Check the shared Git package without modifying a project or user Git config."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tarfile
import tempfile
import io


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--git", required=True, type=Path, help="selected Git output directory")
    parser.add_argument("--reference", required=True, type=Path, help="original catalog Git output")
    parser.add_argument("--python", required=True, type=Path, help="selected Python output directory")
    parser.add_argument("--https", action="store_true", help="also query the public upstream Git tag")
    args = parser.parse_args()
    selected = args.git.resolve()
    reference = args.reference.resolve()
    git = selected / "bin/git"
    records = []

    with tempfile.TemporaryDirectory(prefix="shared-git-check-") as temporary:
        root = Path(temporary)
        home = root / "home"
        home.mkdir()
        environment = {key: value for key, value in os.environ.items()
                       if not key.startswith("GIT_") and key not in ("PYTHONHOME", "PYTHONPATH", "VIRTUAL_ENV")}
        environment.update({
            "HOME": str(home), "XDG_CONFIG_HOME": str(home / ".config"),
            "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_TERMINAL_PROMPT": "0", "GIT_PAGER": "cat",
            "GIT_AUTHOR_NAME": "Git package fixture", "GIT_AUTHOR_EMAIL": "fixture@example.invalid",
            "GIT_COMMITTER_NAME": "Git package fixture", "GIT_COMMITTER_EMAIL": "fixture@example.invalid",
            "PATH": str(selected / "bin") + ":/usr/bin:/bin:/usr/sbin:/sbin",
        })

        def run(name, command, cwd=root, expected=0, extra=None):
            result = subprocess.run([str(value) for value in command], cwd=cwd,
                                    env=environment | (extra or {}), capture_output=True, timeout=90)
            assert result.returncode == expected, (name, result.returncode, result.stdout, result.stderr)
            records.append({"name": name, "returncode": result.returncode})
            return result.stdout

        version = run("version", [git, "--version"])
        assert version == run("reference version", [reference / "bin/git", "--version"])
        builtins = run("builtins", [git, "--list-cmds=builtins"])
        assert builtins == run("reference builtins", [reference / "bin/git", "--list-cmds=builtins"])
        options = run("build features", [git, "version", "--build-options"])
        old_options = run("reference build features", [reference / "bin/git", "version", "--build-options"])
        assert options == old_options, (options, old_options)
        entries = lambda folder: {str(path.relative_to(folder)) for path in folder.rglob("*")}
        assert entries(selected) == entries(reference), "installed Git file/command set changed"
        records.append({"name": "installed file and command set", "returncode": 0})
        helper = selected / "libexec/git-core/git-p4"
        assert helper.read_text().splitlines()[0] == "#!" + str(args.python.resolve() / "bin/python")
        help_text = run("Python Perforce helper startup", [git, "p4", "clone", "--help"])
        assert b"usage:" in help_text.lower()
        repository = root / "source"
        run("initialize", [git, "init", "--quiet", "-b", "main", repository])
        (repository / "example.txt").write_text("declared package fixture\n")
        run("stage", [git, "add", "example.txt"], repository)
        run("commit", [git, "commit", "--quiet", "-m", "Package fixture"], repository)
        run("reference reads SHA1 objects", [reference / "bin/git", "fsck", "--full"], repository)
        revision = run("revision", [git, "rev-parse", "HEAD"], repository).strip()
        assert re.fullmatch(rb"[0-9a-f]{40}", revision)
        clone = root / "clone"
        run("local clone", [git, "clone", "--quiet", "--no-hardlinks", repository, clone])
        assert (clone / "example.txt").read_text() == "declared package fixture\n"
        assert run("clone revision", [git, "rev-parse", "HEAD"], clone).strip() == revision
        archive = run("archive", [git, "archive", "--format=tar", "HEAD"], clone)
        with tarfile.open(fileobj=io.BytesIO(archive)) as stream:
            assert stream.extractfile("example.txt").read() == b"declared package fixture\n"
        worktree = root / "worktree"
        run("worktree", [git, "worktree", "add", "--quiet", "--detach", worktree, "HEAD"], clone)
        assert (worktree / "example.txt").is_file()
        run("Perl email helper startup", [git, "send-email", "--dump-aliases"], clone)
        run("keychain helper startup", [selected / "bin/git-credential-osxkeychain"], expected=128)
        bare = root / "remote.git"
        run("bare clone", [git, "clone", "--quiet", "--bare", repository, bare])
        shallow = root / "shallow"
        run("bootstrap initialize", [git, "init", "--quiet", shallow])
        run("bootstrap shallow fetch", [git, "fetch", "--quiet", "--depth=1", bare.as_uri(),
                                        revision.decode()], shallow)
        run("bootstrap detached checkout", [git, "checkout", "--quiet", "--detach", "FETCH_HEAD"], shallow)
        assert (shallow / "example.txt").read_text() == "declared package fixture\n"
        assert run("bootstrap revision", [git, "rev-parse", "HEAD"], shallow).strip() == revision
        response = run("smart HTTP backend", [selected / "bin/git-http-backend"], extra={
            "GIT_PROJECT_ROOT": str(root), "GIT_HTTP_EXPORT_ALL": "1", "REQUEST_METHOD": "GET",
            "PATH_INFO": "/remote.git/info/refs", "QUERY_STRING": "service=git-upload-pack",
        })
        assert b"application/x-git-upload-pack-advertisement" in response, response
        sha256 = root / "sha256"
        run("SHA256 repository", [git, "init", "--quiet", "--object-format=sha256", sha256])
        run("SHA256 commit", [git, "commit", "--quiet", "--allow-empty", "-m", "Hash fixture"], sha256)
        run("reference reads SHA256 objects", [reference / "bin/git", "fsck", "--full"], sha256)
        assert re.fullmatch(rb"[0-9a-f]{64}", run("SHA256 revision", [git, "rev-parse", "HEAD"], sha256).strip())
        if args.https:
            remote = run("public HTTPS tag", [git, "ls-remote", "--exit-code",
                         "https://github.com/git/git.git", "refs/tags/v2.56.0"])
            assert re.fullmatch(rb"[0-9a-f]{40}\trefs/tags/v2\.56\.0\n", remote), remote

    print(json.dumps({"status": "passed", "git": str(selected), "checks": records,
                      "builtin_count": len(builtins.splitlines()),
                      "limitations": ["No Perforce server, SMTP delivery or keychain read/write was requested."]}, indent=2))


if __name__ == "__main__":
    main()
