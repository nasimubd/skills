#!/usr/bin/env python3
"""Synthetic behavioral checks; no installed Typeless profile is accessed."""
import contextlib
import csv
import importlib.util
import io
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('poc', Path(__file__).with_name('poc.py'))
poc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(poc)


class MigrationProof(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.audio = self.root / 'Recordings'
        self.audio.mkdir()
        (self.audio / 'sample.ogg').write_bytes(b'OggS\x00synthetic-audio')
        self.db = self.root / 'source.db'
        con = sqlite3.connect(self.db)
        con.execute('''CREATE TABLE history_v2 (
            id TEXT PRIMARY KEY, user_id TEXT, refined_text TEXT, mode TEXT,
            status TEXT, created_at TEXT, duration REAL, app_version TEXT,
            audio_local_path TEXT, mode_meta BLOB, audio_context TEXT,
            server_updated_at INTEGER, sync_status TEXT,
            sync_attempt_count INTEGER, synced_from_cloud INTEGER)''')
        values = ('original-record', 'source-user', 'বাংলা, café 👋', 'voice_transcript',
                  'completed', '2026-01-01T00:00:00Z', 1.0, '2.10.0',
                  str(self.audio / 'sample.ogg'), b'\x00\xffmetadata',
                  '{"_encrypted":true,"_key":"synthetic"}', 123, 'synced', 1, 1)
        con.execute('INSERT INTO history_v2 VALUES (' + ','.join('?' for _ in values) + ')', values)
        con.commit()
        con.close()
        self.settings = self.root / 'settings.json'
        self.settings.write_text(json.dumps({'preferredLanguage': 'en', 'selectedMicrophoneDevice': {'deviceId': 'source-device'}, '__DEV_API_HOST': 'https://invalid.example', '__internal__': {'migrations': {}}}))
        self.storage = self.root / 'storage.json'
        self.storage.write_text(json.dumps({'userData': {'user_id': 'source-user', 'email': 'source@example.invalid', 'subscription_plan_id': 'source-plan', 'personal_auto_style_on': True}}))
        self.dictionary = self.root / 'dictionary.json'
        self.dictionary.write_text(json.dumps(['বাংলা', 'ACME, Inc.', 'Say "hello"', 'café', 'বাংলা', '']))

    def run_poc(self, name='run'):
        with contextlib.redirect_stdout(io.StringIO()):
            return poc.run(self.db, self.settings, self.storage, self.audio, self.root / name, self.dictionary)

    def test_archive_restore_preserves_content_and_excludes_identity(self):
        before = poc.digest(self.db)
        report = self.run_poc()
        self.assertEqual(report['history_rows_restored_to_synthetic_identity'], 1)
        self.assertEqual(report['audio_files_copied_and_hash_verified_twice'], 1)
        self.assertTrue(report['restored_from_serialized_archive'])
        self.assertEqual(poc.digest(self.db), before)
        dest = self.root / 'run/synthetic-destination'
        self.assertEqual(json.loads((dest / 'app-settings.json').read_text()), {'preferredLanguage': 'en'})
        con = sqlite3.connect(dest / 'typeless.db')
        row = con.execute('SELECT id,user_id,refined_text,mode_meta,audio_context,sync_status FROM history_v2').fetchone()
        con.close()
        self.assertNotEqual(row[0], 'original-record')
        self.assertNotEqual(row[1], 'source-user')
        self.assertEqual(row[2], 'বাংলা, café 👋')
        self.assertEqual(row[3], b'\x00\xffmetadata')
        self.assertEqual(row[4], '{"_encrypted":true,"_key":"synthetic"}')
        self.assertEqual(row[5], 'poc_quarantined')
        with (self.root / 'run/archive/dictionary.csv').open(newline='') as stream:
            self.assertEqual([r[0] for r in csv.reader(stream)], ['বাংলা', 'ACME, Inc.', 'Say "hello"', 'café'])
        self.assertFalse((dest / 'app-storage.json').exists())
        self.assertFalse((dest / 'user-data.json').exists())

    def test_existing_workspace_is_refused(self):
        self.run_poc()
        with self.assertRaises(FileExistsError):
            self.run_poc()

    def test_audio_path_escape_is_refused(self):
        outside = self.root / 'outside.ogg'
        outside.write_bytes(b'outside')
        con = sqlite3.connect(self.db)
        con.execute('UPDATE history_v2 SET audio_local_path=?', (str(outside),))
        con.commit()
        con.close()
        with self.assertRaisesRegex(ValueError, 'escapes'):
            self.run_poc()

    def test_symlink_audio_escape_is_refused(self):
        outside = self.root / 'outside.ogg'
        outside.write_bytes(b'outside')
        sample = self.audio / 'sample.ogg'
        sample.unlink()
        sample.symlink_to(outside)
        with self.assertRaisesRegex(ValueError, 'escapes'):
            self.run_poc()

    def test_missing_audio_is_reported(self):
        (self.audio / 'sample.ogg').unlink()
        report = self.run_poc()
        self.assertEqual(report['missing_audio_files'], 1)
        self.assertEqual(report['audio_files_copied_and_hash_verified_twice'], 0)

    def test_multiline_dictionary_terms_are_refused(self):
        self.dictionary.write_text(json.dumps(['line\nbreak']))
        with self.assertRaisesRegex(ValueError, 'faithfully'):
            self.run_poc()


if __name__ == '__main__':
    unittest.main(verbosity=2)
