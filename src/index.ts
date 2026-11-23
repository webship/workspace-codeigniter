/**
 * CodeIgniter for Webship Workspace: a platform plugin.
 *
 * What the package carries is placed by the installer from the manifest: the builder and the
 * spark tool in the sites folders, their functions and argparse under core/scripts/plugins/codeigniter/,
 * and its AI items (ai/ in this package) in the folder of their kind: the agents in AI Agents, the skill
 * in AI Skills, the command in AI Commands, the prompts in AI Prompts. The dashboard needs nothing drawn
 * for it: the builder is in the Build list because it is a cmd-*-project.sh, the row menus are the
 * core's, the AI items are listed like any other. What register() adds is what the assistant is told.
 *
 * Everything the dashboard is asked for goes through `api`; this package requires nothing from the
 * dashboard's own files, so it can be installed from npm and removed without a trace.
 */

import type { PluginApi } from '@webship.co/workspace-plugin-api';

/** The plugin's name. A CodeIgniter project has the DDEV project type php: the plugin knows it by its files. */
export const PLATFORM = 'codeigniter';

/** The commands the installer places in every sites folder. */
export const COMMANDS = ['cmd-codeigniter-project.sh', 'cmd-tools-codeigniter-spark.sh'];

/** The agents the installer places in the AI Agents folder. */
export const AGENTS = ['codeigniter-site-builder', 'codeigniter-tester'];

/** The skill the installer places in the AI Skills folder (a folder each, with its SKILL.md). */
export const SKILLS = ['codeigniter-scenarios'];

/** The slash command the installer places in the AI Commands folder. */
export const AI_COMMANDS = ['codeigniter-test'];

/** The prompts the installer places in the AI Prompts folder: each a whole launch command for a new session. */
export const PROMPTS = ['codeigniter-build-and-test', 'codeigniter-scenarios-for-a-group'];

/** What the assistant is told about CodeIgniter in this workspace. */
export function assistantContext(): string {
  return [
    'CodeIgniter (a plugin, @webship.co/workspace-codeigniter): a CodeIgniter app is built with',
    '`bash cmd-codeigniter-project.sh <name> --install --add-users --shield` from a sites folder (dev, test, sandboxes, demos),',
    'from the official app starter, with the official auth library (Shield) when `--shield` is given,',
    'in a container like every other project (project type php, docroot public): on DDEV by default, at https://<name>.ddev.site,',
    'or with `--runtime docker|podman|kubernetes|lando|docksal` on that runtime, at the address the build prints;',
    '`--production` runs it as a live app runs (no debug toolbar, the plain error pages).',
    '`bash cmd-tools-codeigniter-spark.sh <name>` says what the app is; `--run "<spark command>"` runs spark in it,',
    '`--update` updates its packages and migrates, `--environment development|production` switches the environment,',
    '`--add-users` adds the default accounts (admin, developer, user, banned; they need the auth library).',
    '`bash cmd-tools-testing.sh <name>` sets up webship-js with the CodeIgniter step pack; `--run` runs the suite.',
    `For CodeIgniter work, hand over to the agents ${AGENTS.map((a) => `\`${a}\``).join(' and ')}.`,
    `The plugin also places the skill ${SKILLS.map((a) => `\`${a}\``).join(', ')} (the step pack's phrases, by area) in ai-skills/,`,
    `the command ${AI_COMMANDS.map((a) => `\`/${a} <app>\``).join(', ')} in ai-commands/ and the prompts ${PROMPTS.map((a) => `\`${a}\``).join(' and ')} in ai-prompts/.`,
    'Never run php, composer or spark on the host for a project; the database settings in its .env are the container\'s own (db, db, db).',
  ].join(' ');
}

export function register(api: PluginApi): void {
  api.addAssistantContext(assistantContext);
}
