import {attachPrivateGroupCommentsDraft} from './private-group-comments-draft.js';
import {attachPrivateGroupLikeDraft} from './private-group-like-draft.js';
import {attachPostEditDraft} from './post-edit-draft.js';
// Local-only opt-in draft. Never enable for real users without completing
// moderation, privacy, security and launch review.
export function mountPrivateGroupFeedDraft(root,client,groupId,currentUserId){
 let generation=0,disposed=false,cursor=null,loading=false;
 root.innerHTML='<section class="box private-group-feed"><h2>Group posts <small class="draft-label">Development</small></h2><p>Only eligible members can see this draft feed. This is a safety draft, not a production feature. Do not use real personal information.</p><form><label for="group-post-body">Share with this group</label><textarea id="group-post-body" maxlength="5000" required></textarea><button type="submit" class="small-action">Post</button></form><p class="group-feed-status" role="status" aria-live="polite"></p><div class="group-feed-list"></div><button type="button" class="note-action group-feed-more" hidden>Load older posts</button></section>';
 const form=root.querySelector('form'),field=form.querySelector('textarea'),status=root.querySelector('.group-feed-status'),list=root.querySelector('.group-feed-list'),more=root.querySelector('.group-feed-more');
 async function load(append=false){
  if(loading)return;loading=true;if(!append){++generation;cursor=null;list.replaceChildren()}const op=generation;more.disabled=true;status.textContent='Loading group posts…';
  try{const r=await client.rpc('list_private_group_text_posts',{p_group_id:groupId,p_before:append?cursor?.created_at:null,p_before_id:append?cursor?.id:null});if(disposed||op!==generation)return;if(r.error||!Array.isArray(r.data))throw r.error||new Error('Invalid response');
   if(r.data.length===20&&(!r.data[19].id||!r.data[19].created_at))throw new Error('Invalid cursor');
   const likeControls=new Map();for(const post of r.data){const card=document.createElement('article');card.className='saved-note';const author=document.createElement('strong');author.textContent=post.author_name;const text=document.createElement('p');text.className='note-text';text.textContent=post.body;card.append(author,text);
    if(post.author_id===currentUserId){attachPostEditDraft(card,client,'edit_own_private_group_text_post',post,text,()=>!disposed&&list.contains(card),status);const remove=document.createElement('button');remove.type='button';remove.className='note-action destructive';remove.textContent='Delete';remove.addEventListener('click',async()=>{if(loading||remove.disabled||!window.confirm('Delete your group post? Reported content may be retained for review and data may remain in backups.'))return;const action=generation;remove.disabled=true;try{const result=await client.rpc('delete_own_private_group_text_post',{p_post_id:post.id});if(disposed||action!==generation)return;if(result.error)throw result.error;await load()}catch{if(!disposed&&action===generation)status.textContent='Could not delete the post.'}finally{remove.disabled=false}});card.append(remove)}
    if(post.author_id!==currentUserId){if(post.edited_at){const mark=document.createElement('small');mark.className='post-edited';mark.textContent=' · Edited';text.before(mark)}const report=document.createElement('button');report.type='button';report.className='note-action private-group-report';report.textContent='Report';
     report.addEventListener('click',()=>{report.hidden=true;const review=document.createElement('form'),description=document.createElement('p'),label=document.createElement('label'),reason=document.createElement('textarea');description.textContent='A moderator can see the reported post and your reason.';label.textContent='Reason for reporting';reason.required=true;reason.maxLength=2000;label.append(reason);const send=document.createElement('button');send.type='submit';send.className='small-action';send.textContent='Send report';const cancel=document.createElement('button');cancel.type='button';cancel.className='note-action';cancel.textContent='Cancel';cancel.addEventListener('click',()=>{review.remove();report.hidden=false});
      review.addEventListener('submit',async e=>{e.preventDefault();const why=reason.value.trim();if(!why||send.disabled)return;send.disabled=true;try{const r=await client.rpc('report_private_group_text_post',{p_post_id:post.id,p_reason:why});if(disposed||op!==generation)return;if(r.error)throw r.error;review.remove();report.hidden=false;status.textContent='Report submitted or already reported. This does not automatically remove the post.'}catch{if(!disposed&&op===generation)status.textContent='Could not report the post.'}finally{send.disabled=false}});review.append(description,label,send,cancel);card.append(review);reason.focus();
     });card.append(report);
    }
    list.append(card);
    likeControls.set(post.id,attachPrivateGroupLikeDraft(card,client,post.id,()=>!disposed&&list.contains(card)));
    attachPrivateGroupCommentsDraft(card,post,client,currentUserId,()=>!disposed&&list.contains(card));
   }
   if(likeControls.size){
    Promise.resolve().then(()=>client.rpc('get_private_group_post_like_summaries',{p_post_ids:[...likeControls.keys()]})).then(result=>{
     if(disposed||op!==generation)return;if(result.error||!Array.isArray(result.data))throw result.error||new Error('Invalid summaries');
     const summaries=new Map(result.data.map(item=>[item.post_id,item]));for(const [id,control] of likeControls)control.applySummary(summaries.get(id));
    }).catch(()=>{if(!disposed&&op===generation)for(const control of likeControls.values())control.unavailable()});
   }
   if(r.data.length)cursor=r.data[r.data.length-1];more.hidden=r.data.length<20;status.textContent=list.childElementCount?'':'No group posts yet.';
  }catch{if(!disposed&&op===generation)status.textContent='Group posts are unavailable. Please try again later.'}finally{loading=false;more.disabled=false}
 }
 form.addEventListener('submit',async e=>{e.preventDefault();const body=field.value.trim(),button=form.querySelector('button'),op=generation;if(loading||!body||button.disabled)return;button.disabled=true;status.textContent='Posting…';try{const r=await client.rpc('create_private_group_text_post',{p_group_id:groupId,p_body:body});if(disposed||op!==generation)return;if(r.error)throw r.error;field.value='';await load()}catch{if(!disposed&&op===generation)status.textContent='Could not post. Please try again later.'}finally{button.disabled=false}});
 more.addEventListener('click',()=>load(true));load();return {refresh:()=>load(),dispose:()=>{disposed=true;++generation;root.replaceChildren()}};
}
