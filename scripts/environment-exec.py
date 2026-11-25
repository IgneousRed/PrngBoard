#!/usr/bin/env python3
"""Apply the canonical immutable environment manifest and replace this process."""
import json
import os
from pathlib import Path
import re
import signal
import sys
import tempfile

NAME = re.compile(r'[A-Za-z_][A-Za-z0-9_]*\Z')
MARKERS = {'PROJECT_ROOT', 'PROJECT_NIX_ENVIRONMENT', 'PATH'}
NIX_STORE = Path('/nix/store')


def main():
    if len(sys.argv) < 5:
        raise ValueError('usage: environment-exec.py PROJECT_ROOT ENVIRONMENT NIX COMMAND [ARG ...]')
    root, environment = (Path(value).resolve(strict=True) for value in sys.argv[1:3])
    nix_directory = Path(sys.argv[3]).resolve(strict=True).parent
    manifest = json.loads((environment / 'share/project-environment.json').read_text())
    if not isinstance(manifest, dict) or set(manifest) != {'schema', 'variables', 'unset'}:
        raise ValueError('environment manifest must contain schema, variables and unset')
    if type(manifest['schema']) is not int or manifest['schema'] != 1:
        raise ValueError('unsupported environment manifest schema')
    variables, unset = manifest['variables'], manifest['unset']
    if not isinstance(variables, dict) or not isinstance(unset, list):
        raise ValueError('environment variables must be an object and unset must be a list')
    for name in [*variables, *unset]:
        if not isinstance(name, str) or not NAME.fullmatch(name) or name in MARKERS:
            raise ValueError('invalid or reserved environment variable name: ' + repr(name))
    if set(variables).intersection(unset):
        raise ValueError('environment variables cannot also appear in unset')
    if any(not isinstance(value, str) or '\0' in value for value in variables.values()):
        raise ValueError('environment variable values must be strings without NUL bytes')
    exported = os.environ.copy()
    exported.pop('PROJECT_PYTHON_DEVELOPMENT_CONFIG', None)
    for name in unset:
        exported.pop(name, None)
    exported.update(variables)
    exported['PATH'] = os.pathsep.join((str(environment / 'bin'), str(nix_directory),
                                      '/usr/bin', '/bin', '/usr/sbin', '/sbin'))
    exported['PROJECT_ROOT'] = str(root)
    exported['PROJECT_NIX_ENVIRONMENT'] = str(environment)
    if sys.platform == 'darwin' and not exported.get('TMPDIR'):
        exported['TMPDIR'] = tempfile.gettempdir()
    command = sys.argv[4:]
    if 'PROJECT_PYTHON_DEVELOPMENT_CONFIG' in variables:
        config = Path(variables['PROJECT_PYTHON_DEVELOPMENT_CONFIG'])
        if (not config.is_absolute() or not config.is_relative_to(NIX_STORE)
                or not config.is_file() or not config.resolve(strict=True).is_relative_to(NIX_STORE)):
            raise ValueError('Python development config must be an absolute Nix-store file')
        runner = root / 'scripts/python-dev.py'
        if runner.is_symlink() or not runner.is_file() or not runner.resolve(strict=True).is_relative_to(root):
            raise ValueError('Python development runner must be a regular file inside the project')
        command = [str(environment / 'bin/python3'), '-I', str(runner), *command]
    os.chdir(root)
    # POSIX background startup ignores SIGINT/SIGQUIT; restore normal command
    # handling so the launcher's forwarding reaches the final process.
    for name in ('SIGINT', 'SIGQUIT', 'SIGHUP', 'SIGTERM'):
        signal.signal(getattr(signal, name), signal.SIG_DFL)
    os.execvpe(command[0], command, exported)


if __name__ == '__main__':
    try:
        main()
    except FileNotFoundError as error:
        print('dev: ' + str(error), file=sys.stderr)
        raise SystemExit(127)
    except PermissionError as error:
        print('dev: ' + str(error), file=sys.stderr)
        raise SystemExit(126)
    except (OSError, ValueError) as error:
        print('dev: ' + str(error), file=sys.stderr)
        raise SystemExit(2)
