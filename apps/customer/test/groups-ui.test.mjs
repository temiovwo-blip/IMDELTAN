import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {JSDOM} from 'jsdom';
const wait=()=>new Promise(r=>setTimeout(r,25));
test('creating a private group uses the caller LGA and renders names safely',async()=>{
 const dom=new JSDOM('<!doctype html><div id="app"></div>',{url:'https://development.invalid/',runScripts:'outside-only'}),{window}=dom;
 window.confirm=()=>true;
 window.HTMLDialogElement.prototype.showModal=function(){this.setAttribute('open','')};window.HTMLDialogElement.prototype.close=function(){this.removeAttribute('open')};
 const calls=[];let groups=[];
 window.__client={auth:{getSession:async()=>({data:{session:{user:{id:'synthetic'}}}}),onAuthStateChange:()=>({}),signOut:async()=>({error:null})},
 rpc:async(name,args)=>{calls.push({name,args});
 if(name==='list_own_created_groups')return {data:groups,error:null};
 if(name==='find_group_invitee')return {data:[{user_id:'person-id',handle:'test_person',display_name:'<img src=x>'}],error:null};
 if(name==='invite_to_own_group')return {data:null,error:null};
 if(name==='update_own_group'){groups[0].name=args.p_name;groups[0].description=args.p_description;return {data:null,error:null}}
 if(name==='archive_own_group'){groups=[];return {data:null,error:null}}
 if(name==='create_group_in_own_lga'){groups=[{id:'id',lga_name:'Uvwie',name:args.p_name,description:args.p_description,created_at:'2026-01-01T00:00:00Z'}];return {data:'id',error:null}}
 if(name==='get_own_onboarding_status')return {data:[{account_state:'active',eligibility_status:'eligible',policy_complete:true}],error:null};
 if(name==='get_own_privacy_settings')return {data:[{profile_visibility:'private',contact_permission:'friends'}],error:null};
 if(name==='list_current_required_policies'||name==='list_own_blocks'||name==='list_delta_lgas'||name==='get_own_lga')return {data:[],error:null};return {data:null,error:null}},
 from:(table)=>table==='profiles'?{select:()=>({maybeSingle:async()=>({data:{handle:'test_user',display_name:'Test',biography:''},error:null})})}:{select:()=>({order:()=>({limit:async()=>({data:[],error:null})})})}};
 let source=await readFile(new URL('../src/main.js',import.meta.url),'utf8');source=source.replace("import './style.css';",'').replace("import { createClient } from '@supabase/supabase-js';",'const createClient=()=>window.__client;').replaceAll('import.meta.env.VITE_SUPABASE_URL',"'https://development.invalid'").replaceAll('import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY',"'test-public-key'");
 window.eval(source);await wait();const form=window.document.querySelector('#group-form');
 form.elements.name.value=' <img src=x> ';form.elements.description.value=' Local football ';
 form.dispatchEvent(new window.Event('submit',{bubbles:true,cancelable:true}));await wait();await wait();
 const call=calls.find(c=>c.name==='create_group_in_own_lga');assert.equal(call.args.p_name,'<img src=x>');assert.equal(call.args.p_description,'Local football');assert.equal(Object.hasOwn(call.args,'p_lga_id'),false);
 assert.equal(window.document.querySelector('#group-list img'),null);assert.match(window.document.querySelector('#group-list').textContent,/Uvwie · Private group/);
 const inviteButton=[...window.document.querySelectorAll('#group-list .note-action')].find(b=>b.textContent==='Invite');inviteButton.click();
 let inviteForm=window.document.querySelector('#group-list form');inviteForm.querySelector('input').value='TEST_PERSON';inviteForm.dispatchEvent(new window.Event('submit',{bubbles:true,cancelable:true}));await wait();
 assert.equal(calls.find(c=>c.name==='find_group_invitee').args.p_handle,'test_person');assert.equal(window.document.querySelector('#group-list img'),null);
 [...inviteForm.querySelectorAll('button')].find(b=>b.textContent==='Send invitation').click();await wait();assert.equal(calls.find(c=>c.name==='invite_to_own_group').args.p_invitee_id,'person-id');
 [...inviteForm.querySelectorAll('button')].find(b=>b.textContent==='Cancel').click();
 window.document.querySelector('#group-list .note-action').click();const edit=window.document.querySelector('#group-list form');edit.querySelector('input').value=' Updated group ';edit.querySelector('textarea').value=' New description ';
 edit.dispatchEvent(new window.Event('submit',{bubbles:true,cancelable:true}));await wait();await wait();
 const update=calls.find(c=>c.name==='update_own_group');assert.equal(update.args.p_group_id,'id');assert.equal(update.args.p_name,'Updated group');
 window.document.querySelector('#group-list .note-action.destructive').click();await wait();await wait();
 assert.equal(calls.find(c=>c.name==='archive_own_group').args.p_group_id,'id');assert.equal(window.document.querySelector('#group-list').children.length,0);
 window.document.querySelector('#signout').click();await wait();assert.equal(window.document.querySelector('#my-groups').hidden,true);assert.equal(window.document.querySelector('#group-list').children.length,0);
 dom.window.close();
});
