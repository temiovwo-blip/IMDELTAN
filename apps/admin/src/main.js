import {createClient} from '@supabase/supabase-js';
const url=import.meta.env.VITE_SUPABASE_URL,key=import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;
let client=null, factorId=null, generation=0;
if(url&&key){try{if(new URL(url).protocol==='https:')client=createClient(url,key,{auth:{flowType:'pkce',persistSession:true,storage:window.sessionStorage,autoRefreshToken:true,detectSessionInUrl:true}})}catch{/* Invalid public configuration: fail closed. */}}
const status=document.querySelector('#admin-status'),login=document.querySelector('#login-form'),mfa=document.querySelector('#mfa-panel'),reports=document.querySelector('#reports-panel'),signout=document.querySelector('#sign-out'),list=document.querySelector('#reports-list');
function clearSensitive(){++generation;list.replaceChildren();reports.hidden=true;mfa.hidden=true;factorId=null}
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
 if(!data.length){list.textContent='No reports in this test environment.';return}
 for(const report of data){
  const card=document.createElement('article');card.className='report-card';const title=document.createElement('strong');title.textContent=`Report ${report.id} · ${report.status}`;const reason=document.createElement('p');reason.className='reason';reason.textContent=report.reason;
  const label=document.createElement('label');label.textContent='Review note';const input=document.createElement('textarea');input.maxLength=4000;input.required=true;label.append(input);
  card.append(title,reason,label);
  for(const next of ['reviewing','closed']){if(report.status===next)continue;const button=document.createElement('button');button.className='quiet';button.type='button';button.textContent=next==='closed'?'Close report':'Mark reviewing';button.addEventListener('click',async()=>{const justification=input.value.trim();if(!justification){message('Add a review note before continuing.');input.focus();return}button.disabled=true;try{const result=await client.rpc('review_user_report',{p_report_id:report.id,p_new_status:next,p_justification:justification});if(result.error){message('Could not save the review. Check your permission and try again.');return}await loadReports()}catch{message('Unable to connect. Please try again later.')}finally{button.disabled=false}});card.append(button)}
  list.append(card)
 }
 }catch{if(request===generation)message('Unable to load reports. Please try again later.')}
}
login.addEventListener('submit',async e=>{e.preventDefault();if(!client)return;const values=new FormData(login),button=login.querySelector('button');button.disabled=true;message('Signing in…');try{const result=await client.auth.signInWithPassword({email:String(values.get('email')).trim(),password:String(values.get('password'))});if(result.error){message('Sign-in failed. Check your details and try again.');return}login.reset()}catch{message('Unable to connect. Please try again later.')}finally{button.disabled=false}});
document.querySelector('#mfa-form').addEventListener('submit',async e=>{e.preventDefault();if(!client||!factorId)return;const form=e.currentTarget,button=form.querySelector('button');button.disabled=true;try{const result=await client.auth.mfa.challengeAndVerify({factorId,code:String(new FormData(form).get('code'))});if(result.error){message('Verification failed. Check the code and try again.');return}form.reset();const {data}=await client.auth.getSession();await syncSession(data.session)}catch{message('Verification is unavailable. Please try again later.')}finally{button.disabled=false}});
document.querySelector('#refresh-reports').addEventListener('click',loadReports);
signout.addEventListener('click',async()=>{if(!client)return;const {error}=await client.auth.signOut();if(error)message('Unable to sign out. Please try again.');else await syncSession(null)});
if(client){client.auth.getSession().then(({data})=>syncSession(data.session)).catch(()=>message('Unable to check session.'));client.auth.onAuthStateChange((_event,session)=>{setTimeout(()=>syncSession(session),0)})}else{login.querySelector('button').disabled=true;syncSession(null)}
