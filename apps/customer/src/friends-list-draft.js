// Not mounted in the real app until safety and real-service testing is complete.
export function mountFriendsListDraft(root,client,onMessage,onFriendRemoved=()=>{}){
 let generation=0,cursor=null,disposed=false;
 root.innerHTML='<section class="friends-draft"><header><h1>Friends</h1><span>Development only</span></header><p>Friend requests and search are not yet connected. Messaging is not end-to-end encrypted.</p><p role="status" aria-live="polite"></p><div class="friends-list"></div><button type="button" class="friends-more" hidden>Load more</button></section>';
 const list=root.querySelector('.friends-list'),status=root.querySelector('[role=status]'),more=root.querySelector('.friends-more');
 async function load(append=false){
  const op=++generation;if(!append){cursor=null;list.replaceChildren()}more.hidden=true;status.textContent='Loading friends…';
  try{const r=await client.rpc('list_own_friends',{p_after:append?cursor:null});if(disposed||op!==generation)return;if(r.error||!Array.isArray(r.data))throw r.error||new Error('Invalid response');
   for(const friend of r.data){const row=document.createElement('article');row.className='friend-row';const icon=document.createElement('span');icon.className='friend-avatar';icon.textContent=String(friend.display_name||'C').slice(0,1).toUpperCase();const details=document.createElement('div'),name=document.createElement('strong');name.textContent=friend.display_name;details.append(name);if(friend.handle){const handle=document.createElement('small');handle.textContent=`@${friend.handle}`;details.append(handle)}
    const message=document.createElement('button');message.type='button';message.textContent='Message';message.addEventListener('click',()=>onMessage(friend.user_id,friend.display_name));
    const remove=document.createElement('button');remove.type='button';remove.textContent='Remove friend';remove.addEventListener('click',async()=>{
     if(!window.confirm('Remove this friend? Your conversation will no longer be available while you are not friends.'))return;
     const operation=generation;remove.disabled=true;
     try{const result=await client.rpc('remove_own_friend',{p_friend_id:friend.user_id});if(disposed||operation!==generation)return;if(result.error)throw result.error;onFriendRemoved(friend.user_id);await load()}
     catch{if(!disposed&&operation===generation)status.textContent='Could not remove this friend. Please try again.'}
     finally{remove.disabled=false}
    });row.append(icon,details,message,remove);list.append(row);
   }
   cursor=r.data.length?r.data[r.data.length-1].user_id:cursor;more.hidden=r.data.length<50;status.textContent=list.childElementCount?'':'No friends to show.';
  }catch{if(!disposed&&op===generation)status.textContent='Friends are unavailable. Please try again later.'}
 }
 more.addEventListener('click',()=>load(true));load();
 return {refresh:()=>load(),dispose:()=>{disposed=true;++generation;root.replaceChildren()}};
}
