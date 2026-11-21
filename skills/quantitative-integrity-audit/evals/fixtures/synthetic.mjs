import { sha } from '../../scripts/lib/core.mjs';

export const commit='a'.repeat(40);
export const cases=[
  {stage:'stage-1',component:'oi-align',rootCause:'OI joined on future timestamp',input:{decision:300,oiAvailable:305},expected:'missing',actual:'future OI used'},
  {stage:'stage-2',component:'event-gate',rootCause:'AND used instead of OR',input:{cusum:true,shock:false},expected:true,actual:false},
  {stage:'stage-3',component:'alpha-inference',rootCause:'feature order swapped at inference',input:{trained:['a','b'],inferred:['b','a']},expected:'a,b',actual:'b,a'},
  {stage:'stage-4',component:'meta-veto',rootCause:'rank threshold comparison inverted',input:{rank:0.9,threshold:0.85},expected:'accept',actual:'veto'},
  {stage:'stage-5',component:'position-sizing',rootCause:'stop percentage divided twice',input:{equity:10000,slPercent:2},expected:5000,actual:500000}
];
export function reproduce(c){
  const i=c.input;
  switch(c.stage){
    case 'stage-1': return i.oiAvailable>i.decision?'future OI used':'missing';
    case 'stage-2': return i.cusum&&i.shock;
    case 'stage-3': return i.inferred.join(',');
    case 'stage-4': return i.rank>=i.threshold?'veto':'accept';
    case 'stage-5': return Math.round(.01*i.equity/(i.slPercent/100/100));
  }
}
export function finding(c){const actual=reproduce(c);return {stage:c.stage,component:c.component,rootCause:c.rootCause,severity:c.stage==='stage-5'?'P0':'P1',summary:`Synthetic ${c.component} defect`,causalChain:['synthetic input','seeded processing',String(actual),'downstream divergence','observable mismatch'],expected:String(c.expected),actual:String(actual),reproductionCommand:`node skills/quantitative-integrity-audit/evals/fixtures/reproduce.mjs ${c.stage}`,inputHash:sha(c.input),configHash:sha({synthetic:true}),commit,fixture:`synthetic.mjs:${c.stage}`,runtime:'Node.js >=22',evidenceHash:sha({expected:c.expected,actual}),reproduced:actual===c.actual,financialImpact:'Not quantified'};}
