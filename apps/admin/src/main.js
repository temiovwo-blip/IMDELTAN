import {createClient} from '@supabase/supabase-js';
const url=import.meta.env.VITE_SUPABASE_URL,key=import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;
let client=null, factorId=null, generation=0, lgaGeneration=0, commentGeneration=0, messageGeneration=0,groupPostGeneration=0,groupCommentGeneration=0;
if(url&&key){try{if(new URL(url).protocol==='https:')client=createClient(url,key,{auth:{flowType:'pkce',persistSession:true,storage:window.sessionStorage,autoRefreshToken:true,detectSessionInUrl:true}})}catch{/* Invalid public configuration: fail closed. */}}
const status=document.querySelector('#admin-status'),login=document.querySelector('#login-form'),mfa=document.querySelector('#mfa-panel'),reports=document.querySelector('#reports-panel'),signout=document.querySelector('#sign-out'),list=document.querySelector('#reports-list'),lgaList=document.querySelector('#lga-reports-list'),lgaStatus=document.querySelector('#lga-report-status'),commentList=document.querySelector('#comment-reports-list'),commentStatus=document.querySelector('#comment-report-status'),messageList=document.querySelector('#message-reports-list'),messageStatus=document.querySelector('#message-report-status'),groupPostList=document.querySelector('#group-post-reports-list'),groupPostStatus=document.querySelector('#group-post-report-status'),groupCommentList=document.querySelector('#group-comment-reports-list'),groupCommentStatus=document.querySelector('#group-comment-report-status');
function clearSensitive(){++generation;++lgaGeneration;++commentGeneration;++messageGeneration;++groupPostGeneration;++groupCommentGeneration;list.replaceChildren();lgaList.replaceChildren();commentList.replaceChildren();messageList.replaceChildren();groupPostList.replaceChildren();groupCommentList.replaceChildren();lgaStatus.textContent='';commentStatus.textContent='';messageStatus.textContent='';groupPostStatus.textContent='';groupCommentStatus.textContent='';reports.hidden=true;mfa.hidden=true;factorId=null}
function message(text){status.textContent=text}
async function syncSession(session){
 clearSensitive();const request=generation;login.hidden=!!session;signout.hidden=!session;
 if(!session){message(client?'Sign in with an authorized administrator account.':'Sign-in is unavailable until the new project is securely configured.');return}
 message('Checking authentication assurance…');
 try{const {data,error}=await client.auth.mfa.getAuthenticatorAssuranceLevel();if(request!==generation)return;if(error)throw error;
 if(data.currentLevel!=='aal2'){
  const factors=await client.auth.mfa.listFactors();if(request!==generation)return;if(factors.error)throw factors.error;
  const verified=factors.data.totp.filter(f=>f.status==='verified');factorId=verified[0]?.id||null;
  if(!factorId){message('MFA is required. No verified authenticator was found; contact your administrator.');return}
  mfa.hidden=false;message('Enter your authenticator code to continue.');return
 }
 await loadReports();
 }catch{if(request===generation)message('Unable to verify access. Please try again later.')}
}
async function loadReports(){
 if(!client)return;const request=++generation;list.replaceChildren();reports.hidden=true;message('Checking administrator permissions…');
 try{const {data,error}=await client.rpc('list_reports_for_review');if(request!==generation)return;if(error){message('Report access is unavailable or your account is not authorized.');return}
 reports.hidden=false;message('Report review is a development feature. Do not use real reports yet.');
 if(!Array.isArray(data))throw new Error('Invalid response');
 if(!data.length)list.textContent='No user reports in this test environment.';
 for(const report of data){
  const card=document.createElement('article');card.className='report-card';const title=document.createElement('strong');title.textContent=`Report ${report.id} · ${report.status}`;const reason=document.createElement('p');reason.className='reason';reason.textContent=report.reason;
  const label=document.createElement('label');label.textContent='Review note';const input=document.createElement('textarea');input.maxLength=4000;input.required=true;label.append(input);
  card.append(title,reason,label);
  for(const next of ['reviewing','closed']){if(report.status===next)continue;const button=document.createElement('button');button.className='quiet';button.type='button';button.textContent=next==='closed'?'Close report':'Mark reviewing';button.addEventListener('click',async()=>{const justification=input.value.trim();if(!justification){message('Add a review note before continuing.');input.focus();return}button.disabled=true;try{const result=await client.rpc('review_user_report',{p_report_id:report.id,p_new_status:next,p_justification:justification});if(result.error){message('Could not save the review. Check your permission and try again.');return}await loadReports()}catch{message('Unable to connect. Please try again later.')}finally{button.disabled=false}});card.append(button)}
  list.append(card)
 }
 await Promise.all([loadLgaReports(request),loadCommentReports(request),loadMessageReports(request),loadGroupPostReports(request),loadGroupCommentReports(request)]);
 }catch{if(request===generation)message('Unable to load reports. Please try again later.')}
}
function appendContentTriage(card,report,input,localStatus,rpcName='review_lga_content_report'){
 for(const next of ['reviewing','closed']){
  if(report.report_status===next)continue;
  const button=document.createElement('button');button.type='button';button.className='quiet content-triage';button.textContent=next==='closed'?'Close report':'Mark reviewing';
  button.addEventListener('click',async()=>{
   const justification=input.value.trim();if(!justification){localStatus.textContent='Add a review note before continuing.';input.focus();return}
   if(next==='closed'&&!window.confirm('Close this report? This action does not remove the content.'))return;
   const op=generation;button.disabled=true;localStatus.textContent='Saving review…';
   try{const result=await client.rpc(rpcName,{p_report_id:report.report_id,p_new_status:next,p_justification:justification});if(op!==generation||reports.hidden)return;if(result.error)throw result.error;await loadReports()}
   catch{if(op===generation&&!reports.hidden)localStatus.textContent='Could not save the review. Please try again.'}finally{button.disabled=false}
  });card.append(button);
 }
}
async function loadLgaReports(parentRequest=generation){
 if(!client||reports.hidden)return;
 const lgaRequest=++lgaGeneration;
 lgaList.replaceChildren();lgaStatus.textContent='Loading post reports…';
 try{
  const {data,error}=await client.rpc('list_lga_post_reports_for_review');
  if(parentRequest!==generation||lgaRequest!==lgaGeneration||reports.hidden)return;
  if(error||!Array.isArray(data))throw error||new Error('Invalid response');
  lgaStatus.textContent=data.length?'':'No local government post reports.';
  for(const report of data){
   const card=document.createElement('article');card.className='report-card';
   const title=document.createElement('strong');title.textContent=`Post report ${report.report_id} · ${report.report_status}`;
   const post=document.createElement('p');post.className='reason';post.textContent=report.post_body;
   const reason=document.createElement('p');reason.textContent=`Reason: ${report.reason}`;
   const state=document.createElement('p');state.textContent=`Post status: ${report.post_status}`;
   const label=document.createElement('label');label.textContent='Review note (required for every action)';
   const input=document.createElement('textarea');input.required=true;input.maxLength=4000;label.append(input);
   card.append(title,post,reason,state,label);
   if(report.post_status==='active'){
    const remove=document.createElement('button');remove.type='button';remove.className='quiet';remove.textContent='Remove post';
    remove.addEventListener('click',async()=>{
     const justification=input.value.trim();if(!justification){lgaStatus.textContent='Add a reason before removing the post.';input.focus();return}
     if(!window.confirm('Remove this post from the feed? The post and review records are retained.'))return;
     const operation=generation;remove.disabled=true;lgaStatus.textContent='Removing post…';
     try{const result=await client.rpc('remove_reported_lga_text_post',{p_report_id:report.report_id,p_justification:justification});
      if(operation!==generation||reports.hidden)return;if(result.error)throw result.error;await loadReports()}
     catch{if(operation===generation&&!reports.hidden)lgaStatus.textContent='Could not remove the post. Check your access and try again.'}
     finally{remove.disabled=false}
    });card.append(remove);
   }
   appendContentTriage(card,report,input,lgaStatus);
   lgaList.append(card);
  }
 }catch{if(parentRequest===generation&&lgaRequest===lgaGeneration&&!reports.hidden)lgaStatus.textContent='Post report queue unavailable. It may not be enabled in this environment.'}
}
document.querySelector('#refresh-lga-reports').addEventListener('click',()=>loadLgaReports());
async function loadCommentReports(parentRequest=generation){
 if(!client||reports.hidden)return;const current=++commentGeneration;commentList.replaceChildren();commentStatus.textContent='Loading comment reports…';
 try{const {data,error}=await client.rpc('list_lga_comment_reports_for_review');if(parentRequest!==generation||current!==commentGeneration||reports.hidden)return;if(error||!Array.isArray(data))throw error||new Error('Invalid response');
  commentStatus.textContent=data.length?'':'No local government comment reports.';
  for(const report of data){const card=document.createElement('article');card.className='report-card';
   const title=document.createElement('strong');title.textContent=`Comment report ${report.report_id} · ${report.report_status}`;
   const text=document.createElement('p');text.className='reason';text.textContent=report.comment_body;
   const reason=document.createElement('p');reason.textContent=`Reason: ${report.reason}`;
   const state=document.createElement('p');state.textContent=`Comment status: ${report.comment_status}`;
   const label=document.createElement('label');label.textContent='Review note (required for every action)';const input=document.createElement('textarea');input.required=true;input.maxLength=4000;label.append(input);card.append(title,text,reason,state,label);
   if(report.comment_status==='active'){
    const remove=document.createElement('button');remove.type='button';remove.className='quiet';remove.textContent='Remove comment';
    remove.addEventListener('click',async()=>{const justification=input.value.trim();if(!justification){commentStatus.textContent='Add a reason before removing the comment.';input.focus();return}if(!window.confirm('Remove this comment? Review records will be retained.'))return;
     const op=generation;remove.disabled=true;commentStatus.textContent='Removing comment…';
     try{const result=await client.rpc('remove_reported_lga_post_comment',{p_report_id:report.report_id,p_justification:justification});if(op!==generation||reports.hidden)return;if(result.error)throw result.error;await loadReports()}
     catch{if(op===generation&&!reports.hidden)commentStatus.textContent='Could not remove the comment. Check your access and try again.'}finally{remove.disabled=false}
    });card.append(remove);
   }
   appendContentTriage(card,report,input,commentStatus);
   commentList.append(card);
  }
 }catch{if(parentRequest===generation&&current===commentGeneration&&!reports.hidden)commentStatus.textContent='Comment report queue unavailable. It may not be enabled in this environment.'}
}
document.querySelector('#refresh-comment-reports').addEventListener('click',()=>loadCommentReports());
async function loadMessageReports(parentRequest=generation){
 if(!client||reports.hidden)return;const current=++messageGeneration;messageList.replaceChildren();messageStatus.textContent='Loading message reports…';
 try{const {data,error}=await client.rpc('list_direct_message_reports_for_review');if(parentRequest!==generation||current!==messageGeneration||reports.hidden)return;if(error||!Array.isArray(data))throw error||new Error('Invalid response');messageStatus.textContent=data.length?'':'No private-message reports.';
  for(const report of data){const card=document.createElement('article');card.className='report-card';const title=document.createElement('strong');title.textContent=`Message report ${report.report_id} · ${report.report_status}`;const text=document.createElement('p');text.className='reason';text.textContent=report.message_body;const reason=document.createElement('p');reason.textContent=`Reason: ${report.reason}`;const label=document.createElement('label');label.textContent='Review note (required)';const input=document.createElement('textarea');input.required=true;input.maxLength=4000;label.append(input);card.append(title,text,reason,label);
   for(const next of ['reviewing','closed']){if(next===report.report_status)continue;const button=document.createElement('button');button.type='button';button.className='quiet';button.textContent=next==='closed'?'Close report':'Mark reviewing';
    button.addEventListener('click',async()=>{const justification=input.value.trim();if(!justification){messageStatus.textContent='Add a review note before continuing.';input.focus();return}if(next==='closed'&&!window.confirm('Close this report? The message will not be removed.'))return;const op=generation;button.disabled=true;messageStatus.textContent='Saving review…';
     try{const r=await client.rpc('review_direct_message_report',{p_report_id:report.report_id,p_new_status:next,p_justification:justification});if(op!==generation||reports.hidden)return;if(r.error)throw r.error;await loadReports()}catch{if(op===generation&&!reports.hidden)messageStatus.textContent='Could not save the review.'}finally{button.disabled=false}
    });card.append(button);
   }messageList.append(card);
  }
 }catch{if(parentRequest===generation&&current===messageGeneration&&!reports.hidden)messageStatus.textContent='Private-message report queue unavailable. It may not be enabled in this environment.'}
}
document.querySelector('#refresh-message-reports').addEventListener('click',()=>loadMessageReports());
async function loadGroupPostReports(parentRequest=generation){
 if(!client||reports.hidden)return;const current=++groupPostGeneration;groupPostList.replaceChildren();groupPostStatus.textContent='Loading private group reports…';
 try{const {data,error}=await client.rpc('list_private_group_post_reports_for_review');if(parentRequest!==generation||current!==groupPostGeneration||reports.hidden)return;if(error||!Array.isArray(data))throw error||new Error('Invalid response');groupPostStatus.textContent=data.length?'':'No private group post reports.';
  for(const report of data){const card=document.createElement('article');card.className='report-card';const title=document.createElement('strong');title.textContent=`Group post report ${report.report_id} · ${report.report_status}`;const text=document.createElement('p');text.className='reason';text.textContent=report.post_body;const reason=document.createElement('p');reason.textContent=`Reason: ${report.reason}`;const state=document.createElement('p');state.textContent=`Post status: ${report.post_status}`;const label=document.createElement('label');label.textContent='Review note (required for every action)';const input=document.createElement('textarea');input.required=true;input.maxLength=4000;label.append(input);card.append(title,text,reason,state,label);
   if(report.post_status==='active'){const remove=document.createElement('button');remove.type='button';remove.className='quiet';remove.textContent='Remove group post';remove.addEventListener('click',async()=>{const justification=input.value.trim();if(!justification){groupPostStatus.textContent='Add a review note before continuing.';input.focus();return}if(!window.confirm('Remove this post? The post and review records are retained.'))return;const op=generation;remove.disabled=true;groupPostStatus.textContent='Removing group post…';try{const result=await client.rpc('remove_reported_private_group_post',{p_report_id:report.report_id,p_justification:justification});if(op!==generation||reports.hidden)return;if(result.error)throw result.error;await loadReports()}catch{if(op===generation&&!reports.hidden)groupPostStatus.textContent='Could not remove the post.'}finally{remove.disabled=false}});card.append(remove)}
   appendContentTriage(card,report,input,groupPostStatus,'review_private_group_post_report');groupPostList.append(card);
  }
 }catch{if(parentRequest===generation&&current===groupPostGeneration&&!reports.hidden)groupPostStatus.textContent='Group post report queue unavailable. It may not be enabled in this environment.'}
}
document.querySelector('#refresh-group-post-reports').addEventListener('click',()=>loadGroupPostReports());
async function loadGroupCommentReports(parentRequest=generation){
 if(!client||reports.hidden)return;const current=++groupCommentGeneration;groupCommentList.replaceChildren();groupCommentStatus.textContent='Loading private group comment reports…';
 try{const {data,error}=await client.rpc('list_private_group_comment_reports_for_review');if(parentRequest!==generation||current!==groupCommentGeneration||reports.hidden)return;if(error||!Array.isArray(data))throw error||new Error('Invalid response');groupCommentStatus.textContent=data.length?'':'No private group comment reports.';
  for(const report of data){const card=document.createElement('article');card.className='report-card';const title=document.createElement('strong');title.textContent=`Group comment report ${report.report_id} · ${report.report_status}`;const text=document.createElement('p');text.className='reason';text.textContent=report.comment_body;const reason=document.createElement('p');reason.textContent=`Reason: ${report.reason}`;const state=document.createElement('p');state.textContent=`Comment status: ${report.comment_status}`;const label=document.createElement('label');label.textContent='Review note (required for every action)';const input=document.createElement('textarea');input.required=true;input.maxLength=4000;label.append(input);card.append(title,text,reason,state,label);
   if(report.comment_status==='active'){const remove=document.createElement('button');remove.type='button';remove.className='quiet';remove.textContent='Remove group comment';remove.addEventListener('click',async()=>{const justification=input.value.trim();if(!justification){groupCommentStatus.textContent='Add a review note before continuing.';input.focus();return}if(!window.confirm('Remove this comment? The comment and review records are retained.'))return;const op=generation;remove.disabled=true;groupCommentStatus.textContent='Removing group comment…';try{const result=await client.rpc('remove_reported_private_group_comment',{p_report_id:report.report_id,p_justification:justification});if(op!==generation||reports.hidden)return;if(result.error)throw result.error;await loadReports()}catch{if(op===generation&&!reports.hidden)groupCommentStatus.textContent='Could not remove the comment.'}finally{remove.disabled=false}});card.append(remove)}
   appendContentTriage(card,report,input,groupCommentStatus,'review_private_group_comment_report');groupCommentList.append(card);
  }
 }catch{if(parentRequest===generation&&current===groupCommentGeneration&&!reports.hidden)groupCommentStatus.textContent='Group comment report queue unavailable. It may not be enabled in this environment.'}
}
document.querySelector('#refresh-group-comment-reports').addEventListener('click',()=>loadGroupCommentReports());
login.addEventListener('submit',async e=>{e.preventDefault();if(!client)return;const values=new FormData(login),button=login.querySelector('button');button.disabled=true;message('Signing in…');try{const result=await client.auth.signInWithPassword({email:String(values.get('email')).trim(),password:String(values.get('password'))});if(result.error){message('Sign-in failed. Check your details and try again.');return}login.reset()}catch{message('Unable to connect. Please try again later.')}finally{button.disabled=false}});
document.querySelector('#mfa-form').addEventListener('submit',async e=>{e.preventDefault();if(!client||!factorId)return;const form=e.currentTarget,button=form.querySelector('button');button.disabled=true;try{const result=await client.auth.mfa.challengeAndVerify({factorId,code:String(new FormData(form).get('code'))});if(result.error){message('Verification failed. Check the code and try again.');return}form.reset();const {data}=await client.auth.getSession();await syncSession(data.session)}catch{message('Verification is unavailable. Please try again later.')}finally{button.disabled=false}});
document.querySelector('#refresh-reports').addEventListener('click',loadReports);
signout.addEventListener('click',async()=>{if(!client)return;const {error}=await client.auth.signOut();if(error)message('Unable to sign out. Please try again.');else await syncSession(null)});
if(client){client.auth.getSession().then(({data})=>syncSession(data.session)).catch(()=>message('Unable to check session.'));client.auth.onAuthStateChange((_event,session)=>{setTimeout(()=>syncSession(session),0)})}else{login.querySelector('button').disabled=true;syncSession(null)}
