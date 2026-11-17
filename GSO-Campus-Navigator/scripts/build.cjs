/** Buildless app: verify the release surface and generate a deterministic offline manifest. */
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),dist=path.join(root,'dist');
const html=fs.readFileSync(path.join(dist,'index.html'),'utf8');
const scripts=[...html.matchAll(/<script defer src="([^"]+)"/g)].map(m=>m[1]);
const core=['index.html','style.css','dashboard.css','manifest.webmanifest','assets/icon.svg','assets/campus-preview.svg','assets/eg-walls.png','assets/og-walls.png',...scripts,...fs.readdirSync(path.join(dist,'config')).filter(f=>f.endsWith('.json')).map(f=>'config/'+f)];
const hash=crypto.createHash('sha256');for(const file of core){let bytes=fs.readFileSync(path.join(dist,file));hash.update(file).update(bytes)}
const version=hash.digest('hex').slice(0,12);
let template=fs.readFileSync(path.join(root,'scripts/service-worker.template.js'),'utf8').replace('__VERSION__',version).replace('__FILES__',JSON.stringify(core));fs.writeFileSync(path.join(dist,'sw.js'),template);
console.log(JSON.stringify({release:version,scripts:scripts.length,offlineFiles:core.length}));
