import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, cpSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
const root = mkdtempSync(join(tmpdir(), 'zlaunch-delivery-'));
const source = resolve('Custom');
const git = (cwd, ...args) => execFileSync('git', args, {cwd, encoding:'utf8', stdio:['ignore','pipe','pipe']}).trim();
const put = (path, body, mode=0o644) => writeFileSync(path, body, {mode});
try {
  const repo=join(root,'repo'), remote=join(root,'remote.git'), bin=join(root,'bin');
  mkdirSync(repo); mkdirSync(bin); mkdirSync(join(repo,'Custom'));
  git(root,'init','--bare',remote); git(repo,'init','-b','custom/main');
  git(repo,'config','user.name','Fixture'); git(repo,'config','user.email','fixture@example.invalid');
  git(repo,'remote','add','origin',remote);
  put(join(repo,'base'),'base'); git(repo,'add','.'); git(repo,'commit','-m','base');
  const base=git(repo,'rev-parse','HEAD'); git(repo,'push','origin','custom/main');
  const meta={repository:'zachthinks/ZLaunch',team:'FVY9AS28CU',version:'0.1.7',upstream_tag:'v0.11.19',upstream_commit:base,upstream_prerelease:false};
  put(join(repo,'Custom/release.json'),JSON.stringify(meta));
  for(const file of ['promote.mjs','publish-verified.mjs','publication-policy.mjs']) cpSync(join(source,file),join(repo,'Custom',file));
  put(join(repo,'Custom/publish.sh'),'#!/bin/sh\nprintf published > "$FIXTURE_ROOT/published"\n',0o755);
  git(repo,'add','.'); git(repo,'commit','-m','candidate'); const candidate=git(repo,'rev-parse','HEAD');
  put(join(bin,'gh'),`#!/usr/bin/env node
import fs from 'node:fs';
const args=process.argv.slice(2), endpoint=args.find(x=>x.startsWith('repos/'));
const root=process.env.FIXTURE_ROOT;
if(endpoint.includes('/statuses/') && !endpoint.includes('/commits/')) { fs.appendFileSync(root+'/attestation',JSON.stringify(args)+'\\n'); console.log('{}'); }
else { const data=JSON.parse(fs.readFileSync(root+'/responses.json')); if(!(endpoint in data))process.exit(2); console.log(JSON.stringify(data[endpoint])); }
`,0o755);
  // Treat the gh fixture as an ES module without invoking the real GitHub CLI.
  put(join(bin,'package.json'),'{"type":"module"}');
  const env={...process.env,PATH:bin+':'+process.env.PATH,FIXTURE_ROOT:root,GITHUB_REPOSITORY:'zachthinks/ZLaunch',GITHUB_EVENT_NAME:'schedule',GITHUB_RUN_ID:'123',CHECKED_COMMIT:candidate,SYNC_BASE:base};
  const promote=extra=>spawnSync('node',['Custom/promote.mjs'],{cwd:repo,env:{...env,...extra},encoding:'utf8'});
  assert.notEqual(promote({CHECKED_COMMIT:base}).status,0);
  assert.equal(git(root,'--git-dir',remote,'rev-parse','custom/main'),base);
  const result=promote({}); assert.equal(result.status,0,result.stderr);
  assert.equal(git(root,'--git-dir',remote,'rev-parse','custom/main'),candidate);
  assert.match(readFileSync(join(root,'attestation'),'utf8'),new RegExp(candidate));
  assert.notEqual(promote({}).status,0,'stale base must not promote again');
  // URL rewrite permits realistic origin identity checks without network access.
  git(repo,'config',`url.${remote}.insteadOf`,'https://github.com/zachthinks/ZLaunch.git');
  git(repo,'remote','set-url','origin','https://github.com/zachthinks/ZLaunch.git');
  // get-url expands rewrite rules, so narrowly mock only this read, delegating all
  // actual branch/cleanliness/remote ancestry operations to real Git.
  const realGit=execFileSync('/usr/bin/which',['git'],{encoding:'utf8'}).trim();
  put(join(bin,'git'),`#!/bin/sh
if [ "$1 $2 $3 $4" = 'remote get-url origin ' ]; then echo https://github.com/zachthinks/ZLaunch.git; else exec '${realGit}' "$@"; fi
`,0o755);
  const status={context:'zlaunch/stable-verified',state:'success',creator:{login:'github-actions[bot]'},target_url:'https://github.com/zachthinks/ZLaunch/actions/runs/123'};
  const run={id:123,repository:{full_name:'zachthinks/ZLaunch'},path:'.github/workflows/custom-sync.yml',event:'schedule',status:'completed',conclusion:'success'};
  const responses={
    'repos/zachthinks/ZLaunch/releases?per_page=100':[[{tag_name:'v0.1.6',draft:false,prerelease:false}]],
    [`repos/zachthinks/ZLaunch/commits/${candidate}/statuses?per_page=100`]:[status],
    'repos/zachthinks/ZLaunch/actions/runs/123':run
  };
  const check=(args=[],extra={})=>{put(join(root,'responses.json'),JSON.stringify(responses));return spawnSync('node',['Custom/publish-verified.mjs',...args],{cwd:repo,env:{...env,...extra},encoding:'utf8'});};
  let checked=check();assert.equal(checked.status,0,checked.stderr);
  assert.notEqual(check(['--publish']).status,0,'publishing needs explicit activation');
  run.conclusion='failure';assert.notEqual(check().status,0);run.conclusion='success';
  responses['repos/zachthinks/ZLaunch/releases?per_page=100'][0].push({tag_name:'v0.1.7',draft:true});
  assert.notEqual(check().status,0,'existing draft blocks duplicate');responses['repos/zachthinks/ZLaunch/releases?per_page=100'][0].pop();
  put(join(repo,'dirty'),'dirty');assert.notEqual(check().status,0,'dirty checkout blocks publication');rmSync(join(repo,'dirty'));
  checked=check(['--publish'],{ZLAUNCH_AUTOPUBLISH:'1',NOTARY_PROFILE:'ZLaunch-Local'});assert.equal(checked.status,0,checked.stderr);
  assert.equal(readFileSync(join(root,'published'),'utf8'),'published');
  console.log('Disposable delivery fixtures passed: exact SHA, fast-forward, stale base, provenance, activation, drafts, dirty source and publisher handoff.');
} finally { rmSync(root,{recursive:true,force:true}); }
