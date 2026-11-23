import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { spawnSync } from 'child_process';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const FUNCTIONS = path.join(PKG, 'scripts', 'functions', 'fun-codeigniter.sh');

// The cucumber.js webship-js scaffolds, as far as the testing hook reads it.
const SCAFFOLD = `module.exports = {
  default: {
    requireModule: ['ts-node/register'],
    require: [
      'node_modules/webship-js/tests/step-definitions/**/*.js',          // Webship-js core step definitions.
      'tests/step-definitions/**/*.js',                                  // Your custom step definitions.
    ],
    paths: ['tests/features/**/*.feature'],
    worldParameters: {
      launchUrl: process.env.LAUNCH_URL || 'http://localhost:8080',
    },
  },
};
`;

/**
 * A project folder with the testing stack scaffolded, and the tooling folder the installer would have filled.
 * A CodeIgniter app has the framework's spark script and app/Config/Paths.php; `shield` adds the auth library.
 */
function project(kind: 'codeigniter' | 'drupal', { shield = true } = {}) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'codeigniter-plugin-'));
  const dir = path.join(root, 'dev', 'site1');
  fs.mkdirSync(path.join(dir, '.ddev'), { recursive: true });
  fs.writeFileSync(path.join(dir, '.ddev', 'config.yaml'), `name: site1\ntype: ${kind === 'codeigniter' ? 'php' : 'drupal11'}\ndocroot: ${kind === 'codeigniter' ? 'public' : 'web'}\n`);
  if (kind === 'codeigniter') {
    fs.mkdirSync(path.join(dir, 'app', 'Config'), { recursive: true });
    fs.mkdirSync(path.join(dir, 'app', 'Database', 'Seeds'), { recursive: true });
    fs.mkdirSync(path.join(dir, 'writable'), { recursive: true });
    fs.writeFileSync(path.join(dir, 'app', 'Config', 'Paths.php'), '<?php\n');
    fs.writeFileSync(path.join(dir, 'spark'), '#!/usr/bin/env php\n<?php\n/*\n * CodeIgniter command-line tools\n */\n');
    if (shield) fs.mkdirSync(path.join(dir, 'vendor', 'codeigniter4', 'shield'), { recursive: true });
  }
  fs.writeFileSync(path.join(dir, 'cucumber.js'), SCAFFOLD);
  fs.writeFileSync(path.join(dir, 'package.json'), JSON.stringify({ name: 'site1', devDependencies: { 'webship-js': '^2.0.6' } }, null, 2));
  const scripts = path.join(root, 'core', 'scripts');
  fs.mkdirSync(path.join(scripts, 'plugins', 'codeigniter'), { recursive: true });
  fs.copyFileSync(path.join(PKG, 'testing', 'site.feature'), path.join(scripts, 'plugins', 'codeigniter', 'site.feature'));
  return { root, dir, scripts };
}

/** Run bash with the plugin's functions sourced and `ddev` replaced by a recorder that also logs the accounts a seeder would read. */
function bash(script: string, env: Record<string, string> = {}) {
  const fake = 'ddev() { echo "ddev $*" >> "${DDEV_LOG:-/dev/null}" ; if [ "$1" == "exec" ] && [ -f writable/webship-workspace-accounts.json ] ; then cat writable/webship-workspace-accounts.json >> "${DDEV_LOG:-/dev/null}" ; echo >> "${DDEV_LOG:-/dev/null}" ; fi ; return 0 ; }';
  const r = spawnSync('bash', ['-c', `${fake}\nsource ${FUNCTIONS}\n${script}`],
    { encoding: 'utf8', env: { ...process.env, ...env } });
  return r;
}

test('the default accounts are one per group that tells accounts apart and a banned one, with example addresses', () => {
  const r = bash('set_codeigniter_users ; for u in "${users[@]}" ; do n="user_${u}_name" ; m="user_${u}_mail" ; p="user_${u}_password" ; g="user_${u}_role" ; s="user_${u}_state" ; echo "${!n}|${!m}|${!p}|${!g}|${!s}" ; done');
  assert.strictEqual(r.status, 0, r.stderr);
  const rows = r.stdout.trim().split('\n').map((l) => l.split('|'));
  assert.deepStrictEqual(rows.map((x) => x[0]), ['admin', 'developer', 'user', 'banned']);
  assert.deepStrictEqual(rows.map((x) => x[3]), ['admin', 'developer', 'user', 'user']);
  assert.deepStrictEqual(rows.map((x) => x[4]), ['active', 'active', 'active', 'banned']);
  for (const [name, mail, password] of rows) {
    assert.strictEqual(mail, `${name}@example.com`);
    assert.ok(password.length >= 8, 'long enough for the password rules of the auth library');
  }
});

test('the accounts are written through the app by a seeder, with their group and state, and removed through it', () => {
  const p = project('codeigniter');
  const log = path.join(p.root, 'ddev.log');
  const env = { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log };
  let r = bash('set_codeigniter_users ; add_codeigniter_users', env);
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  let written = fs.readFileSync(log, 'utf8');
  assert.match(written, /^ddev exec php spark db:seed WebshipWorkspaceAccounts$/m);
  const job = JSON.parse(written.split('\n').find((l) => l.startsWith('{')) as string);
  assert.strictEqual(job.action, 'save');
  assert.deepStrictEqual(job.accounts.map((a: any) => [a.username, a.email, a.groups.join(','), a.banned]), [
    ['admin', 'admin@example.com', 'admin', false],
    ['developer', 'developer@example.com', 'developer', false],
    ['user', 'user@example.com', 'user', false],
    ['banned', 'banned@example.com', 'user', true],
  ]);
  assert.deepStrictEqual(fs.readdirSync(path.join(p.dir, 'app', 'Database', 'Seeds')), [], 'the seeder of the call is gone');
  assert.deepStrictEqual(fs.readdirSync(path.join(p.dir, 'writable')), [], 'and its list too');
  fs.writeFileSync(log, '');
  r = bash('set_codeigniter_users ; cancel_codeigniter_users', env);
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  written = fs.readFileSync(log, 'utf8');
  const removal = JSON.parse(written.split('\n').find((l) => l.startsWith('{')) as string);
  assert.strictEqual(removal.action, 'delete');
  assert.deepStrictEqual(removal.accounts.map((a: any) => a.email), ['admin@example.com', 'developer@example.com', 'user@example.com', 'banned@example.com']);
});

test('an app without the auth library has no accounts to write, and says so', () => {
  const p = project('codeigniter', { shield: false });
  const r = bash('set_codeigniter_users ; add_codeigniter_users', { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1' });
  assert.notStrictEqual(r.status, 0);
  assert.match(r.stdout, /no auth library/);
});

test('the testing hook adds the step pack, the users registry, the mailbox, the tags and a first feature to a CodeIgniter project, once', () => {
  const p = project('codeigniter');
  const log = path.join(p.root, 'ddev.log');
  const run = () => bash(`cd ${p.dir} && testing_configure_codeigniter ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log });
  const r = run();
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const pkg = JSON.parse(fs.readFileSync(path.join(p.dir, 'package.json'), 'utf8'));
  assert.strictEqual(pkg.devDependencies['@webship-js/codeigniter-steps'], '^2.0.0');
  assert.strictEqual(pkg.devDependencies['webship-js'], '^2.0.6', 'what was there stays');
  const cucumber = fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8');
  const lines = cucumber.split('\n');
  const core = lines.findIndex((l) => l.includes('node_modules/webship-js/tests/step-definitions'));
  assert.strictEqual(lines[core + 1], "      'node_modules/@webship-js/codeigniter-steps/tests/step-definitions/**/*.js',", 'the pack is listed right after webship-js');
  assert.match(cucumber, /admin: \{ email: process\.env\.CODEIGNITER_ADMIN_EMAIL \|\| 'admin@example\.com', username: process\.env\.CODEIGNITER_ADMIN_USERNAME \|\| 'admin', password: process\.env\.CODEIGNITER_ADMIN_PASSWORD \|\| '[^']+' \},/);
  assert.match(cucumber, /banned: \{ email: process\.env\.CODEIGNITER_BANNED_EMAIL \|\| 'banned@example\.com'/);
  assert.match(cucumber, /mailUrl: process\.env\.MAIL_URL \|\|/);
  assert.match(cucumber, /tags: process\.env\.CUCUMBER_TAGS \|\| 'not @wip and not @must-fail and not @development',/);
  // Still a module node can load, with the registry where webship-js reads it.
  const loaded = spawnSync(process.execPath, ['-e', `const c = require(${JSON.stringify(path.join(p.dir, 'cucumber.js'))}).default; console.log(JSON.stringify([c.require, Object.keys(c.worldParameters.users), c.tags, typeof c.worldParameters.mailUrl, c.worldParameters.users.user.username]))`], { encoding: 'utf8', env: { ...process.env, LAUNCH_URL: 'https://site1.ddev.site' } });
  assert.strictEqual(loaded.status, 0, loaded.stderr);
  const [requires, handles, tags, mail, username] = JSON.parse(loaded.stdout);
  assert.strictEqual(requires.length, 3);
  assert.deepStrictEqual(handles, ['admin', 'developer', 'user', 'banned']);
  assert.match(tags, /not @development/);
  assert.strictEqual(mail, 'string');
  assert.strictEqual(username, 'user');
  assert.ok(fs.existsSync(path.join(p.dir, 'tests', 'features', 'site.feature')));
  assert.match(fs.readFileSync(log, 'utf8'), /"username": "banned", "email": "banned@example\.com", "password": "[^"]+", "groups": \["user"\], "banned": true/, 'an app with the auth library gets the default accounts');
  // Again, after a person changed the feature: nothing is doubled, nothing is reset.
  fs.writeFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'Feature: mine\n');
  assert.strictEqual(run().status, 0);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), cucumber);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'utf8'), 'Feature: mine\n');
});

test('in an app whose package.json is a module, cucumber.js becomes an ES module and tests/ stays CommonJS, once', () => {
  const p = project('codeigniter');
  fs.writeFileSync(path.join(p.dir, 'package.json'), JSON.stringify({ name: 'site1', private: true, type: 'module', devDependencies: { 'webship-js': '^2.0.16' } }, null, 2));
  const run = () => bash(`cd ${p.dir} && testing_configure_codeigniter ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1' });
  const r = run();
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const src = fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8');
  assert.match(src, /^const config = \{/m);
  assert.doesNotMatch(src, /module\.exports/);
  assert.match(src, /\nexport default config\.default;\n$/);
  assert.deepStrictEqual(JSON.parse(fs.readFileSync(path.join(p.dir, 'tests', 'package.json'), 'utf8')), { type: 'commonjs' });
  const url = 'file://' + path.join(p.dir, 'cucumber.js');
  const loaded = spawnSync(process.execPath, ['--input-type=module', '-e', `const c = (await import(${JSON.stringify(url)})).default; console.log(JSON.stringify([c.require.length, Object.keys(c.worldParameters.users), c.tags]))`], { encoding: 'utf8', env: { ...process.env, LAUNCH_URL: 'https://site1.ddev.site' } });
  assert.strictEqual(loaded.status, 0, loaded.stderr);
  const [requires, handles, tags] = JSON.parse(loaded.stdout);
  assert.strictEqual(requires, 3);
  assert.deepStrictEqual(handles, ['admin', 'developer', 'user', 'banned']);
  assert.match(tags, /not @development/);
  assert.strictEqual(run().status, 0);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), src);
});

test('the testing hook leaves a project of another platform alone', () => {
  const p = project('drupal');
  const r = bash(`cd ${p.dir} && testing_configure_codeigniter ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1' });
  assert.strictEqual(r.status, 0);
  assert.strictEqual(r.stdout, '');
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), SCAFFOLD);
  assert.ok(!fs.existsSync(path.join(p.dir, 'tests')));
});

test('the spark tool refuses a project that is not CodeIgniter', () => {
  const p = project('drupal');
  const r = bash('PROJECT_NAME=site1 ; RUN="routes" ; trim_project_name() { :; } ; codeigniter_spark_tool', { WORKSPACE_ROOT: p.root, doc_name: 'dev' });
  assert.strictEqual(r.status, 1);
  assert.match(r.stdout, /is not a CodeIgniter project/);
});

test('the first feature names no platform in a step, and no password', () => {
  const feature = fs.readFileSync(path.join(PKG, 'testing', 'site.feature'), 'utf8');
  const steps = feature.split('\n').filter((l) => /^\s*(Given|When|Then|And|But) /.test(l));
  assert.ok(steps.length >= 10);
  for (const s of steps) assert.doesNotMatch(s, /codeigniter|shield|spark/i, s);
  assert.doesNotMatch(feature, /password "/);
  assert.doesNotMatch(feature, /user create|shield:user|I register/i, 'a suite never creates an account');
});

// ---- The runtimes: DDEV as before, and Docker Compose, Podman, Kubernetes, Lando and Docksal through the core's layer ----

const ADDRESSES: Record<string, string> = {
  docker: 'http://127.0.0.1:41234', podman: 'http://127.0.0.1:41234', lando: 'http://127.0.0.1:41234',
  kubernetes: 'http://172.18.0.2:30080', docksal: 'http://site1.docksal.site',
};

/**
 * Run the builder in a throwaway workspace with `ddev` replaced by a recorder, and the core's layer by stand-ins:
 * `layer` is the runtime it answers with (runtime_of, rt_url, rt_claim), or '' for a core that has no layer yet.
 * The recorder makes what `composer create-project` would have made, as far as the builder reads it.
 */
function build(layer: string, env: Record<string, string> = {}) {
  const p = project('codeigniter');
  fs.rmSync(p.dir, { recursive: true });
  const log = path.join(p.root, 'ddev.log');
  const address = ADDRESSES[layer] || '';
  const prelude = [
    'ddev() { echo "ddev $*" >> "' + log + '" ; case "$*" in',
    '  "composer create-project codeigniter4/appstarter"*) mkdir -p app/Config app/Database/Seeds writable && echo "<?php" > app/Config/Paths.php && printf "%s\\n" "            // \'csrf\'," > app/Config/Filters.php ;;',
    '  "composer require codeigniter4/shield"*) mkdir -p vendor/codeigniter4/shield ;;',
    'esac ; return 0 ; }',
    'trim_project_name() { :; } ; drop_database() { :; } ; ddev_nodejs_version() { echo 24 ; } ; ddev_up() { ddev "$@" ; }',
    layer ? `runtime_of() { echo "\${RUNTIME_ANSWER}" ; } ; rt_url() { [ "\${RUNTIME_ANSWER}" == ddev ] && echo "https://\${PROJECT_NAME}.ddev.site" || echo "${address}" ; } ; rt_claim() { echo "rt_claim $* in $(basename "$PWD")" >> "${log}" ; }` : '',
    `source ${FUNCTIONS}`,
    'codeigniter_build',
  ].join('\n');
  const r = spawnSync('bash', ['-c', prelude], { encoding: 'utf8', input: '', env: { ...process.env, WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1',
    SHIELD: 'yes', INSTALL: 'yes', ADD_USERS: 'no', PRODUCTION: 'no', LAUNCH: 'no', distribution_webroot: 'public', distribution_title: 'CodeIgniter', RUNTIME: '_none_', RUNTIME_ANSWER: layer || 'ddev',
    account_name: 'webmaster', account_pass: 'CHANGE_ME.123123', account_mail: 'webmaster@example.com', ...env } });
  const calls = fs.existsSync(log) ? fs.readFileSync(log, 'utf8').trim().split('\n').filter((c) => /^(ddev|rt_claim) /.test(c)) : [];
  return { r, calls, dir: path.join(p.root, 'dev', 'site1'), root: p.root };
}

test('on DDEV the build is what it was: the same commands with the layer and without it, the app in the project root', () => {
  const without = build('');
  const withLayer = build('ddev');
  for (const b of [without, withLayer]) {
    assert.strictEqual(b.r.status, 0, b.r.stderr + b.r.stdout);
    assert.match(b.r.stdout, /Go to https:\/\/site1\.ddev\.site\/login and log in as webmaster@example\.com/);
    assert.match(fs.readFileSync(path.join(b.dir, '.env'), 'utf8'), /^app\.baseURL = 'https:\/\/site1\.ddev\.site\/'$/m);
  }
  assert.deepStrictEqual(withLayer.calls, without.calls);
  assert.ok(without.calls.includes('ddev composer create-project codeigniter4/appstarter --no-interaction'));
  assert.ok(!without.calls.some((c) => c.startsWith('rt_claim ')), 'on DDEV nothing is claimed');
});

test('on Docker Compose, Podman, Kubernetes, Lando and Docksal the plugin claims the app and gives it the runtime\'s address', () => {
  const ddev = build('ddev').calls;
  for (const runtime of Object.keys(ADDRESSES)) {
    const address = ADDRESSES[runtime];
    const b = build(runtime, { RUNTIME: runtime });
    assert.strictEqual(b.r.status, 0, runtime + ': ' + b.r.stderr + b.r.stdout);
    assert.deepStrictEqual(b.calls.slice(0, 2), [ddev[0], 'rt_claim codeigniter in site1'], runtime);
    const expected = ddev.map((c) => c.replace('ddev composer create-project codeigniter4/appstarter --no-interaction', 'ddev composer create-project codeigniter4/appstarter . --no-interaction'));
    assert.deepStrictEqual(b.calls.filter((c) => !c.startsWith('rt_claim ')), expected, runtime);
    const dotenv = fs.readFileSync(path.join(b.dir, '.env'), 'utf8');
    assert.match(dotenv, new RegExp(`^app\\.baseURL = '${address.replace(/[.]/g, '\\.')}/'$`, 'm'), runtime);
    for (const line of ['database.default.hostname = db', 'database.default.database = db', 'database.default.username = db', 'database.default.password = db']) {
      assert.ok(dotenv.includes(`${line}\n`), `${runtime}: ${line}`);
    }
    assert.ok(!fs.existsSync(path.join(b.dir, '.ddev')), `${runtime}: nothing of DDEV's is written`);
    assert.match(b.r.stdout, new RegExp(`Go to ${address.replace(/[.]/g, '\\.')}/login and log in as webmaster@example\\.com`), runtime);
    assert.doesNotMatch(b.r.stdout + dotenv, /ddev\.site/, runtime);
  }
});

test('--runtime on a workspace without the runtime layer is refused, never built on DDEV in silence', () => {
  const b = build('', { RUNTIME: 'docker' });
  assert.strictEqual(b.r.status, 1);
  assert.match(b.r.stdout, /--runtime docker needs a Webship Workspace with the container runtimes/);
  assert.deepStrictEqual(b.calls, []);
  assert.ok(!fs.existsSync(b.dir), 'no folder was made');
  assert.strictEqual(build('', { RUNTIME: 'ddev' }).r.status, 0);
});

test('the builder takes --runtime, with the runtimes of the core\'s own builders', () => {
  const args = fs.readFileSync(path.join(PKG, 'scripts', 'args', 'arg-codeigniter.sh'), 'utf8');
  assert.match(args, /parser\.add_argument\('--runtime',\s+dest='RUNTIME',\s+default="_none_",\s+choices=\['ddev', 'docker', 'podman', 'kubernetes', 'lando', 'docksal'\],/);
});

/** An app of another runtime: compose.yaml with the plugin's claim, the framework's files, no .ddev folder. */
function runtimeApp() {
  const p = project('codeigniter');
  fs.rmSync(path.join(p.dir, '.ddev'), { recursive: true });
  fs.writeFileSync(path.join(p.dir, 'compose.yaml'), 'name: site1\nx-webship:\n  platform: codeigniter\n  runtime: docker\n  type: php\n  port: 41234\n');
  return p;
}
const LAYER = 'runtime_of() { echo docker ; } ; rt_is_platform() { grep -q "^  platform: $2$" "$1/compose.yaml" 2>/dev/null ; } ; rt_url() { echo http://127.0.0.1:41234 ; } ; ';

test('an app is known on every runtime: the claim through the core\'s layer, the framework\'s files on DDEV', () => {
  const rt = runtimeApp();
  assert.strictEqual(bash(`${LAYER} codeigniter_is_project ${rt.dir}`).status, 0);
  assert.notStrictEqual(bash(`codeigniter_is_project ${rt.dir}`).status, 0, 'an older core reads no compose.yaml');
  assert.strictEqual(bash(`${LAYER} codeigniter_is_project ${project('codeigniter').dir}`).status, 0, 'DDEV as before');
  assert.strictEqual(bash(`codeigniter_is_project ${project('codeigniter').dir}`).status, 0);
  assert.notStrictEqual(bash(`${LAYER} codeigniter_is_project ${project('drupal').dir}`).status, 0);
});

test('the spark tool and the test users work on an app of a runtime, and say its address', () => {
  const rt = runtimeApp();
  const log = path.join(rt.root, 'ddev.log');
  const env = { WORKSPACE_ROOT: rt.root, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log };
  const add = bash(`${LAYER} set_codeigniter_users ; add_codeigniter_users`, env);
  assert.strictEqual(add.status, 0, add.stdout + add.stderr);
  assert.match(fs.readFileSync(log, 'utf8'), /db:seed WebshipWorkspaceAccounts/);
  const what = bash(`${LAYER} trim_project_name() { :; } ; RUN=_none_ ; UPDATE=no ; ENVIRONMENT= ; ADD_USERS=no ; CANCEL_USERS=no ; codeigniter_spark_tool`, env);
  assert.strictEqual(what.status, 0, what.stdout + what.stderr);
  assert.match(what.stdout, /^dev\/site1: CodeIgniter .* at http:\/\/127\.0\.0\.1:41234$/m);
  assert.doesNotMatch(what.stdout, /ddev\.site/);
});

test('the feature of the runtimes drives an app the plugin claims, and names no platform in a step', () => {
  const feature = fs.readFileSync(path.join(PKG, 'features', 'codeigniter-runtimes.feature'), 'utf8');
  const scenarios = feature.split(/\n(?=  @needs-runtime-)/).slice(1);
  assert.strictEqual(scenarios.length, 6);
  for (const s of scenarios) assert.match(s, /^  @needs-runtime-(docker|kubernetes) @needs-platform-codeigniter\n  Scenario: /);
  const steps = feature.split('\n').filter((l) => /^\s*(Given|When|Then|And|But) /.test(l));
  for (const s of steps) assert.doesNotMatch(s, /codeigniter|shield|spark/i, s);
  assert.doesNotMatch(feature, /ddev\.site|127\.0\.0\.1/);
  const manifest = JSON.parse(fs.readFileSync(path.join(PKG, 'package.json'), 'utf8')).workspacePlugin;
  assert.ok(manifest.features.includes('features/codeigniter-runtimes.feature'));
  assert.match(manifest.featuresSite, /^cmd-codeigniter-project\.sh ci-codeigniter( [A-Za-z0-9._=-]+)* --runtime docker$/);
});
