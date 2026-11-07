// Dismissal removes only the notice. It never changes the referenced item.
export function appendNoticeDismissDraft(row,client,id,isCurrent,onDismiss,onError){
 const button=document.createElement('button');button.type='button';button.className='note-action notice-dismiss';button.textContent='Clear notice';button.setAttribute('aria-label','Clear this notice');
 button.addEventListener('click',async()=>{
  const controls=[...row.querySelectorAll('button')];if(controls.some(control=>control.disabled))return;controls.forEach(control=>{control.disabled=true});
  try{const result=await client.rpc('dismiss_own_in_app_notification',{p_notification_id:id});if(!isCurrent())return;if(result.error)throw result.error;row.remove();onDismiss()}
  catch{if(isCurrent())onError()}
  finally{controls.forEach(control=>{control.disabled=false})}
 });row.append(button);
}
