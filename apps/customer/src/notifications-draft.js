import {appendNoticeDismissDraft} from './notification-dismiss-draft.js';
import {mountGroupNotificationsDraft} from './group-notifications-draft.js';
import {mountGroupRemovalNotificationsDraft} from './group-removal-notifications-draft.js';
import {mountMessageNotificationsDraft} from './message-notifications-draft.js';
// Local-only in-app notices. Not push notifications.
export function mountNotificationsDraft(root,client,onOpenRequests=()=>{},onOpenMessages=()=>{},onOpenGroups=()=>{}){
 let disposed=false,generation=0,cursor=null,loading=false;
 root.innerHTML='<section class="notifications-draft"><h1>Notifications <small class="draft-label">Development</small></h1><p>In-app notices for friend requests, group invitations, membership changes and messages. Refresh to check for new activity; message text is not included.</p><button type="button" class="note-action notice-refresh">Refresh</button><p class="notice-status" role="status" aria-live="polite"></p><h2>Friend requests</h2><div class="notice-list"></div><button type="button" class="note-action notice-more" hidden>Load older</button><div class="message-notices-mount"></div><div class="group-notices-mount"></div><div class="group-removal-notices-mount"></div></section>';
 const messageNotices=mountMessageNotificationsDraft(root.querySelector('.message-notices-mount'),client,onOpenMessages);
 const groupNotices=mountGroupNotificationsDraft(root.querySelector('.group-notices-mount'),client,onOpenGroups);
 const removalNotices=mountGroupRemovalNotificationsDraft(root.querySelector('.group-removal-notices-mount'),client);
 const list=root.querySelector('.notice-list'),status=root.querySelector('.notice-status'),more=root.querySelector('.notice-more');
 async function load(append=false){
  if(loading)return;loading=true;if(!append){++generation;cursor=null;list.replaceChildren()}const op=generation;more.hidden=true;status.textContent='Loading notifications…';
  try{const r=await client.rpc('list_own_friend_request_notifications',{p_before:append?cursor?.created_at:null,p_before_id:append?cursor?.id:null});if(disposed||op!==generation)return;if(r.error||!Array.isArray(r.data))throw r.error||new Error('Invalid response');
   if(r.data.length===30&&(!r.data[29].created_at||!r.data[29].id))throw new Error('Invalid cursor');
   for(const n of r.data){const row=document.createElement('article');row.className='friend-request-row notice-row';const title=document.createElement('strong');title.textContent=n.read_at?'Friend request':'New friend request';const button=document.createElement('button');button.type='button';button.textContent='View requests';
    button.addEventListener('click',async()=>{if(button.disabled)return;button.disabled=true;try{const result=await client.rpc('mark_own_friend_request_notification_read',{p_notification_id:n.id});if(disposed||op!==generation)return;if(result.error)throw result.error;title.textContent='Friend request';onOpenRequests()}catch{if(!disposed&&op===generation)status.textContent='Could not open this notification. Please try again.'}finally{button.disabled=false}});row.append(title,button);appendNoticeDismissDraft(row,client,n.id,()=>!disposed&&op===generation,()=>{status.textContent='Notice cleared. The friend request is unchanged.'},()=>{status.textContent='Could not clear notice.'});list.append(row)}
   if(r.data.length)cursor=r.data[r.data.length-1];more.hidden=r.data.length<30;status.textContent=list.childElementCount?'':'No pending friend-request notifications.';
  }catch{if(!disposed&&op===generation)status.textContent='Notifications unavailable. Please try again.'}finally{loading=false}
 }
 root.querySelector('.notice-refresh').addEventListener('click',()=>{load();messageNotices.refresh();groupNotices.refresh();removalNotices.refresh()});more.addEventListener('click',()=>load(true));load();
 return {refresh:()=>{load();messageNotices.refresh();groupNotices.refresh();removalNotices.refresh()},dispose:()=>{disposed=true;++generation;messageNotices.dispose();groupNotices.dispose();removalNotices.dispose();root.replaceChildren()}};
}
