import { hapTasks, OhosHapContext, OhosPluginId } from '@ohos/hvigor-ohos-plugin';
import { hvigor } from '@ohos/hvigor';
import { existsSync, readFileSync } from 'fs';
import { resolve } from 'path';

// Local demo credentials are optional and must never enter release BuildProfile fields.
hvigor.afterNodeEvaluate((node) => {
  if (node.getNodeName() !== 'entry') {
    return;
  }
  const context = node.getContext(OhosPluginId.OHOS_HAP_PLUGIN) as OhosHapContext;
  if (!context || context.getBuildMode() !== 'debug') {
    return;
  }
  const localPath = resolve(context.getModulePath(), 'demo-login.local.json');
  if (!existsSync(localPath)) {
    return;
  }
  const local = JSON.parse(readFileSync(localPath, 'utf8')) as Record<string, unknown>;
  if (typeof local.DEMO_USERNAME !== 'string' || typeof local.DEMO_PASSWORD !== 'string') {
    throw new Error('demo-login.local.json requires string DEMO_USERNAME and DEMO_PASSWORD fields');
  }
  const profile = context.getBuildProfileOpt();
  const debug = profile.buildOptionSet?.find((option) => option.name === 'debug');
  if (!debug) {
    throw new Error('Missing debug buildOptionSet');
  }
  debug.arkOptions = debug.arkOptions || {};
  debug.arkOptions.buildProfileFields = {
    ...debug.arkOptions.buildProfileFields,
    DEMO_USERNAME: local.DEMO_USERNAME,
    DEMO_PASSWORD: local.DEMO_PASSWORD
  };
  context.setBuildProfileOpt(profile);
});

export default {
  system: hapTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: []       /* Custom plugin to extend the functionality of Hvigor. */
}
