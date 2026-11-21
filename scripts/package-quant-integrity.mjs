#!/usr/bin/env node
import {cpSync,mkdirSync,mkdtempSync,readFileSync,readdirSync,statSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {resolve,join,relative} from 'node:path';
import {createHash} from 'node:crypto';
const root=resolve(import.meta.dirname,'..');
const out=resolve(process.argv[2]||mkdtempSync(join(tmpdir(),'qia-packages-')));
const canonical=join(root,'skills/quantitative-integrity-audit');
const hash=p=>createHash('sha256').update(readFileSync(p)).digest('hex');
function files(dir){return readdirSync(dir,{withFileTypes:true}).flatMap(x=>{const p=join(dir,x.name);return statSync(p).isDirectory()?files(p):[p]});}
for(const [host,source] of [['claude','plugins/quant-integrity-auditor'],['codex','codex-plugins/quant-integrity-auditor']]){
  const dest=join(out,host,'quant-integrity-auditor');mkdirSync(dest,{recursive:true});
  cpSync(join(root,source),dest,{recursive:true,dereference:true});
  rmSync(join(dest,'skills/quantitative-integrity-audit'),{recursive:true,force:true});
  cpSync(canonical,join(dest,'skills/quantitative-integrity-audit'),{recursive:true,dereference:true});
  if(host==='claude') {rmSync(join(dest,'scripts/shared'),{recursive:true,force:true});cpSync(join(canonical,'scripts'),join(dest,'scripts/shared'),{recursive:true});rmSync(join(dest,'bin/quant-integrity-auditor'),{force:true});cpSync(join(canonical,'scripts/qia'),join(dest,'bin/quant-integrity-auditor'));}
  if(host==='claude') {mkdirSync(join(dest,'.claude-plugin'),{recursive:true});cpSync(join(dest,'plugin.json'),join(dest,'.claude-plugin/plugin.json'));}
  const packaged=join(dest,'skills/quantitative-integrity-audit');
  for(const p of files(canonical)) {const rel=relative(canonical,p);if(hash(p)!==hash(join(packaged,rel)))throw Error(`SHA-256 parity failed: ${host}/${rel}`);}
  console.log(`${host}: ${files(canonical).length} canonical files SHA-256 matched at ${dest}`);
}
