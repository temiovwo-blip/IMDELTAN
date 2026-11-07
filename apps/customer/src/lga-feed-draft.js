import {attachPostEditDraft} from './post-edit-draft.js';
import {attachLgaInteractionsDraft} from './lga-interactions-draft.js';
// Local-only draft. Not mounted in the application until feature/security review.
export function mountLgaFeedDraft(root,client,currentUserId){
  let request=0,cursor=null,disposed=false;
  root.innerHTML='<section class="box"><h2>Local government posts <small class="draft-label">Development</small></h2><p>Text posts here are visible to eligible members in your local government. Do not share personal information in development.</p><form><label for="lga-feed-body">Share with your local government</label><textarea id="lga-feed-body" maxlength="5000" required></textarea><button class="small-action" type="submit">Post</button></form><p role="status" aria-live="polite"></p><div class="lga-feed-list"></div><button class="note-action lga-feed-more" type="button" hidden>Load more</button></section>';
  const form=root.querySelector('form'),body=root.querySelector('textarea'),status=root.querySelector('[role=status]'),list=root.querySelector('.lga-feed-list'),more=root.querySelector('.lga-feed-more');
  async function load(append=false){
    const op=++request;if(!append){cursor=null;list.replaceChildren()}more.hidden=true;status.textContent='Loading local posts…';
    try{
      const result=await client.rpc('list_lga_text_posts',{p_before:append?cursor?.created_at:null,p_before_id:append?cursor?.id:null});
      if(disposed||op!==request)return;if(result.error||!Array.isArray(result.data))throw result.error||new Error('Invalid response');
      const likeControls=new Map();for(const post of result.data){
        const article=document.createElement('article');article.className='saved-note';
        const author=document.createElement('strong');author.textContent=post.author_name;
        const text=document.createElement('p');text.className='note-text';text.textContent=post.body;
        article.append(author,text);
        if(post.author_id===currentUserId){
          attachPostEditDraft(article,client,'edit_own_lga_text_post',post,text,()=>!disposed&&list.contains(article),status);
          const remove=document.createElement('button');remove.type='button';remove.className='note-action destructive';remove.textContent='Delete';
          remove.addEventListener('click',async()=>{
            if(!window.confirm('Delete your post? Reported content may be retained for moderation and data may remain in backups.'))return;const action=request;remove.disabled=true;
            try{const r=await client.rpc('delete_own_lga_text_post',{p_post_id:post.id});if(disposed||action!==request)return;if(r.error)throw r.error;await load()}
            catch{if(!disposed&&action===request)status.textContent='Could not delete the post. Please try again.'}
            finally{remove.disabled=false}
          });article.append(remove);
        }else{
          if(post.edited_at){const mark=document.createElement('small');mark.className='post-edited';mark.textContent=' · Edited';text.before(mark)}
          const report=document.createElement('button');report.type='button';report.className='note-action lga-report';report.textContent='Report';
          report.addEventListener('click',()=>{
            report.hidden=true;
            const review=document.createElement('form');
            const label=document.createElement('label');label.textContent='Why are you reporting this post?';
            const reason=document.createElement('textarea');reason.required=true;reason.maxLength=2000;reason.setAttribute('aria-label','Reason for reporting');
            const send=document.createElement('button');send.type='submit';send.className='small-action';send.textContent='Send report';
            const cancel=document.createElement('button');cancel.type='button';cancel.className='note-action';cancel.textContent='Cancel';
            cancel.addEventListener('click',()=>{review.remove();report.hidden=false});
            review.addEventListener('submit',async event=>{
              event.preventDefault();const value=reason.value.trim();if(!value)return;const action=request;send.disabled=true;
              try{const r=await client.rpc('report_lga_text_post',{p_post_id:post.id,p_reason:value});if(disposed||action!==request)return;if(r.error)throw r.error;review.remove();report.hidden=false;status.textContent='Report submitted or already reported. This does not automatically remove the post.'}
              catch{if(!disposed&&action===request)status.textContent='Could not send your report. Please try again later.'}
              finally{send.disabled=false}
            });
            label.append(reason);review.append(label,send,cancel);article.append(review);reason.focus();
          });article.append(report);
        }
        const save=document.createElement('button');save.type='button';save.className='note-action lga-save';save.textContent='Save';
        save.addEventListener('click',async()=>{if(save.disabled)return;const action=request;save.disabled=true;try{const result=await client.rpc('save_visible_lga_text_post',{p_post_id:post.id});if(disposed||action!==request)return;if(result.error)throw result.error;status.textContent='Saved privately. You can find this in Saved.'}catch{if(!disposed&&action===request)status.textContent='Could not save the post. It may be unavailable or your saved list may be full.'}finally{save.disabled=false}});article.append(save);
        list.append(article);
        likeControls.set(post.id,attachLgaInteractionsDraft(article,post,client,currentUserId,true));
      }
      if(likeControls.size){
        Promise.resolve().then(()=>client.rpc('get_lga_post_like_summaries',{p_post_ids:[...likeControls.keys()]})).then(result=>{
          if(disposed)return;if(result.error||!Array.isArray(result.data))throw result.error||new Error('Invalid summaries');
          const summaries=new Map(result.data.map(item=>[item.post_id,item]));for(const [id,control] of likeControls)control.applySummary(summaries.get(id));
        }).catch(()=>{if(!disposed)for(const control of likeControls.values())control.unavailable()});
      }
      cursor=result.data.length?result.data[result.data.length-1]:cursor;more.hidden=result.data.length<20;status.textContent=list.childElementCount?'':'No posts yet.';
    }catch{if(!disposed&&op===request)status.textContent='Local posts are unavailable. Complete account setup or try again later.'}
  }
  form.addEventListener('submit',async event=>{
    event.preventDefault();const text=body.value.trim(),button=form.querySelector('button');if(!text||button.disabled)return;const op=request;button.disabled=true;status.textContent='Posting…';
    try{const result=await client.rpc('create_lga_text_post',{p_body:text});if(disposed||op!==request)return;if(result.error)throw result.error;body.value='';await load()}
    catch{if(!disposed&&op===request)status.textContent='Could not post. Please try again later.'}
    finally{button.disabled=false}
  });
  more.addEventListener('click',()=>load(true));
  load();
  return {refresh:()=>load(),dispose:()=>{disposed=true;++request;root.replaceChildren()}};
}
