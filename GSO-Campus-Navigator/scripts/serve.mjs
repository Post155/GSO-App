import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../dist/',import.meta.url));
const types={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.json':'application/json; charset=utf-8','.svg':'image/svg+xml','.png':'image/png','.pdf':'application/pdf','.webmanifest':'application/manifest+json'};
const server=http.createServer(async(req,res)=>{try{if(!['GET','HEAD'].includes(req.method)){res.writeHead(405);res.end();return}let pathname=decodeURIComponent(new URL(req.url,'http://localhost').pathname);let file=path.resolve(root,'.'+pathname);if(file!==path.resolve(root)&&!file.startsWith(root)){res.writeHead(403);res.end();return}if(pathname.endsWith('/'))file=path.join(file,'index.html');let body=await fs.readFile(file);res.writeHead(200,{'Content-Type':types[path.extname(file)]||'application/octet-stream','X-Content-Type-Options':'nosniff','Cache-Control':'no-cache'});res.end(req.method==='HEAD'?undefined:body)}catch{res.writeHead(404,{'Content-Type':'text/plain; charset=utf-8'});res.end('Datei nicht gefunden')}});
server.listen(4173,'127.0.0.1',()=>console.log('GSO Navigator: http://localhost:4173 · Beenden mit Strg+C'));
