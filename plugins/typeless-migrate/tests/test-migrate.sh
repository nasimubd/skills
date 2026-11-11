#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/profile/Recordings"; printf audio > "$T/profile/Recordings/a.ogg"
python3 - "$T" <<'PY'
import json,sqlite3,sys
from pathlib import Path
r=Path(sys.argv[1]);(r/'profile/app-settings.json').write_text(json.dumps({'preferredLanguage':'en','__DEV_API_HOST':'secret'}));c=sqlite3.connect(r/'profile/typeless.db');c.execute('create table history_v2(id text,audio_local_path text)');c.execute('insert into history_v2 values(?,?)',('1',str(r/'profile/Recordings/a.ogg')));c.commit();c.close();(r/'terms.csv').write_text('café\n"ACME, Inc."\ncafé\n')
PY
"$ROOT/bin/typeless-migrate" --profile "$T/profile" --output "$T/dry" --dictionary "$T/terms.csv" | grep '"mode": "dry-run"'; test ! -e "$T/dry"
"$ROOT/bin/typeless-migrate" --profile "$T/profile" --output "$T/archive" --dictionary "$T/terms.csv" --execute >/dev/null
test -f "$T/archive/manifest.json"; test -f "$T/archive/audio/a.ogg"; grep -q credentials_copied "$T/archive/manifest.json"
