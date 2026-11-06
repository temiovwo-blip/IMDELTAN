import './style.css';
import { createClient } from '@supabase/supabase-js';
const root=document.querySelector('#app');
// A consistent, lightweight icon family. No external icon fonts or network requests.
const iconPaths={
 home:'<path d="m3 10 9-7 9 7v9a2 2 0 0 1-2 2h-4.5v-6h-5v6H5a2 2 0 0 1-2-2z"/>',
 explore:'<circle cx="12" cy="12" r="9"/><path d="m15.8 8.2-2.1 5.5-5.5 2.1 2.1-5.5z"/>',
 people:'<circle cx="9" cy="8" r="3"/><path d="M3.5 19v-1.5A5.5 5.5 0 0 1 9 12h.1a5.5 5.5 0 0 1 5.4 5.5V19zM16 5.4a3 3 0 0 1 0 5.5M17 12.5a5 5 0 0 1 3.5 4.8V19h-3"/>',
 message:'<path d="M4 5.5A2.5 2.5 0 0 1 6.5 3h11A2.5 2.5 0 0 1 20 5.5v9a2.5 2.5 0 0 1-2.5 2.5H10l-4.5 3v-3H6.5A2.5 2.5 0 0 1 4 14.5z"/><path d="M8 8h8M8 12h5"/>',
 menu:'<path d="M4 7h16M4 12h16M4 17h16"/>',
 heart:'<path d="M20.7 8.4c0 4-4.8 7.4-8.7 10-3.9-2.6-8.7-6-8.7-10a4.6 4.6 0 0 1 8.7-2.1 4.6 4.6 0 0 1 8.7 2.1z"/>',
 share:'<path d="M14 5l6 5-6 5v-3c-5.2 0-7.8 2-10 5 .3-6.2 3.2-9 10-9z"/>',
 bell:'<path d="M18 9a6 6 0 0 0-12 0c0 6-2 6-2 8h16c0-2-2-2-2-8M10 20a2 2 0 0 0 4 0"/>',
 bookmark:'<path d="M6 4.5A1.5 1.5 0 0 1 7.5 3h9A1.5 1.5 0 0 1 18 4.5V21l-6-4-6 4z"/>',
 settings:'<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .34 1.88l.06.06-1.8 3.12-.09-.02a1.7 1.7 0 0 0-1.8.64l-.05.07h-3.6l-.03-.08a1.7 1.7 0 0 0-1.8-.63l-.09.02-1.8-3.12.06-.06A1.7 1.7 0 0 0 8.1 15l-.07-.05v-3.6l.08-.03a1.7 1.7 0 0 0 .63-1.8l-.02-.09 3.12-1.8.06.06A1.7 1.7 0 0 0 13.78 8l.05-.07h3.6l.03.08a1.7 1.7 0 0 0 1.8.63l.09-.02 1.8 3.12-.06.06a1.7 1.7 0 0 0-.34 1.88l.07.05v1.2z" transform="translate(-2 -2)"/>',
 help:'<circle cx="12" cy="12" r="9"/><path d="M9.4 9a2.7 2.7 0 1 1 4.7 1.8c-.8.7-2.1 1.1-2.1 2.7M12 17h.01"/>',
 mark:'<path d="M6 18V6h4.2c4.4 0 7.8 2.6 7.8 6s-3.4 6-7.8 6H6z"/><path d="M9.6 9.5v5M12 9.5c1.9 0 3.3 1 3.3 2.5S13.9 14.5 12 14.5"/>'
};
const icon=(name)=>`<svg class="ui-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${iconPaths[name]}</svg>`;

const url=import.meta.env.VITE_SUPABASE_URL, key=import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;
let client=null;
if(url&&key){try{if(new URL(url).protocol==='https:') client=createClient(url,key,{auth:{flowType:'pkce',persistSession:true,storage:window.sessionStorage,autoRefreshToken:true,detectSessionInUrl:true}})}catch{/* Invalid configuration: fail closed. */}}
root.innerHTML=`<header><button class="header-menu" id="open-menu" type="button" aria-label="Open menu">${icon('menu')}</button><div class="brand"><span class="logo">${icon('mark')}</span><span class="brand-name">IMDELTAN<small>YOUR COMMUNITY</small></span></div></header><div class="layout"><aside class="sidebar"><p class="sidebar-label">YOUR SPACE</p><nav class="side-nav" aria-label="Main navigation"><span class="nav-item current" aria-current="page">${icon('home')}<span>Home</span></span><span class="nav-item unavailable">${icon('explore')}<span>Discover<small>Coming later</small></span></span><span class="nav-item unavailable">${icon('people')}<span>Communities<small>Coming later</small></span></span><span class="nav-item unavailable">${icon('message')}<span>Messages<small>Coming later</small></span></span></nav><div class="sidecard"><span class="sidecard-kicker">OUR COMMUNITY</span><b>Better together.</b><p>A place for the people and stories that connect us.</p></div></aside><main><div class="notice"><b>Development preview.</b> Community content is illustrative. Registration is closed. Do not use real accounts or personal data in this development preview.</div><div class="feed-heading"><div><span class="eyebrow">YOUR COMMUNITY</span><h1>Home</h1></div><span class="feed-heading-note">A place to belong</span></div><div class="feed-tabs" aria-label="Example feed categories"><span class="feed-tab active">For you</span><span class="feed-tab muted">Following <small>Coming later</small></span></div><section class="composer" aria-label="Post composer preview"><span class="composer-avatar" aria-hidden="true">i</span><span class="composer-prompt">What would you like to share?</span><span class="composer-photo" aria-hidden="true">+</span></section><div class="feed-section-title"><h2>Community stories</h2><span>Examples</span></div><div class="stories" aria-label="Illustrative story examples"><div class="story story-first"><div class="story-add">+</div><b>Your story</b><small>Coming later</small></div><div class="story story-photo"><img src="/community.jpg" alt=""><span class="story-initial">D</span><b>Delta voices</b></div><div class="story story-photo"><img src="/community-life.jpg" alt=""><span class="story-initial">O</span><b>Our community</b></div><div class="story story-photo"><img src="/community-market.jpg" alt=""><span class="story-initial">M</span><b>Market moments</b></div></div><div class="feed-section-title feed-title"><h2>From your community</h2><span>Sample post</span></div><article class="feed-post"><div class="feed-author"><span class="feed-avatar">IC</span><div><strong>IMDELTAN Community</strong><small>Example post · Community</small></div><span class="feed-more" aria-hidden="true">•••</span></div><p>Good stories bring us closer. What’s one thing you love about your community?</p><img src="/community-life.jpg" alt="Illustrative AI-generated image of a community gathering"><div class="feed-post-meta"><span>Community conversation</span><span>Example content</span></div><div class="feed-actions" aria-label="Post actions preview"><button type="button" disabled>${icon('heart')}<span>Like</span></button><button type="button" disabled>${icon('message')}<span>Comment</span></button><button type="button" disabled>${icon('share')}<span>Share</span></button></div></article><article class="feed-post feed-text-post"><div class="feed-author"><span class="feed-avatar alt">DV</span><div><strong>Delta Voices</strong><small>Example post · Community</small></div><span class="feed-more" aria-hidden="true">•••</span></div><p>From the places we call home to the stories we share, community makes the difference. What should we celebrate together?</p><div class="post-topic"><span aria-hidden="true">✳</span><div><strong>Our community, our stories</strong><small>A sample conversation</small></div></div><div class="feed-post-meta"><span>Community conversation</span><span>Example content</span></div><div class="feed-actions" aria-label="Post actions preview"><button type="button" disabled>${icon('heart')}<span>Like</span></button><button type="button" disabled>${icon('message')}<span>Comment</span></button><button type="button" disabled>${icon('share')}<span>Share</span></button></div></article><section class="box" id="onboarding" hidden><h2>Account setup</h2><p>These steps are in development and must not be used with real accounts.</p><p id="onboarding-status" role="status" aria-live="polite"></p><div id="onboarding-steps"></div></section><section class="box" id="profile-editor" hidden><h2>Your profile <small class="draft-label">Development</small></h2><p>Update your profile details. Profile visibility controls are still being built.</p><p id="profile-lga" class="profile-lga"></p><form id="profile-form" hidden><label for="profile-name">Display name</label><input id="profile-name" name="displayName" maxlength="80" autocomplete="name" required><label for="profile-handle">Username</label><input id="profile-handle" name="handle" minlength="3" maxlength="30" pattern="[a-z0-9_]{3,30}" autocapitalize="none" autocomplete="off" aria-describedby="profile-hint" required><small id="profile-hint">Use 3–30 lowercase letters, numbers or underscores.</small><label for="profile-bio">About you <span>(optional)</span></label><textarea id="profile-bio" name="biography" maxlength="500"></textarea><button class="small-action" type="submit">Save profile</button></form><p id="profile-message" role="status" aria-live="polite"></p></section><section class="box" id="private-posts" hidden><h2>Your private notes</h2><p>Only you can see these draft text posts. Account setup is required. Showing up to 20 recent notes.</p><form id="post-form"><label for="post-body">Write a private note</label><textarea id="post-body" name="body" maxlength="5000" required></textarea><button class="primary" type="submit">Save private note</button></form><p id="post-message" role="status" aria-live="polite"></p><div id="post-list"></div></section><section class="box" id="joined-groups" hidden><h2>Groups you joined <small class="draft-label">Development</small></h2><p>Group posts and conversations are not available yet.</p><p id="joined-message" role="status" aria-live="polite"></p><div id="joined-list"></div><button id="joined-more" class="note-action" type="button" hidden>Load more groups</button><h3 class="subheading">Unavailable memberships</h3><p>Groups that are unavailable are shown without their names. You can still leave them.</p><p id="unavailable-message" role="status" aria-live="polite"></p><div id="unavailable-list"></div><button id="unavailable-more" class="note-action" type="button" hidden>Load more unavailable memberships</button></section><section class="box" id="group-invitations" hidden><h2>Group invitations <small class="draft-label">Development</small></h2><p>Invitations are limited to your selected local government in this draft. Group conversations and posts are not available yet.</p><p id="invitations-message" role="status" aria-live="polite"></p><div id="invitations-list"></div><button id="invitations-more" class="note-action" type="button" hidden>Load more</button></section><section class="box" id="my-groups" hidden><h2>My groups <small class="draft-label">Development</small></h2><p>Create a private group in your selected local government. Joining, invitations and group posts are not available yet.</p><form id="group-form"><label for="group-name">Group name</label><input id="group-name" name="name" maxlength="120" required><label for="group-description">Description (optional)</label><textarea id="group-description" name="description" maxlength="1000"></textarea><button class="small-action" type="submit">Create private group</button></form><p id="group-message" role="status" aria-live="polite"></p><div id="group-list"></div><button id="groups-more" class="note-action" type="button" hidden>Load more</button></section><section class="box" id="privacy" hidden><h2>Privacy settings <small class="draft-label">Development</small></h2><p>These settings are being built and are not yet enforced throughout the app. Do not rely on them for privacy.</p><form id="privacy-form" hidden><label for="privacy-profile">Who can see your profile?</label><select id="privacy-profile" name="profile"><option value="private">Only me</option><option value="friends">Friends</option><option value="public">Everyone</option></select><label for="privacy-contact">Who may contact you?</label><select id="privacy-contact" name="contact"><option value="nobody">Nobody</option><option value="friends">Friends only</option><option value="members">Members</option></select><button class="small-action" type="submit">Save settings</button></form><p id="privacy-message" role="status" aria-live="polite"></p></section><section class="box" id="blocks" hidden><h2>Blocked accounts (draft)</h2><p>Blocks are not yet enforced across the app. This development list shows account IDs only; do not use it for real safety decisions.</p><p id="blocks-message" role="status" aria-live="polite"></p><div id="block-list"></div><button id="blocks-more" class="small-action" type="button" hidden>Load more</button></section><section class="box"><h2>Made for meaningful connection</h2><p>Community, privacy and safety are being built into the foundation.</p></section></main><aside class="right"><div class="box"><h2>Made for meaningful connection</h2><p>Find familiar voices, discover communities and share your story.</p><div class="value-row"><span class="value-icon">${icon('people')}</span><span><b>Your space, your choice</b><small>Privacy controls are planned.</small></span></div><div class="value-row"><span class="value-icon">${icon('message')}</span><span><b>Respect comes first</b><small>Safety tools are in development.</small></span></div></div><div class="box"><h2>Thoughtful by design</h2><p>We’re working toward a lighter experience for mobile data.</p></div></aside></div><nav class="mobile-nav" aria-label="Example navigation"><span class="mobile-item current" aria-current="page">${icon('home')}<small>Home</small></span><span class="mobile-item unavailable">${icon('explore')}<small>Discover</small><span class="sr-only">Coming later</span></span><span class="mobile-item unavailable">${icon('people')}<small>Communities</small><span class="sr-only">Coming later</span></span><span class="mobile-item unavailable">${icon('message')}<small>Messages</small><span class="sr-only">Coming later</span></span></nav><dialog id="menu-dialog" aria-labelledby="menu-title"><div class="menu-top"><div><span class="menu-overline">IMDELTAN</span><h2 id="menu-title">Your space</h2></div><button id="close-menu" class="menu-close" type="button" aria-label="Close menu">×</button></div><button type="button" class="menu-account" id="menu-account"><span class="menu-avatar">${icon('mark')}</span><span><b>Your account</b><small>View account options</small></span><span class="menu-arrow" aria-hidden="true">›</span></button><p class="menu-label">YOUR COMMUNITY</p><div class="menu-list"><div class="menu-row disabled">${icon('people')}<span>Communities<small>Spaces to connect · Coming later</small></span></div><button class="menu-row" id="menu-groups" type="button">${icon('people')}<span>My groups<small>Development</small></span></button><button class="menu-row" id="menu-joined" type="button">${icon('people')}<span>Joined groups<small>Development</small></span></button><button class="menu-row" id="menu-invitations" type="button">${icon('message')}<span>Group invitations<small>Development</small></span></button><div class="menu-row disabled">${icon('people')}<span>Friends<small>Coming later</small></span></div><div class="menu-row disabled">${icon('explore')}<span>Discover<small>Coming later</small></span></div><div class="menu-row disabled">${icon('bookmark')}<span>Saved<small>Coming later</small></span></div><button class="menu-row" id="menu-notes" type="button">${icon('message')}<span>Private notes<small>Development</small></span></button></div><p class="menu-label">ACCOUNT &amp; SUPPORT</p><div class="menu-list menu-secondary"><button class="menu-row" id="menu-profile" type="button">${icon('people')}<span>Edit profile<small>Development</small></span></button><button class="menu-row" id="menu-privacy" type="button">${icon('settings')}<span>Settings &amp; privacy<small>Development</small></span></button><div class="menu-row disabled">${icon('help')}<span>Help &amp; support<small>Coming later</small></span></div></div><p id="menu-status" class="menu-status" role="status" aria-live="polite"></p><button id="signout" class="menu-signout" type="button" hidden>Sign out</button><p class="menu-end">Made for our community.</p></dialog><dialog id="auth-dialog" aria-labelledby="auth-title"><button class="close" aria-label="Close account" hidden>×</button><div class="auth-brand"><span class="auth-mark" aria-hidden="true">${icon('mark')}</span><h2 id="auth-title">imdeltan</h2><p>Closer to home. Closer to each other.</p></div><div class="auth-card"><p id="auth-copy" class="auth-copy">Sign in to your account</p><p id="config-note" class="config-note" role="status"></p><form id="signin"><label class="sr-only" for="auth-email">Email address</label><input id="auth-email" type="email" name="email" autocomplete="username" placeholder="Email address" required><label class="sr-only" for="auth-password">Password</label><input id="auth-password" type="password" name="password" autocomplete="current-password" placeholder="Password" required><p id="auth-message" role="status" aria-live="polite"></p><button type="submit" class="primary">Log in</button></form></div><p class="auth-foot"><span aria-hidden="true">✦</span> &nbsp; A place to connect and belong</p><p class="auth-registration">Registration is not open yet.</p></dialog>`;
const dialog=document.querySelector('#auth-dialog'),form=document.querySelector('#signin'), status=document.querySelector('#auth-message');
const menuDialog=document.querySelector('#menu-dialog');let menuOpener=null;
function openMenu(event){menuOpener=event.currentTarget;menuDialog.showModal()}
function closeMenu(){menuDialog.close();menuOpener?.focus()}
document.querySelector('#open-menu').addEventListener('click',openMenu);
document.querySelector('#close-menu').addEventListener('click',closeMenu);
menuDialog.addEventListener('click',(event)=>{if(event.target===menuDialog)closeMenu()});
menuDialog.addEventListener('close',()=>menuOpener?.focus());
document.querySelector('#menu-account').addEventListener('click',()=>{closeMenu();dialog.showModal()});
for(const [button,target] of [['#menu-profile','#profile-editor'],['#menu-privacy','#privacy'],['#menu-notes','#private-posts'],['#menu-groups','#my-groups'],['#menu-invitations','#group-invitations'],['#menu-joined','#joined-groups']]){
  document.querySelector(button).addEventListener('click',()=>{closeMenu();const panel=document.querySelector(target);if(!panel.hidden)panel.scrollIntoView({behavior:'smooth',block:'start'})});
}

document.querySelector('.close').addEventListener('click',()=>dialog.close());
dialog.addEventListener('cancel',(event)=>{if(document.querySelector('.close').hidden)event.preventDefault()});
function setSignedIn(value){document.querySelector('.close').hidden=!value;document.querySelector('#onboarding').hidden=!value;document.querySelector('#private-posts').hidden=!value;document.querySelector('#blocks').hidden=!value;document.querySelector('#privacy').hidden=!value;document.querySelector('#profile-editor').hidden=!value;document.querySelector('#my-groups').hidden=!value;document.querySelector('#group-invitations').hidden=!value;document.querySelector('#joined-groups').hidden=!value;if(value){refreshOnboarding();refreshPosts();refreshBlocks();refreshPrivacy();refreshProfile();refreshGroups();refreshInvitations();refreshJoined()}else{for(const state of Object.values(joinedState)){++state.request;state.list.replaceChildren();state.message.textContent='';state.more.hidden=true}++invitationsRequest;document.querySelector('#invitations-list').replaceChildren();document.querySelector('#invitations-message').textContent='';document.querySelector('#invitations-more').hidden=true;++groupsRequest;document.querySelector('#group-form').reset();document.querySelector('#group-list').replaceChildren();document.querySelector('#group-message').textContent='';document.querySelector('#groups-more').hidden=true;++profileRequest;document.querySelector('#profile-form').reset();document.querySelector('#profile-form').hidden=true;document.querySelector('#profile-message').textContent='';document.querySelector('#profile-lga').textContent='';++privacyRequest;document.querySelector('#privacy-form').reset();document.querySelector('#privacy-form').hidden=true;document.querySelector('#privacy-message').textContent='';++blockRequest;++feedRequest;document.querySelector('#post-form').reset();document.querySelector('#post-message').textContent='';document.querySelector('#block-list').replaceChildren();document.querySelector('#blocks-message').textContent='';document.querySelector('#blocks-more').hidden=true;++onboardingRequest;document.querySelector('#onboarding-steps').replaceChildren();document.querySelector('#post-list').replaceChildren();}form.hidden=value;document.querySelector('#signout').hidden=!value;document.querySelector('#auth-copy').textContent=value?'You are signed in.':'Sign in to your account'}
if(!client){document.querySelector('#config-note').textContent='Sign-in is unavailable until the new development project is securely configured.';form.querySelector('button').disabled=true}
form.addEventListener('submit',async(event)=>{event.preventDefault();if(!client)return;const values=new FormData(form), button=form.querySelector('button');button.disabled=true;status.textContent='Signing in…';try{const {error}=await client.auth.signInWithPassword({email:String(values.get('email')).trim(),password:String(values.get('password'))});if(error){status.textContent='Sign-in failed. Check your details and try again.';return}form.reset();status.textContent='';setSignedIn(true);dialog.close()}catch{status.textContent='Unable to connect. Please try again later.'}finally{button.disabled=false}});
document.querySelector('#signout').addEventListener('click',async()=>{if(!client)return;const button=document.querySelector('#signout');button.disabled=true;try{const {error}=await client.auth.signOut();if(error){document.querySelector('#menu-status').textContent='Unable to sign out. Please try again.';return}document.querySelector('#menu-status').textContent='';setSignedIn(false);if(menuDialog.open)menuDialog.close();if(!dialog.open)dialog.showModal()}catch{document.querySelector('#menu-status').textContent='Unable to sign out. Please try again.'}finally{button.disabled=false}});

let feedRequest=0;
async function refreshPosts(){
  const request=++feedRequest, list=document.querySelector('#post-list'), msg=document.querySelector('#post-message');
  if(!client||document.querySelector('#private-posts').hidden)return;
  list.replaceChildren(); msg.textContent='Loading private notes…';
  try {
    const {data,error}=await client.from('posts').select('id,body,created_at').order('created_at',{ascending:false}).limit(20);
    if(request!==feedRequest||document.querySelector('#private-posts').hidden)return;
    if(error){msg.textContent='Private notes are unavailable. Complete onboarding or try again later.';return}
    list.replaceChildren();
    for(const post of data){
      const item=document.createElement('article');item.className='saved-note';
      const text=document.createElement('p');text.className='note-text';text.textContent=post.body;
      const actions=document.createElement('div');actions.className='note-actions';
      const edit=document.createElement('button');edit.type='button';edit.className='note-action';edit.textContent='Edit';
      const remove=document.createElement('button');remove.type='button';remove.className='note-action destructive';remove.textContent='Delete';
      edit.addEventListener('click',()=>{
        const editor=document.createElement('form'),input=document.createElement('textarea');input.value=post.body;input.maxLength=5000;input.required=true;input.setAttribute('aria-label','Edit private note');
        const save=document.createElement('button');save.type='submit';save.className='small-action';save.textContent='Save changes';
        const cancel=document.createElement('button');cancel.type='button';cancel.className='note-action';cancel.textContent='Cancel';
        cancel.addEventListener('click',()=>{editor.remove();text.hidden=false;actions.hidden=false});
        editor.addEventListener('submit',async(event)=>{
          event.preventDefault();const body=input.value.trim();if(!body){msg.textContent='Write something before saving.';return}
          const operation=feedRequest;save.disabled=true;msg.textContent='Saving changes…';
          try{const result=await client.rpc('edit_own_private_text_post',{p_post_id:post.id,p_body:body});if(operation!==feedRequest||document.querySelector('#private-posts').hidden)return;if(result.error)throw result.error;await refreshPosts()}
          catch{if(operation===feedRequest&&!document.querySelector('#private-posts').hidden)msg.textContent='Could not save changes. Please try again.'}
          finally{save.disabled=false}
        });
        editor.append(input,save,cancel);text.hidden=true;actions.hidden=true;item.append(editor);input.focus();
      });
      remove.addEventListener('click',async()=>{
        if(!window.confirm('Delete this private note?'))return;
        const operation=feedRequest;remove.disabled=true;msg.textContent='Deleting…';
        try{const result=await client.rpc('delete_own_private_text_post',{p_post_id:post.id});if(operation!==feedRequest||document.querySelector('#private-posts').hidden)return;if(result.error)throw result.error;await refreshPosts()}
        catch{if(operation===feedRequest&&!document.querySelector('#private-posts').hidden)msg.textContent='Could not delete the note. Please try again.'}
        finally{remove.disabled=false}
      });
      actions.append(edit,remove);item.append(text,actions);list.appendChild(item);
    }
    msg.textContent=data.length?'':'No private notes yet.';
  }catch{if(request===feedRequest)msg.textContent='Unable to load notes. Please try again later.'}
}
document.querySelector('#post-form').addEventListener('submit',async(event)=>{
  event.preventDefault();if(!client)return;const field=document.querySelector('#post-body'), msg=document.querySelector('#post-message'), button=event.currentTarget.querySelector('button');
  const body=field.value.trim();if(!body)return;button.disabled=true;msg.textContent='Saving…';
  try {const {error}=await client.rpc('create_own_private_text_post',{p_body:body});if(error){msg.textContent='Unable to save. Complete onboarding or try again later.';return}field.value='';await refreshPosts()}
  catch{msg.textContent='Unable to connect. Please try again later.'}finally{button.disabled=false}
});

let onboardingRequest=0;
async function refreshOnboarding(){
  const request=++onboardingRequest, panel=document.querySelector('#onboarding'), out=document.querySelector('#onboarding-steps'), status=document.querySelector('#onboarding-status');
  if(!client||panel.hidden)return;out.replaceChildren();status.textContent='Checking account setup…';
  try{
    const init=await client.rpc('initialize_own_onboarding');if(request!==onboardingRequest||panel.hidden)return;if(init.error)throw init.error;
    const result=await client.rpc('get_own_onboarding_status');if(request!==onboardingRequest||panel.hidden)return;if(result.error||!result.data?.length)throw result.error||new Error('Missing setup state');
    const state=result.data[0];if(!['pending','active'].includes(state.account_state)){status.textContent='This account cannot continue setup. Please contact support.';return}
    const lgas=await client.rpc('list_delta_lgas');if(request!==onboardingRequest||panel.hidden)return;if(lgas.error||!Array.isArray(lgas.data))throw lgas.error||new Error('LGA list unavailable');
    const ownLga=await client.rpc('get_own_lga');if(request!==onboardingRequest||panel.hidden)return;if(ownLga.error||!Array.isArray(ownLga.data))throw ownLga.error||new Error('LGA unavailable');
    const selectedLga=ownLga.data[0]??null;
    const policies=await client.rpc('list_current_required_policies');if(request!==onboardingRequest||panel.hidden)return;if(policies.error)throw policies.error;
    status.textContent='Follow the steps below. Self-declaration does not independently verify age.';
    const lgaStep=document.createElement('div');lgaStep.className='setup-step';
    const lgaTitle=document.createElement('h3');lgaTitle.textContent='Your local government';
    const lgaLabel=document.createElement('label');lgaLabel.textContent='Choose your local government area';
    const lgaSelect=document.createElement('select');lgaSelect.className='lga-select';lgaSelect.required=true;
    const empty=document.createElement('option');empty.value='';empty.textContent='Select an LGA';lgaSelect.append(empty);
    for(const lga of lgas.data){const option=document.createElement('option');option.value=lga.id;option.textContent=lga.name;lgaSelect.append(option)}
    lgaSelect.value=selectedLga?.id??'';lgaLabel.append(lgaSelect);
    const lgaButton=document.createElement('button');lgaButton.type='button';lgaButton.className='small-action';lgaButton.textContent='Save local government';
    lgaButton.addEventListener('click',async()=>{
      if(!lgaSelect.value){status.textContent='Please choose your local government first.';return}
      const operation=onboardingRequest;lgaButton.disabled=true;status.textContent='Saving local government…';
      try{const r=await client.rpc('set_own_lga',{p_lga_id:lgaSelect.value});if(operation!==onboardingRequest||panel.hidden)return;if(r.error)throw r.error;await refreshOnboarding();await refreshProfile()}
      catch{if(operation===onboardingRequest&&!panel.hidden)status.textContent='Could not save your local government. Please try again.'}
      finally{lgaButton.disabled=false}
    });
    lgaStep.append(lgaTitle,lgaLabel,lgaButton);out.append(lgaStep);
    if(state.eligibility_status==='pending'){
      const wrap=document.createElement('div');wrap.className='setup-step';const title=document.createElement('h3');title.textContent='Adult eligibility';
      const label=document.createElement('label'),checkbox=document.createElement('input');checkbox.type='checkbox';checkbox.className='check';label.append(checkbox,document.createTextNode(' I declare that I am 18 years of age or older.'));
      const button=document.createElement('button');button.type='button';button.className='small-action';button.textContent='Confirm declaration';
      button.addEventListener('click',async()=>{if(!checkbox.checked){status.textContent='Please confirm the declaration first.';return}button.disabled=true;try{const r=await client.rpc('declare_adult_eligibility',{p_confirmed:true});if(r.error){status.textContent='Could not record the declaration. Please try again.';return}await refreshOnboarding()}catch{status.textContent='Unable to connect. Please try again.'}finally{button.disabled=false}});wrap.append(title,label,button);out.append(wrap);
    }else if(state.eligibility_status!=='eligible'){const p=document.createElement('p');p.textContent='Your account eligibility cannot be completed here. Please contact support.';out.append(p)}
    const heading=document.createElement('h3');heading.textContent='Required policies';out.append(heading);
    if(!policies.data.length){const p=document.createElement('p');p.textContent='No current required policies are available. Setup cannot continue.';out.append(p)}
    for(const policy of policies.data){
      const card=document.createElement('div');card.className='setup-step';const name=document.createElement('strong');name.textContent=`${policy.policy_key} · version ${policy.version}`;card.append(name);
      let validLink=false;try{const parsed=new URL(policy.content_url);if(parsed.protocol==='https:'){validLink=true;const link=document.createElement('a');link.href=parsed.href;link.target='_blank';link.rel='noopener noreferrer';link.textContent='Read policy';card.append(link)}}catch{/* Invalid links are not displayed. */}
      const note=document.createElement('span');note.textContent=policy.accepted?'Accepted':'Not accepted';card.append(note);
      if(!policy.accepted&&validLink){const confirmation=document.createElement('label');const checked=document.createElement('input');checked.type='checkbox';checked.className='check';confirmation.append(checked,document.createTextNode(' I have read and accept this policy.'));card.append(confirmation);const button=document.createElement('button');button.type='button';button.className='small-action';button.textContent='Accept this policy';button.addEventListener('click',async()=>{if(!checked.checked){status.textContent='Please confirm that you have read and accept the policy.';return}button.disabled=true;try{const r=await client.rpc('accept_current_policy',{p_policy_version_id:policy.id});if(r.error){status.textContent='Could not record acceptance. Please try again.';return}await refreshOnboarding()}catch{status.textContent='Unable to connect. Please try again.'}finally{button.disabled=false}});card.append(button)}out.append(card);
    }
    if(state.account_state==='pending'&&state.eligibility_status==='eligible'&&state.policy_complete&&selectedLga){const button=document.createElement('button');button.className='small-action';button.type='button';button.textContent='Complete account setup';button.addEventListener('click',async()=>{button.disabled=true;try{const r=await client.rpc('complete_own_onboarding');if(r.error){status.textContent='Could not finish setup. Please try again.';return}await refreshOnboarding();await refreshPosts();await refreshBlocks();await refreshPrivacy();await refreshProfile();await refreshGroups();await refreshInvitations();await refreshJoined()}catch{status.textContent='Unable to connect. Please try again.'}finally{button.disabled=false}});out.append(button)}
    if(state.account_state==='active'&&state.policy_complete)status.textContent='Your account setup is complete for the current required policies.';
  }catch{if(request===onboardingRequest)status.textContent='Account setup is unavailable. Please try again later.'}
}
const joinedPanel=document.querySelector('#joined-groups');
const joinedState={
  available:{request:0,cursor:null,list:document.querySelector('#joined-list'),message:document.querySelector('#joined-message'),more:document.querySelector('#joined-more'),rpc:'list_own_joined_groups'},
  unavailable:{request:0,cursor:null,list:document.querySelector('#unavailable-list'),message:document.querySelector('#unavailable-message'),more:document.querySelector('#unavailable-more'),rpc:'list_own_unavailable_group_memberships'}
};
async function loadJoined(kind,append=false){
  const state=joinedState[kind],request=++state.request;if(!client||joinedPanel.hidden)return;
  if(!append){state.cursor=null;state.list.replaceChildren()}
  state.more.hidden=true;state.message.textContent='Loading…';
  try{
    const {data,error}=await client.rpc(state.rpc,{p_before:append?state.cursor?.joined_at??null:null,p_before_id:append?state.cursor?.id??null:null});
    if(request!==state.request||joinedPanel.hidden)return;if(error||!Array.isArray(data))throw error||new Error('Invalid groups');
    for(const group of data){
      const card=document.createElement('article');card.className='setup-step';const title=document.createElement('strong');title.textContent=kind==='available'?group.name:'Unavailable group';card.append(title);
      if(kind==='available'){const label=document.createElement('span');label.textContent=`${group.lga_name} · Private group`;const details=document.createElement('p');details.textContent=group.description;card.append(label,details)}
      const leave=document.createElement('button');leave.type='button';leave.className='note-action destructive';leave.textContent='Leave group';
      leave.addEventListener('click',async()=>{
        if(!window.confirm('Leave this group? Rejoining is not available yet.'))return;
        const operation=state.request;leave.disabled=true;state.message.textContent='Leaving group…';
        try{const result=await client.rpc('leave_joined_group',{p_group_id:group.id});if(operation!==state.request||joinedPanel.hidden)return;if(result.error)throw result.error;await refreshJoined()}
        catch{if(operation===state.request&&!joinedPanel.hidden)state.message.textContent='Could not leave the group. Please try again.'}
        finally{leave.disabled=false}
      });card.append(leave);state.list.append(card);
    }
    if(data.length)state.cursor={joined_at:data[data.length-1].joined_at,id:data[data.length-1].id};
    state.more.hidden=data.length<25;state.message.textContent=state.list.childElementCount?'':kind==='available'?'No joined groups.':'No unavailable memberships.';
  }catch{if(request===state.request&&!joinedPanel.hidden)state.message.textContent='Groups unavailable. Complete account setup or try again later.'}
}
async function refreshJoined(){await Promise.all([loadJoined('available'),loadJoined('unavailable')])}
for(const kind of Object.keys(joinedState))joinedState[kind].more.addEventListener('click',()=>loadJoined(kind,true));
let invitationsRequest=0,invitationsCursor=null;
const invitationsPanel=document.querySelector('#group-invitations'),invitationsList=document.querySelector('#invitations-list'),invitationsMessage=document.querySelector('#invitations-message'),invitationsMore=document.querySelector('#invitations-more');
async function refreshInvitations(append=false){
  const request=++invitationsRequest;if(!client||invitationsPanel.hidden)return;
  if(!append){invitationsCursor=null;invitationsList.replaceChildren()}
  invitationsMore.hidden=true;invitationsMessage.textContent='Loading invitations…';
  try{
    const {data,error}=await client.rpc('list_own_group_invitations',{p_before:append?invitationsCursor?.created_at??null:null,p_before_id:append?invitationsCursor?.id??null:null});
    if(request!==invitationsRequest||invitationsPanel.hidden)return;if(error||!Array.isArray(data))throw error||new Error('Invalid invitations');
    for(const invitation of data){
      const card=document.createElement('article');card.className='setup-step';
      const title=document.createElement('strong');title.textContent=invitation.group_name;
      const detail=document.createElement('span');detail.textContent=`${invitation.lga_name} · Private group invitation`;
      const actions=document.createElement('div');actions.className='note-actions';
      for(const accept of [true,false]){
        const button=document.createElement('button');button.type='button';button.className=accept?'small-action':'note-action';button.textContent=accept?'Accept':'Decline';
        button.addEventListener('click',async()=>{
          const operation=invitationsRequest;for(const item of actions.querySelectorAll('button'))item.disabled=true;invitationsMessage.textContent=accept?'Accepting invitation…':'Declining invitation…';
          try{const result=await client.rpc('respond_to_group_invitation',{p_invitation_id:invitation.id,p_accept:accept});if(operation!==invitationsRequest||invitationsPanel.hidden)return;if(result.error)throw result.error;await refreshInvitations();await refreshJoined()}
          catch{if(operation===invitationsRequest&&!invitationsPanel.hidden)invitationsMessage.textContent='Could not respond. The invitation may no longer be available.'}
          finally{for(const item of actions.querySelectorAll('button'))item.disabled=false}
        });actions.append(button);
      }
      card.append(title,detail,actions);invitationsList.append(card);
    }
    if(data.length)invitationsCursor={created_at:data[data.length-1].created_at,id:data[data.length-1].id};
    invitationsMore.hidden=data.length<25;invitationsMessage.textContent=invitationsList.childElementCount?'':'No group invitations.';
  }catch{if(request===invitationsRequest&&!invitationsPanel.hidden)invitationsMessage.textContent='Invitations unavailable. Complete account setup or try again later.'}
}
invitationsMore.addEventListener('click',()=>refreshInvitations(true));
let groupsRequest=0,groupsCursor=null;
const groupsPanel=document.querySelector('#my-groups'),groupsForm=document.querySelector('#group-form'),groupsList=document.querySelector('#group-list'),groupsMessage=document.querySelector('#group-message'),groupsMore=document.querySelector('#groups-more');
async function refreshGroups(append=false){
  const request=++groupsRequest;if(!client||groupsPanel.hidden)return;
  if(!append){groupsCursor=null;groupsList.replaceChildren()}
  groupsMore.hidden=true;groupsMessage.textContent='Loading groups…';
  try{
    const {data,error}=await client.rpc('list_own_created_groups',{p_after:append?groupsCursor?.created_at??null:null,p_after_id:append?groupsCursor?.id??null:null});
    if(request!==groupsRequest||groupsPanel.hidden)return;
    if(error||!Array.isArray(data))throw error||new Error('Invalid groups');
    for(const group of data){
      const card=document.createElement('article');card.className='setup-step';const title=document.createElement('strong');title.textContent=group.name;
      const subtitle=document.createElement('span');subtitle.textContent=`${group.lga_name} · Private group`;
      const description=document.createElement('p');description.textContent=group.description;
      const actions=document.createElement('div');actions.className='note-actions';
      const edit=document.createElement('button');edit.type='button';edit.className='note-action';edit.textContent='Edit';
      const archive=document.createElement('button');archive.type='button';archive.className='note-action destructive';archive.textContent='Archive';
      const invite=document.createElement('button');invite.type='button';invite.className='note-action';invite.textContent='Invite';
      invite.addEventListener('click',()=>{
        actions.hidden=true;const form=document.createElement('form');const label=document.createElement('label');label.textContent='Find by exact username';
        const field=document.createElement('input');field.required=true;field.minLength=3;field.maxLength=30;field.autocomplete='off';field.setAttribute('autocapitalize','none');label.append(field);
        const note=document.createElement('p');note.textContent='Only people in this LGA who allow discovery and member contact may appear.';
        const find=document.createElement('button');find.type='submit';find.className='small-action';find.textContent='Find person';
        const cancel=document.createElement('button');cancel.type='button';cancel.className='note-action';cancel.textContent='Cancel';
        const resultBox=document.createElement('div');resultBox.setAttribute('aria-live','polite');
        cancel.addEventListener('click',()=>{form.remove();actions.hidden=false});
        form.addEventListener('submit',async(event)=>{
          event.preventDefault();const handle=field.value.trim().toLowerCase();resultBox.replaceChildren();
          if(!/^[a-z0-9_]{3,30}$/.test(handle)){resultBox.textContent='Enter a valid username.';return}
          const operation=groupsRequest;find.disabled=true;resultBox.textContent='Searching…';
          try{
            const result=await client.rpc('find_group_invitee',{p_group_id:group.id,p_handle:handle});
            if(operation!==groupsRequest||groupsPanel.hidden||!form.isConnected)return;
            if(result.error||!Array.isArray(result.data))throw result.error||new Error('Invalid result');resultBox.replaceChildren();
            if(!result.data.length){resultBox.textContent='No available person found.';return}
            const person=result.data[0],display=document.createElement('p');display.textContent=`${person.display_name||person.handle} · @${person.handle}`;
            const send=document.createElement('button');send.type='button';send.className='small-action';send.textContent='Send invitation';
            send.addEventListener('click',async()=>{
              const sentAt=groupsRequest;send.disabled=true;resultBox.append(document.createTextNode(' Sending…'));
              try{const response=await client.rpc('invite_to_own_group',{p_group_id:group.id,p_invitee_id:person.user_id});if(sentAt!==groupsRequest||groupsPanel.hidden||!form.isConnected)return;if(response.error)throw response.error;resultBox.textContent='Request processed. Delivery depends on the person’s current settings.'}
              catch{if(sentAt===groupsRequest&&!groupsPanel.hidden&&form.isConnected)resultBox.textContent='Could not process the invitation. Please try again.'}
              finally{send.disabled=false}
            });resultBox.append(display,send);
          }catch{if(operation===groupsRequest&&!groupsPanel.hidden&&form.isConnected)resultBox.textContent='Search unavailable. Please try again later.'}
          finally{find.disabled=false}
        });
        form.append(label,note,find,cancel,resultBox);card.append(form);field.focus();
      });
      edit.addEventListener('click',()=>{
        const form=document.createElement('form'),nameLabel=document.createElement('label'),descriptionLabel=document.createElement('label');
        nameLabel.textContent='Group name';const name=document.createElement('input');name.value=group.name;name.required=true;name.maxLength=120;nameLabel.append(name);
        descriptionLabel.textContent='Description';const details=document.createElement('textarea');details.value=group.description;details.maxLength=1000;descriptionLabel.append(details);
        const save=document.createElement('button');save.type='submit';save.className='small-action';save.textContent='Save changes';
        const cancel=document.createElement('button');cancel.type='button';cancel.className='note-action';cancel.textContent='Cancel';
        cancel.addEventListener('click',()=>{form.remove();title.hidden=false;subtitle.hidden=false;description.hidden=false;actions.hidden=false});
        form.addEventListener('submit',async(event)=>{
          event.preventDefault();const cleanName=name.value.trim(),cleanDescription=details.value.trim();if(!cleanName){groupsMessage.textContent='Enter a group name.';return}
          const operation=groupsRequest;save.disabled=true;groupsMessage.textContent='Saving group…';
          try{const result=await client.rpc('update_own_group',{p_group_id:group.id,p_name:cleanName,p_description:cleanDescription});if(operation!==groupsRequest||groupsPanel.hidden)return;if(result.error)throw result.error;await refreshGroups()}
          catch{if(operation===groupsRequest&&!groupsPanel.hidden)groupsMessage.textContent='Could not save changes. Please try again.'}
          finally{save.disabled=false}
        });
        form.append(nameLabel,descriptionLabel,save,cancel);title.hidden=true;subtitle.hidden=true;description.hidden=true;actions.hidden=true;card.append(form);name.focus();
      });
      archive.addEventListener('click',async()=>{
        if(!window.confirm('Archive this group? It will be hidden from your active list, but its data is not deleted.'))return;
        const operation=groupsRequest;archive.disabled=true;groupsMessage.textContent='Archiving group…';
        try{const result=await client.rpc('archive_own_group',{p_group_id:group.id});if(operation!==groupsRequest||groupsPanel.hidden)return;if(result.error)throw result.error;await refreshGroups()}
        catch{if(operation===groupsRequest&&!groupsPanel.hidden)groupsMessage.textContent='Could not archive the group. Please try again.'}
        finally{archive.disabled=false}
      });
      actions.append(edit,invite,archive);card.append(title,subtitle,description,actions);groupsList.append(card);
    }
    if(data.length)groupsCursor={created_at:data[data.length-1].created_at,id:data[data.length-1].id};
    groupsMore.hidden=data.length<25;groupsMessage.textContent=groupsList.childElementCount?'':'No groups created yet.';
  }catch{if(request===groupsRequest&&!groupsPanel.hidden)groupsMessage.textContent='Groups unavailable. Complete account setup or try again later.'}
}
groupsMore.addEventListener('click',()=>refreshGroups(true));
groupsForm.addEventListener('submit',async(event)=>{
  event.preventDefault();if(!client||groupsPanel.hidden)return;
  const name=groupsForm.elements.name.value.trim(),description=groupsForm.elements.description.value.trim();
  if(!name||name.length>120||description.length>1000){groupsMessage.textContent='Please check your group details.';return}
  const request=groupsRequest,button=groupsForm.querySelector('button');button.disabled=true;groupsMessage.textContent='Creating group…';
  try{
    const result=await client.rpc('create_group_in_own_lga',{p_name:name,p_description:description});
    if(request!==groupsRequest||groupsPanel.hidden)return;if(result.error)throw result.error;
    groupsForm.reset();await refreshGroups();
  }catch{if(request===groupsRequest&&!groupsPanel.hidden)groupsMessage.textContent='Could not create the group. Check your account setup and try again.'}
  finally{button.disabled=false}
});
let profileRequest=0;
const profilePanel=document.querySelector('#profile-editor'),profileForm=document.querySelector('#profile-form'),profileMessage=document.querySelector('#profile-message');
async function refreshProfile(){
  const request=++profileRequest;if(!client||profilePanel.hidden)return;
  profileForm.hidden=true;profileMessage.textContent='Loading profile…';
  try{
    const {data,error}=await client.from('profiles').select('handle,display_name,biography').maybeSingle();
    if(request!==profileRequest||profilePanel.hidden)return;
    if(error||!data)throw error||new Error('Profile unavailable');
    const lga=await client.rpc('get_own_lga');if(request!==profileRequest||profilePanel.hidden)return;if(lga.error)throw lga.error;
    document.querySelector('#profile-lga').textContent=Array.isArray(lga.data)&&lga.data[0]?`Local government: ${lga.data[0].name}`:'Local government not selected yet.';
    profileForm.elements.handle.value=data.handle??'';
    profileForm.elements.displayName.value=data.display_name??'';
    profileForm.elements.biography.value=data.biography??'';
    profileForm.hidden=false;profileMessage.textContent='';
  }catch{if(request===profileRequest&&!profilePanel.hidden)profileMessage.textContent='Profile unavailable. Complete account setup or try again later.'}
}
profileForm.elements.handle.addEventListener('input',()=>{profileForm.elements.handle.value=profileForm.elements.handle.value.toLowerCase()});
profileForm.addEventListener('submit',async(event)=>{
  event.preventDefault();if(!client||profilePanel.hidden)return;
  const handle=profileForm.elements.handle.value.trim().toLowerCase(),name=profileForm.elements.displayName.value.trim(),biography=profileForm.elements.biography.value.trim();
  if(!/^[a-z0-9_]{3,30}$/.test(handle)||name.length<1||name.length>80||biography.length>500){profileMessage.textContent='Please check your profile details.';return}
  const request=profileRequest,button=profileForm.querySelector('button');button.disabled=true;profileMessage.textContent='Saving profile…';
  try{
    const result=await client.rpc('update_own_profile',{p_handle:handle,p_display_name:name,p_biography:biography});
    if(request!==profileRequest||profilePanel.hidden)return;
    if(result.error){profileMessage.textContent=result.error.code==='23505'?'That username is not available. Please choose another.':'Could not save your profile. Please try again.';return}
    profileForm.elements.handle.value=handle;profileForm.elements.displayName.value=name;profileForm.elements.biography.value=biography;profileMessage.textContent='Profile saved.';
  }catch{if(request===profileRequest&&!profilePanel.hidden)profileMessage.textContent='Could not save your profile. Please try again.'}
  finally{button.disabled=false}
});
let privacyRequest=0;
const privacyPanel=document.querySelector('#privacy'), privacyForm=document.querySelector('#privacy-form'), privacyMessage=document.querySelector('#privacy-message');
async function refreshPrivacy(){
  const request=++privacyRequest;
  if(!client||privacyPanel.hidden)return;
  privacyForm.hidden=true;privacyMessage.textContent='Loading settings…';
  try{
    const {data,error}=await client.rpc('get_own_privacy_settings');
    if(request!==privacyRequest||privacyPanel.hidden)return;
    const settings=Array.isArray(data)&&data.length===1?data[0]:null;
    if(error||!settings||!['private','friends','public'].includes(settings.profile_visibility)||!['nobody','friends','members'].includes(settings.contact_permission))throw error||new Error('Invalid settings');
    privacyForm.elements.profile.value=settings.profile_visibility;
    privacyForm.elements.contact.value=settings.contact_permission;
    privacyForm.hidden=false;privacyMessage.textContent='';
  }catch{if(request===privacyRequest&&!privacyPanel.hidden)privacyMessage.textContent='Settings are unavailable. Complete account setup or try again later.'}
}
privacyForm.addEventListener('submit',async(event)=>{
  event.preventDefault();if(!client||privacyPanel.hidden)return;
  const request=privacyRequest,button=privacyForm.querySelector('button');button.disabled=true;privacyMessage.textContent='Saving…';
  try{
    const result=await client.rpc('update_own_privacy_settings',{p_profile_visibility:privacyForm.elements.profile.value,p_contact_permission:privacyForm.elements.contact.value});
    if(request!==privacyRequest||privacyPanel.hidden)return;
    if(result.error)throw result.error;
    privacyMessage.textContent='Settings saved. Full privacy enforcement is still being built.';
  }catch{if(request===privacyRequest&&!privacyPanel.hidden)privacyMessage.textContent='Could not save settings. Please try again.'}
  finally{button.disabled=false}
});
let blockRequest=0, blockCursor=null;
const blockPanel=document.querySelector('#blocks'), blockList=document.querySelector('#block-list'), blockMessage=document.querySelector('#blocks-message'), blockMore=document.querySelector('#blocks-more');
async function refreshBlocks(append=false){
  const request=++blockRequest;
  if(!client||blockPanel.hidden)return;
  if(!append){blockCursor=null;blockList.replaceChildren()}
  blockMore.hidden=true;blockMessage.textContent='Loading blocked accounts…';
  try{
    const {data,error}=await client.rpc('list_own_blocks',{p_after:append?blockCursor:null});
    if(request!==blockRequest||blockPanel.hidden)return;
    if(error||!Array.isArray(data))throw error||new Error('Invalid block list');
    for(const block of data){
      const row=document.createElement('div');row.className='setup-step';
      const label=document.createElement('span');label.textContent=`Account ID: ${block.blocked_id}`;
      const button=document.createElement('button');button.type='button';button.className='small-action';button.textContent='Remove block';
      button.addEventListener('click',async()=>{
        if(!window.confirm('Remove this block record? Blocks are not yet enforced across the app.'))return;
        const operation=blockRequest;button.disabled=true;blockMessage.textContent='Removing block…';
        try{const result=await client.rpc('unblock_user',{p_target_id:block.blocked_id});if(operation!==blockRequest||blockPanel.hidden)return;if(result.error)throw result.error;await refreshBlocks()}
        catch{if(operation===blockRequest&&!blockPanel.hidden)blockMessage.textContent='Could not remove the block. Please try again.'}
        finally{button.disabled=false}
      });
      row.append(label,button);blockList.append(row);
    }
    blockCursor=data.length?data[data.length-1].blocked_id:blockCursor;
    blockMore.hidden=data.length<50;
    blockMessage.textContent=blockList.childElementCount?'':'No blocked accounts recorded.';
  }catch{if(request===blockRequest&&!blockPanel.hidden)blockMessage.textContent='Block list unavailable. Complete onboarding or try again later.'}
}
blockMore.addEventListener('click',()=>refreshBlocks(true));
dialog.showModal();
if(client){client.auth.getSession().then(({data})=>{setSignedIn(Boolean(data.session));if(data.session&&dialog.open)dialog.close()}).catch(()=>{});client.auth.onAuthStateChange((_event,session)=>{setTimeout(()=>{setSignedIn(Boolean(session));if(!session&&!dialog.open)dialog.showModal()},0)})}
