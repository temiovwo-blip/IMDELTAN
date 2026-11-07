import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {JSDOM} from 'jsdom';

const wait = () => new Promise(resolve => setTimeout(resolve, 25));

test('privacy form loads, saves selected values, and clears at sign-out', async () => {
  const dom = new JSDOM('<!doctype html><div id="app"></div>', {url:'https://development.invalid/',runScripts:'outside-only'});
  const {window}=dom;
  window.HTMLDialogElement.prototype.showModal=function(){this.setAttribute('open','')};
  window.HTMLDialogElement.prototype.close=function(){this.removeAttribute('open')};
  const calls=[];
  const client={
    auth:{getSession:async()=>({data:{session:{user:{id:'synthetic'}}}}),onAuthStateChange:()=>({}),signOut:async()=>({error:null})},
    rpc:async(name,args)=>{
      calls.push({name,args});
      if(name==='get_own_privacy_settings') return {data:[{profile_visibility:'private',contact_permission:'friends'}],error:null};
      if(name==='get_own_onboarding_status')return {data:[{account_state:'active',eligibility_status:'eligible',policy_complete:true}],error:null};
      if(name==='list_current_required_policies'||name==='list_own_blocks')return {data:[],error:null};
      return {data:null,error:null};
    },
    from:()=>({select:()=>({order:()=>({limit:async()=>({data:[],error:null})})})})
  };
  window.__client=client;
  let source=await readFile(new URL('../src/main.js',import.meta.url),'utf8');
  source=source.replace("import './style.css';",'').replace("import { createClient } from '@supabase/supabase-js';",'const createClient=()=>window.__client;').replaceAll('import.meta.env.VITE_SUPABASE_URL',"'https://development.invalid'").replaceAll('import.meta.env.DEV','false').replaceAll('import.meta.env.VITE_ENABLE_SOCIAL_DRAFTS',"'false'").replaceAll('import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY',"'test-public-key'");
  window.eval(source);
  await wait();
  const form=window.document.querySelector('#privacy-form');
  assert.equal(form.hidden,false);
  assert.equal(form.elements.profile.value,'private');
  assert.equal(form.elements.contact.value,'friends');
  form.elements.profile.value='friends'; form.elements.contact.value='members';
  form.dispatchEvent(new window.Event('submit',{bubbles:true,cancelable:true}));
  await wait();
  const saved=calls.find(c=>c.name==='update_own_privacy_settings');
  assert.equal(saved.args.p_profile_visibility,'friends');
  assert.equal(saved.args.p_contact_permission,'members');
  assert.match(window.document.querySelector('#privacy-message').textContent,/saved/i);
  window.document.querySelector('#signout').click();
  await wait();
  assert.equal(window.document.querySelector('#privacy').hidden,true);
  assert.equal(form.hidden,true);
  assert.equal(window.document.querySelector('#privacy-message').textContent,'');
  dom.window.close();
});

test('late privacy response cannot redisplay settings after sign-out', async () => {
  const dom=new JSDOM('<!doctype html><div id="app"></div>',{url:'https://development.invalid/',runScripts:'outside-only'});
  const {window}=dom;
  window.HTMLDialogElement.prototype.showModal=function(){this.setAttribute('open','')};
  window.HTMLDialogElement.prototype.close=function(){this.removeAttribute('open')};
  let resolvePrivacy;
  window.__client={
    auth:{getSession:async()=>({data:{session:{user:{id:'synthetic'}}}}),onAuthStateChange:()=>({}),signOut:async()=>({error:null})},
    rpc:async(name)=>{
      if(name==='get_own_privacy_settings')return await new Promise(resolve=>{resolvePrivacy=resolve});
      if(name==='get_own_onboarding_status')return {data:[{account_state:'active',eligibility_status:'eligible',policy_complete:true}],error:null};
      if(name==='list_current_required_policies'||name==='list_own_blocks')return {data:[],error:null};
      return {data:null,error:null};
    },
    from:()=>({select:()=>({order:()=>({limit:async()=>({data:[],error:null})})})})
  };
  let source=await readFile(new URL('../src/main.js',import.meta.url),'utf8');
  source=source.replace("import './style.css';",'').replace("import { createClient } from '@supabase/supabase-js';",'const createClient=()=>window.__client;').replaceAll('import.meta.env.VITE_SUPABASE_URL',"'https://development.invalid'").replaceAll('import.meta.env.DEV','false').replaceAll('import.meta.env.VITE_ENABLE_SOCIAL_DRAFTS',"'false'").replaceAll('import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY',"'test-public-key'");
  window.eval(source);await wait();
  assert.equal(typeof resolvePrivacy,'function');
  window.document.querySelector('#signout').click();await wait();
  resolvePrivacy({data:[{profile_visibility:'public',contact_permission:'members'}],error:null});await wait();
  assert.equal(window.document.querySelector('#privacy').hidden,true);
  assert.equal(window.document.querySelector('#privacy-form').hidden,true);
  assert.equal(window.document.querySelector('#privacy-message').textContent,'');
  dom.window.close();
});
