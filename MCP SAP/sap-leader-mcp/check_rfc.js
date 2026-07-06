import { serverManager } from './src/server-manager.js';
import { read_function_module } from './src/tools/abap-tools.js';

async function main() {
  await serverManager.loadConfig();
  await serverManager.setActiveServer('sandbox-new');
  
  const result = await read_function_module({ function_name: 'Z_RFC_PROGRAM_UPDATE' });
  console.log(JSON.stringify(result.interface, null, 2));
}

main().catch(console.error);
