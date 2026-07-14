import { serverManager } from './src/server-manager.js';
import { call_function } from './src/tools/query-tools.js';
import fs from 'fs';

async function main() {
  await serverManager.loadConfig();
  await serverManager.setActiveServer('sandbox-new');
  
  const sourceCode = fs.readFileSync('../ZMAP_TYPE.abap', 'utf-8');
  const sourceLines = sourceCode.split(/\r?\n/);
  
  const itSource = sourceLines.map(line => ({ LINE: line }));

  console.log(`Pushing ${itSource.length} lines to ZMAP_TYPE...`);

  const result = await call_function({
    function_name: 'Z_RFC_PROGRAM_UPDATE',
    parameters: {
      IV_PROGRAM_NAME: 'ZMAP_TYPE',
      IV_PACKAGE: '$TMP', // Usually sandbox uses local object or whatever it is
      IT_SOURCE: itSource
    }
  });

  if (result.result) {
    console.log('Success:', result.result.EV_SUCCESS);
    console.log('Message:', result.result.EV_MESSAGE);
  } else {
    console.log('Result:', result);
  }
}

main().catch(console.error);
