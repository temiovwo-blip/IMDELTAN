import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {JSDOM} from 'jsdom';
const wait=()=>new Promise(resolve=>setTimeout(resolve,25));

test('note text is not HTML, and edit and delete call self-only operations',async()=>{
  const dom=new JSDOM('<!doctype html><div id="app"></div>',{url:'https://development.invalid/',runScripts:'outside-only'});
  const {window}=dom;
  window.HTMLDialogElement.prototype.showModal=function(){this.setAttribute('open','')};
  window.HTMLDialogElement.prototype.close=function(){this.removeAttribute('open')};
  window.confirm=()=>true;
  let note={id:'synthetic-id',body:'<img src=x onerror=alert(1)>'};const calls=[];
  window.__client={
    auth:{getSession:async()=>({data:{session:{user:{id:'synthetic'}}}}),onAuthStateChange:()=>({})},
    rpc:async(name,args)=>{
      calls.push({name,args});
      if(name==='edit_own_private_text_post')note.body=args.p_body;
      if(name==='delete_own_private_text_post')note=null;
      if(name==='get_own_onboarding_status')return {data:[{account_state:'active',eligibility_status:'eligible',policy_complete:true}],error:null};
      if(name==='list_current_required_policies'||name==='list_own_blocks')return {data:[],error:null};
      if(name==='get_own_privacy_settings')return {data:[{profile_visibility:'private',contact_permission:'friends'}],error:null};
      return {data:null,error:null};
    },
    from:()=>({select:()=>({order:()=>({limit:async()=>({data:note?[{...note}]:[],error:null})})})})
  };
  let source=await readFile(new URL('../src/main.js',import.meta.url),'utf8');
  source=source.replace("import './style.css';",'').replace("import { createClient } from '@supabase/supabase-js';",'const createClient=()=>window.__client;').replaceAll('import.meta.env.VITE_SUPABASE_URL',"'https://development.invalid'").replaceAll('import.meta.env.MODE',"'production'").replaceAll('import.meta.env.DEV','false').replaceAll('import.meta.env.VITE_ENABLE_SOCIAL_DRAFTS',"'false'").replaceAll('import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY',"'test-public-key'");
  window.eval(source);await wait();
  assert.equal(window.document.querySelector('#post-list img'),null);
  assert.equal(window.document.querySelector('.note-text').textContent,'<img src=x onerror=alert(1)>');
  window.document.querySelector('.saved-note .note-action').click();
  const editor=window.document.querySelector('.saved-note form');editor.querySelector('textarea').value=' Changed ';
  editor.dispatchEvent(new window.Event('submit',{bubbles:true,cancelable:true}));await wait();
  const edit=calls.find(c=>c.name==='edit_own_private_text_post');assert.equal(edit.args.p_post_id,'synthetic-id');assert.equal(edit.args.p_body,'Changed');
  assert.equal(window.document.querySelector('.note-text').textContent,'Changed');
  window.document.querySelector('.note-action.destructive').click();await wait();
  assert.equal(calls.find(c=>c.name==='delete_own_private_text_post').args.p_post_id,'synthetic-id');
  assert.equal(window.document.querySelectorAll('.saved-note').length,0);
  dom.window.close();
});
