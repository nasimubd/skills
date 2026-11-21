import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync, mkdirSync, chmodSync } from 'node:fs';
import { join } from 'node:path';

export const STAGES = ['stage-1','stage-2','stage-3','stage-4','stage-5'];
export const sha = value => createHash('sha256').update(typeof value === 'string' ? value : JSON.stringify(value)).digest('hex');
export const stable = value => JSON.stringify(value, Object.keys(value).sort());
export function redact(value) {
  if (typeof value === 'string') return value.replace(/(gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|(?:api[_-]?key|token|secret|password)\s*[:=]\s*[^\s,;]+)/gi, '[REDACTED]');
  if (Array.isArray(value)) return value.map(redact);
  if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k,v]) => [k, /^(api[_-]?key|token|secret|password|authorization)$/i.test(k) ? '[REDACTED]' : redact(v)]));
  return value;
}
export function clean(value) { const x = JSON.stringify(value); if (JSON.stringify(redact(value)) !== x) throw Error('secret-bearing evidence must be sanitized before validation'); return value; }
export function fingerprint({component, rootCause, stage}) {
  if (!component || !rootCause || !stage) throw Error('fingerprint requires component, rootCause and stage');
  return sha([stage.trim().toLowerCase(), component.trim().toLowerCase(), rootCause.trim().toLowerCase().replace(/\s+/g,' ')].join('|'));
}
export function gh(cmd, args) { return execFileSync(cmd, args, {encoding:'utf8', timeout:30000}); }
export function parseRepo(url) {
  const match = url.match(/(?:github\.com[:/])([^/]+)\/([^/]+?)(?:\.git)?$/);
  if (!match) throw Error('GitHub origin required');
  return `${match[1]}/${match[2]}`;
}
export function collectIssues(repo, call=gh, binary='gh') {
  function pages(path) { const all=[]; for(let page=1;page<=10000;page++){const batch=JSON.parse(call(binary,['api',`${path}${path.includes('?')?'&':'?'}per_page=100&page=${page}`])); if(!Array.isArray(batch)) throw Error('API page is not an array'); all.push(...batch); if(batch.length<100)return all;} throw Error('pagination limit exceeded'); }
  return pages(`repos/${repo}/issues?state=all`).filter(x=>!x.pull_request).map(issue=>{
    const comments=pages(`repos/${repo}/issues/${issue.number}/comments`);
    const timeline=pages(`repos/${repo}/issues/${issue.number}/timeline`);
    return {number:issue.number,url:issue.html_url,title:issue.title,status:issue.state,body:issue.body||'',labels:(issue.labels||[]).map(x=>x.name),comments,timeline};
  });
}
export function baseline(issues, repo, timestamp=new Date().toISOString()) {
  const entries=issues.map(x=>{
    const body=x.body||''; const tag=body.match(/Root-cause fingerprint:\s*([a-f0-9]{64})/i);
    const field=name=>body.match(new RegExp(`^${name}:\\s*(.+)$`,'im'))?.[1]?.trim();
    let fp=tag?.[1]||null;
    if(!fp&&field('Stage')&&field('Component')&&field('Root Cause')) fp=fingerprint({stage:field('Stage'),component:field('Component'),rootCause:field('Root Cause')});
    return redact({...x, fingerprint:fp});
  });
  const data={repo,timestamp,complete:true,issues:entries};
  return {...data, checksum:sha(JSON.stringify(data))};
}
export function verifyBaseline(base) { const {checksum,...data}=base; if (!base.complete || sha(JSON.stringify(data))!==checksum) throw Error('incomplete or corrupted baseline'); }
export function validateFinding(f) {
  if (!STAGES.includes(f.stage)) throw Error('invalid stage');
  if (!['P0','P1','P2','P3'].includes(f.severity)) throw Error('invalid severity');
  for (const key of ['component','rootCause','summary','causalChain','expected','actual','reproductionCommand','inputHash','configHash','commit','fixture','runtime','evidenceHash']) if (!f[key]) throw Error(`missing ${key}`);
  if (!/^[a-f0-9]{40}$/.test(f.commit)) throw Error('invalid commit');
  if (!/^[a-f0-9]{64}$/.test(f.inputHash)|| !/^[a-f0-9]{64}$/.test(f.evidenceHash)) throw Error('invalid evidence hash');
  if (!Array.isArray(f.causalChain)||f.causalChain.length<5) throw Error('incomplete causal chain');
  clean(f);
  return true;
}
export function classify(findings, base) {
  verifyBaseline(base);
  const known=new Set(base.issues.map(x=>x.fingerprint).filter(Boolean));
  const seen=new Set();
  return findings.map(f=>{
    const fp=fingerprint(f); const excluded=known.has(fp)||seen.has(fp);
    if (!excluded&&f.reproduced===true) seen.add(fp);
    let status='UNVERIFIED';
    if (excluded) status='EXCLUDED';
    else if (f.reproduced===true) { validateFinding(f); status='CONFIRMED'; }
    return {...redact(f),fingerprint:fp,status};
  });
}
export function report(base, findings, meta={}) {
  const rows=classify(findings,base); const confirmed=rows.filter(x=>x.status==='CONFIRMED');
  const counts=Object.fromEntries(['P0','P1','P2','P3'].map(p=>[p,confirmed.filter(x=>x.severity===p).length]));
  return {auditRunId:sha(`${base.repo}|${base.timestamp}|${meta.commit||''}`).slice(0,16),timestamp:new Date().toISOString(),repository:base.repo,commit:meta.commit||null,baselineChecksum:base.checksum,baselineCount:base.issues.length,existingOpen:base.issues.filter(x=>x.status==='open').length,existingClosed:base.issues.filter(x=>x.status==='closed').length,unclassifiedHistoricalIssues:base.issues.filter(x=>!x.fingerprint).map(x=>x.number),excluded:rows.filter(x=>x.status==='EXCLUDED').length,confirmed:confirmed.length,unverified:rows.filter(x=>x.status==='UNVERIFIED').length,blockedInvestigations:meta.blockedInvestigations||0,severity:counts,financialImpacting:confirmed.filter(x=>x.financialImpact&&x.financialImpact!=='Not quantified').length,signalRelated:confirmed.filter(x=>['stage-1','stage-2','stage-3','stage-4'].includes(x.stage)).length,alphaRelated:confirmed.filter(x=>x.stage==='stage-3').length,deploymentRelated:confirmed.filter(x=>x.category==='deployment').length,stageScorecard:Object.fromEntries(STAGES.map(s=>[s,{componentsInspected:meta.coverage?.[s]?.componentsInspected||[],testsExecuted:meta.coverage?.[s]?.testsExecuted||0,testsPassed:meta.coverage?.[s]?.testsPassed||0,testsFailed:meta.coverage?.[s]?.testsFailed||0,confirmed:confirmed.filter(x=>x.stage===s).length,unverified:rows.filter(x=>x.stage===s&&x.status==='UNVERIFIED').length,remainingGaps:meta.coverage?.[s]?.remainingGaps||['agent evidence required']} ])),deployment:meta.deployment||'UNVERIFIED',issueRegister:[],verdict:confirmed.length?'INTEGRITY COMPROMISED':'INTEGRITY NOT FULLY VERIFIED',findings:rows};
}
export function issueBody(f,r) {
  validateFinding(f);
  const telemetry={auditTimestamp:r.timestamp,auditRunId:r.auditRunId,repository:r.repository,commit:f.commit,inputHash:f.inputHash,configHash:f.configHash,evidenceHash:f.evidenceHash,modelArtifacts:f.modelArtifacts||'not provided',deploymentBuildId:f.deploymentBuildId||'unverified',containerDigest:f.containerDigest||'unverified',datasetSnapshot:f.datasetSnapshot||'not provided',featureVector:f.featureVector||'not provided',prediction:f.prediction||'not provided',signalIds:f.signalIds||[],orderIds:f.orderIds||[],reviewedIssueNumbers:f.reviewedIssueNumbers||[],noveltyRationale:f.noveltyRationale||'structured fingerprints only'};
  const fields={'Executive Summary':f.summary,'Severity':f.severity,'Financial Impact':f.financialImpact||'Not quantified','Affected Stage and Component':`${f.stage} / ${f.component}`,'Source Files and Functions':(f.files||[]).join(', ')||'See evidence','Expected Behavior':f.expected,'Actual Behavior':f.actual,'Root-Cause Analysis':f.rootCause,'Causal Chain':f.causalChain.join(' → '),'Deterministic Reproduction':f.reproductionCommand,'Reproduction Environment':f.runtime,'Full Provenance Telemetry':JSON.stringify(telemetry,null,2),'Financial Consequence':f.financialImpact||'Not quantified','Remediation Requirements':f.remediation||'Investigate root cause and correct in a separate change','Regression Acceptance Criteria':f.acceptance||'Reproduction passes after fix','Evidence and Artifacts':f.fixture};
  return Object.entries(fields).map(([k,v])=>`## ${k}\n${v}`).join('\n\n')+`\n\nRoot-cause fingerprint: ${f.fingerprint||fingerprint(f)}`;
}
export function publish(r, base, {call=gh,binary='gh',authorization=false,confirm=false}={}) {
  if (!authorization||!confirm) throw Error('explicit publication authorization and confirmation required');
  verifyBaseline(base);
  const published=[];
  for (const f of r.findings.filter(x=>x.status==='CONFIRMED')) {
    validateFinding(f);
    const fp=fingerprint(f);
    const fresh=baseline(collectIssues(base.repo,call,binary),base.repo);
    const known=new Set(fresh.issues.map(x=>x.fingerprint).filter(Boolean));
    const unclassified=fresh.issues.filter(x=>!x.fingerprint).map(x=>x.number);
    if(unclassified.length && (!Array.isArray(f.reviewedIssueNumbers)||unclassified.some(n=>!f.reviewedIssueNumbers.includes(n))||!f.noveltyRationale)) throw Error(`manual root-cause review required for ${unclassified.length} unstructured historical issue(s)`);
    for(const x of published) known.add(x.fingerprint);
    if (known.has(fp)) continue;
    const title=`[INTEGRITY AUDIT][${f.severity}][${f.stage.toUpperCase()}] ${f.rootCause.slice(0,90)}`;
    const body=issueBody(f,r);
    clean(body);
    const result=JSON.parse(call(binary,['api',`repos/${base.repo}/issues`,'-X','POST','-f',`title=${title}`,'-f',`body=${body}`]));
    published.push({number:result.number,url:result.html_url,fingerprint:fp});
  }
  return published;
}
export function writePrivate(path,data) { mkdirSync(join(path,'..'),{recursive:true,mode:0o700}); writeFileSync(path,JSON.stringify(redact(data),null,2),{mode:0o600}); chmodSync(path,0o600); }
