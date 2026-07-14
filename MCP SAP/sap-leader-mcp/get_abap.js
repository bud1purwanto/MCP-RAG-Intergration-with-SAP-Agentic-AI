import { serverManager } from './src/server-manager.js';
import { read_program } from './src/tools/abap-tools.js';
import fs from 'fs';

async function main() {
  await serverManager.loadConfig();
  const connectRes = await serverManager.setActiveServer('sandbox-new');
  console.log('Connect result:', connectRes);
  
  const result = await read_program({ program_name: 'ZMAP_TYPE' });
  if (result.source) {
    fs.writeFileSync('../ZMAP_TYPE.abap', result.source);
    console.log('Successfully saved to ZMAP_TYPE.abap');
  } else {
    console.log('Failed:', result);
  }
}

main().catch(console.error);
