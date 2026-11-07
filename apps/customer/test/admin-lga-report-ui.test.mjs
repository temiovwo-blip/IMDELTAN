import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {JSDOM} from 'jsdom';
const wait=()=>new Promise(r=>setTimeout(r,20));
test('admin draft post reports require a reason and render untrusted text safely',async()=>{
 const html=await readFile(new URL('../../admin/index.html',import.meta.url),'utf8');
 const dom=new JSDOM(html,{url:'https://dev.invalid',runScripts:'outside-only'});const w=dom.window;w.confirm=()=>true;let rows=[{report_id:'report-1',report_status:'open',post_status:'active',post_body:'<img src=x onerror=alert(1)>',reason:'<script>bad()</script>'}];const calls=[];
 w.__client={auth:{getSession:async()=>({data:{session:{user:{id:'mod'}}}}),onAuthStateChange:()=>({}),mfa:{getAuthenticatorAssuranceLevel:async()=>({data:{currentLevel:'aal2'}})},signOut:async()=>({error:null})},rpc:async(name,args)=>{calls.push({name,args});if(name==='list_reports_for_review')return {data:[],error:null};if(name==='list_lga_post_reports_for_review')return {data:rows,error:null};if(name==='remove_reported_lga_text_post'){rows=[];return {data:null,error:null}}}};
 let s=await readFile(new URL('../../admin/src/main.js',import.meta.url),'utf8');s=s.replace("import {createClient} from '@supabase/supabase-js';",'const createClient=()=>window.__client;').replaceAll('import.meta.env.VITE_SUPABASE_URL',"'https://dev.invalid'").replaceAll('import.meta.env.DEV','false').replaceAll('import.meta.env.VITE_ENABLE_SOCIAL_DRAFTS',"'false'").replaceAll('import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY',"'public-test-key'");w.eval(s);await wait();
 const list=w.document.querySelector('#lga-reports-list');assert.equal(list.querySelectorAll('img,script').length,0);assert.equal(list.querySelector('.reason').textContent,'<img src=x onerror=alert(1)>');
 list.querySelector('button').click();await wait();assert.equal(calls.filter(c=>c.name==='remove_reported_lga_text_post').length,0);
 list.querySelector('textarea').value=' policy reason ';list.querySelector('button').click();await wait();assert.equal(calls.find(c=>c.name==='remove_reported_lga_text_post').args.p_report_id,'report-1');assert.equal(calls.find(c=>c.name==='remove_reported_lga_text_post').args.p_justification,'policy reason');assert.equal(list.children.length,0);
 w.document.querySelector('#sign-out').click();await wait();assert.equal(w.document.querySelector('#reports-panel').hidden,true);assert.equal(list.children.length,0);dom.window.close();
});
