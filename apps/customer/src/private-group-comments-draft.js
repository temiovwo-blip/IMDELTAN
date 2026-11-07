// Local-only, opt-in private-group comments; never treat as launch-ready.
export function attachPrivateGroupCommentsDraft(article,post,client,currentUserId,isActive){
 const comments=document.createElement('button');comments.type='button';comments.className='note-action group-comments-toggle';comments.textContent='Comments';comments.setAttribute('aria-expanded','false');
 const note=document.createElement('span');note.className='group-comments-status';note.setAttribute('role','status');note.setAttribute('aria-live','polite');
 const panel=document.createElement('div');panel.className='group-comments';panel.hidden=true;article.append(comments,note,panel);
 let commentRequest=0;const alive=()=>isActive();
 async function loadComments(){
  const op=++commentRequest;panel.replaceChildren();note.textContent='Loading comments…';
  const container=document.createElement('div'),more=document.createElement('button');more.type='button';more.className='note-action group-comments-more';more.textContent='Load older comments';more.hidden=true;
  let cursor=null,loading=false;
   function renderRows(items){const fragment=document.createDocumentFragment();for(const comment of [...items].reverse()){
    const row=document.createElement('article');row.className='group-comment';const name=document.createElement('strong');name.textContent=comment.author_name;const body=document.createElement('p');body.textContent=comment.body;row.append(name);const marker=document.createElement('small');marker.className='comment-edited';marker.textContent=comment.edited_at?' · Edited':'';row.append(marker,body);
    if(comment.author_id===currentUserId){
     const edit=document.createElement('button');edit.type='button';edit.className='note-action group-comment-edit';edit.textContent='Edit comment';
     edit.addEventListener('click',()=>{if(!alive()||op!==commentRequest)return;edit.hidden=true;const form=document.createElement('form'),label=document.createElement('label'),field=document.createElement('textarea');label.textContent='Edit comment';field.required=true;field.maxLength=2000;field.value=comment.body;label.append(field);
      const save=document.createElement('button');save.type='submit';save.className='small-action';save.textContent='Save changes';const cancel=document.createElement('button');cancel.type='button';cancel.className='note-action';cancel.textContent='Cancel';cancel.addEventListener('click',()=>{form.remove();edit.hidden=false});
      form.addEventListener('submit',async e=>{e.preventDefault();const value=field.value.trim();if(!value||save.disabled)return;save.disabled=true;cancel.disabled=true;try{const result=await client.rpc('edit_own_private_group_post_comment',{p_comment_id:comment.id,p_body:value});if(!alive()||op!==commentRequest||!form.isConnected)return;if(result.error)throw result.error;comment.body=value;body.textContent=value;marker.textContent=' · Edited';form.remove();edit.hidden=false;note.textContent='Comment updated.'}catch{if(alive()&&op===commentRequest&&form.isConnected)note.textContent='Could not update the comment. It may be unavailable, restricted or temporarily limited.'}finally{save.disabled=false;cancel.disabled=false}});
      form.append(label,save,cancel);row.append(form);field.focus();
     });row.append(edit);const remove=document.createElement('button');remove.type='button';remove.className='note-action';remove.textContent='Delete comment';remove.addEventListener('click',async()=>{if(!window.confirm('Delete your comment? Reported content may be retained for moderation and data may remain in backups.'))return;remove.disabled=true;try{const result=await client.rpc('delete_own_private_group_post_comment',{p_comment_id:comment.id});if(!alive()||op!==commentRequest)return;if(result.error)throw result.error;await loadComments()}catch{if(alive()&&op===commentRequest)note.textContent='Could not delete comment.'}finally{remove.disabled=false}});row.append(remove)}
    if(comment.author_id!==currentUserId){
     const report=document.createElement('button');report.type='button';report.className='note-action group-comment-report';report.textContent='Report comment';
     report.addEventListener('click',()=>{
      report.hidden=true;const form=document.createElement('form'),description=document.createElement('p'),label=document.createElement('label'),reason=document.createElement('textarea');
      description.textContent='A moderator can see the reported comment and your reason.';label.textContent='Reason for reporting';reason.required=true;reason.maxLength=2000;reason.setAttribute('aria-label','Reason for reporting comment');label.append(reason);
      const send=document.createElement('button');send.type='submit';send.className='small-action';send.textContent='Send report';const cancel=document.createElement('button');cancel.type='button';cancel.className='note-action';cancel.textContent='Cancel';
      cancel.addEventListener('click',()=>{form.remove();report.hidden=false});
      form.addEventListener('submit',async e=>{e.preventDefault();const why=reason.value.trim();if(!why||send.disabled)return;send.disabled=true;
       try{const r=await client.rpc('report_private_group_post_comment',{p_comment_id:comment.id,p_reason:why});if(!alive()||op!==commentRequest)return;if(r.error)throw r.error;form.remove();report.hidden=false;note.textContent='Report submitted or already reported. It does not automatically remove the comment.'}
       catch{if(alive()&&op===commentRequest)note.textContent='Could not report comment.'}finally{send.disabled=false}
      });form.append(description,label,send,cancel);row.append(form);reason.focus();
     });row.append(report);
    }
    fragment.append(row);
   }return fragment;}

  async function loadPage(append=false){
   if(loading)return;loading=true;more.disabled=true;note.textContent='Loading comments…';
   try{const r=await client.rpc('list_private_group_post_comments',{p_post_id:post.id,p_before:append?cursor?.created_at:null,p_before_id:append?cursor?.id:null});if(!alive()||op!==commentRequest)return;if(r.error||!Array.isArray(r.data))throw r.error||new Error('Invalid comments');
    if(r.data.length===30&&(!r.data[29].created_at||!r.data[29].id))throw new Error('Invalid comment cursor');
    const fragment=renderRows(r.data);if(append)container.prepend(fragment);else container.replaceChildren(fragment);
    if(r.data.length)cursor=r.data[r.data.length-1];more.hidden=r.data.length<30;note.textContent='';
   }catch{if(alive()&&op===commentRequest)note.textContent='Comments are unavailable. Please try again.'}
   finally{loading=false;more.disabled=false}
  }
  more.addEventListener('click',()=>loadPage(true));
  const form=document.createElement('form'),field=document.createElement('textarea');field.maxLength=2000;field.required=true;field.setAttribute('aria-label','Write a comment');
  const submit=document.createElement('button');submit.type='submit';submit.className='small-action';submit.textContent='Comment';form.append(field,submit);
  form.addEventListener('submit',async e=>{e.preventDefault();const body=field.value.trim();if(!body||submit.disabled)return;submit.disabled=true;try{const result=await client.rpc('create_private_group_post_comment',{p_post_id:post.id,p_body:body});if(!alive()||op!==commentRequest)return;if(result.error)throw result.error;await loadComments()}catch{if(alive()&&op===commentRequest)note.textContent='Could not add comment.'}finally{submit.disabled=false}});
  panel.append(more,container,form);await loadPage();
 }
 comments.addEventListener('click',()=>{panel.hidden=!panel.hidden;comments.setAttribute('aria-expanded',String(!panel.hidden));if(!panel.hidden)loadComments();else{++commentRequest;panel.replaceChildren();note.textContent=''}});
}
