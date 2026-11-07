// Development-only inline editor. Server makes the final authorization decision.
export function attachPostEditDraft(card,client,rpcName,post,body,isActive,status){
 const marker=document.createElement('small');marker.className='post-edited';marker.textContent=post.edited_at?' · Edited':'';body.before(marker);
 const edit=document.createElement('button');edit.type='button';edit.className='note-action post-edit';edit.textContent='Edit';
 edit.addEventListener('click',()=>{
  if(!isActive())return;edit.hidden=true;const form=document.createElement('form'),label=document.createElement('label'),field=document.createElement('textarea');label.textContent='Edit post';field.required=true;field.maxLength=5000;field.value=post.body;label.append(field);
  const save=document.createElement('button');save.type='submit';save.className='small-action';save.textContent='Save changes';const cancel=document.createElement('button');cancel.type='button';cancel.className='note-action';cancel.textContent='Cancel';
  cancel.addEventListener('click',()=>{form.remove();edit.hidden=false});
  form.addEventListener('submit',async e=>{e.preventDefault();const value=field.value.trim();if(!value||save.disabled)return;save.disabled=true;cancel.disabled=true;try{const result=await client.rpc(rpcName,{p_post_id:post.id,p_body:value});if(!isActive()||!form.isConnected)return;if(result.error)throw result.error;post.body=value;body.textContent=value;marker.textContent=' · Edited';form.remove();edit.hidden=false;status.textContent='Post updated.'}catch{if(isActive()&&form.isConnected)status.textContent='Could not update the post. It may be unavailable, restricted or temporarily limited.'}finally{save.disabled=false;cancel.disabled=false}});
  form.append(label,save,cancel);card.append(form);field.focus();
 });card.append(edit);
}
