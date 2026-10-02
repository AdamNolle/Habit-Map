/* Deterministic frame painter for an explicitly illustrative product preview. */
const canvas = document.getElementById('frame');
const c = canvas.getContext('2d', { alpha: false });
const W = 1920, H = 1080, FPS = 30, SHOT = 2320;
const C = { dark:'#0a0c0b', ink:'#f1f0ea', muted:'#a8ada6', quiet:'#82877e', line:'#26382b', green:'#3dff7f', dim:'#1d3023', fill:'#1d7a3b', paper:'#ecece3', deep:'#0f1912' };
const insight = new Image(); insight.src = '../assets/insight-snapshot.png';
const widget = new Image(); widget.src = '../../Packages/HabitMapCore/Tests/HabitMapCoreTests/__Snapshots__/HabitWidgetViewSnapshotTests/test_compact_allDoneToday.1.png';
const clamp = (n,a=0,b=1)=>Math.max(a,Math.min(b,n));
const smooth = x=>{ x=clamp(x); return x*x*(3-2*x); };
const lerp = (a,b,t)=>a+(b-a)*t;
function box(x,y,w,h,color,r=0){c.fillStyle=color;c.beginPath();c.roundRect(x,y,w,h,r);c.fill()}
function rule(x,y,w,color=C.line){box(x,y,w,2,color)}
function txt(body,x,y,size,color=C.ink,font='Segoe UI',weight=400,align='left'){
  c.fillStyle=color;c.font=`${weight} ${size}px ${font}`;c.textAlign=align;c.textBaseline='alphabetic';c.fillText(body,x,y);
}
function mono(body,x,y,size=18,color=C.quiet,align='left'){txt(body,x,y,size,color,'Consolas',400,align)}
function header(x,no,title,light=false){let ink=light?'#135d2b':C.green;rule(x-810,100,1620,ink);mono(`${no} / ${title}`,x-810,145,19,ink);mono('PRODUCT PREVIEW  •  ILLUSTRATIVE VISUALS',x-810,1015,16,light?'#13602d':C.quiet)}
function grid(x,y,cols,rows,size,gap,progress,variant=0){
  for(let col=0;col<cols;col++)for(let row=0;row<rows;row++){
    const idx=col*rows+row;
    const active=(idx*17+row*11+variant*19)%9!==0;
    let tone=C.dim;
    if(active && progress>((idx*23+variant*37)%100)/100)tone=(idx+row)%12===0?C.green:C.fill;
    box(x+col*(size+gap),y+row*(size+gap),size,size,tone,Math.max(2,size*.10));
  }
}
function scene0(x,t){
  header(x,'00','AN ATLAS OF SMALL DAYS');
  const reveal=smooth((t-.2)/1.2), title=smooth((t-.6)/1.25);
  [[0,0],[64,0],[0,64],[64,64]].forEach(([dx,dy],i)=>{
    const scale=smooth((t-.2-i*.16)/.6); if(!scale)return;
    const d=48*scale;
    box(x-805+dx+(48-d)/2,242+dy+(48-d)/2,d,d,i===0||i===3?C.green:'#22452d',5);
  });
  c.save();c.beginPath();c.rect(x-820,360,1580*title,340);c.clip();
  txt('HABIT MAP',x-810,595,205,C.ink,'Segoe UI',700);c.restore();
  mono('A GENTLER RECORD OF SHOWING UP',x-800,675,28,C.green);
  rule(x-810,758,1600,C.line);
  mono('IN DEVELOPMENT  /  NO APP FOOTAGE IN THIS PREVIEW',x-800,818,21,C.muted);
  for(let i=0;i<24;i++)box(x-790+i*72,918,37,37,i%5<Math.round(reveal*5)?C.fill:C.dim,5);
}
function scene1(x,t){
  header(x,'01','MAKE ROOM FOR RETURN');
  const enter=smooth((t-3.2)/1.1), offset=lerp(95,0,enter);
  txt('Make room',x-810,460+offset,172,C.ink,'Segoe UI',400);
  txt('for return.',x-805,675+offset,181,C.green,'Georgia',400);
  txt('Mark a day. Find a rhythm. Come back when you can.',x-796,800,38,C.muted);
  for(let col=0;col<20;col++){
    const lit=smooth((t-4.6-col*.1)/.7);
    box(x-800+col*83,880,57,57,lit>.5?(col%6===0?C.green:C.fill):C.dim,7);
  }
}
function scene2(x,t){
  header(x,'02','THE LONGER VIEW');
  txt('Today becomes',x-810,345,123,C.ink);
  txt('an atlas.',x-805,535,155,C.green,'Georgia');
  mono('PAGES  /  DAY DETAIL  /  CALENDAR HEATMAP',x-800,603,23,C.muted);
  box(x-820,655,1640,230,C.deep,15);
  const progress=smooth((t-9.4)/7.4);
  grid(x-782,691,43,5,25,11,progress,2);
  mono('ILLUSTRATIVE CALENDAR PATTERN  /  NATIVE COMPONENT IMPLEMENTED IN APP SOURCE',x-800,940,17,C.muted);
}
function scene3(x,t){
  header(x,'03','INSIGHT / SOURCE EVIDENCE');
  txt('Notice the',x-810,350,128,C.ink);
  txt('patterns.',x-805,538,163,C.green,'Georgia');
  txt('Native UI component snapshots from the app’s test suite.',x-800,610,34,C.muted);
  box(x-810,670,1610,240,C.line,14);box(x-806,674,1602,232,C.dark,11);
  const slide=lerp(100,0,smooth((t-18.6)/1.2));
  if(insight.complete) c.drawImage(insight,x-783,700+slide,1198,211);
  if(widget.complete) c.drawImage(widget,x+505,650-slide,255,255);
  mono('EXAMPLE TEST DATA  •  NOT RECORDED APP INTERACTION',x-800,963,22,C.green);
}
function scene4(x,t){
  box(x-1000,0,2000,1080,C.green);
  rule(x-810,100,1620,'#16883c');
  mono('04 / KEEP THE DOOR OPEN',x-810,145,19,'#135b2a');
  const rise=lerp(80,0,smooth((t-26.4)/1.2));
  txt('The next day',x-810,440+rise,175,'#0d2714');
  txt('is yours.',x-805,670+rise,220,C.ink,'Georgia');
  rule(x-800,774,1550,'#16883c');
  mono('FOLLOW DEVELOPMENT  ↗  GITHUB.COM/ADAMNOLLE/HABIT-MAP',x-795,837,26,'#135b2a');
  mono('ILLUSTRATIVE PRODUCT PREVIEW  /  APP FOOTAGE TO FOLLOW',x-810,1015,16,'#135b2a');
  for(let i=0;i<7;i++)for(let j=0;j<7;j++)box(x+490+i*65,200+j*65,32,32,(i+j)%3?'#2bb95a':'#69ff99',3);
}
function camera(t){
  const phases=[[0,0],[3.5,0],[4.1,1],[8.6,1],[9.3,2],[17.5,2],[18.3,3],[25.5,3],[26.3,4],[34,4]];
  for(let i=1;i<phases.length;i++)if(t<phases[i][0]){
    let[a,k]=phases[i-1],[b,l]=phases[i];return lerp(k,l,smooth((t-a)/(b-a)))*SHOT;
  }
  return 4*SHOT;
}
window.renderFrame=function(frame){
  const t=frame/FPS;
  c.fillStyle=C.dark;c.fillRect(0,0,W,H);
  c.save();c.translate(W/2-camera(t),0);
  scene0(0,t);scene1(SHOT,t);scene2(SHOT*2,t);scene3(SHOT*3,t);scene4(SHOT*4,t);
  c.restore();
  // Fine cinema grain, deterministic per frame and visually subordinate to the type.
  c.globalAlpha=.035;c.fillStyle='#ffffff';
  for(let i=0;i<330;i++){let q=(frame*1103515245+i*7919)>>>0;c.fillRect(q%W,(q*1664525>>>0)%H,1,1)}
  c.globalAlpha=1;
};
window.renderFrame(0);
