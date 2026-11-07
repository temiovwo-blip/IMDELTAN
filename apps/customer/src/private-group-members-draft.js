// Local-only owner membership controls. The server enforces authorization.
export function mountPrivateGroupMembersDraft(card,client,groupId,isActive,onClose=()=>{}){
 const panel=document.createElement('section');panel.className='group-members-draft';const heading=document.createElement('h4');heading.textContent='Group members · Development';const details=document.createElement('p');details.textContent='Only currently eligible members who are not blocked and remain in this LGA are listed. Removing a member prevents automatic rejoining; their content is not erased.';const status=document.createElement('p');status.setAttribute('role','status');status.setAttribute('aria-live','polite');const list=document.createElement('div');const more=document.createElement('button');more.type='button';more.className='note-action group-members-more';more.textContent='Load older members';more.hidden=true;const close=document.createElement('button');close.type='button';close.className='note-action';close.textContent='Close members';panel.append(heading,details,status,list,more,close);card.append(panel);
 let generation=0,closed=false,loading=false,mutating=false,cursor=null;const alive=()=>!closed&&isActive()&&panel.isConnected;
 close.addEventListener('click',()=>{closed=true;++generation;panel.remove();onClose()});
 async function load(append=false){
  if(!alive()||loading||mutating)return;loading=true;const op=++generation;if(!append){cursor=null;list.replaceChildren()}more.disabled=true;status.textContent='Loading members…';
  try{const result=await client.rpc('list_own_private_group_members',{p_group_id:groupId,p_before:append?cursor?.joined_at:null,p_before_id:append?cursor?.user_id:null});if(!alive()||op!==generation)return;if(result.error||!Array.isArray(result.data))throw result.error||new Error('Invalid members');
   if(result.data.length===25&&(!result.data[24].joined_at||!result.data[24].user_id))throw new Error('Invalid member cursor');
   for(const member of result.data){const row=document.createElement('div');row.className='group-member-row';const name=document.createElement('span');name.textContent=member.display_name||'Community member';const remove=document.createElement('button');remove.type='button';remove.className='note-action destructive group-member-remove';remove.textContent='Remove member';remove.addEventListener('click',async()=>{
     if(!alive()||loading||mutating||remove.disabled||!window.confirm('Remove this member? They will lose group access and cannot automatically rejoin. Their content is not erased.'))return;mutating=true;more.disabled=true;remove.disabled=true;const action=generation;status.textContent='Removing member…';
     try{const result=await client.rpc('remove_own_private_group_member',{p_group_id:groupId,p_member_id:member.user_id});if(!alive()||action!==generation)return;if(result.error)throw result.error;row.remove();status.textContent='Member removed. An in-app notice was created; no push or email is sent.'}
     catch{if(alive()&&action===generation)status.textContent='Could not remove the member. They may be unavailable.'}finally{mutating=false;more.disabled=false;remove.disabled=false}
    });row.append(name,remove);list.append(row)}
   if(result.data.length)cursor=result.data[result.data.length-1];more.hidden=result.data.length<25;status.textContent=list.childElementCount?'':'No visible members.';
  }catch{if(alive()&&op===generation)status.textContent='Members are unavailable. Please try again.'}finally{loading=false;more.disabled=false}
 }
 more.addEventListener('click',()=>load(true));load();return {dispose:()=>{closed=true;++generation;panel.remove()}};
}
