import {appendNoticeDismissDraft} from './notification-dismiss-draft.js';
// Development-only, generic in-app group invitation notices.
export function mountGroupNotificationsDraft(root,client,onOpen=()=>{}){
 let disposed=false,epoch=0,cursor=null,loading=false;
 root.innerHTML='<section class="group-notices"><h2>Group invitations</h2><p class="group-notices-status" role="status" aria-live="polite"></p><div class="group-notices-list"></div><button type="button" class="note-action group-notices-more" hidden>Load older invitation notices</button></section>';
 const status=root.querySelector('.group-notices-status'),list=root.querySelector('.group-notices-list'),more=root.querySelector('.group-notices-more');
 async function load(append=false){
  if(loading)return;loading=true;if(!append){++epoch;cursor=null;list.replaceChildren()}const op=epoch;more.disabled=true;status.textContent='Loading invitation notices…';
  try{const r=await client.rpc('list_own_group_invitation_notifications',{p_before:append?cursor?.created_at:null,p_before_id:append?cursor?.id:null});if(disposed||op!==epoch)return;if(r.error||!Array.isArray(r.data))throw r.error||new Error('Invalid response');
   if(r.data.length===30&&(!r.data[29].created_at||!r.data[29].id))throw new Error('Invalid cursor');
   for(const n of r.data){const row=document.createElement('article');row.className='friend-request-row group-notice-row';const label=document.createElement('strong');label.textContent=n.read_at?'Group invitation':'New group invitation';const button=document.createElement('button');button.type='button';button.textContent='View invitations';
    button.addEventListener('click',async()=>{if(button.disabled)return;button.disabled=true;try{const result=await client.rpc('mark_own_group_invitation_notification_read',{p_notification_id:n.id});if(disposed||op!==epoch)return;if(result.error)throw result.error;label.textContent='Group invitation';onOpen()}catch{if(!disposed&&op===epoch)status.textContent='Could not open this notice. Please try again.'}finally{button.disabled=false}});row.append(label,button);appendNoticeDismissDraft(row,client,n.id,()=>!disposed&&op===epoch,()=>{status.textContent='Notice cleared. The invitation is unchanged.'},()=>{status.textContent='Could not clear notice.'});list.append(row);
   }
   if(r.data.length)cursor=r.data[r.data.length-1];more.hidden=r.data.length<30;status.textContent=list.childElementCount?'':'No pending group invitation notices.';
  }catch{if(!disposed&&op===epoch)status.textContent='Group invitation notices unavailable. Please try again.'}finally{loading=false;more.disabled=false}
 }
 more.addEventListener('click',()=>load(true));load();return {refresh:()=>load(),dispose:()=>{disposed=true;++epoch;root.replaceChildren()}};
}
