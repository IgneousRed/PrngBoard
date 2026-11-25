"""Review the staged publication boundary, without reading ignored material."""
import argparse
import hashlib
from pathlib import Path, PurePosixPath
import subprocess
import sys

PUBLIC_ROOTS = {
    '.gitattributes', '.githooks', '.gitignore', 'README.md',
    'LanguageDefaultPrng.txt', 'FSR', 'MWC', 'MWCP', 'Odin', 'SFC', 'SFCK',
    'WYR', 'lib', 'main.odin', 'flake.nix', 'flake.lock', 'nix', 'scripts', 'docs',
}
PRIVATE_ROOTS = {'README.md', 'experiments', 'todo', 'reworks', 'instructions'}
RESERVED = {'.private', '.local', '.work', '.vendor', '.git'}
RECORD_FOLDERS = {'FSR', 'MWC', 'MWCP', 'Odin', 'SFC', 'SFCK', 'WYR'}
OUTGOING_REFS = {'refs/heads/main'}
PUBLIC_REMOTE = 'https://github.com/IgneousRed/PrngBoard.git'
PRIVATE_REMOTE = 'https://github.com/IgneousRed/prng-board-private.git'


def has_machine_ref_details(data):
    # A policy's namespace wildcard is not an actual machine-owned ref identity.
    return b'refs/t3/' in data.replace(b'refs/t3/*', b'')


def check_outgoing_refs(refs):
    if not refs or any(ref not in OUTGOING_REFS for ref in refs):
        raise SystemExit('outgoing refs must be explicitly allowlisted: refs/heads/main only; no app-owned or backup refs')


def check_history(root, private, refs):
    check_outgoing_refs(refs)
    denied = set()
    if not private:
        denied = {line for line in (root / 'scripts/publication-deny.sha256').read_text().splitlines()
                  if line and not line.startswith('#')}
    objects = subprocess.check_output(
        ['git', '-C', str(root), 'rev-list', '--objects', *refs, '--'], text=True).splitlines()
    # Check every tree, not only rev-list's single representative name per blob:
    # the same blob may also appear under a copied or renamed historical path.
    commits = subprocess.check_output(
        ['git', '-C', str(root), 'rev-list', *refs, '--'], text=True).splitlines()
    for commit in commits:
        entries = subprocess.check_output(
            ['git', '-C', str(root), 'ls-tree', '-r', '-z', commit]).split(b'\0')
        for entry in filter(None, entries):
            _, raw_path = entry.split(b'\t', 1)
            path = PurePosixPath(raw_path.decode('utf-8'))
            if RESERVED.intersection(path.parts) or (not private and path.name == 'AGENTS.md') or (
                    not private and path.parts[0] in RECORD_FOLDERS and path.suffix == '.txt'):
                raise SystemExit(f'reserved or reclassified historical path in {commit}: {path}')
    for entry in objects:
        oid = entry.split(' ', 1)[0]
        kind = subprocess.check_output(['git', '-C', str(root), 'cat-file', '-t', oid]).strip()
        if kind != b'blob':
            continue
        data = subprocess.check_output(['git', '-C', str(root), 'cat-file', 'blob', oid])
        if hashlib.sha256(data).hexdigest() in denied:
            raise SystemExit(f'reclassified historical content: {oid}')
        if private and has_machine_ref_details(data):
            raise SystemExit(f'machine-only app ref details in outgoing private content: {oid}')
    print(f'History boundary passed: {root.name}, {len(commits)} commits, outgoing {", ".join(refs)}')


def check_push(root, private, remote, lines):
    expected = PRIVATE_REMOTE if private else PUBLIC_REMOTE
    if remote != expected:
        raise SystemExit(f'unapproved publication destination; expected {expected}')
    refs = []
    for line in lines:
        fields = line.split()
        if len(fields) != 4:
            raise SystemExit('invalid pre-push ref record')
        local_ref, local_oid, remote_ref, _ = fields
        check_outgoing_refs([local_ref, remote_ref])
        current = subprocess.check_output(
            ['git', '-C', str(root), 'rev-parse', '--verify', local_ref + '^{commit}'], text=True).strip()
        if current != local_oid:
            raise SystemExit('outgoing ref changed; recheck before publication')
        refs.append(local_ref)
    if refs:
        check_history(root, private, refs)


def check(root, allowed):
    entries = subprocess.check_output(
        ['git', '-C', str(root), 'ls-files', '--stage', '-z']).split(b'\0')
    errors = []
    denied = set()
    if root.name != '.private':
        denied = {line for line in (root / 'scripts/publication-deny.sha256').read_text().splitlines()
                  if line and not line.startswith('#')}
    for entry in filter(None, entries):
        metadata, raw_path = entry.split(b'\t', 1)
        path = PurePosixPath(raw_path.decode('utf-8'))
        if (path.parts[0] not in allowed or RESERVED.intersection(path.parts)
                or (root.name != '.private' and path.name == 'AGENTS.md')):
            errors.append(f'unreviewed or reserved path: {path}')
        if metadata.split()[0] not in (b'100644', b'100755'):
            errors.append(f'symlink, submodule or unsupported file mode: {path}')
        else:
            data = subprocess.check_output(
                ['git', '-C', str(root), 'cat-file', 'blob', metadata.split()[1].decode()])
            if hashlib.sha256(data).hexdigest() in denied:
                errors.append(f'reclassified staged content: {path}')
            if root.name == '.private' and has_machine_ref_details(data):
                errors.append(f'machine-only app ref details in staged private content: {path}')
    if errors:
        raise SystemExit('\n'.join(errors))
    print(f'Publication boundary passed: {root.name}, {len(entries) - 1} staged files')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--private', action='store_true')
    parser.add_argument('--history', action='store_true')
    parser.add_argument('--ref', action='append', default=[])
    parser.add_argument('--push', metavar='REMOTE_URL')
    args = parser.parse_args()
    project = Path(__file__).resolve().parent.parent
    root = project / '.private' if args.private else project
    if not (root / '.git').is_dir():
        parser.error(f'expected independent Git repository: {root}')
    if args.push:
        check_push(root, args.private, args.push, sys.stdin)
    elif args.history:
        check_history(root, args.private, args.ref)
    else:
        check(root, PRIVATE_ROOTS if args.private else PUBLIC_ROOTS)
