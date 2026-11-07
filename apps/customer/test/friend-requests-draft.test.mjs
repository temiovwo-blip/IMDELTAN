import test from 'node:test';import assert from 'node:assert/strict';import {JSDOM} from 'jsdom';import {mountFriendRequestsDraft} from '../src/friend-requests-draft.js';
const wait=()=>new Promise(r=>setTimeout(r,15));
test('friend request draft performs exact lookup, safe display and acceptance',async()=>{
 const dom=new JSDOM('<div id="root"></div>');globalThis.document=dom.window.document;const calls=[];let pending=[{id:'r1',direction:'received',other_user_id:'u2',other_name:'<img src=x>',created_at:'2026-01-01'}],changed=0;
 const client={rpc:async(name,args)=>{calls.push({name,args});if(name==='list_own_friend_requests_display')return {data:pending,error:null};if(name==='find_friend_by_handle')return {data:[{user_id:'u3',handle:'example',display_name:'<script>bad()</script>'}],error:null};if(name==='respond_friend_request'){pending=[];return {error:null}}return {error:null}}};
 const root=document.querySelector('#root'),app=mountFriendRequestsDraft(root,client,()=>changed++);await wait();assert.equal(root.querySelector('img'),null);assert.equal(root.querySelector('.friend-request-row strong').textContent,'<img src=x>');
 root.querySelector('input').value='EXAMPLE';root.querySelector('form').dispatchEvent(new dom.window.Event('submit',{bubbles:true,cancelable:true}));await wait();assert.equal(calls.find(x=>x.name==='find_friend_by_handle').args.p_handle,'example');assert.equal(root.querySelector('.friend-search-results script'),null);
 root.querySelector('.friend-result button').click();await wait();assert.equal(calls.find(x=>x.name==='send_friend_request').args.p_target_id,'u3');root.querySelector('.friend-request-row button').click();await wait();assert.equal(calls.find(x=>x.name==='respond_friend_request').args.p_accept,true);assert.equal(changed,1);assert.equal(root.querySelectorAll('.friend-request-row').length,0);
 app.dispose();dom.window.close();delete globalThis.document;
});
