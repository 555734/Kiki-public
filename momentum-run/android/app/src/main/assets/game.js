'use strict';

const canvas = document.getElementById('game');
const ctx = canvas.getContext('2d', { alpha:false });
const WORLD_H = 720;
let W=1280,H=720,dpr=1,scale=1;
function resize(){
  dpr=Math.min(window.devicePixelRatio||1,2);
  W=innerWidth; H=innerHeight;
  canvas.width=Math.round(W*dpr); canvas.height=Math.round(H*dpr);
  canvas.style.width=W+'px'; canvas.style.height=H+'px';
  scale=H/WORLD_H;
}
addEventListener('resize',resize,{passive:true}); resize();

const input={left:false,right:false,down:false,run:false,jump:false,jumpPressed:false,jumpReleased:false};
const keyMap={ArrowLeft:'left',KeyA:'left',ArrowRight:'right',KeyD:'right',ArrowDown:'down',KeyS:'down',ShiftLeft:'run',ShiftRight:'run',KeyX:'run',Space:'jump',KeyZ:'jump',ArrowUp:'jump'};
addEventListener('keydown',e=>{const k=keyMap[e.code];if(k){e.preventDefault(); if(k==='jump'&&!input.jump) input.jumpPressed=true;input[k]=true;}});
addEventListener('keyup',e=>{const k=keyMap[e.code];if(k){e.preventDefault(); if(k==='jump') input.jumpReleased=true;input[k]=false;}});
function bind(id,key){
  const el=document.getElementById(id); const touches=new Set();
  const on=e=>{e.preventDefault(); touches.add(e.pointerId); if(key==='jump'&&!input.jump)input.jumpPressed=true; input[key]=true;el.classList.add('active');try{el.setPointerCapture(e.pointerId)}catch(_){} };
  const off=e=>{e.preventDefault();touches.delete(e.pointerId);if(!touches.size){if(key==='jump'&&input.jump)input.jumpReleased=true;input[key]=false;el.classList.remove('active');}};
  el.addEventListener('pointerdown',on);el.addEventListener('pointerup',off);el.addEventListener('pointercancel',off);el.addEventListener('lostpointercapture',off);
}
bind('left','left');bind('right','right');bind('down','down');bind('run','run');bind('jump','jump');

const level={width:6900, floor:600, rects:[
  {x:0,y:600,w:1500,h:200},{x:1560,y:600,w:900,h:200},{x:2520,y:600,w:1380,h:200},{x:3960,y:600,w:980,h:200},{x:5010,y:600,w:1890,h:200},
  {x:660,y:505,w:180,h:30},{x:930,y:445,w:170,h:30},{x:1220,y:390,w:170,h:30},
  {x:1800,y:500,w:220,h:30},{x:2130,y:420,w:210,h:30},
  {x:2750,y:500,w:180,h:30},{x:3030,y:430,w:190,h:30},{x:3300,y:345,w:220,h:30},
  {x:3680,y:260,w:48,h:340},
  {x:4260,y:490,w:180,h:30},{x:4550,y:405,w:200,h:30},{x:4860,y:315,w:48,h:285},
  {x:5250,y:490,w:160,h:30},{x:5480,y:420,w:160,h:30},{x:5710,y:350,w:160,h:30},{x:5940,y:280,w:160,h:30},
  {x:6280,y:355,w:48,h:245},{x:6470,y:455,w:180,h:30}
]};
const spawn={x:160,y:520};

const p={x:spawn.x,y:spawn.y,w:42,h:66,vx:0,vy:0,face:1,onGround:false,wasGround:false,coyote:0,jumpBuffer:0,jumpHold:0,wall:0,wallLock:0,jumpChain:0,chainTimer:0,landSpeed:0,skid:0,crouch:false,anim:0,stretch:0,invuln:0};
function reset(){Object.assign(p,{x:spawn.x,y:spawn.y,vx:0,vy:0,onGround:false,wasGround:false,coyote:0,jumpBuffer:0,jumpHold:0,wall:0,wallLock:0,jumpChain:0,chainTimer:0,skid:0,crouch:false});cam.x=0;}
document.getElementById('reset').onclick=reset;

function overlap(ax,ay,aw,ah,b){return ax<b.x+b.w&&ax+aw>b.x&&ay<b.y+b.h&&ay+ah>b.y;}
function nearWall(dir){
  const testX=p.x+dir*4;
  for(const r of level.rects) if(overlap(testX,p.y,p.w,p.h,r)) return true;
  return false;
}
function moveX(dt){
  p.x+=p.vx*dt;
  for(const r of level.rects){
    if(overlap(p.x,p.y,p.w,p.h,r)){
      if(p.vx>0) p.x=r.x-p.w; else if(p.vx<0) p.x=r.x+r.w;
      p.vx=0;
    }
  }
}
function moveY(dt){
  p.onGround=false; p.y+=p.vy*dt;
  for(const r of level.rects){
    if(overlap(p.x,p.y,p.w,p.h,r)){
      if(p.vy>0){p.y=r.y-p.h;p.vy=0;p.onGround=true;}
      else if(p.vy<0){p.y=r.y+r.h;p.vy=35;}
    }
  }
}
function approach(v,t,a){return v<t?Math.min(t,v+a):Math.max(t,v-a);}
function doJump(){
  if(p.onGround||p.coyote>0){
    const fast=Math.abs(p.vx)>360;
    if(p.chainTimer>0&&fast) p.jumpChain=Math.min(3,p.jumpChain+1); else p.jumpChain=1;
    const impulses=[0,720,790,900];
    p.vy=-impulses[p.jumpChain]; p.onGround=false;p.coyote=0;p.jumpHold=.18;p.chainTimer=0;p.stretch=.16;
  } else if(p.wall){
    p.vy=-760; p.vx=-p.wall*510; p.face=-p.wall; p.wallLock=.12; p.jumpHold=.14; p.jumpChain=1;p.stretch=.16;
  }
}
function update(dt){
  p.wasGround=p.onGround;
  if(input.jumpPressed) p.jumpBuffer=.12;
  else p.jumpBuffer=Math.max(0,p.jumpBuffer-dt);
  p.coyote=p.onGround?.085:Math.max(0,p.coyote-dt);
  p.chainTimer=Math.max(0,p.chainTimer-dt);
  p.wallLock=Math.max(0,p.wallLock-dt);
  p.stretch=Math.max(0,p.stretch-dt);

  const dir=(input.right?1:0)-(input.left?1:0);
  const max=input.run?510:320;
  const accel=p.onGround?(input.run?1550:1250):830;
  const braking=p.onGround?2100:980;
  if(p.wallLock<=0){
    if(dir){
      if(Math.sign(p.vx)&&Math.sign(p.vx)!==dir&&Math.abs(p.vx)>180){p.skid=.12;p.vx=approach(p.vx,0,braking*dt);}
      else p.vx=approach(p.vx,dir*max,accel*dt);
      p.face=dir;
    } else p.vx=approach(p.vx,0,(p.onGround?1180:110)*dt);
  }
  p.skid=Math.max(0,p.skid-dt);
  p.crouch=input.down&&p.onGround&&Math.abs(p.vx)<150;

  if(p.jumpBuffer>0&&(p.onGround||p.coyote>0||p.wall)){doJump();p.jumpBuffer=0;}
  if(input.jump&&p.jumpHold>0&&p.vy<0){p.vy-=1150*dt;p.jumpHold-=dt;}else p.jumpHold=0;
  if(input.jumpReleased&&p.vy<-260)p.vy*=.52;

  const gravity=(p.vy<0&&input.jump)?1800:2350;
  p.vy=Math.min(p.vy+gravity*dt,1250);
  moveX(dt);
  p.wall=0;
  if(!p.onGround&&p.vy>0){if(nearWall(-1))p.wall=-1;else if(nearWall(1))p.wall=1;if(p.wall&&dir===p.wall)p.vy=Math.min(p.vy,210);}
  moveY(dt);

  if(!p.wasGround&&p.onGround){
    p.landSpeed=Math.abs(p.vx);
    if(p.landSpeed>300)p.chainTimer=.48; else {p.chainTimer=0;p.jumpChain=0;}
  }
  if(p.wasGround&&!p.onGround&&p.vy>=0)p.coyote=.085;
  if(p.y>920){reset();return;}
  p.x=Math.max(0,Math.min(level.width-p.w,p.x));
  p.anim+=dt*(2.5+Math.abs(p.vx)/80);
  cam.target=Math.max(0,Math.min(level.width-viewWorldW(),p.x-viewWorldW()*.38));
  cam.x+=(cam.target-cam.x)*(1-Math.pow(.0005,dt));
  input.jumpPressed=false;input.jumpReleased=false;
}

const cam={x:0,target:0};
function viewWorldW(){return W/scale;}

function roundRect(x,y,w,h,r){ctx.beginPath();ctx.roundRect(x,y,w,h,r);}
function drawBackground(){
  const vw=viewWorldW();
  const grad=ctx.createLinearGradient(0,0,0,WORLD_H);grad.addColorStop(0,'#78c8ff');grad.addColorStop(.72,'#c8efff');grad.addColorStop(1,'#eaf8ff');ctx.fillStyle=grad;ctx.fillRect(0,0,vw,WORLD_H);
  ctx.fillStyle='#ffffffcc';
  const cloud=(x,y,s)=>{ctx.beginPath();ctx.arc(x,y,36*s,0,Math.PI*2);ctx.arc(x+42*s,y-12*s,50*s,0,Math.PI*2);ctx.arc(x+93*s,y+1*s,34*s,0,Math.PI*2);ctx.fill();};
  for(let i=-1;i<8;i++){const x=i*380-(cam.x*.12%380);cloud(x,120+(i%3)*55,.65+(i%2)*.15)}
  ctx.fillStyle='#87c98d';ctx.beginPath();ctx.moveTo(0,555);for(let x=-100;x<vw+200;x+=260){const xx=x-(cam.x*.2%260);ctx.quadraticCurveTo(xx+130,390+(Math.sin((x+cam.x)*.003)*35),xx+260,555)}ctx.lineTo(vw,650);ctx.lineTo(0,650);ctx.fill();
  ctx.fillStyle='#5caf70';ctx.beginPath();ctx.moveTo(0,585);for(let x=-100;x<vw+200;x+=210){const xx=x-(cam.x*.34%210);ctx.quadraticCurveTo(xx+105,470+(Math.sin((x+cam.x)*.006)*25),xx+210,585)}ctx.lineTo(vw,650);ctx.lineTo(0,650);ctx.fill();
  for(let i=0;i<12;i++){const x=i*310-(cam.x*.48%310)-100;const y=565;ctx.fillStyle='#7b5a3a';ctx.fillRect(x,y-74,18,74);ctx.fillStyle='#387f4a';ctx.beginPath();ctx.arc(x+9,y-92,46,0,Math.PI*2);ctx.arc(x-20,y-64,32,0,Math.PI*2);ctx.arc(x+38,y-62,31,0,Math.PI*2);ctx.fill();}
}
function drawLevel(){
  for(const r of level.rects){
    if(r.x+r.w<cam.x-40||r.x>cam.x+viewWorldW()+40)continue;
    const x=r.x-cam.x;
    ctx.fillStyle=r.h>50?'#9a673b':'#815331';ctx.fillRect(x,r.y,r.w,r.h);
    ctx.fillStyle='#49a64f';ctx.fillRect(x,r.y,r.w,12);
    ctx.fillStyle='#79c45e';ctx.fillRect(x,r.y,r.w,5);
    if(r.h>50){ctx.fillStyle='#b17a48';for(let xx=x+18;xx<x+r.w;xx+=55){ctx.fillRect(xx,r.y+40+(Math.floor(xx/55)%2)*24,20,10)}}
  }
  const gx=6700-cam.x;if(gx>-80&&gx<viewWorldW()+80){ctx.fillStyle='#4c5360';ctx.fillRect(gx,430,15,170);ctx.fillStyle='#f5f1df';ctx.beginPath();ctx.moveTo(gx+15,438);ctx.lineTo(gx+88,458);ctx.lineTo(gx+15,480);ctx.closePath();ctx.fill();}
}
function drawPlayer(){
  const x=p.x-cam.x+p.w/2, y=p.y+p.h/2;
  ctx.save();ctx.translate(x,y);ctx.scale(p.face,1);
  if(p.skid>0)ctx.rotate(-p.face*.11);
  let sy=1,sx=1;if(p.stretch>0){sy=1.11;sx=.92}if(p.crouch){sy=.72;sx=1.14;ctx.translate(0,10)}
  if(p.jumpChain===3&&!p.onGround)ctx.rotate(Math.sin(p.anim*1.4)*.18);
  ctx.scale(sx,sy);
  ctx.fillStyle='#f3ead9';ctx.beginPath();ctx.arc(0,-21,15,0,Math.PI*2);ctx.fill();
  ctx.fillStyle='#20324d';ctx.beginPath();ctx.arc(4,-24,14,Math.PI,Math.PI*2);ctx.fill();
  ctx.fillStyle='#ee7b42';roundRect(-15,-7,30,34,8);ctx.fill();
  ctx.fillStyle='#20324d';roundRect(-13,18,26,15,5);ctx.fill();
  const stride=p.onGround?Math.sin(p.anim)*9:6;
  ctx.strokeStyle='#20324d';ctx.lineWidth=8;ctx.lineCap='round';
  ctx.beginPath();ctx.moveTo(-6,29);ctx.lineTo(-9-stride,45);ctx.moveTo(7,29);ctx.lineTo(9+stride,45);ctx.stroke();
  ctx.strokeStyle='#f3ead9';ctx.lineWidth=7;ctx.beginPath();ctx.moveTo(-12,0);ctx.lineTo(-20-stride*.4,17);ctx.moveTo(12,1);ctx.lineTo(20+stride*.4,16);ctx.stroke();
  ctx.fillStyle='#fff';ctx.beginPath();ctx.arc(5,-22,3,0,Math.PI*2);ctx.fill();ctx.fillStyle='#263241';ctx.beginPath();ctx.arc(6,-22,1.6,0,Math.PI*2);ctx.fill();
  ctx.restore();
}
function draw(){
  ctx.setTransform(dpr*scale,0,0,dpr*scale,0,0);ctx.clearRect(0,0,W/scale,H/scale);
  drawBackground();drawLevel();drawPlayer();
  ctx.fillStyle='#0d2037aa';roundRect(18,16,235,70,14);ctx.fill();ctx.fillStyle='#fff';ctx.font='700 18px system-ui';ctx.fillText('SPEED '+Math.round(Math.abs(p.vx)),34,44);ctx.font='700 15px system-ui';ctx.fillText(p.wall?'WALL':p.onGround?'GROUND':('JUMP '+Math.max(1,p.jumpChain)),34,69);
  if(p.x>6580){ctx.fillStyle='#0d2037cc';roundRect(viewWorldW()/2-150,125,300,82,18);ctx.fill();ctx.fillStyle='#fff';ctx.textAlign='center';ctx.font='800 28px system-ui';ctx.fillText('GOAL!',viewWorldW()/2,158);ctx.font='600 14px system-ui';ctx.fillText('RESETで最初から',viewWorldW()/2,185);ctx.textAlign='left';}
}

let last=performance.now(),acc=0;const STEP=1/120;
function frame(now){let dt=Math.min(.05,(now-last)/1000);last=now;acc+=dt;while(acc>=STEP){update(STEP);acc-=STEP;}draw();requestAnimationFrame(frame)}
requestAnimationFrame(frame);
