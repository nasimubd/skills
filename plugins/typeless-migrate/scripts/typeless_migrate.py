#!/usr/bin/env python3
import argparse,csv,hashlib,json,shutil,sqlite3,sys
from pathlib import Path
PORTABLE={'featureShortcutBindings','preferredLanguage','autoSelectLanguages','selectedLanguages','launchAtSystemStartup','showFlowBarOnDesktop','enableInteractionSoundEffects','enableShowAppInDock','historyDurationSeconds','enabledMuteBackgroundAudio','translationModeTargetLanguageCodes','translationModeAlertPreferredLanguageCode','appearancePreference'}
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b)
 return h.hexdigest()
def main(a):
 profile=a.profile.expanduser();db=profile/'typeless.db';settings=profile/'app-settings.json';recordings=profile/'Recordings';out=a.output.expanduser()
 if not all(p.exists() for p in (db,settings,recordings)):raise SystemExit('missing required Typeless source path')
 if out.exists():raise SystemExit('refusing existing output directory')
 con=sqlite3.connect(db.as_uri()+'?mode=ro',uri=True);con.execute('PRAGMA query_only=ON');rows=con.execute('SELECT id,audio_local_path FROM history_v2').fetchall();audio=[]
 for rid,path in rows:
  if path:
   p=Path(path).resolve(strict=False)
   if recordings.resolve() not in p.parents:raise SystemExit('recording path escapes Recordings directory')
   if p.is_file():audio.append(p)
 terms=[]
 if a.dictionary:
  with a.dictionary.expanduser().open(newline='',encoding='utf-8') as f:
   for row in csv.reader(f):
    vals=[x.strip() for x in row if x.strip()]
    if len(vals)>1:raise SystemExit('dictionary CSV must contain one non-empty column per row')
    if vals:terms.append(vals[0])
  terms=list(dict.fromkeys(terms))
  if len(terms)>3000 or any('\x00' in x or '\n' in x or '\r' in x or len(x.encode('utf-16-le'))//2>100 for x in terms):raise SystemExit('dictionary exceeds observed importer constraints')
 cfg=json.loads(settings.read_text());report={'mode':'execute' if a.execute else 'dry-run','history_rows':len(rows),'recordings_found':len(audio),'portable_settings':len([k for k in PORTABLE if k in cfg]),'dictionary_terms':len(terms),'credentials_copied':False,'destination_modified':False,'learned_personalization_transferred':False}
 if not a.execute:print(json.dumps(report,indent=2));return 0
 out.mkdir(mode=0o700);(out/'audio').mkdir(mode=0o700);src_hash=sha(db);shutil.copyfile(db,out/'source-database-snapshot.db');assert sha(out/'source-database-snapshot.db')==src_hash
 json.dump({k:cfg[k] for k in PORTABLE if k in cfg},(out/'settings.json').open('x'),ensure_ascii=False,indent=2)
 with (out/'dictionary.csv').open('x',newline='',encoding='utf-8') as f:csv.writer(f).writerows([[t] for t in terms])
 hashes=[]
 for p in audio:
  d=out/'audio'/p.name;shutil.copyfile(p,d);hashes.append({'name':p.name,'sha256':sha(d),'size':d.stat().st_size})
 report.update({'source_database_sha256':src_hash,'audio_hashes':hashes,'archive_complete':True});json.dump(report,(out/'manifest.json').open('x'),ensure_ascii=False,indent=2);print(json.dumps(report,indent=2));return 0
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--profile',type=Path,default=Path.home()/'Library/Application Support/Typeless');p.add_argument('--output',type=Path,required=True);p.add_argument('--dictionary',type=Path);p.add_argument('--execute',action='store_true');sys.exit(main(p.parse_args()))
