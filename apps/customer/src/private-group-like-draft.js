// Development-only group like control. Summaries are filtered by the backend.
export function attachPrivateGroupLikeDraft(card,client,postId,isActive){
 const button=document.createElement('button');button.type='button';button.className='note-action private-group-like';button.textContent='Loading likes…';button.disabled=true;
 const status=document.createElement('span');status.className='group-like-status';status.setAttribute('role','status');status.setAttribute('aria-live','polite');card.append(button,status);let liked=false;
 function applySummary(value){if(!isActive())return;if(!value||typeof value.liked_by_me!=='boolean'||!['string','number'].includes(typeof value.like_count)||!/^\d+$/.test(String(value.like_count))||!Number.isSafeInteger(Number(value.like_count))){unavailable();return}liked=value.liked_by_me;button.textContent=`${liked?'Unlike':'Like'} · ${value.like_count}`;button.disabled=false}
 function unavailable(){if(isActive()){button.textContent='Likes unavailable';button.disabled=true}}
 async function summary(){
  try{const r=await client.rpc('get_private_group_post_like_summary',{p_post_id:postId});if(!isActive())return;if(r.error||!Array.isArray(r.data)||!r.data[0])throw r.error||new Error('Invalid summary');applySummary(r.data[0])}
  catch{unavailable()}
 }
 button.addEventListener('click',async()=>{if(button.disabled)return;button.disabled=true;status.textContent='Saving…';try{const r=await client.rpc('set_private_group_post_like',{p_post_id:postId,p_liked:!liked});if(!isActive())return;if(r.error)throw r.error;await summary();if(isActive())status.textContent=''}catch{if(isActive()){status.textContent='Could not update like.';button.disabled=false}}});
 return {applySummary,unavailable};
}
