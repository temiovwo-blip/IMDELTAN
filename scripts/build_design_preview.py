"""Generate an offline, example-only social design preview from customer source."""
from pathlib import Path
import base64
import re

root=Path(__file__).resolve().parents[1]
source=(root/'apps/customer/src/main.js').read_text()
paths=dict(re.findall(r"\b(home|explore|people|message|menu|bookmark|settings|help|mark|heart|share|bell):'([^']+)'",source))
template=source.split('root.innerHTML=`',1)[1].split('`;\nconst dialog',1)[0]
def icon(match):
    return '<svg class="ui-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'+paths[match.group(1)]+'</svg>'
template=re.sub(r"\$\{icon\('([^']+)'\)\}",icon,template)
if '${' in template: raise ValueError('Unexpected template expression')
for name in ('community.jpg','community-life.jpg','community-market.jpg','delta-cover.jpg'):
    encoded=base64.b64encode((root/'apps/customer/public'/name).read_bytes()).decode()
    template=template.replace('src="/'+name+'"','src="data:image/jpeg;base64,'+encoded+'"')
template=template.replace('<button id="signout" class="menu-signout" type="button" hidden>', '<button id="signout" class="menu-signout" type="button" disabled>')
css=(root/'apps/customer/src/style.css').read_text()
js="""const m=document.querySelector('#menu-dialog');document.querySelector('#open-menu').onclick=()=>m.showModal();document.querySelector('#close-menu').onclick=()=>m.close();m.onclick=e=>{if(e.target===m)m.close()};"""
html='<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>IMDELTAN social design preview</title><style>'+css+'\n.preview-banner{padding:10px 16px;text-align:center;background:#0a3466;color:white;font:600 12px system-ui;line-height:1.5} #auth-dialog{display:none} </style></head><body><div class="preview-banner">DESIGN PREVIEW · Sample content, not a live social feed</div><div id="app">'+template+'</div><script>'+js+'</script></body></html>'
(root/'prototypes/imdeltan-social-feed-preview.html').write_text(html)
