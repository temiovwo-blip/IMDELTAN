// Development-only, deliberately opened by the user. Never displays outgoing
// messages, never enables sending, and never automatically reports anything.
export function mountBlockedMessageSafetyDraft(root,client,onBack=()=>{}){
 let disposed=false,epoch=0,cursor=null,loading=false;
 root.innerHTML='<section class="blocked-message-safety"><button type="button" class="note-action safety-back">← Conversations</button><h2>Report a message after blocking</h2><p>These are messages you received from accounts you blocked, including messages the sender removed from the conversation. This does not reopen a conversation or unblock anyone. Some messages may be upsetting.</p><button type="button" class="note-action safety-refresh">Refresh</button><p class="safety-status" role="status" aria-live="polite"></p><div class="safety-list"></div><button type="button" class="note-action safety-more" hidden>Load older messages</button></section>';
 const status=root.querySelector('.safety-status'),list=root.querySelector('.safety-list'),more=root.querySelector('.safety-more');
 async function load(append=false){
  if(loading)return;loading=true;if(!append){++epoch;cursor=null;list.replaceChildren()}const op=epoch;more.disabled=true;status.textContent='Loading received messages…';
  try{const r=await client.rpc('list_own_blocked_received_messages',{p_before:append?cursor?.created_at:null,p_before_id:append?cursor?.id:null});if(disposed||op!==epoch)return;if(r.error||!Array.isArray(r.data))throw r.error||new Error('Invalid response');
   if(r.data.length===30&&(!r.data[29].created_at||!r.data[29].id))throw new Error('Invalid cursor');
   for(const message of r.data){const row=document.createElement('article');row.className='safety-message';const text=document.createElement('p');text.className='message-bubble';text.textContent=message.body;const report=document.createElement('button');report.type='button';report.className='note-action safety-report';report.textContent='Report message';
    report.addEventListener('click',()=>{report.hidden=true;const form=document.createElement('form'),notice=document.createElement('p'),label=document.createElement('label'),reason=document.createElement('textarea');notice.textContent='A moderator can see this message and your reason. Other messages are not included in this report.';label.textContent='Reason for reporting';reason.maxLength=2000;reason.required=true;label.append(reason);
     const send=document.createElement('button');send.type='submit';send.className='small-action';send.textContent='Send report';const cancel=document.createElement('button');cancel.type='button';cancel.className='note-action';cancel.textContent='Cancel';cancel.addEventListener('click',()=>{form.remove();report.hidden=false});
     form.addEventListener('submit',async e=>{e.preventDefault();const why=reason.value.trim();if(!why||send.disabled)return;send.disabled=true;
      try{const result=await client.rpc('report_received_friend_message',{p_message_id:message.id,p_reason:why});if(disposed||op!==epoch)return;if(result.error)throw result.error;form.remove();report.hidden=false;status.textContent='Report submitted or already reported. This does not automatically remove the message.'}catch{if(!disposed&&op===epoch)status.textContent='Could not report the message. Please try again.'}finally{send.disabled=false}
     });form.append(notice,label,send,cancel);row.append(form);reason.focus();
    });row.append(text,report);list.append(row);
   }
   if(r.data.length)cursor=r.data[r.data.length-1];more.hidden=r.data.length<30;status.textContent=list.childElementCount?'':'No received messages from accounts you have blocked.';
  }catch{if(!disposed&&op===epoch)status.textContent='Safety view unavailable. Please try again.'}finally{loading=false;more.disabled=false}
 }
 root.querySelector('.safety-back').addEventListener('click',onBack);root.querySelector('.safety-refresh').addEventListener('click',()=>load());more.addEventListener('click',()=>load(true));load();
 return {dispose:()=>{disposed=true;++epoch;root.replaceChildren()}};
}
