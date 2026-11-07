import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {JSDOM} from 'jsdom';
const wait=()=>new Promise(r=>setTimeout(r,25));
test('communities screen shows safe LGA names and navigates tabs with one menu',async()=>{
 const dom=new JSDOM('<div id="app"></div>',{url:'https://dev.invalid',runScripts:'outside-only'}),w=dom.window;w.scrollTo=()=>{};w.HTMLDialogElement.prototype.showModal=function(){this.setAttribute('open','')};w.HTMLDialogElement.prototype.close=function(){this.removeAttribute('open')};
 const calls=[];w.__client={auth:{getSession:async()=>({data:{session:{user:{id:'test'}}}}),onAuthStateChange:()=>({}),signOut:async()=>({error:null})},rpc:async(name)=>{calls.push(name);if(name==='list_delta_lgas')return {data:[{id:'1',name:'Uvwie'},{id:'2',name:'<img src=x>'}],error:null};if(name==='get_own_lga')return {data:[{id:'1',name:'Uvwie'}],error:null};if(name==='get_own_onboarding_status')return {data:[{account_state:'pending',eligibility_status:'pending',policy_complete:false}],error:null};return {data:[],error:null}},from:()=>({select:()=>({maybeSingle:async()=>({data:{},error:null}),order:()=>({limit:async()=>({data:[],error:null})})})})};
 let s=await readFile(new URL('../src/main.js',import.meta.url),'utf8');s=s.replace("import './style.css';",'').replace("import { createClient } from '@supabase/supabase-js';",'const createClient=()=>window.__client;').replaceAll('import.meta.env.VITE_SUPABASE_URL',"'https://dev.invalid'").replaceAll('import.meta.env.MODE',"'production'").replaceAll('import.meta.env.DEV','false').replaceAll('import.meta.env.VITE_ENABLE_SOCIAL_DRAFTS',"'false'").replaceAll('import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY',"'public-test-key'");w.eval(s);await wait();
 w.document.querySelector('#nav-communities').click();await wait();assert.equal(w.document.querySelector('#community-screen').hidden,false);assert.equal(w.document.body.dataset.communityTab,'discover');assert.equal(w.document.querySelectorAll('.community-lga').length,2);assert.equal(w.document.querySelector('#community-lga-list img'),null);assert.equal(w.document.querySelector('.community-lga-label').textContent,'Your LGA');
 w.document.querySelector('[data-community-tab="groups"]').click();assert.equal(w.document.body.dataset.communityTab,'groups');assert.equal(w.document.querySelector('#community-discover').hidden,true);
 w.document.querySelector('[data-community-tab="invites"]').click();assert.equal(w.document.body.dataset.communityTab,'invites');
 w.document.querySelector('#nav-home').click();assert.equal(w.document.querySelector('#community-screen').hidden,true);assert.equal(w.document.querySelector('#community-lga-list').childElementCount,0);
 w.document.querySelector('#open-menu').click();w.document.querySelector('#menu-communities').click();await wait();assert.equal(w.document.querySelector('#community-screen').hidden,false);
 w.document.querySelector('#signout').click();await wait();assert.equal(w.document.querySelector('#community-screen').hidden,true);assert.equal(w.document.querySelector('#community-lga-list').childElementCount,0);dom.window.close();
});
