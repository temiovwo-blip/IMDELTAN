import test from 'node:test';import assert from 'node:assert/strict';import {JSDOM} from 'jsdom';import {mountNotificationsDraft} from '../src/notifications-draft.js';
const wait=()=>new Promise(r=>setTimeout(r,15));
test('local notification opens pending requests and clears on disposal',async()=>{
 const dom=new JSDOM('<div id="root"></div>');globalThis.document=dom.window.document;const calls=[];let opened=0;const client={rpc:async(name,args)=>{calls.push({name,args});return name==='list_own_friend_request_notifications'?{data:[{id:'n1',request_id:'r1',created_at:'2026-01-01T00:00:00Z',read_at:null}],error:null}:{error:null}}};
 const root=document.querySelector('#root'),view=mountNotificationsDraft(root,client,()=>opened++);await wait();assert.match(root.textContent,/New friend request/);root.querySelector('.notice-row button').click();await wait();assert.equal(calls.find(c=>c.name==='mark_own_friend_request_notification_read').args.p_notification_id,'n1');assert.equal(opened,1);view.dispose();assert.equal(root.childElementCount,0);dom.window.close();delete globalThis.document;
});
test('late notification responses cannot repopulate disposed view',async()=>{
 const dom=new JSDOM('<div id="root"></div>');globalThis.document=dom.window.document;let resolve;const client={rpc:()=>new Promise(r=>{resolve=r})};const root=document.querySelector('#root'),view=mountNotificationsDraft(root,client);view.dispose();resolve({data:[{id:'late'}],error:null});await wait();assert.equal(root.childElementCount,0);dom.window.close();delete globalThis.document;
});
