import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,writeFileSync,readFileSync,chmodSync,existsSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {execFileSync} from 'node:child_process';
import {cases,finding} from '../evals/fixtures/synthetic.mjs';
const cli=resolve('skills/quantitative-integrity-audit/scripts/qia');
test('CLI inventories before audit and never contacts real GitHub',()=>{
  const dir=mkdtempSync(join(tmpdir(),'qia-cli-')),bin=join(dir,'bin'),repo=join(dir,'repo'),out=join(dir,'private');mkdirSync(bin);mkdirSync(repo);
  const log=join(dir,'gh.log'),script=join(bin,'gh');writeFileSync(script,'#!/bin/sh\nprintf "%s\\n" "$*" >> "$QIA_MOCK_LOG"\nprintf "[]\\n"\n');chmodSync(script,0o755);
  const git=(...a)=>execFileSync('git',a,{cwd:repo,encoding:'utf8'}).trim();git('init','-q');git('remote','add','origin','https://github.com/o/r.git');writeFileSync(join(repo,'README'),'synthetic');git('add','.');git('-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-qm','fixture');
  const f=finding(cases[0]);f.commit=git('rev-parse','HEAD');const input=join(dir,'findings.json');writeFileSync(input,JSON.stringify([f]));
  const env={...process.env,PATH:`${bin}:${process.env.PATH}`,QIA_MOCK_LOG:log};
  const result=execFileSync('node',[cli,'audit','--findings',input,'--out',out],{cwd:repo,env,encoding:'utf8'});
  assert.match(result,/Issue baseline collected first/);assert.equal(readFileSync(log,'utf8').split('\n').filter(Boolean).length,1);
  const r=JSON.parse(readFileSync(join(out,'report.json'),'utf8'));assert.equal(r.confirmed,1);assert.equal(r.baselineCount,0);assert.equal(r.deployment,'UNVERIFIED');assert.ok(existsSync(join(out,'baseline.json')));
});
