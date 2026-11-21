import {cases,reproduce} from './synthetic.mjs';
const c=cases.find(x=>x.stage===process.argv[2]);
if(!c) throw Error('unknown stage');
const actual=reproduce(c);
console.log(JSON.stringify({stage:c.stage,expected:c.expected,actual,reproduced:actual===c.actual}));
if(actual!==c.actual) process.exitCode=1;
