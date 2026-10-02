import { mkdir, writeFile } from 'node:fs/promises';

const base = new URL('./', import.meta.url);
const out = new URL('./frames/', base);
await mkdir(out, { recursive: true });
const pages = await (await fetch('http://127.0.0.1:9222/json')).json();
const target = pages.find(page => page.type === 'page');
if (!target) throw new Error('No Edge page target on port 9222');
const socket = new WebSocket(target.webSocketDebuggerUrl);
let nextId = 0;
const pending = new Map();
await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject; });
socket.onmessage = ({ data }) => {
  const message = JSON.parse(data);
  if (!pending.has(message.id)) return;
  const { resolve, reject } = pending.get(message.id);
  pending.delete(message.id);
  if (message.error) reject(new Error(message.error.message)); else resolve(message.result);
};
function send(method, params={}) {
  const id=++nextId;
  return new Promise((resolve,reject)=>{pending.set(id,{resolve,reject});socket.send(JSON.stringify({id,method,params}));});
}
await send('Emulation.setDeviceMetricsOverride',{width:1920,height:1080,deviceScaleFactor:1,mobile:false});
await send('Page.enable');
await send('Page.navigate',{url:new URL('./motion.html',base).href});
await new Promise(resolve=>setTimeout(resolve,1200));
const ready=await send('Runtime.evaluate',{expression:'typeof window.renderFrame === "function" && [...document.images].every(i=>i.complete&&i.naturalWidth>0)',returnByValue:true});
if (!ready.result.value) throw new Error('Frame painter or source images did not load');
for(let frame=0;frame<1020;frame++){
  const painted=await send('Runtime.evaluate',{expression:`window.renderFrame(${frame})`,returnByValue:true});
  if(painted.exceptionDetails)throw new Error(`Painter failed at frame ${frame}: ${painted.exceptionDetails.text}`);
  const shot=await send('Page.captureScreenshot',{format:'jpeg',quality:88,captureBeyondViewport:false});
  await writeFile(new URL(`./frames/frame-${String(frame+1).padStart(4,'0')}.jpg`,base),Buffer.from(shot.data,'base64'));
  if(frame%100===0)console.log(`${frame+1}/1020 frames`);
}
socket.close();
