import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {JSDOM} from 'jsdom';
const wait=()=>new Promise(resolve=>setTimeout(resolve,25));

test('profile form saves only own fields, handles username conflict, clears on sign out',async()=>{
 const dom=new JSDOM('<!doctype html><div id="app"></div>',{url:'https://development.invalid/',runScripts:'outside-only'});const {window}=dom;
 window.HTMLDialogElement.prototype.showModal=function(){this.setAttribute('open','')};window.HTMLDialogElement.prototype.close=function(){this.removeAttribute('open')};
 const calls=[];let conflict=false;
 window.__client={auth:{getSession:async()=>({data:{session:{user:{id:'synthetic'}}}}),onAuthStateChange:()=>({}),signOut:async()=>({error:null})},
 rpc:async(name,args)=>{calls.push({name,args});if(name==='update_own_profile'&&conflict)return {error:{code:'23505'}};
 if(name==='get_own_onboarding_status')return {data:[{account_state:'active',eligibility_status:'eligible',policy_complete:true}],error:null};
 if(name==='get_own_privacy_settings')return {data:[{profile_visibility:'private',contact_permission:'friends'}],error:null};
 if(name==='list_current_required_policies'||name==='list_own_blocks')return {data:[],error:null};return {data:null,error:null}},
 from:(table)=>table==='profiles'?{select:()=>({maybeSingle:async()=>({data:{handle:'first_name',display_name:'First Name',biography:'Hello'},error:null})})}:{select:()=>({order:()=>({limit:async()=>({data:[],error:null})})})}};
 let source=await readFile(new URL('../src/main.js',import.meta.url),'utf8');
 source=source.replace("import './style.css';",'').replace("import { createClient } from '@supabase/supabase-js';",'const createClient=()=>window.__client;').replaceAll('import.meta.env.VITE_SUPABASE_URL',"'https://development.invalid'").replaceAll('import.meta.env.MODE',"'production'").replaceAll('import.meta.env.DEV','false').replaceAll('import.meta.env.VITE_ENABLE_SOCIAL_DRAFTS',"'false'").replaceAll('import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY',"'test-public-key'");
 window.eval(source);await wait();const form=window.document.querySelector('#profile-form');
 assert.equal(form.hidden,false);assert.equal(form.elements.displayName.value,'First Name');assert.equal(form.elements.handle.value,'first_name');
 form.elements.handle.value='NEW_NAME';form.elements.handle.dispatchEvent(new window.Event('input',{bubbles:true}));assert.equal(form.elements.handle.value,'new_name');
 form.elements.displayName.value=' New Name ';form.elements.biography.value=' Welcome ';
 form.dispatchEvent(new window.Event('submit',{bubbles:true,cancelable:true}));await wait();
 let call=calls.find(c=>c.name==='update_own_profile');assert.equal(call.args.p_handle,'new_name');assert.equal(call.args.p_display_name,'New Name');assert.equal(call.args.p_biography,'Welcome');
 assert.match(window.document.querySelector('#profile-message').textContent,/saved/i);
 conflict=true;form.dispatchEvent(new window.Event('submit',{bubbles:true,cancelable:true}));await wait();assert.match(window.document.querySelector('#profile-message').textContent,/not available/i);
 window.document.querySelector('#signout').click();await wait();assert.equal(window.document.querySelector('#profile-editor').hidden,true);assert.equal(form.hidden,true);assert.equal(form.elements.displayName.value,'');
 dom.window.close();
});
