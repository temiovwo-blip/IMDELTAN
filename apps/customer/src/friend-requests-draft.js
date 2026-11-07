// Local-only draft: not mounted or deployed for real users.
export function mountFriendRequestsDraft(root,client,onChanged=()=>{}){
 let generation=0,cursor=null,disposed=false;
 root.innerHTML='<section class="friend-requests-draft"><h1>Find friends</h1><p>Search for an exact username. Only eligible public profiles that allow member contact can appear.</p><form class="friend-search"><label for="friend-handle">Username</label><input id="friend-handle" name="username" minlength="3" maxlength="30" required autocomplete="off" autocapitalize="none"><button type="submit">Search</button></form><p class="friend-search-status" role="status" aria-live="polite"></p><div class="friend-search-results"></div><h2>Friend requests</h2><p class="friend-requests-status" role="status" aria-live="polite"></p><div class="friend-requests-list"></div><button type="button" class="friend-requests-more" hidden>Load more</button></section>';
 const form=root.querySelector('.friend-search'),field=form.querySelector('input'),searchStatus=root.querySelector('.friend-search-status'),results=root.querySelector('.friend-search-results'),status=root.querySelector('.friend-requests-status'),list=root.querySelector('.friend-requests-list'),more=root.querySelector('.friend-requests-more');
 let searchGeneration=0;
 async function load(append=false){
  const op=++generation;if(!append){cursor=null;list.replaceChildren()}more.hidden=true;status.textContent='Loading requests…';
  try{const r=await client.rpc('list_own_friend_requests_display',{p_before:append?cursor?.created_at:null,p_before_id:append?cursor?.id:null});if(disposed||op!==generation)return;if(r.error||!Array.isArray(r.data))throw r.error||new Error('Invalid response');
   for(const request of r.data){const row=document.createElement('article');row.className='friend-request-row';const title=document.createElement('strong');title.textContent=request.other_name;const direction=document.createElement('small');direction.textContent=request.direction==='received'?'Received request':'Request sent';row.append(title,direction);
    const actions=request.direction==='received'?[['Accept',true],['Decline',false]]:[['Cancel',null]];
    for(const [label,accept] of actions){const button=document.createElement('button');button.type='button';button.textContent=label;button.addEventListener('click',async()=>{const action=generation;button.disabled=true;status.textContent='Updating request…';
     try{const result=accept===null?await client.rpc('cancel_own_friend_request',{p_request_id:request.id}):await client.rpc('respond_friend_request',{p_request_id:request.id,p_accept:accept});if(disposed||action!==generation)return;if(result.error)throw result.error;onChanged();await load()}
     catch{if(!disposed&&action===generation)status.textContent='Could not update the request. Please try again.'}finally{button.disabled=false}});row.append(button)}
    list.append(row);
   }
   cursor=r.data.length?r.data[r.data.length-1]:cursor;more.hidden=r.data.length<50;status.textContent=list.childElementCount?'':'No pending requests.';
  }catch{if(!disposed&&op===generation)status.textContent='Requests are unavailable. Please try again later.'}
 }
 form.addEventListener('submit',async event=>{
  event.preventDefault();const button=form.querySelector('button');if(button.disabled)return;const handle=field.value.trim().toLowerCase(),op=++searchGeneration;results.replaceChildren();
  if(!/^[a-z0-9_]{3,30}$/.test(handle)){searchStatus.textContent='Enter a valid username.';return}
  button.disabled=true;searchStatus.textContent='Searching…';
  try{const r=await client.rpc('find_friend_by_handle',{p_handle:handle});if(disposed||op!==searchGeneration)return;if(r.error||!Array.isArray(r.data))throw r.error||new Error('Invalid response');searchStatus.textContent=r.data.length?'':'No eligible account found.';
   for(const user of r.data){const row=document.createElement('article');row.className='friend-result';const name=document.createElement('strong');name.textContent=user.display_name||'Community member';const username=document.createElement('span');username.textContent=`@${user.handle}`;const send=document.createElement('button');send.type='button';send.textContent='Send friend request';send.addEventListener('click',async()=>{send.disabled=true;try{const result=await client.rpc('send_friend_request',{p_target_id:user.user_id});if(disposed||op!==searchGeneration)return;if(result.error)throw result.error;searchStatus.textContent='Request submitted if available.';await load()}catch{if(!disposed&&op===searchGeneration)searchStatus.textContent='Could not submit a request. Please try again later.'}finally{send.disabled=false}});row.append(name,username,send);results.append(row)}
  }catch{if(!disposed&&op===searchGeneration)searchStatus.textContent='Search unavailable. Please try again later.'}finally{button.disabled=false}
 });
 more.addEventListener('click',()=>load(true));load();
 return {refresh:()=>load(),dispose:()=>{disposed=true;++generation;++searchGeneration;root.replaceChildren()}};
}
