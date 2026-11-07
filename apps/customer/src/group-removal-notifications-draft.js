import {appendNoticeDismissDraft} from './notification-dismiss-draft.js';
// Local-only manual-refresh notices. No push/email, reason or appeal flow.
export function mountGroupRemovalNotificationsDraft(root,client){
 let disposed=false,generation=0,cursor=null,loading=false;
 root.innerHTML='<section class="group-removal-notices"><h2>Group membership changes</h2><p>A group owner may remove a member. This notice does not include a reason or an appeal process.</p><p class="group-removal-status" role="status" aria-live="polite"></p><div class="group-removal-list"></div><button type="button" class="note-action group-removal-more" hidden>Load older membership notices</button></section>';
 const status=root.querySelector('.group-removal-status'),list=root.querySelector('.group-removal-list'),more=root.querySelector('.group-removal-more');
 async function load(append=false){
  if(loading)return;loading=true;if(!append){++generation;cursor=null;list.replaceChildren()}const op=generation;more.disabled=true;status.textContent='Loading membership notices…';
  try{const r=await client.rpc('list_own_group_removal_notifications',{p_before:append?cursor?.created_at:null,p_before_id:append?cursor?.id:null});if(disposed||op!==generation)return;if(r.error||!Array.isArray(r.data))throw r.error||new Error('Invalid notices');
   if(r.data.length===30&&(!r.data[29].created_at||!r.data[29].id))throw new Error('Invalid cursor');
   for(const notice of r.data){const row=document.createElement('article');row.className='friend-request-row group-removal-notice';const title=document.createElement('strong');title.textContent=notice.read_at?'Group membership removed':'New group membership removal';const detail=document.createElement('span');detail.textContent=notice.group_name?`Group: ${notice.group_name}`:'Group details unavailable';const read=document.createElement('button');read.type='button';read.className='note-action group-removal-read';read.textContent='Mark read';read.disabled=Boolean(notice.read_at);
    read.addEventListener('click',async()=>{if(read.disabled)return;read.disabled=true;try{const result=await client.rpc('mark_own_group_removal_notification_read',{p_notification_id:notice.id});if(disposed||op!==generation)return;if(result.error)throw result.error;title.textContent='Group membership removed';read.remove()}catch{if(!disposed&&op===generation){status.textContent='Could not mark this notice as read.';read.disabled=false}}});
    row.append(title,detail,read);appendNoticeDismissDraft(row,client,notice.id,()=>!disposed&&op===generation,()=>{status.textContent='Notice cleared. Membership is unchanged.'},()=>{status.textContent='Could not clear notice.'});
    // A previously read notice still needs to remain dismissible.
    if(notice.read_at)read.remove();list.append(row);
   }
   if(r.data.length)cursor=r.data[r.data.length-1];more.hidden=r.data.length<30;status.textContent=list.childElementCount?'':'No group membership notices.';
  }catch{if(!disposed&&op===generation)status.textContent='Membership notices unavailable. Please try again.'}finally{loading=false;more.disabled=false}
 }
 more.addEventListener('click',()=>load(true));load();return {refresh:()=>load(),dispose:()=>{disposed=true;++generation;root.replaceChildren()}};
}
