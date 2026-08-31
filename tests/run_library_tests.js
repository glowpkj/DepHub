const fs=require('node:fs');
const path=require('node:path');
const os=require('node:os');
const cp=require('node:child_process');
const root=path.resolve(__dirname,'..');
const luau=process.argv[2];
if(!luau) throw new Error('Usage: node tests/run_library_tests.js /path/to/luau');
function quote(value){let eq='=';while(value.includes(']'+eq+']'))eq+='=';return '['+eq+'['+value+']'+eq+']';}
function files(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(entry=>{const file=path.join(dir,entry.name);return entry.isDirectory()?files(file):file.endsWith('.lua')?[file]:[];});}
const paths=files(path.join(root,'library')).map(file=>path.relative(root,file).replaceAll('\\','/'));
const sources='local sources={\n'+paths.map(file=>`[ ${quote(file)} ]=${quote(fs.readFileSync(path.join(root,file),'utf8'))},`).join('\n')+'\n}';
const harness=fs.readFileSync(path.join(__dirname,'library_harness.luau'),'utf8').replace('-- INSERT_SOURCES',()=>sources);
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'dephub-library-test-'));const file=path.join(temp,'test.luau');
try{fs.writeFileSync(file,harness);const result=cp.spawnSync(luau,[file],{encoding:'utf8',timeout:30000});process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');if(result.error)throw result.error;process.exitCode=result.status===null?1:result.status;}
finally{if(fs.existsSync(file))fs.unlinkSync(file);fs.rmdirSync(temp);}
