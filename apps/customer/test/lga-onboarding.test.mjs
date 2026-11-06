import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {JSDOM} from 'jsdom';
const wait=()=>new Promise(r=>setTimeout(r,25));
test('onboarding requires an LGA and displays the selected local government',async()=>{
 const dom=new JSDOM('<!doctype html><div id="app"></div>',{url:'https://development.invalid/',runScripts:'outside-only'}),{window}=dom;
 window.HTMLDialogElement.prototype.showModal=function(){this.setAttribute('open','')};window.HTMLDialogElement.prototype.close=function(){this.removeAttribute('open')};
 let selected=null;const calls=[];
 window.__client={auth:{getSession:async()=>({data:{session:{user:{id:'synthetic'}}}}),onAuthStateChange:()=>({})},
 rpc:async(name,args)=>{calls.push({name,args});if(name==='list_delta_lgas')return {data:[{id:'uvwie-id',name:'Uvwie'},{id:'okpe-id',name:'Okpe'}],error:null};
 if(name==='get_own_lga')return {data:selected?[selected]:[],error:null};
 if(name==='set_own_lga'){selected={id:args.p_lga_id,name:args.p_lga_id==='uvwie-id'?'Uvwie':'Okpe'};return {data:null,error:null}}
 if(name==='get_own_onboarding_status')return {data:[{account_state:'pending',eligibility_status:'eligible',policy_complete:true}],error:null};
 if(name==='get_own_privacy_settings')return {data:[{profile_visibility:'private',contact_permission:'friends'}],error:null};
 if(name==='list_current_required_policies'||name==='list_own_blocks')return {data:[],error:null};return {data:null,error:null}},
 from:(table)=>table==='profiles'?{select:()=>({maybeSingle:async()=>({data:{handle:'test_user',display_name:'Test',biography:''},error:null})})}:{select:()=>({order:()=>({limit:async()=>({data:[],error:null})})})}};
 let source=await readFile(new URL('../src/main.js',import.meta.url),'utf8');source=source.replace("import './style.css';",'').replace("import { createClient } from '@supabase/supabase-js';",'const createClient=()=>window.__client;').replaceAll('import.meta.env.VITE_SUPABASE_URL',"'https://development.invalid'").replaceAll('import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY',"'test-public-key'");
 window.eval(source);await wait();
 assert.ok(window.document.querySelector('.lga-select'));assert.doesNotMatch(window.document.querySelector('#onboarding-steps').textContent,/Complete account setup/);
 window.document.querySelector('.lga-select').value='uvwie-id';
 [...window.document.querySelectorAll('#onboarding-steps button')].find(b=>b.textContent==='Save local government').click();await wait();await wait();
 assert.equal(calls.find(c=>c.name==='set_own_lga').args.p_lga_id,'uvwie-id');
 assert.match(window.document.querySelector('#onboarding-steps').textContent,/Complete account setup/);
 assert.equal(window.document.querySelector('#profile-lga').textContent,'Local government: Uvwie');
 dom.window.close();
});
