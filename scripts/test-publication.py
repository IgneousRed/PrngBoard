#!/usr/bin/env python3
"""Synthetic Git fixtures for private working-instruction boundaries."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location('publication', SCRIPTS / 'check-publication.py')
PUBLICATION = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PUBLICATION)


class InstructionBoundaryTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='publication-instructions-')
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.public = self.directory / 'public'
        self.private = self.public / '.private'
        for root in (self.public, self.private):
            root.mkdir(parents=True)
            self.git(root, 'init', '--quiet', '--initial-branch=main')
        (self.public / 'scripts').mkdir()
        (self.public / 'scripts/publication-deny.sha256').write_text('')

    def git(self, root, *arguments, data=None):
        result = subprocess.run(['git', '-C', str(root), *arguments], input=data,
                                text=True, capture_output=True, check=True,
                                env=os.environ | {'GIT_AUTHOR_NAME': 'Fixture',
                                    'GIT_AUTHOR_EMAIL': 'fixture@example.invalid',
                                    'GIT_COMMITTER_NAME': 'Fixture',
                                    'GIT_COMMITTER_EMAIL': 'fixture@example.invalid'})
        return result.stdout.strip()

    def stage(self, root, path, content='synthetic private instructions\n'):
        target = root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)
        self.git(root, 'add', '--', path)

    def commit(self, root, parent=None):
        tree = self.git(root, 'write-tree')
        arguments = ('-p', parent) if parent else ()
        commit = self.git(root, 'commit-tree', tree, *arguments, data='fixture\n')
        self.git(root, 'update-ref', 'refs/heads/main', commit)
        return commit

    def test_public_staging_rejects_root_and_nested_instructions(self):
        for path in ('AGENTS.md', 'lib/AGENTS.md', 'docs/nested/AGENTS.md'):
            with self.subTest(path=path):
                self.stage(self.public, path)
                with self.assertRaisesRegex(SystemExit, 'reserved path: ' + path):
                    PUBLICATION.check(self.public, PUBLICATION.PUBLIC_ROOTS)
                self.git(self.public, 'rm', '--cached', '--', path)

    def test_public_history_rejects_removed_nested_instructions(self):
        self.stage(self.public, 'lib/AGENTS.md')
        parent = self.commit(self.public)
        self.git(self.public, 'rm', '--', 'lib/AGENTS.md')
        self.stage(self.public, 'README.md', 'synthetic public documentation\n')
        self.commit(self.public, parent)
        with self.assertRaisesRegex(SystemExit, 'historical path'):
            PUBLICATION.check_history(self.public, False, ['refs/heads/main'])

    def test_private_instruction_copy_is_allowed_in_staging_and_history(self):
        self.stage(self.private, 'instructions/AGENTS.md',
                   'Policy only: never upload `refs/t3/*`.\n')
        PUBLICATION.check(self.private, PUBLICATION.PRIVATE_ROOTS)
        self.commit(self.private)
        PUBLICATION.check_history(self.private, True, ['refs/heads/main'])

    def test_private_instructions_cannot_include_actual_machine_ref_details(self):
        self.stage(self.private, 'instructions/AGENTS.md',
                   'Policy: refs/t3/*; synthetic ref: refs/t3/checkpoints/example\n')
        with self.assertRaisesRegex(SystemExit, 'machine-only app ref details'):
            PUBLICATION.check(self.private, PUBLICATION.PRIVATE_ROOTS)
        self.commit(self.private)
        with self.assertRaisesRegex(SystemExit, 'machine-only app ref details'):
            PUBLICATION.check_history(self.private, True, ['refs/heads/main'])

    def test_public_ignore_and_archive_rules_cover_nested_instructions(self):
        for name in ('.gitignore', '.gitattributes'):
            self.stage(self.public, name, (SCRIPTS.parent / name).read_text())
        for path in ('AGENTS.md', 'lib/AGENTS.md'):
            with self.subTest(path=path):
                self.assertEqual(self.git(self.public, 'check-ignore', '--', path), path)
                self.assertEqual(self.git(self.public, 'check-attr', 'export-ignore', '--', path),
                                 path + ': export-ignore: set')


if __name__ == '__main__':
    unittest.main()
