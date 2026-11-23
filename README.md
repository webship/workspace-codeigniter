# @webship.co/workspace-codeigniter

CodeIgniter for the [Webship Workspace](https://github.com/webship/workspace) dashboard: a builder
that makes a real CodeIgniter app in a container from the official app starter, with the official
auth library (Shield) on request, a spark tool for the apps it built, the default accounts, the
[CodeIgniter step pack](https://github.com/webship/codeigniter-steps) wired into the workspace's
testing setup, and its AI items — two agents, a skill, a command and two prompts — each listed in
the workspace folder of its kind.

The workspace is container-based (DDEV by default): a CodeIgniter project is a row like any other,
so the row menus the core draws (start, stop, launch, backup, clone, remove, tests) work on it
unchanged.

It is made from the reference platform plugin, `@webship.co/workspace-wordpress`.

## Use it

```bash
cd ~/workspace
bash core/scripts/plugins.sh --require @webship.co/workspace-codeigniter --with-needs   # npm install into the dashboard
bash core/scripts/plugins.sh --activate codeigniter --with-needs                         # plugins.codeigniter in settings.yml
bash core/scripts/plugins.sh --install codeigniter                                       # commands, functions, args, AI items
bash core/scripts/plugins.sh --configure codeigniter                                     # nothing to configure: it has no settings file
```

The same four steps are buttons on the dashboard's **Settings → Plugins** page. `--install` is
idempotent. `--uninstall` removes what it placed; an AI item you edited stays.

Everything the plugin carries lands in the folder it belongs to, when that folder is an active
workspace folder:

| What | Lands in |
| --- | --- |
| `cmd-codeigniter-project.sh`, `cmd-tools-codeigniter-spark.sh` | every active sites folder: `dev/`, `test/`, `sandboxes/`, `demos/` |
| The agents `codeigniter-site-builder`, `codeigniter-tester` | `ai-agents/` |
| The skill `codeigniter-scenarios` | `ai-skills/` |
| The command `/codeigniter-test` | `ai-commands/` |
| The prompts `codeigniter-build-and-test`, `codeigniter-scenarios-for-a-group` | `ai-prompts/` |

There they are listed like any other item of the folder, and installed into Claude Code from there.

## What it needs

A workspace starts empty, so the manifest says what else this plugin needs (`needs`):

- one sites folder, for the builder and the tool: `dev`, `test`, `sandboxes`, `demos` (`dev` is the one added when none is there). The folder also carries `cmd-tools-testing.sh` and the Users tools this plugin's hooks answer to.
- `ai-agents`, `ai-skills`, `ai-commands` and `ai-prompts`: the AI folders its agents, its skill, its command and its prompts are placed in.

`--require` says so, `--activate` and `--install` stop until the workspace has them, and `--with-needs` adds what is missing first:

```bash
bash core/scripts/plugins.sh --activate codeigniter --with-needs   # dev and the four AI folders are required, activated and installed first
bash core/scripts/plugins.sh --install codeigniter
```

Everything the builder runs for an app runs in the app's own container, through the container tool the workspace already needs: Composer is the web container's. The plugin asks for no command of its own on the machine.

## What the package holds

| Path | What it is |
| --- | --- |
| `commands/cmd-codeigniter-project.sh` | The builder, in the Build list as **CodeIgniter (app starter)**, installed into every sites folder |
| `commands/cmd-tools-codeigniter-spark.sh` | spark for one app: what the app is, a command, updates, the environment, the default accounts |
| `scripts/functions/fun-codeigniter.sh` | The bash functions behind both, sourced by bootstrap once installed; the names the core's tools look for (`set_codeigniter_users`, `add_codeigniter_users`, `cancel_codeigniter_users`, `testing_configure_codeigniter`) |
| `scripts/args/arg-codeigniter.sh`, `arg-codeigniter-spark.sh` | Their argparse; the Build form draws the builder's flags from the first |
| `testing/site.feature` | The first feature a CodeIgniter project gets when testing is set up |
| `ai/agents/codeigniter-site-builder.md` | The agent that builds and maintains CodeIgniter apps with these commands |
| `ai/agents/codeigniter-tester.md` | The agent that writes and runs scenarios with the CodeIgniter step pack |
| `ai/skills/codeigniter-scenarios/` | The skill: the step pack's phrases by area, the traps found on a real app, three example features |
| `ai/commands/codeigniter-test.md` | The slash command `/codeigniter-test <app>`: set up, match every step, run, report |
| `ai/prompts/codeigniter-build-and-test.md`, `codeigniter-scenarios-for-a-group.md` | Two prompts: whole launch commands for a new session |
| `src/index.ts` | `register(api)`: what the assistant is told about CodeIgniter here |
| `features/codeigniter.feature` | Scenarios for the dashboard's own browser suite |
| `features/codeigniter-runtimes.feature` | The row, the test users and the pages of an app built on Docker Compose and on Kubernetes |

The `workspacePlugin` block in `package.json` is the manifest the installer reads.

## What is different from a platform with a project type

DDEV has no project type for CodeIgniter. The plugin keeps the shape of the reference and changes
only this:

| | WordPress (the reference) | CodeIgniter |
| --- | --- | --- |
| Project | `--project-type=wordpress` | `--project-type=php --docroot=public`: the app starter serves from `public/` |
| Recognised by | The DDEV project type | Its files: the framework's `spark` script and `app/Config/Paths.php`; on another runtime than DDEV, the plugin's claim on the project |
| Database | The container tool's default, settings written by the tool | The container tool's default (MariaDB); the builder writes the container's own `db` / `db` / `db` on the host `db` into the app's `.env`, as the tool writes nothing for a `php` project |
| Getting the code | `wp core download` | `composer create-project codeigniter4/appstarter`, in the web container |
| Install | `wp core install` | `spark migrate --all`; with `--shield`, the auth library (`composer require codeigniter4/shield`, `spark shield:setup`) and the workspace account as the first account, in the superadmin group |
| Accounts | WP-CLI | A seeder of the auth library's user model, run by spark for the time of the call |
| Users menu of the row | Reads the project type | On DDEV it does not apply (the type is `php`): `cmd-tools-codeigniter-spark.sh --add-users`, or `cmd-tools-add-users.sh <name> codeigniter`. On another runtime the plugin's claim gives the row the list (see [Runtimes](#runtimes)) |

## The commands

Run them from a sites folder. `--help` is safe on both.

### Build an app

```bash
cd ~/workspace/dev
bash cmd-codeigniter-project.sh myapp --install --add-users --shield
```

| Flag | What it does |
| --- | --- |
| `--shield` | Add the official auth library, set up by its own command (`spark shield:setup`), with CSRF protection on for every form (the `csrf` filter the app starter ships commented out) |
| `--install` | Migrate the database; with `--shield`, the workspace account is the first account of the app, in the superadmin group |
| `--add-users` | With `--install` and `--shield`: add the default accounts |
| `--production` | Run the app as a live app runs: `CI_ENVIRONMENT = production` (the plain error pages instead of the debug page, no debug toolbar). Without it the app runs in development |
| `--php-version <x>` | The PHP of the project container |
| `--runtime <name>` | The container runtime to build on: `ddev` (the default), `docker`, `kubernetes`, `podman`, `lando` or `docksal`. See [Runtimes](#runtimes) |
| `--launch` | Open the app when it is ready |

On DDEV the app answers at `https://myapp.ddev.site`, the login (with `--shield`) at `/login`, its mail
catcher at `https://myapp.ddev.site:8026`. The build runs `ddev config --project-type=php
--docroot=public` with the Node.js of the workspace (24), makes the app from the official app
starter with Composer in the web container, and writes its `.env`: the address, the container's
own database settings and the sender of its mail (the app sends through the web container's
sendmail, which the container tool hands to its mail catcher). A project of the same name is
deleted first.


### Runtimes

```bash
bash cmd-codeigniter-project.sh myapp --shield --install --add-users                        # DDEV, the default
bash cmd-codeigniter-project.sh myapp --shield --install --add-users --runtime docker       # Docker Compose
bash cmd-codeigniter-project.sh myapp --shield --install --add-users --runtime kubernetes   # a Kubernetes cluster
bash cmd-codeigniter-project.sh myapp --shield --install --add-users --runtime lando        # Lando
bash cmd-codeigniter-project.sh myapp --shield --install --add-users --runtime docksal      # Docksal
```

Without `--runtime` a build takes `container.runtime` of the workspace's `settings.yml`, then DDEV.
It needs a Webship Workspace with the container runtimes
([webship/workspace#694](https://github.com/webship/workspace/issues/694)); on an older one the
builder refuses `--runtime` and builds on DDEV only. Lando and Docksal need a Workspace whose runtime
layer has them ([webship/workspace#729](https://github.com/webship/workspace/issues/729),
[#730](https://github.com/webship/workspace/issues/730)).

| | DDEV | Docker Compose | Kubernetes | Podman | Lando | Docksal |
| --- | --- | --- | --- | --- | --- | --- |
| Build with `--shield --install --add-users --production` | Yes | Yes | Yes | Not yet run | Yes | Yes |
| The pages, and a login as the workspace account and the default accounts (`banned` refused) | Yes | Yes | Yes | Not yet run | Yes | Yes |
| `cmd-tools-codeigniter-spark.sh`: status, `--run`, the accounts | Yes | Yes | Yes | Not yet run | Yes | Yes |
| Test users, added and cancelled | Yes | Yes | Yes | Not yet run | Yes | Yes |
| Mail caught by Mailpit (the auth library's login link) | Yes | Yes | Yes | Not yet run | Yes | Yes |
| The testing setup and the first feature | Yes | Yes | Yes | Not yet run | Yes | Yes |
| The step pack's examples (49 scenarios) | Yes | Yes | Yes | Not yet run | Yes | Yes |
| Export and import the database | Yes | Yes | Yes | Not yet run | Yes | Yes |
| The row in the dashboard, and remove | Yes | Yes | Yes | Not yet run | Yes | Yes |

"Yes" means it was run on a real app of that runtime. Podman runs the same code as Docker Compose
and was not run yet.

| Runtime | The app's address | What the project carries |
| --- | --- | --- |
| DDEV | `https://myapp.ddev.site` | `.ddev/config.yaml` |
| Docker Compose | `http://127.0.0.1:<port>`, printed by the build | `compose.yaml`, `.webship/runtime/Dockerfile` |
| Kubernetes | `http://<node address>:<port>`, printed by the build | The same, and `k8s/` (the namespace `ws-myapp`) |
| Lando | `http://127.0.0.1:<port>`, printed by the build | `.lando.yml` (Lando's proxy stays off) |
| Docksal | `http://myapp.docksal.site`, on Docksal's own proxy | `.docksal/docksal.env`, `.docksal/docksal.yml` |

What differs on Docker Compose, Kubernetes, Lando and Docksal:

- **The claim:** the project type is `php` there too, which says nothing of the platform, so the builder writes `platform: codeigniter` in the `x-webship:` block of the project (the core's `rt_claim`). The tools read it, and the row's Tests menu offers the plugin's test users through it. On DDEV the builder writes no claim, as before: the app is known by its files, and the row has no test users.
- **The address** in the app's `.env` (`app.baseURL`) is the runtime's. The rest of `.env` is the same on every runtime: `db` / `db` / `db` on the host `db`, and PHP's own mail, which each runtime hands to its mail catcher.
- **`composer create-project`** is told the project root (`.`), as DDEV takes it.
- **The web server** is Apache; the app starter ships the `public/.htaccess` it needs.
- **HTTPS and a host name** are DDEV's: a runtime's address is plain HTTP.

The same commands work on every runtime: `cmd-tools-codeigniter-spark.sh`, `cmd-tools-add-users.sh`,
`cmd-tools-testing.sh`. The pattern is the Workspace's
[`core/docs/plugins-on-runtimes.md`](https://github.com/webship/workspace/blob/1.0.x/core/docs/plugins-on-runtimes.md).

### Work on an app

```bash
bash cmd-tools-codeigniter-spark.sh myapp                                 # version, environment, accounts
bash cmd-tools-codeigniter-spark.sh myapp --run "routes"
bash cmd-tools-codeigniter-spark.sh myapp --update                        # Composer packages and the new migrations
bash cmd-tools-codeigniter-spark.sh myapp --environment production        # or development
bash cmd-tools-codeigniter-spark.sh myapp --add-users                     # the default accounts
bash cmd-tools-codeigniter-spark.sh myapp --cancel-users                  # delete them
```

### The default accounts

| Account | Address | Group | Handle in the tests |
| --- | --- | --- | --- |
| `admin` | `admin@example.com` | admin | `admin` |
| `developer` | `developer@example.com` | developer (it has the `admin.settings` permission) | `developer` |
| `user` | `user@example.com` | user (the one a new account gets) | `user` |
| `banned` | `banned@example.com` | user, banned: the app refuses its login | `banned` |

One account per group of the auth library that tells accounts apart, and one named by its state.
Each account has the password of the workspace's other default lists. They are for local apps and
for tests; the app's first account is the workspace account and is never written into a test.
`bash cmd-tools-codeigniter-spark.sh myapp --add-users` and `bash cmd-tools-add-users.sh myapp
codeigniter` add the same list; adding them again gives them back their name, password, group and
state. They need an app built with `--shield`.

### Test an app

```bash
bash cmd-tools-testing.sh myapp                 # webship-js, the step pack, the users registry, a first feature
bash cmd-tools-testing.sh myapp --run           # run the suite in the container
bash cmd-tools-testing.sh myapp --run --path tests/features/site.feature
```

`cmd-tools-testing.sh` is the workspace's own. For a CodeIgniter project it also adds
`@webship-js/codeigniter-steps` to `package.json`, lists its step definitions in `cucumber.js` after
webship-js's own, writes the users registry (the handles above, overridable with
`CODEIGNITER_<HANDLE>_EMAIL`, `CODEIGNITER_<HANDLE>_USERNAME` and `CODEIGNITER_<HANDLE>_PASSWORD`),
the mailbox of the project (`mailUrl`) and the tags that keep the pack's development lane
(`@development`) out of a normal run, places `tests/features/site.feature` when the project has
none, and makes sure the default accounts are on the app. The app starter keeps its own PHPUnit
tests in `tests/`; the webship-js folders live beside them. Run it again and it adds what is
missing and keeps what you changed.

`tests/features/site.feature` passes on an app built with `--install --add-users --shield`, in
development and in production. The features of the step pack also open four pages a new app does
not have (a page for any signed-in account, one for the admin group, one for a permission, and an
error nothing catches): the pack's README says how to add them.

## The AI items

`ai/` in the package holds one folder per kind, the manifest's `ai` block names each item, and
`--install` places it in the workspace folder of that kind.

| Kind | Item | Use it to |
| --- | --- | --- |
| Agent | `codeigniter-site-builder` | Build, update, maintain or remove a CodeIgniter app with the commands above, in containers only |
| Agent | `codeigniter-tester` | Set the testing stack up, look at the app in the Playwright MCP browser first, write scenarios from the pack's steps and run them; it never creates an account in a suite and never writes a platform name into a step phrase |
| Skill | `codeigniter-scenarios` | Write a scenario from phrases that exist: the pack's steps by area, the handles of the users registry, the traps found on a real app, and three features that pass on a new app |
| Command | `/codeigniter-test <app> [feature or @tag]` | Run the suite of an app from inside a session: set up when missing, match every step, run, report what failed and why |
| Prompt | `codeigniter-build-and-test` | Start a session that builds an app, says what it is, sets the testing stack up and runs the first feature |
| Prompt | `codeigniter-scenarios-for-a-group` | Start a session that writes and runs the scenarios of one group of accounts |

After `--install` each is in its folder on the dashboard. **Install** there puts an agent, a skill
or a command into Claude Code (`~/.claude/agents`, `~/.claude/skills`, `~/.claude/commands`), or
from the command line:

```bash
cd ~/workspace/ai-agents   && bash cmd-tools-ai-items.sh codeigniter-tester --install
cd ~/workspace/ai-skills   && bash cmd-tools-ai-items.sh codeigniter-scenarios --install
cd ~/workspace/ai-commands && bash cmd-tools-ai-items.sh codeigniter-test --install
```

A prompt is not installed: it is the whole `claude …` launch command of a new session, and the
dashboard's **New screen** form lists it as a template. By hand, fill the placeholders in and run
the command of the file from the folder it names.

The items are written for any AI CLI, with Claude Code as the default shape: the frontmatter and
the file layout are Claude Code's, the body of each item is plain Markdown that names no tool or
feature of one CLI, a command says in words what its arguments are, and the text between the
triple quotes of a prompt can be given to another AI CLI as it is.

Every step phrase the items show is checked against the definitions of the step pack and of
webship-js (`tests/fixtures/step-definitions.txt`), and every command and flag against the
plugin's own.

## Develop it

```bash
npm install     # builds dist/ (TypeScript)
npm run lint
npm test        # the manifest, the commands, the AI items, the functions against a scaffolded project
```

CI runs the same on Node.js 20 and 24, parses every shell script, and runs the plugin's
`features/codeigniter.feature` against a dashboard with this plugin installed
(`webship/workspace/.github/workflows/plugin-browser-suite.yml`).
