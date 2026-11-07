import test from 'node:test';
import assert from 'node:assert/strict';
import {JSDOM} from 'jsdom';
import {mountLgaFeedDraft} from '../src/lga-feed-draft.js';
const wait=()=>new Promise(r=>setTimeout(r,10));
test('draft feed renders text safely and creates/deletes only own post',async()=>{
 const dom=new JSDOM('<div id="root"></div>',{url:'https://example.invalid'});
 globalThis.document=dom.window.document;globalThis.window=dom.window;window.confirm=()=>true;
 let rows=[{id:'own',author_id:'me',author_name:'<img src=x>',body:'<script>bad()</script>',created_at:'2026-01-01T00:00:00Z'},{id:'other',author_id:'other',author_name:'Other',body:'Hello',created_at:'2026-01-01T00:00:00Z'}];const calls=[];
 const client={rpc:async(name,args)=>{calls.push({name,args});if(name==='list_lga_text_posts')return {data:rows,error:null};if(name==='create_lga_text_post'){rows.unshift({id:'new',author_id:'me',author_name:'Me',body:args.p_body,created_at:'2026-01-01T00:00:00Z'});return {data:'new',error:null}}if(name==='report_lga_text_post')return {data:'report',error:null};if(name==='delete_own_lga_text_post'){rows=rows.filter(r=>r.id!==args.p_post_id);return {data:null,error:null}}}};
 const root=document.querySelector('#root'),feed=mountLgaFeedDraft(root,client,'me');await wait();
 assert.equal(root.querySelectorAll('script,img').length,0);assert.equal(root.querySelectorAll('.destructive').length,1);
 root.querySelector('.lga-report').click();const reportForm=root.querySelector('.saved-note form');reportForm.querySelector('textarea').value=' Concerning ';reportForm.dispatchEvent(new window.Event('submit',{bubbles:true,cancelable:true}));await wait();assert.equal(calls.find(c=>c.name==='report_lga_text_post').args.p_reason,'Concerning');
 root.querySelector('textarea').value=' Hello community ';root.querySelector('form').dispatchEvent(new window.Event('submit',{bubbles:true,cancelable:true}));await wait();
 assert.equal(calls.find(c=>c.name==='create_lga_text_post').args.p_body,'Hello community');assert.equal(root.querySelectorAll('.destructive').length,2);
 root.querySelector('.destructive').click();await wait();assert.equal(calls.find(c=>c.name==='delete_own_lga_text_post').args.p_post_id,'new');
 feed.dispose();assert.equal(root.childElementCount,0);dom.window.close();delete globalThis.document;delete globalThis.window;
});

test('late feed responses do not restore content after disposal',async()=>{
 const dom=new JSDOM('<div id="root"></div>');globalThis.document=dom.window.document;globalThis.window=dom.window;
 let resolve;const client={rpc:()=>new Promise(r=>{resolve=r})};const root=document.querySelector('#root');const feed=mountLgaFeedDraft(root,client,'me');
 feed.dispose();resolve({data:[{id:'x',author_id:'me',author_name:'Private',body:'do not show'}],error:null});await wait();
 assert.equal(root.childElementCount,0);dom.window.close();delete globalThis.document;delete globalThis.window;
});
