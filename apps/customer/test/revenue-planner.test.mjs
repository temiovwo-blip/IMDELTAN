import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {JSDOM} from 'jsdom';

const html=fs.readFileSync(new URL('../../../prototypes/business-revenue-planner.html',import.meta.url),'utf8');
const script=html.match(/<script>\s*([\s\S]*?)\s*<\/script>/)?.[1];
const ids=['businesses','price','refund','feePercent','feeFixed','hosting','support','marketing'];
const outputs=['gross','deductions','costs','net','breakEven'];
const money=n=>new Intl.NumberFormat('en-NG',{style:'currency',currency:'NGN',maximumFractionDigits:2,minimumFractionDigits:2}).format(n);
function setup(){
 const elements={};
 for(const id of ids){
  const tag=html.match(new RegExp(`<input id="${id}"[^>]*>`))?.[0];assert.ok(tag,`missing ${id}`);
  const value=tag.match(/value="([^"]+)"/)?.[1];assert.notEqual(value,undefined);
  elements[id]={value,initial:value,events:{},addEventListener(type,fn){this.events[type]=fn;}};
 }
 for(const id of [...outputs,'error'])elements[id]={textContent:''};
 elements.planner={events:{},addEventListener(type,fn){this.events[type]=fn;},reset(){for(const id of ids)elements[id].value=elements[id].initial;}};
 elements.reset={events:{},addEventListener(type,fn){this.events[type]=fn;}};
 assert.ok(script,'missing inline script');
 vm.runInNewContext(script,{document:{getElementById(id){assert.ok(elements[id],`unknown element ${id}`);return elements[id];}},Intl,Number,Object,Math});
 return elements;
}
function set(el,id,value){el[id].value=value;el[id].events.input();}

test('illustrative default values calculate gross, deductions, loss and break-even',()=>{
 const e=setup();assert.equal(e.gross.textContent,money(100000));assert.equal(e.deductions.textContent,money(3500));assert.equal(e.costs.textContent,money(120000));assert.equal(e.net.textContent,money(-23500));assert.equal(e.breakEven.textContent,'25');assert.equal(e.error.textContent,'');
});
test('calculates variable deductions, fixed fees, and a profitable scenario',()=>{
 const e=setup();set(e,'businesses','100');set(e,'feeFixed','100');assert.equal(e.gross.textContent,money(500000));assert.equal(e.deductions.textContent,money(27500));assert.equal(e.costs.textContent,money(120000));assert.equal(e.net.textContent,money(352500));assert.equal(e.breakEven.textContent,'26');
});
test('clears stale results for invalid input and recovers immediately',()=>{
 const e=setup();for(const value of ['','-1','1000001','1.5','NaN','Infinity','1.001','1e3']){set(e,'businesses',value);assert.notEqual(e.error.textContent,'');for(const id of outputs)assert.equal(e[id].textContent,'—');}
 set(e,'businesses','20');assert.equal(e.error.textContent,'');assert.equal(e.gross.textContent,money(100000));set(e,'refund','101');assert.notEqual(e.error.textContent,'');
});
test('zero or negative per-business contribution cannot break even',()=>{
 const e=setup();set(e,'feePercent','100');assert.match(e.breakEven.textContent,/Not achievable/);set(e,'feePercent','0');set(e,'feeFixed','6000');assert.match(e.breakEven.textContent,/Not achievable/);set(e,'price','0');assert.match(e.breakEven.textContent,/Not achievable/);
});
test('zero businesses, zero costs, and reset are handled',()=>{
 const e=setup();set(e,'businesses','0');assert.equal(e.gross.textContent,money(0));assert.equal(e.net.textContent,money(-120000));for(const id of ['hosting','support','marketing'])set(e,id,'0');assert.equal(e.breakEven.textContent,'0');e.reset.events.click();assert.equal(e.gross.textContent,money(100000));assert.equal(e.breakEven.textContent,'25');
});
test('standalone prototype has no network or browser-storage calls',()=>{
 assert.match(html,/Content-Security-Policy/);assert.match(html,/Illustrative only—not a forecast/);assert.doesNotMatch(script,/\b(fetch|XMLHttpRequest|WebSocket|localStorage|sessionStorage|sendBeacon)\b/);assert.doesNotMatch(html,/<(?:script|link|img)\b[^>]*(?:src|href)=["']https?:/i);
});

test('break-even uses exact decimal arithmetic rather than floating point',()=>{
 const e=setup();set(e,'refund','0');set(e,'feePercent','0');set(e,'feeFixed','0');set(e,'price','0.10');set(e,'hosting','0.30');set(e,'support','0');set(e,'marketing','0');assert.equal(e.breakEven.textContent,'3');
});

test('zero costs require zero customers even with no contribution',()=>{
 const e=setup();for(const id of ['hosting','support','marketing','price'])set(e,id,'0');assert.equal(e.breakEven.textContent,'0');
});

test('interactive HTML updates and resets in a simulated browser',()=>{
 const dom=new JSDOM(html,{runScripts:'dangerously'});
 try{
  const d=dom.window.document, field=d.getElementById('businesses');
  assert.equal(d.getElementById('gross').textContent,money(100000));
  field.value='50';field.dispatchEvent(new dom.window.Event('input',{bubbles:true}));
  assert.equal(d.getElementById('gross').textContent,money(250000));
  d.getElementById('reset').click();assert.equal(field.value,'20');assert.equal(d.getElementById('gross').textContent,money(100000));
 }finally{dom.window.close();}
});
