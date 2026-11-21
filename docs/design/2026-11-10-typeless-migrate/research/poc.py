#!/usr/bin/env python3
"""Offline research PoC. Writes only beneath a new workspace, never to Typeless."""
import argparse
import base64
import csv
import hashlib
import json
import os
from pathlib import Path
import shutil
import sqlite3
import uuid

SETTINGS = {
    'featureShortcutBindings', 'preferredLanguage', 'autoSelectLanguages',
    'selectedLanguages', 'launchAtSystemStartup', 'showFlowBarOnDesktop',
    'enableInteractionSoundEffects', 'enableShowAppInDock',
    'historyDurationSeconds', 'enabledMuteBackgroundAudio',
    'translationModeTargetLanguageCodes', 'translationModeAlertPreferredLanguageCode',
    'appearancePreference',
}
SERVER_SETTINGS = {
    'dictation_settings', 'translation_settings',
    'personal_auto_style_on', 'personal_auto_dictionary_on', 'locale',
}


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def packed(value):
    return {'__blob__': base64.b64encode(value).decode()} if isinstance(value, bytes) else value


def unpacked(value):
    return base64.b64decode(value['__blob__']) if isinstance(value, dict) and set(value) == {'__blob__'} else value


def write_json(path, value):
    with path.open('x', encoding='utf-8') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write('\n')


def run(snapshot, settings_path, storage_path, recordings, workspace, dictionary=None):
    os.umask(0o077)
    snapshot = snapshot.resolve(strict=True)
    recordings = recordings.resolve(strict=True)
    workspace = workspace.absolute()
    # Requiring a new directory makes repeat runs fail closed and avoids overwrites.
    workspace.mkdir(parents=True, exist_ok=False)
    archive = workspace / 'archive'
    restored = workspace / 'synthetic-destination'
    for path in (archive, restored, archive / 'audio', restored / 'Recordings'):
        path.mkdir(mode=0o700)
    original_hash = digest(snapshot)
    source = sqlite3.connect(snapshot.as_uri() + '?mode=ro', uri=True)
    source.execute('PRAGMA query_only=ON')
    source.row_factory = sqlite3.Row
    cached_user = json.loads(storage_path.read_text())['userData']
    source_user = cached_user['user_id']
    target_user = 'poc-destination-' + str(uuid.uuid4())
    schema = source.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name='history_v2'").fetchone()[0]
    write_json(archive / 'schema.json', {'history_v2': schema})
    settings = json.loads(settings_path.read_text())
    portable_settings = {key: settings[key] for key in sorted(SETTINGS) if key in settings}
    server_settings = {key: cached_user[key] for key in sorted(SERVER_SETTINGS) if key in cached_user}
    write_json(archive / 'settings.json', portable_settings)
    write_json(archive / 'account-preferences-reference.json', server_settings)
    write_json(restored / 'app-settings.json', portable_settings)
    target = sqlite3.connect(restored / 'typeless.db')
    target.execute(schema)
    expected_hashes = []
    row_count = audio_count = missing_audio = 0
    with (archive / 'history.jsonl').open('x', encoding='utf-8') as output:
        for row in source.execute('SELECT * FROM history_v2 WHERE user_id=? ORDER BY created_at,id', (source_user,)):
            row = dict(row)
            archive_row = {k: packed(v) for k, v in row.items()}
            old_audio = row.get('audio_local_path')
            if old_audio:
                audio = Path(old_audio).resolve(strict=False)
                if recordings not in audio.parents:
                    raise ValueError('Audio reference escapes the expected Recordings directory')
                if audio.is_file():
                    suffix = audio.suffix
                    relative = 'audio/' + hashlib.sha256(row['id'].encode()).hexdigest() + suffix
                    copied = archive / relative
                    shutil.copyfile(audio, copied)
                    original_audio_hash = digest(audio)
                    assert digest(copied) == original_audio_hash
                    archive_row['audio_local_path'] = relative
                    dest_audio = restored / 'Recordings' / copied.name
                    shutil.copyfile(copied, dest_audio)
                    assert digest(dest_audio) == original_audio_hash
                    row['audio_local_path'] = str(dest_audio)
                    audio_count += 1
                else:
                    missing_audio += 1
                    archive_row['audio_local_path'] = None
                    row['audio_local_path'] = None
            # Preserve source metadata in the private archive; never export authentication.
            output.write(json.dumps(archive_row, ensure_ascii=False) + '\n')
            row_count += 1
    # Restore exclusively from the serialized archive, not from source rows.
    with (archive / 'history.jsonl').open(encoding='utf-8') as exported:
        for line in exported:
            row = {k: unpacked(v) for k, v in json.loads(line).items()}
            if row.get('audio_local_path'):
                archived_audio = archive / row['audio_local_path']
                row['audio_local_path'] = str(restored / 'Recordings' / archived_audio.name)
            original_row = dict(row)
            row['id'] = str(uuid.uuid5(uuid.NAMESPACE_URL, target_user + '/' + row['id']))
            row['user_id'] = target_user
            row['server_updated_at'] = None
            row['sync_attempt_count'] = 0
            row['synced_from_cloud'] = 0
            # Research-only quarantine marker: NOT a supported application sync state.
            row['sync_status'] = 'poc_quarantined'
            cols = list(row)
            target.execute('INSERT INTO history_v2 (' + ','.join('"' + c + '"' for c in cols) + ') VALUES (' + ','.join('?' for _ in cols) + ')', [row[c] for c in cols])
            expected_hashes.append((row['id'], hashlib.sha256(json.dumps({k: packed(v) for k, v in original_row.items() if k not in {'id', 'user_id', 'server_updated_at', 'sync_attempt_count', 'synced_from_cloud', 'sync_status'}}, sort_keys=True, ensure_ascii=False).encode()).hexdigest()))
    target.commit()
    preserved = 0
    for record_id, expected in expected_hashes:
        target.row_factory = sqlite3.Row
        actual = dict(target.execute('SELECT * FROM history_v2 WHERE id=?', (record_id,)).fetchone())
        actual_hash = hashlib.sha256(json.dumps({k: packed(v) for k, v in actual.items() if k not in {'id', 'user_id', 'server_updated_at', 'sync_attempt_count', 'synced_from_cloud', 'sync_status'}}, sort_keys=True, ensure_ascii=False).encode()).hexdigest()
        assert actual_hash == expected
        preserved += 1
    assert target.execute('SELECT count(*) FROM history_v2 WHERE user_id=?', (source_user,)).fetchone()[0] == 0
    assert target.execute("SELECT count(*) FROM history_v2 WHERE sync_status IN ('pending_upload','sync_failed')").fetchone()[0] == 0
    assert target.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
    assert json.loads((restored / 'app-settings.json').read_text()) == portable_settings
    dictionary_count = None
    if dictionary:
        terms = json.loads(dictionary.read_text())
        if not isinstance(terms, list) or not all(isinstance(t, str) for t in terms):
            raise ValueError('Dictionary fixture must be a JSON list of terms')
        terms = list(dict.fromkeys(t.strip() for t in terms if t.strip()))
        if any('\x00' in t or '\n' in t or '\r' in t or len(t.encode('utf-16-le')) // 2 > 100 for t in terms):
            raise ValueError('Dictionary input cannot be represented faithfully by the observed importer')
        if len(terms) > 3000:
            raise ValueError('Observed importer supports at most 3000 words per file')
        with (archive / 'dictionary.csv').open('x', newline='', encoding='utf-8') as stream:
            csv.writer(stream).writerows([t] for t in terms)
        assert (archive / 'dictionary.csv').stat().st_size <= 5 * 1024 * 1024
        with (archive / 'dictionary.csv').open(newline='', encoding='utf-8') as stream:
            assert [r[0] for r in csv.reader(stream)] == terms
        dictionary_count = len(terms)
    assert digest(snapshot) == original_hash
    assert not any((restored / name).exists() for name in ['user-data.json', 'app-storage.json', 'Cookies', 'transcription-history-sync-state.json', 'transcription-history-sync-task.json'])
    report = {
        'history_rows_exported': row_count,
        'history_rows_restored_to_synthetic_identity': preserved,
        'audio_files_copied_and_hash_verified_twice': audio_count,
        'missing_audio_files': missing_audio,
        'local_settings_roundtripped': len(portable_settings),
        'cached_account_preference_groups_archived_only': len(server_settings),
        'dictionary_fixture_terms_roundtripped': dictionary_count,
        'snapshot_sha256_unchanged': True,
        'destination_integrity': 'ok',
        'restored_from_serialized_archive': True,
        'credentials_copied': False,
        'network_requests': 0,
        'destination_launched_in_typeless': False,
        'learned_personalization_transferred': False,
        'sync_marker': 'poc_quarantined; research only, not app-supported',
    }
    write_json(workspace / 'result.json', report)
    source.close()
    target.close()
    print(json.dumps(report, indent=2))
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for arg in ['snapshot', 'settings', 'storage', 'recordings', 'workspace']:
        parser.add_argument('--' + arg, type=Path, required=True)
    parser.add_argument('--dictionary-fixture', type=Path)
    args = parser.parse_args()
    run(args.snapshot, args.settings, args.storage, args.recordings, args.workspace, args.dictionary_fixture)
