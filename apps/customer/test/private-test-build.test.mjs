import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync,rmSync,readdirSync,readFileSync,existsSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';

const root=dirname(dirname(fileURLToPath(import.meta.url)));
const vite=join(root,'node_modules/vite/bin/vite.js');
const ref='uxfyhpukeqttrvcfemts'; // Dedicated synthetic project; tests use a fake key and never contact it.
const fake={IMDELTAN_SYNTHETIC_PROJECT_REF:ref,IMDELTAN_SYNTHETIC_ONLY_CONFIRM:'SYNTHETIC-ONLY-ISOLATED-PROJECT',VITE_SUPABASE_URL:`https://${ref}.supabase.co`,VITE_SUPABASE_PUBLISHABLE_KEY:'sb_publishable_'+'x'.repeat(24),VITE_ENABLE_SOCIAL_DRAFTS:'true'};
function build(mode,overrides={}){
 const dir=mkdtempSync(join(tmpdir(),'imdeltan-build-check-'));
 try{
  const env={...process.env,...fake,...overrides};
  const result=spawnSync(process.execPath,[vite,'build','--mode',mode,'--outDir',dir,'--emptyOutDir'],{cwd:root,env,encoding:'utf8',timeout:90000});
  const assets=join(dir,'assets');let js='',assetNames=[];
  if(result.status===0){assetNames=readdirSync(assets);for(const name of assetNames)if(name.endsWith('.js'))js+=readFileSync(join(assets,name),'utf8');}
  const marker=existsSync(join(dir,'imdeltan-synthetic-test-only.json'));
  return {status:result.status,output:(result.stdout||'')+(result.stderr||''),js,assetNames,marker,error:result.error};
 }finally{rmSync(dir,{recursive:true,force:true});}
}

test('normal production build excludes draft modules even when social flag is set',()=>{
 const r=build('production');assert.equal(r.status,0,r.output);assert.equal(r.marker,false);
 for(const s of ['list_lga_text_posts','create_lga_text_post','create_lga_post_comment','list_private_group_text_posts','create_private_group_text_post','list_private_group_post_comments','list_friend_messages','send_friend_message','list_own_private_group_members','remove_own_private_group_member','list_own_group_removal_notifications','save_visible_lga_text_post','edit_own_private_group_post_comment','SYNTHETIC-ONLY PRIVATE TEST'])assert.equal(r.js.includes(s),false,`unexpected ${s}`);
 assert.equal(r.assetNames.some(s=>s.includes('-draft-')),false,'draft chunk included in production build');
});

test('explicit synthetic build includes drafts and an unambiguous warning',()=>{
 const r=build('imdeltan-synthetic-apk');assert.equal(r.status,0,r.output);assert.equal(r.marker,true);
 for(const s of ['list_lga_text_posts','list_private_group_text_posts','send_friend_message','SYNTHETIC-ONLY PRIVATE TEST'])assert.ok(r.js.includes(s),`missing ${s}`);
});

test('synthetic build fails closed for missing confirmation, wrong target or key',()=>{
 for(const bad of [
  {IMDELTAN_SYNTHETIC_ONLY_CONFIRM:''},
  {VITE_ENABLE_SOCIAL_DRAFTS:''},
  {IMDELTAN_SYNTHETIC_PROJECT_REF:'bdhcpgqxhnecrcopoxge',VITE_SUPABASE_URL:'https://bdhcpgqxhnecrcopoxge.supabase.co'},
  {IMDELTAN_SYNTHETIC_PROJECT_REF:'aaaaaaaaaaaaaaaaaaaa',VITE_SUPABASE_URL:'https://aaaaaaaaaaaaaaaaaaaa.supabase.co'},
  {VITE_SUPABASE_URL:'https://other.example'},
  {VITE_SUPABASE_PUBLISHABLE_KEY:'sb_secret_not-allowed'},
  {IMDELTAN_SYNTHETIC_PROJECT_REF:''}
 ]){
  const r=build('imdeltan-synthetic-apk',bad);assert.notEqual(r.status,0,'invalid synthetic build unexpectedly succeeded');assert.match(r.output,/Synthetic APK build refused/);
 }
});

test('standard build refuses a development NODE_ENV that could expose drafts',()=>{
 const r=build('production',{NODE_ENV:'development'});assert.notEqual(r.status,0);assert.match(r.output,/Standard builds require NODE_ENV=production/);
});
