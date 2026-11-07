import {mountBlockedMessageSafetyDraft} from './blocked-message-safety-draft.js';
// Local-only draft: explicitly not end-to-end encrypted; do not mount for real users.
export function mountDirectMessagesDraft(root,client,currentUserId){
 let generation=0,threadId=null,disposed=false,safety=null;
 root.innerHTML='<section class="messages-draft"><header class="messages-heading"><h1>Messages</h1><span>Development only</span></header><p class="messages-disclaimer">Text-only draft. Messages are not end-to-end encrypted. Do not use real private information.</p><p class="messages-status" role="status" aria-live="polite"></p><button type="button" class="note-action messages-safety-open">Report a message after blocking</button><div class="messages-safety" hidden></div><div class="messages-list"></div><section class="messages-thread" hidden><button type="button" class="messages-back">← Conversations</button><h2 class="messages-name"></h2><button type="button" class="note-action messages-more" hidden>Load older messages</button><div class="messages-content"></div><form><label for="direct-message-text">Message</label><textarea id="direct-message-text" maxlength="5000" required></textarea><button type="submit">Send</button></form></section></section>';
 const safetyRoot=root.querySelector('.messages-safety'),safetyOpen=root.querySelector('.messages-safety-open');
 const list=root.querySelector('.messages-list'),status=root.querySelector('.messages-status'),thread=root.querySelector('.messages-thread'),content=root.querySelector('.messages-content'),name=root.querySelector('.messages-name'),more=root.querySelector('.messages-more'),form=root.querySelector('form'),field=form.querySelector('textarea');
 async function loadList(){
  const op=++generation;if(safety){safety.dispose();safety=null}safetyRoot.hidden=true;safetyOpen.hidden=false;threadId=null;thread.hidden=true;content.replaceChildren();name.textContent='';field.value='';more.hidden=true;list.hidden=false;list.replaceChildren();status.textContent='Loading conversations…';
  try{const r=await client.rpc('list_friend_conversations');if(disposed||op!==generation)return;if(r.error||!Array.isArray(r.data))throw r.error||new Error('Invalid response');
   for(const c of r.data){const button=document.createElement('button');button.type='button';button.className='conversation-row';const icon=document.createElement('span');icon.className='conversation-avatar';icon.textContent=String(c.friend_name||'C').slice(0,1).toUpperCase();const label=document.createElement('span');label.textContent=c.friend_name;button.append(icon,label);button.addEventListener('click',()=>openThread(c.conversation_id,c.friend_name));list.append(button)}
   status.textContent=r.data.length?'':'No conversations yet. Start one from your friends list.';
  }catch{if(!disposed&&op===generation)status.textContent='Conversations are unavailable. Please try again later.'}
 }
 async function openThread(id,displayName){
  const op=++generation;if(safety){safety.dispose();safety=null}safetyRoot.hidden=true;safetyOpen.hidden=true;threadId=id;list.hidden=true;thread.hidden=false;content.replaceChildren();name.textContent=displayName;field.value='';more.hidden=true;status.textContent='Loading messages…';
  let cursor=null,loading=false;
   function render(items){const fragment=document.createDocumentFragment();for(const m of [...items].reverse()){
    const row=document.createElement('div');row.className=m.sender_id===currentUserId?'message-row own-message':'message-row';const bubble=document.createElement('p');bubble.className=m.sender_id===currentUserId?'message-bubble own':'message-bubble';bubble.textContent=m.body;row.append(bubble);
    if(m.sender_id===currentUserId){const hide=document.createElement('button');hide.type='button';hide.className='note-action message-hide';hide.textContent='Remove message';
     hide.addEventListener('click',async()=>{if(hide.disabled||!window.confirm('Remove this message from the conversation? It may still be retained and available for safety reporting. This is not permanent erasure.'))return;hide.disabled=true;
      try{const result=await client.rpc('hide_own_friend_message',{p_message_id:m.id});if(disposed||op!==generation)return;if(result.error)throw result.error;row.remove();status.textContent='Message removed from the conversation. It may still be retained for safety review.'}
      catch{if(!disposed&&op===generation)status.textContent='Could not remove the message. Please try again.'}finally{hide.disabled=false}
     });row.append(hide);
    }
    if(m.sender_id!==currentUserId){const report=document.createElement('button');report.type='button';report.className='note-action message-report';report.textContent='Report message';
     report.addEventListener('click',()=>{report.hidden=true;const review=document.createElement('form'),explanation=document.createElement('p'),label=document.createElement('label'),reason=document.createElement('textarea');
      explanation.textContent='A moderator can see this message and your reason. Other messages are not included in this report.';label.textContent='Reason for reporting';reason.required=true;reason.maxLength=2000;label.append(reason);
      const submit=document.createElement('button');submit.type='submit';submit.className='small-action';submit.textContent='Send report';const cancel=document.createElement('button');cancel.type='button';cancel.className='note-action';cancel.textContent='Cancel';
      cancel.addEventListener('click',()=>{review.remove();report.hidden=false});review.addEventListener('submit',async e=>{e.preventDefault();const why=reason.value.trim();if(!why||submit.disabled)return;submit.disabled=true;
       try{const result=await client.rpc('report_received_friend_message',{p_message_id:m.id,p_reason:why});if(disposed||op!==generation)return;if(result.error)throw result.error;review.remove();report.hidden=false;status.textContent='Report submitted or already reported. This does not automatically remove the message.'}
       catch{if(!disposed&&op===generation)status.textContent='Could not report the message. Please try again.'}finally{submit.disabled=false}
      });review.append(explanation,label,submit,cancel);row.append(review);reason.focus();
     });row.append(report)}fragment.append(row);
   }return fragment;}

  async function loadPage(append=false){
   if(loading)return;loading=true;more.disabled=true;status.textContent='Loading messages…';
   try{const r=await client.rpc('list_friend_messages',{p_conversation_id:id,p_before:append?cursor?.created_at:null,p_before_id:append?cursor?.id:null});if(disposed||op!==generation)return;if(r.error||!Array.isArray(r.data))throw r.error||new Error('Invalid response');
    if(r.data.length===50&&(!r.data[49].id||!r.data[49].created_at))throw new Error('Invalid cursor');
    const fragment=render(r.data);if(append)content.prepend(fragment);else content.replaceChildren(fragment);
    if(r.data.length)cursor=r.data[r.data.length-1];more.hidden=r.data.length<50;status.textContent=content.childElementCount?'':'No messages yet.';
   }catch{if(!disposed&&op===generation)status.textContent='Messages are unavailable. Please try again later.'}finally{loading=false;more.disabled=false}
  }
  more.onclick=()=>loadPage(true);await loadPage();
 }
 form.addEventListener('submit',async e=>{
  e.preventDefault();const text=field.value.trim(),id=threadId,op=generation,button=form.querySelector('button');if(!id||!text||button.disabled)return;button.disabled=true;status.textContent='Sending…';
  try{const r=await client.rpc('send_friend_message',{p_conversation_id:id,p_body:text});if(disposed||op!==generation)return;if(r.error)throw r.error;field.value='';await openThread(id,name.textContent)}
  catch{if(!disposed&&op===generation)status.textContent='Could not send. Check contact settings or try again later.'}
  finally{button.disabled=false}
 });
 root.querySelector('.messages-back').addEventListener('click',loadList);
 safetyOpen.addEventListener('click',()=>{++generation;threadId=null;content.replaceChildren();name.textContent='';field.value='';more.hidden=true;list.hidden=true;thread.hidden=true;safetyOpen.hidden=true;safetyRoot.hidden=false;status.textContent='';safety=mountBlockedMessageSafetyDraft(safetyRoot,client,loadList)});
 loadList();
 async function openFriend(friendId,displayName){
  const op=++generation;if(safety){safety.dispose();safety=null}safetyRoot.hidden=true;safetyOpen.hidden=true;threadId=null;content.replaceChildren();name.textContent='';field.value='';more.hidden=true;list.hidden=true;thread.hidden=true;status.textContent='Opening conversation…';
  try{const r=await client.rpc('start_friend_conversation',{p_friend_id:friendId});if(disposed||op!==generation)return;if(r.error||!r.data)throw r.error||new Error('Conversation unavailable');await openThread(r.data,displayName)}
  catch{if(!disposed&&op===generation)status.textContent='Unable to start a conversation. Check contact settings or try again later.'}
 }
 return {refresh:loadList,openFriend,openConversation:id=>openThread(id,'Conversation'),dispose:()=>{disposed=true;++generation;threadId=null;if(safety)safety.dispose();root.replaceChildren()}};
}
