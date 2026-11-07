import {mountFriendsListDraft} from './friends-list-draft.js';
import {mountFriendRequestsDraft} from './friend-requests-draft.js';
import {mountDirectMessagesDraft} from './direct-messages-draft.js';
import {mountNotificationsDraft} from './notifications-draft.js';
import {mountSavedLgaPostsDraft} from './saved-lga-posts-draft.js';

// A deliberately opt-in development-only workspace. Not production ready.
export function mountSocialWorkspaceDraft(root,client,currentUserId,onOpenGroups=()=>{}){
 root.innerHTML='<section class="social-workspace"><div class="social-tabs" role="group" aria-label="Social sections"><button type="button" data-social-tab="friends">Friends</button><button type="button" data-social-tab="requests">Requests</button><button type="button" data-social-tab="messages">Messages</button><button type="button" data-social-tab="notifications">Notifications</button><button type="button" data-social-tab="saved">Saved</button></div><div data-social-panel="friends"></div><div data-social-panel="requests" hidden></div><div data-social-panel="messages" hidden></div><div data-social-panel="notifications" hidden></div><div data-social-panel="saved" hidden></div></section>';
 const panels=Object.fromEntries([...root.querySelectorAll('[data-social-panel]')].map(p=>[p.dataset.socialPanel,p]));let disposed=false;
 function show(tab){if(disposed||!panels[tab])return;for(const [key,panel] of Object.entries(panels))panel.hidden=key!==tab;for(const b of root.querySelectorAll('[data-social-tab]')){const selected=b.dataset.socialTab===tab;b.classList.toggle('active',selected);b.setAttribute('aria-pressed',String(selected))}}
 const messages=mountDirectMessagesDraft(panels.messages,client,currentUserId);
 const friends=mountFriendsListDraft(panels.friends,client,(id,name)=>{show('messages');messages.openFriend(id,name)},()=>messages.refresh());
 const requests=mountFriendRequestsDraft(panels.requests,client,()=>friends.refresh());
 const saved=mountSavedLgaPostsDraft(panels.saved,client);
 const notices=mountNotificationsDraft(panels.notifications,client,()=>{requests.refresh();show('requests')},id=>{show('messages');messages.openConversation(id)},onOpenGroups);
 for(const button of root.querySelectorAll('[data-social-tab]'))button.addEventListener('click',()=>{show(button.dataset.socialTab);if(button.dataset.socialTab==='notifications')notices.refresh();if(button.dataset.socialTab==='saved')saved.refresh()});
 show('friends');
 return {show:tab=>{show(tab);if(tab==='saved')saved.refresh()},dispose:()=>{disposed=true;friends.dispose();requests.dispose();messages.dispose();notices.dispose();saved.dispose();root.replaceChildren()}};
}
