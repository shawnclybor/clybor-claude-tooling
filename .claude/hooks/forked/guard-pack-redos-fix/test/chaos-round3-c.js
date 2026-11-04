const G=require('../lib/git-safety.js');
const GC='com'+'mit';
const cwd=require('fs').mkdtempSync(require('os').tmpdir()+'/c3-');
require('child_process').execFileSync('git',['-C',cwd,'init','-q','-b','feat']);
for (const [k,g] of [[3,'\n    '],[4,'\n    '],[5,'\n    '],[6,'\n        '],[8,'\n    '],[6,'  ']]) {
  const cmd=Array.from({length:k},(_,i)=>`export_${i}=1`).join(g)+g+'git '+GC+' -m x';
  const t=Date.now(); const r=G.checkCommand(cmd,null,'high',cwd); console.log(k,JSON.stringify(g),r.blocked,Date.now()-t,'ms');
}
