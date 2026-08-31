/**
 * packaging plugin for OpenCode.ai
 *
 * Auto-registers the skills directory via the config hook (no symlinks needed).
 *
 * Unlike superpowers, this plugin injects no per-session bootstrap context.
 * The packaging skills are task-triggered — you reach for them when building or
 * auditing a marketplace repo — so OpenCode's native `skill` tool discovering
 * them is all that is needed.
 */

import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const PackagingPlugin = async () => {
  const packagingSkillsDir = path.resolve(__dirname, '../../skills');

  return {
    // Inject skills path into live config so OpenCode discovers packaging
    // skills without requiring manual symlinks or config file edits.
    // This works because Config.get() returns a cached singleton — modifications
    // here are visible when skills are lazily discovered later.
    config: async (config) => {
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      if (!config.skills.paths.includes(packagingSkillsDir)) {
        config.skills.paths.push(packagingSkillsDir);
      }
    },
  };
};
