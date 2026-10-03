import {mkdtempSync,mkdirSync,writeFileSync,readFileSync,rmSync} from 'node:fs';
import {execFileSync,spawnSync} from 'node:child_process';
import assert from 'node:assert/strict';
const root=mkdtempSync('/tmp/zlaunch-sync-test-');
const script=new URL('../sync.mjs', import.meta.url).pathname;
const run=(cwd,...args)=>execFileSync('git',args,{cwd,encoding:'utf8',stdio:['ignore','pipe','pipe']}).trim();
function setup(conflict){
 const d=root+'/'+(conflict?'conflict':'clean'); mkdirSync(d);
 run(d,'init','-b','main'); run(d,'config','user.name','Test'); run(d,'config','user.email','test@example.invalid');
 mkdirSync(d+'/Custom');writeFileSync(d+'/Custom/release.json',JSON.stringify({version:'0.1.0',upstream_tag:'v0.11.12'}));writeFileSync(d+'/.gitignore','build/\norigin.git/\n');writeFileSync(d+'/shared.txt','base\n');run(d,'add','.');run(d,'commit','-m','base');const base=run(d,'rev-parse','HEAD');
 writeFileSync(d+'/shared.txt','upstream\n');run(d,'add','.');run(d,'commit','-m','upstream');run(d,'tag','v0.11.13');
 run(d,'switch','-c','custom/main',base);writeFileSync(d+(conflict?'/shared.txt':'/custom.txt'),'custom\n');run(d,'add','.');run(d,'commit','-m','custom');const original=run(d,'rev-parse','HEAD');
 run(d,'remote','add','upstream',d);run(d,'init','--bare',d+'/origin.git');run(d,'remote','add','origin',d+'/origin.git');
 const bins=d+'/bin';mkdirSync(bins);writeFileSync(bins+'/gh','#!/bin/sh\nprintf \'%s\\n\' \'{"tag_name":"v0.11.13","draft":false,"prerelease":false}\'\n',{mode:0o755});run(d,'add','bin');run(d,'commit','-m','fixture helper');const start=run(d,'rev-parse','HEAD');
 const go=()=>spawnSync('node',[script],{cwd:d,env:{...process.env,PATH:bins+':'+process.env.PATH},encoding:'utf8'});
 let out=go();
 if(conflict){assert.notEqual(out.status,0);assert.equal(run(d,'branch','--show-current'),'custom/main');assert.equal(run(d,'rev-parse','HEAD'),start);assert.equal(run(d,'status','--porcelain'),'');assert.match(readFileSync(d+'/build/sync-conflicts.txt','utf8'),/shared.txt/);assert.notEqual(go().status,0);}
 else{assert.equal(out.status,0,out.stderr);assert.equal(JSON.parse(readFileSync(d+'/Custom/release.json')).version,'0.1.1');run(d,'push','origin','HEAD');run(d,'switch','custom/main');out=go();assert.equal(out.status,0,out.stderr);assert.match(out.stdout,/Resume/);}
 console.log(conflict?'Conflict cleanup and retry passed':'Clean merge, version bump, and remote-candidate resume passed');
}
try{setup(false);setup(true);}finally{rmSync(root,{recursive:true,force:true});}
