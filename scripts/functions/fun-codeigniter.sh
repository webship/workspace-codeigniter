#!/usr/bin/env bash

# CodeIgniter for the Webship Workspace: build an app from the official app starter (with the official
# auth library on request), run spark on it, add its default accounts, and wire its step pack into the
# testing setup.
#
# Placed by `plugins.sh --install codeigniter` in core/scripts/plugins/codeigniter/functions/, where
# bootstrap sources it after the core's own functions. Everything runs in the project's container
# (DDEV by default: `ddev composer …`, `ddev exec php spark …`), never on the host. DDEV has no project
# type of its own for CodeIgniter: a project is of type php with the public docroot, and the plugin
# knows it by its files (the spark script and app/Config/Paths.php). The container tool writes no
# database settings for a php project, so the builder writes the container's own values (db, db, db
# on the host db) into the app's .env, and nothing personal.
#
# Four names are the ones the core's tools look for:
#   set_codeigniter_users          the default accounts            (cmd-tools-add-users.sh <project> codeigniter)
#   add_codeigniter_users          create them through the app     (the same tool, and --add-users of the builder)
#   cancel_codeigniter_users       delete them                     (cmd-tools-cancel-users.sh <project> codeigniter)
#   testing_configure_codeigniter  the step pack in the testing stack (cmd-tools-testing.sh <project>)

# The step pack a CodeIgniter app is tested with, and the release line it is required at.
readonly CODEIGNITER_STEPS_PACKAGE='@webship-js/codeigniter-steps';
readonly CODEIGNITER_STEPS_VERSION='^2.0.0';

# The default accounts, the ones a scenario logs in as: one per group of the auth library that tells
# accounts apart (the admin area, the site settings, neither), and one named by its state. Accounts
# are configuration, created once on the app; a test suite never creates or deletes one.
#   admin      the "admin" group: the admin area
#   developer  the "developer" group: the "admin.settings" permission, not the admin area
#   user       the "user" group, the one a new account gets
#   banned     the "user" group, banned: the app refuses its login
function set_codeigniter_users() {
  users=(admin developer user banned);
  local user ;
  for user in "${users[@]}" ; do
    printf -v "user_${user}_name" '%s' "${user}" ;
    printf -v "user_${user}_mail" '%s' "${user}@example.com" ;
    printf -v "user_${user}_password" '%s' 'dD.123123ddd' ;
    printf -v "user_${user}_state" '%s' 'active' ;
  done
  user_admin_role='admin' ;
  user_developer_role='developer' ;
  user_user_role='user' ;
  user_banned_role='user' ;
  user_banned_state='banned' ;
}

# Is this folder a CodeIgniter project? A container project whose app has the spark script of the
# framework and its app/Config/Paths.php.
function codeigniter_is_project() {
  local project_path="$1";
  [ -f "${project_path}/.ddev/config.yaml" ] && [ -f "${project_path}/app/Config/Paths.php" ] \
    && grep -q 'CodeIgniter' "${project_path}/spark" 2>/dev/null ;
}

# Does the app of the current folder have the official auth library?
function codeigniter_has_shield() {
  [ -d vendor/codeigniter4/shield ] ;
}

# Go to the project a tool was asked about, or say why not.
function codeigniter_enter_project() {
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}";
  if [ ! -d "${project_path}" ] ; then
    echo "No project ${PROJECT_NAME} in ${WORKSPACE_ROOT}/${doc_name}." ;
    return 1 ;
  fi
  if ! codeigniter_is_project "${project_path}" ; then
    echo "${doc_name}/${PROJECT_NAME} is not a CodeIgniter project (it has no spark script and app/Config/Paths.php of the framework)." ;
    return 1 ;
  fi
  cd "${project_path}" || return 1 ;
}

# The .env of a new app: the address, no index.php in the addresses, the database of the container
# (its own db, db, db on the host db) and the sender of its mail. The mail goes out through the
# sendmail of the web container, which the container tool hands to its mail catcher.
function codeigniter_write_env() {
  local base_url="$1" ;
  cat > .env <<ENVEOF
CI_ENVIRONMENT = development
app.baseURL = '${base_url}/'
app.indexPage = ''
database.default.hostname = db
database.default.database = db
database.default.username = db
database.default.password = db
database.default.DBDriver = MySQLi
database.default.port = 3306
email.fromEmail = 'noreply@example.com'
email.fromName = '${distribution_title:-CodeIgniter} app'
ENVEOF
}

# Write accounts through the app itself: a seeder of the auth library's user model, run by spark,
# so a password is hashed the way the app hashes it. Reads lines of "name|email|password|group|state"
# on standard input; "delete" as the first argument removes the accounts of those addresses instead,
# and "list" lists every account of the app. Runs in the project folder, in the container; the seeder
# and its list are there only for the time of the call.
function codeigniter_write_accounts() {
  local action="${1:-save}" ;
  local seeder="app/Database/Seeds/WebshipWorkspaceAccounts.php" list="writable/webship-workspace-accounts.json" ;
  if ! codeigniter_has_shield ; then
    echo "  The app has no auth library (codeigniter4/shield): build it with --shield to have accounts." ;
    return 1 ;
  fi
  python3 -c '
import json, sys
rows = [line.split("|") for line in sys.stdin.read().splitlines() if line.strip()]
print(json.dumps({"action": sys.argv[1], "accounts": [
    {"username": r[0], "email": r[1], "password": r[2], "groups": [r[3]] if len(r) > 3 and r[3] else [], "banned": len(r) > 4 and r[4] == "banned"}
    for r in rows]}))' "${action}" > "${list}" || return 1 ;
  cat > "${seeder}" <<'PHPEOF'
<?php

// Written by the Webship Workspace for the time of one call, then removed.

namespace App\Database\Seeds;

use CodeIgniter\Database\Seeder;
use CodeIgniter\Shield\Entities\User;
use CodeIgniter\Shield\Models\UserModel;

class WebshipWorkspaceAccounts extends Seeder
{
    public function run(): void
    {
        $job   = json_decode((string) file_get_contents(WRITEPATH . 'webship-workspace-accounts.json'), true, 512, JSON_THROW_ON_ERROR);
        $users = model(UserModel::class);

        if ($job['action'] === 'list') {
            foreach ($users->orderBy('id')->findAll() as $user) {
                printf("  %s <%s> %s%s\n", $user->username, $user->email, implode(', ', $user->getGroups()), $user->isBanned() ? ' (banned)' : '');
            }

            return;
        }

        foreach ($job['accounts'] as $account) {
            $user = $users->findByCredentials(['email' => $account['email']]);
            if ($job['action'] === 'delete') {
                if ($user !== null) {
                    $users->delete($user->id, true);
                }
                printf("  %s %s\n", $account['email'], $user === null ? 'is not there' : 'deleted');

                continue;
            }
            if ($user === null) {
                $user = new User(['username' => $account['username'], 'email' => $account['email'], 'password' => $account['password']]);
                $users->save($user);
                $user = $users->findById($users->getInsertID());
            } else {
                $user->fill(['username' => $account['username'], 'email' => $account['email'], 'password' => $account['password']]);
                $users->save($user);
            }
            $user->activate();
            if ($account['groups'] !== []) {
                $user->syncGroups(...$account['groups']);
            }
            $account['banned'] ? $user->ban() : $user->unBan();
            printf("  %s <%s> %s%s\n", $user->username, $user->email, implode(', ', $user->getGroups()), $user->isBanned() ? ' (banned)' : '');
        }
    }
}
PHPEOF
  ddev exec php spark db:seed WebshipWorkspaceAccounts ;
  local rc=$? ;
  rm -f "${seeder}" "${list}" ;
  return ${rc} ;
}

# Build a CodeIgniter app from nothing: the container, the app made from the official app starter,
# the auth library with --shield, and with --install its database and its first account.
function codeigniter_build() {
  trim_project_name ;
  local base_url="https://${PROJECT_NAME}.ddev.site" ;
  local php_version="${PHP_VERSION:-${site_php_version:-}}" ;
  local environment='development' ;
  [ "${PRODUCTION}" == 'yes' ] && environment='production' ;

  cd ${WORKSPACE_ROOT}/${doc_name} || exit 1 ;

  drop_database ;
  rm -rf "${PROJECT_NAME}" ;
  mkdir -p "${PROJECT_NAME}" ;
  cd ${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME} || exit 1 ;

  # DDEV has no project type for the framework: php, with the public docroot of the app starter.
  ddev config --project-type=php --docroot="${distribution_webroot}" --project-name=${PROJECT_NAME} \
    --nodejs-version=$(ddev_nodejs_version) ${php_version:+--php-version=${php_version}} --auto || exit 1 ;
  ddev_up start -y || exit 1 ;

  # The official app starter, with Composer in the web container.
  ddev composer create-project codeigniter4/appstarter --no-interaction \
    || { echo "composer create-project codeigniter4/appstarter failed." ; exit 1 ; } ;
  codeigniter_write_env "${base_url}" ;

  if [ "${SHIELD}" == 'yes' ] ; then
    # The official auth library, set up by its own command: its configuration, the helpers, its
    # routes, CSRF protection kept in the session, and (with --install) its tables. The command asks
    # before each change and takes the default (yes) with no answer; without --install it is told no
    # for the tables.
    ddev composer require codeigniter4/shield --no-interaction || { echo "composer require codeigniter4/shield failed." ; exit 1 ; } ;
    if [ "${INSTALL}" == 'yes' ] ; then
      ddev exec php spark shield:setup < /dev/null || exit 1 ;
    else
      printf 'n\n' | ddev exec php spark shield:setup || exit 1 ;
    fi
    # CSRF protection for every form: the filter the app starter ships commented out.
    sed -i "s#^            // 'csrf',#            'csrf',#" app/Config/Filters.php ;
    grep -q "^            'csrf'," app/Config/Filters.php || echo "  The csrf filter could not be turned on in app/Config/Filters.php: turn it on by hand." ;
  fi

  if [ "${INSTALL}" == 'yes' ] ; then
    ddev exec php spark migrate --all || { echo "The migrations failed." ; exit 1 ; } ;
    if [ "${SHIELD}" == 'yes' ] ; then
      printf '%s|%s|%s|superadmin|active\n' "${account_name}" "${account_mail}" "${account_pass}" | codeigniter_write_accounts save > /dev/null \
        || { echo "The workspace account could not be written." ; exit 1 ; } ;
      if [ "${ADD_USERS}" == 'yes' ] ; then
        set_codeigniter_users ;
        add_codeigniter_users ;
        cd ${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME} || exit 1 ;
      fi
    elif [ "${ADD_USERS}" == 'yes' ] ; then
      echo "--add-users needs --shield: the app starter alone has no accounts." ;
    fi
  elif [ "${ADD_USERS}" == 'yes' ] ; then
    echo "--add-users needs --install: there is no database to add accounts to yet." ;
  fi

  ddev exec php spark env "${environment}" > /dev/null ;

  local version ;
  version="$(ddev exec php spark --version 2>/dev/null | grep -o 'v[0-9][0-9.]*' | head -1)" ;
  if [ "${INSTALL}" == 'yes' ] ; then
    local with='' ;
    [ "${SHIELD}" == 'yes' ] && with=' with the auth library' ;
    echo "${doc_name} ${PROJECT_NAME} has been installed: CodeIgniter ${version}${with} (${environment}).";
    if [ "${SHIELD}" == 'yes' ] ; then
      echo "Go to ${base_url}/login and log in as ${account_mail}";
    else
      echo "Go to ${base_url}";
    fi
  else
    echo "${doc_name} ${PROJECT_NAME} is ready: CodeIgniter ${version} (${environment}). Migrate its database with bash cmd-tools-codeigniter-spark.sh ${PROJECT_NAME} --run \"migrate --all\"";
    echo "Go to ${base_url}";
  fi

  if [ "${LAUNCH}" == 'yes' ] ; then
    ddev launch ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name};
}

# Create the default accounts through the app. An account that is already there gets its name,
# password, groups and state back. The list is loaded by the caller (set_codeigniter_users): the
# core's add_users, the builder, the spark tool.
function add_codeigniter_users() {
  codeigniter_enter_project || return 1 ;
  local user user_name user_mail user_password user_role user_state lines="" ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail";
    user_password="user_${user}_password"; user_role="user_${user}_role"; user_state="user_${user}_state";

    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo "      User mail: ${!user_mail}";
    echo "  User password: ${!user_password}";
    echo "     User group: ${!user_role:-user}";
    echo "     User state: ${!user_state:-active}";
    echo " ================================================================= ";

    lines="${lines}${!user_name}|${!user_mail}|${!user_password}|${!user_role:-user}|${!user_state:-active}"$'\n' ;
  done
  printf '%s' "${lines}" | codeigniter_write_accounts save ;
  local rc=$? ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${rc} ;
}

# Delete the default accounts.
function cancel_codeigniter_users() {
  codeigniter_enter_project || return 1 ;
  local user user_name user_mail lines="" ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail";
    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo " ================================================================= ";
    lines="${lines}${!user_name}|${!user_mail}|||"$'\n' ;
  done
  printf '%s' "${lines}" | codeigniter_write_accounts delete ;
  local rc=$? ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${rc} ;
}

# What cmd-tools-codeigniter-spark.sh does: the first of --run, --update, --environment, --add-users,
# --cancel-users that was asked for; with none of them, what the app is.
function codeigniter_spark_tool() {
  trim_project_name ;
  codeigniter_enter_project || exit 1 ;

  if ! ddev describe -j 2>/dev/null | grep -q '"status":"running"' ; then
    ddev start -y || exit 1 ;
  fi

  if [ ! "${RUN}" == '_none_' ] ; then
    # Unquoted on purpose: --run "migrate --all" is a command and its arguments.
    ddev exec php spark ${RUN} ;
    exit $? ;
  fi

  if [ "${UPDATE}" == 'yes' ] ; then
    ddev composer update --no-interaction ;
    ddev exec php spark migrate --all ;
  elif [ -n "${ENVIRONMENT}" ] ; then
    ddev exec php spark env "${ENVIRONMENT}" ;
  elif [ "${ADD_USERS}" == 'yes' ] ; then
    set_codeigniter_users ;
    add_codeigniter_users ;
  elif [ "${CANCEL_USERS}" == 'yes' ] ; then
    set_codeigniter_users ;
    cancel_codeigniter_users ;
  else
    echo "${doc_name}/${PROJECT_NAME}: CodeIgniter $(ddev exec php spark --version 2>/dev/null | grep -o 'v[0-9][0-9.]*' | head -1) at https://${PROJECT_NAME}.ddev.site" ;
    echo "  Environment: $(grep -E '^[[:space:]]*CI_ENVIRONMENT[[:space:]]*=' .env 2>/dev/null | head -1 | sed -E 's/.*=[[:space:]]*//')" ;
    if codeigniter_has_shield ; then
      echo "" ; echo "Accounts:" ;
      printf '' | codeigniter_write_accounts list ;
    else
      echo "  No auth library: the app has no accounts." ;
    fi
  fi
  cd ${WORKSPACE_ROOT}/${doc_name};
}

# The step pack in the testing stack of a CodeIgniter project. The core's testing_configure calls this
# in the project folder once webship-js is scaffolded and before the dependencies are installed;
# for a project that is not CodeIgniter it changes nothing.
#
# It adds the pack to package.json, lists its step definitions in cucumber.js after webship-js's
# own, gives cucumber.js the users registry of the default accounts (a handle a scenario reads,
# mapped to an account; never the workspace account), the mailbox of the project and the tags that
# keep the pack's lanes out of a normal run, and writes a first feature when the project has none of
# its own. Every part is skipped when it is already there, so a second run adds what the first
# missed and never resets a suite.
function testing_configure_codeigniter() {
  local project_path="$1";
  codeigniter_is_project "${project_path}" || return 0 ;
  if [ ! -f "${project_path}/cucumber.js" ] || [ ! -f "${project_path}/package.json" ] ; then
    echo "  CodeIgniter: cucumber.js is not here yet — run the testing setup again once webship-js is scaffolded." ;
    return 1 ;
  fi

  echo "Adding the CodeIgniter step pack (${CODEIGNITER_STEPS_PACKAGE} ${CODEIGNITER_STEPS_VERSION}).";
  set_codeigniter_users ;
  local registry="" user user_name user_mail user_password ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail"; user_password="user_${user}_password";
    registry="${registry}${user}|${!user_mail}|${!user_password}|${!user_name}"$'\n' ;
  done

  python3 - "${project_path}" "${CODEIGNITER_STEPS_PACKAGE}" "${CODEIGNITER_STEPS_VERSION}" 'CODEIGNITER' "${registry}" <<'PYEOF' || return 1
import json, re, sys

project, pack, version, prefix, registry = sys.argv[1:6]

# package.json: the pack as a dev dependency, at the release line this plugin was proven on.
pkg_file = project + '/package.json'
pkg = json.load(open(pkg_file))
if pack not in pkg.get('dependencies', {}) and pack not in pkg.get('devDependencies', {}):
    pkg.setdefault('devDependencies', {})[pack] = version
    open(pkg_file, 'w').write(json.dumps(pkg, indent=4) + '\n')
    print('  package.json: %s %s' % (pack, version))

# cucumber.js: the pack's step definitions after webship-js's own, the users registry, the mailbox
# and the tags of the pack's lanes.
cucumber_file = project + '/cucumber.js'
src = open(cucumber_file).read()
before = src

if ('node_modules/%s/' % pack) not in src:
    line = "'node_modules/%s/tests/step-definitions/**/*.js'," % pack
    core = re.search(r"^([ \t]*)'node_modules/webship-js/tests/step-definitions/[^']*',.*$", src, re.M)
    opening = re.search(r"^([ \t]*)require:[ \t]*\[[ \t]*$", src, re.M)
    if core:
        src = src[:core.end()] + '\n' + core.group(1) + line + src[core.end():]
    elif opening:
        src = src[:opening.end()] + '\n' + opening.group(1) + '  ' + line + src[opening.end():]
    else:
        sys.exit("  cucumber.js has no require list this can add to. Add this line to it:\n    " + line)
    print('  cucumber.js: the step definitions of %s' % pack)

if not re.search(r"^[ \t]*tags:", src, re.M):
    default = re.search(r"^([ \t]*)default:[ \t]*\{[ \t]*$", src, re.M)
    if default:
        pad = default.group(1) + '  '
        block = [
            pad + "// The pack's lane needs the app in development (@development: the debug toolbar and the debug page),",
            pad + "// and its assertions that must fail are no part of a normal run.",
            pad + "tags: process.env.CUCUMBER_TAGS || 'not @wip and not @must-fail and not @development',",
        ]
        src = src[:default.end()] + '\n' + '\n'.join(block) + src[default.end():]
        print('  cucumber.js: the tags that keep the lane of the pack out of a normal run')

world = re.search(r"^([ \t]*)worldParameters:[ \t]*\{[ \t]*$", src, re.M)
if not world:
    sys.exit("  cucumber.js has no worldParameters block to add the users registry to.")
pad = world.group(1) + '  '
additions = []
if not re.search(r"^[ \t]*mailUrl:", src, re.M):
    additions += [
        pad + "// The mailbox that catches the mail of the app (the login link steps read it).",
        pad + "mailUrl: process.env.MAIL_URL || (process.env.LAUNCH_URL || '').replace(/\\/+$/, '') + ':8026',",
    ]
if not re.search(r"^[ \t]*users:[ \t]*\{", src, re.M):
    rows = [r.split('|') for r in registry.splitlines() if r.strip()]
    additions += [
        pad + "// The users registry: a handle a scenario reads, mapped to an account of this app (the default",
        pad + "// accounts: cmd-tools-codeigniter-spark.sh --add-users). Override one with %s_<HANDLE>_EMAIL," % prefix,
        pad + "// %s_<HANDLE>_USERNAME and %s_<HANDLE>_PASSWORD." % (prefix, prefix),
        pad + "users: {",
    ]
    for handle, email, password, name in rows:
        env = '%s_%s' % (prefix, handle.upper())
        additions.append(pad + "  %s: { email: process.env.%s_EMAIL || '%s', username: process.env.%s_USERNAME || '%s', password: process.env.%s_PASSWORD || '%s' }," % (handle, env, email, env, name, env, password))
    additions.append(pad + "},")
    print('  cucumber.js: the users registry (%s)' % ', '.join(r[0] for r in rows))
if additions:
    src = src[:world.end()] + '\n' + '\n'.join(additions) + src[world.end():]

# An app whose package.json says "type": "module" (a front end built with Vite, for one) makes node
# read every .js file of the app as an ES module: the CommonJS cucumber.js the scaffold writes cannot
# load there, and neither can the step definitions under tests/. cucumber.js becomes an ES module that
# exports the same default profile, and tests/ gets a package.json of its own that keeps its .js
# files CommonJS. The app starter has no package.json, so this is for an app that added one.
if pkg.get('type') == 'module':
    if re.search(r"^module\.exports\s*=\s*\{", src, re.M) and not re.search(r"^export default ", src, re.M):
        src = re.sub(r"^module\.exports\s*=\s*\{", "// The app's package.json says \"type\": \"module\": this file is an ES module, the profiles stay as they were.\nconst config = {", src, count=1, flags=re.M)
        src = src.rstrip() + '\n\nexport default config.default;\n'
        print('  cucumber.js: an ES module (the package.json of the app says "type": "module")')
    tests_pkg = project + '/tests/package.json'
    try:
        open(tests_pkg)
    except OSError:
        import os
        os.makedirs(project + '/tests', exist_ok=True)
        open(tests_pkg, 'w').write(json.dumps({'type': 'commonjs'}, indent=2) + '\n')
        print('  tests/package.json: the step definitions under tests/ stay CommonJS')

if src != before:
    open(cucumber_file, 'w').write(src)
PYEOF

  # A first feature, when the project has none for the app yet: the welcome page, the login page,
  # each default account where the app sends it.
  local feature="${WORKSPACE_SCRIPTS}/plugins/codeigniter/site.feature" ;
  if [ -f "${feature}" ] && [ ! -f "${project_path}/tests/features/site.feature" ] ; then
    mkdir -p "${project_path}/tests/features" && cp "${feature}" "${project_path}/tests/features/site.feature" \
      && echo "  tests/features/site.feature: a first feature for the app" ;
  fi

  # The scenarios log in as the default accounts: make sure an app with the auth library has them.
  if ( cd "${project_path}" && codeigniter_has_shield ) ; then
    if ( add_codeigniter_users > /dev/null 2>&1 ) ; then
      echo "  the default accounts are on the app (${users[*]})" ;
    else
      echo "  The default accounts could not be written: migrate the database first (bash cmd-tools-codeigniter-spark.sh ${PROJECT_NAME} --run \"migrate --all\")." ;
    fi
  else
    echo "  The app has no auth library: the scenarios that log in need an app built with --shield." ;
  fi
}
