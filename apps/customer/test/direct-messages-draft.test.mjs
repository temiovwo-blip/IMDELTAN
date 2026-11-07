import test from 'node:test';import assert from 'node:assert/strict';import {JSDOM} from 'jsdom';import {mountDirectMessagesDraft} from '../src/direct-messages-draft.js';
const wait=()=>new Promise(r=>setTimeout(r,10));
test('message draft shows safe text, sends to selected thread and clears on dispose',async()=>{
 const dom=new JSDOM('<div id="root"></div>');globalThis.document=dom.window.document;const root=document.querySelector('#root');const calls=[];let messages=[{id:'m1',sender_id:'other',body:'<img src=x onerror=alert(1)>',created_at:'2026-01-01'}];
 const client={rpc:async(name,args)=>{calls.push({name,args});if(name==='list_friend_conversations')return {data:[{conversation_id:'c1',friend_name:'<svg onload=bad()>'}],error:null};if(name==='list_friend_messages')return {data:messages,error:null};if(name==='send_friend_message'){messages=[{id:'m2',sender_id:'me',body:args.p_body},...messages];return {data:'m2',error:null}}}};
 const app=mountDirectMessagesDraft(root,client,'me');await wait();assert.equal(root.querySelector('svg'),null);root.querySelector('.conversation-row').click();await wait();assert.equal(root.querySelector('.messages-content img'),null);assert.equal(root.querySelector('.message-bubble').textContent,'<img src=x onerror=alert(1)>');
 root.querySelector('textarea').value=' Hello ';root.querySelector('form').dispatchEvent(new dom.window.Event('submit',{bubbles:true,cancelable:true}));await wait();assert.equal(calls.find(c=>c.name==='send_friend_message').args.p_conversation_id,'c1');assert.equal(calls.find(c=>c.name==='send_friend_message').args.p_body,'Hello');assert.equal(root.querySelectorAll('.message-bubble').length,2);
 app.dispose();assert.equal(root.childElementCount,0);dom.window.close();delete globalThis.document;
});
