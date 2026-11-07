import { defineConfig, loadEnv } from 'vite';

// This mode is for packaged, synthetic-only development experiments, not a
// release or permission to connect to real users. Server authorization remains
// mandatory; a build flag cannot enforce who is in a Supabase project.
const TEST_MODE='imdeltan-synthetic-apk';
const SYNTHETIC_PROJECT_REF='uxfyhpukeqttrvcfemts';
export default defineConfig(({command,mode})=>{
 const env=loadEnv(mode,process.cwd(),'');
 // Never let NODE_ENV make a standard build act like a development server.
 if(command==='build' && mode!==TEST_MODE && env.NODE_ENV && env.NODE_ENV!=='production'){
  throw new Error('Standard builds require NODE_ENV=production.');
 }
 if(mode===TEST_MODE){
  if(command!=='build')throw new Error('Synthetic APK mode is build-only.');
  const ref=env.IMDELTAN_SYNTHETIC_PROJECT_REF||'';
  const url=env.VITE_SUPABASE_URL||'';
  const key=env.VITE_SUPABASE_PUBLISHABLE_KEY||'';
  if(env.IMDELTAN_SYNTHETIC_ONLY_CONFIRM!=='SYNTHETIC-ONLY-ISOLATED-PROJECT' ||
     ref!==SYNTHETIC_PROJECT_REF || url!==`https://${SYNTHETIC_PROJECT_REF}.supabase.co` ||
     !/^sb_publishable_[A-Za-z0-9_-]{20,}$/.test(key) ||
     env.VITE_ENABLE_SOCIAL_DRAFTS!=='true'){
   throw new Error('Synthetic APK build refused: the dedicated test project and explicit synthetic-only confirmation are required. Never use production or the existing shared development project.');
  }
 }
 return {
  server:{host:'0.0.0.0',allowedHosts:true},preview:{host:'0.0.0.0',allowedHosts:true},
  plugins:mode===TEST_MODE?[{name:'imdeltan-synthetic-marker',generateBundle(){
   this.emitFile({type:'asset',fileName:'imdeltan-synthetic-test-only.json',source:'{"syntheticOnly":true,"version":1}\n'});
  }}]:[]
 };
});
