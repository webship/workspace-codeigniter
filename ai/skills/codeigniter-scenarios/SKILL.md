---
name: codeigniter-scenarios
description: Write and run webship-js scenarios for a CodeIgniter app of the Webship Workspace with the CodeIgniter step pack (`@webship-js/codeigniter-steps`) — the phrases of the pack by area (the session and the login link by mail, forms and their messages, groups and permissions, the framework's own pages, the debug toolbar), the handles of the users registry, and the workspace command that runs them in the app's container. Use when asked to "write a scenario for this CodeIgniter app", "test the login link", "which step is there for a page only admins may open", "add a feature for the registration refusals", or when a `.feature` file of a CodeIgniter project is being written or fixed.
argument-hint: '<app> [what to cover]'
---

# codeigniter-scenarios

Scenarios for a CodeIgniter app of a Webship Workspace (`~/workspace`, container-based, DDEV by
default), written from the steps of [`@webship-js/codeigniter-steps`](https://github.com/webship/codeigniter-steps)
and of [webship-js](https://github.com/webship/webship-js) itself, and run in the app's container
by the workspace's own command. It comes with the CodeIgniter plugin (`@webship.co/workspace-codeigniter`),
like the builder (`cmd-codeigniter-project.sh`), the spark tool (`cmd-tools-codeigniter-spark.sh`) and
the agents `codeigniter-site-builder` and `codeigniter-tester`.

## Where everything is

| What | Where |
| --- | --- |
| The app | `~/workspace/<folder>/<app>`, at `https://<app>.ddev.site` (`<folder>` is a sites folder: `dev`, `test`, `sandboxes`, `demos`) |
| Its mail | the mail catcher of the project, `https://<app>.ddev.site:8026` |
| The suite's configuration | `<app>/cucumber.js`: the step definitions it loads, the users registry (`worldParameters.users`), the mailbox (`mailUrl`) |
| The features | `<app>/tests/features/*.feature` (`site.feature` is the first one the setup wrote) |
| The pack's steps | `<app>/node_modules/@webship-js/codeigniter-steps/tests/step-definitions/*.steps.js` |
| webship-js's steps | `<app>/node_modules/webship-js/tests/step-definitions/*.js` |
| The reports | `<app>/tests/reports/` |

## The order of work

1. **Make sure the testing stack is there.** From the sites folder:
   ```bash
   cd ~/workspace/<folder>
   bash cmd-tools-testing.sh <app>
   ```
   It adds webship-js, the step pack, the users registry, the mailbox and
   `tests/features/site.feature`, and makes sure the default accounts are on the app. It is safe
   to run again: it adds what is missing and keeps what was changed.
2. **Read the installed steps before writing a phrase.** They are the source of truth: the pack
   moves, and a phrase from memory is a guess.
   ```bash
   cd ~/workspace/<folder>/<app>
   grep -hE "^(Given|When|Then)\(" node_modules/@webship-js/codeigniter-steps/tests/step-definitions/*.steps.js
   ```
   Every step carries a comment block with five examples above it; open the file when a phrase
   is not obvious.
3. **Look at the page first** (the Playwright MCP browser, a tab of your own) when the scenario
   is about a page you have not seen: its fields by their labels, its messages, where a refused
   account is sent.
4. **Write the feature** in `<app>/tests/features/`, from phrases that exist (the lists below).
5. **Match every step without a browser**, then run the feature, then the suite:
   ```bash
   cd ~/workspace/<folder>
   bash cmd-tools-testing.sh <app> --dry-run --path tests/features/<name>.feature
   bash cmd-tools-testing.sh <app> --run --path tests/features/<name>.feature
   bash cmd-tools-testing.sh <app> --run --tags "@critical"
   bash cmd-tools-testing.sh <app> --run
   ```
   A dry run says `Undefined` for a phrase no definition matches: fix the phrase, do not write a
   step for it.

## Accounts: a handle, never a password

A scenario logs in by a handle of the users registry. The default accounts are on an app built
with `--shield` already (`bash cmd-tools-codeigniter-spark.sh <app> --add-users` writes them again,
with their name, password, groups and state):

| Handle | Account | What the app does with it |
| --- | --- | --- |
| `admin` | `admin@example.com` | The "admin" group |
| `developer` | `developer@example.com` | The "developer" group, which has the "admin.settings" permission |
| `user` | `user@example.com` | The "user" group, the one a new account gets |
| `banned` | `banned@example.com` | Banned: the app refuses its login |

```gherkin
Given I am a logged in user with the "admin" user
Then I should be logged in
When I fill in "Password" with the password of "user"
```

## The phrases, by area

Each line is a phrase the pack or webship-js defines, and each one passed on an app built with
`bash cmd-codeigniter-project.sh <app> --install --add-users --shield`, the pages an app guards
among them (see the traps). Most `should` steps also take the negative: `should not see`,
`should not be`, `should not have`.

### The session and the login link

```gherkin
Given I am an anonymous user
Given I am a logged in user with the "user" user
When I log in as "user" with the login form
When I log in as "user" with the login form and ask to be remembered
When I log in with the email "user@example.com" and the password "wrong-password"
When I log out
When my session expires
Then I should be logged in
Then I should not be logged in
Then I should be logged in as "user"
Then I should see the login form
When I ask for a login link for "user"
Then an email with the subject "Your Login Link" should be sent to "user"
Then the email with the subject "Your Login Link" to "user" should contain "Username: user"
When I open the "Login" link of the email to "user"
Then no email should be sent to "nobody@example.com"
```

### Forms and their messages

```gherkin
When I fill in "Email Address" with the email of "user"
When I fill in "Username" with the username of "user"
Then the "Email Address" field should hold the email of "user"
Then I should see the error message "Unable to log you in. Please check your password."
Then I should see the success message "You have successfully logged out."
Then I should not see any error message
Then the "Username" field should block submission as required
When the security token of the form expires
```

### Groups and permissions

```gherkin
Then I should have access to "/admin"
Then I should not have access to "/admin"
Then the access to "/admin" should be:
  | account   | access  |
  | admin     | allowed |
  | developer | denied  |
  | user      | denied  |
  | visitor   | login   |
```

### The framework's own pages

```gherkin
Then I should see the welcome page
Then the page should say it runs in the "production" environment
Then I should see the 404 error page
Then the page should not show debug information
When a page of another site sends the login form of "user" to "/login"
Then I should see the debug toolbar
When I open the "Routes" panel of the debug toolbar
Then the "Routes" panel of the debug toolbar should show "LoginController::loginView"
```

`I am an anonymous user`, `I should see "<text>"`, `I click the "<name>" button`, `a cookie with the
name "remember" should exist` and `the response status code should be 200` are webship-js's own
steps; its fields, dialogs, cookies, status codes and accessibility audits are used as they are and
never redefined for this platform.

## Traps found on a real app

- **A new app guards no page.** The app starter has one page, the welcome page, and the auth library
  adds only its own (login, registration, the login link). The access steps and
  `I should be logged in as "..."` need the pages your app guards with the library's filters
  (`session`, `group:admin,superadmin`, `permission:admin.settings`) and a page that names the
  signed-in account (`worldParameters.accountPath`). The step pack's repository has four such pages
  in its `site/` folder, to copy into an app that has none.
- **A refused account gets no word.** The library sends an account without the group or the
  permission to the home page, and the welcome page shows no message: the access steps read where
  the browser was sent, not a text.
- **Two messages tell an account apart.** A wrong password of a known address reads "Please check
  your password.", an unknown address "Please check your credentials.": write the scenario for the
  case it means.
- **The logout leaves a cookie.** The "remember" cookie stays in the browser after a logout, but
  the app forgets its token: assert that nobody is logged in once the session expires, not that the
  cookie is gone.
- **Development or production.** An app built without `--production` runs in development: the
  debug toolbar is on every page, an error shows the debug page, a 404 tells how it was routed, and
  a form with an out-of-date token is refused with the 403 debug page instead of the login page and
  its message. A scenario about either needs the app in that environment
  (`bash cmd-tools-codeigniter-spark.sh <app> --environment production`).
- **A login link is for once.** A link opened twice is refused; a link opened while an account is
  logged in sends the browser on to the home page and drops the error.

## Rules

- **No account is created in a suite.** No account made in a hook, no registration that goes
  through: registration is tested through its refusals only, with an address that is already
  taken. An account the registry does not have is asked for, not made.
- **Never the workspace account.** The app's first account is not in the registry.
- **No password in a feature file**, except where a wrong password is the subject.
- **No platform name in a step phrase**: `I should see the 404 error page`, never a phrase that
  names the framework or a library. The same holds for a custom step.
- **What a scenario changes, it changes back** in the same scenario.
- **A custom step is the last resort**: look in the pack and in webship-js first, write it in
  `<app>/tests/step-definitions/` with a comment block and examples, and say it may belong in
  the pack.
- **Everything runs in the container**, through `cmd-tools-testing.sh`. Never `npx cucumber-js`
  or `npx playwright` on the host.
- **A failing scenario is a result.** No `@wip`, no longer timeout, no looser assertion to turn a
  run green: say what the app did.

## Examples that run

`examples/` holds three features that pass on an app built with
`bash cmd-codeigniter-project.sh <app> --install --add-users --shield`, in development and in
production alike. Copy one into the suite and run it:

```bash
cp ~/workspace/ai-skills/codeigniter-scenarios/examples/session.feature ~/workspace/<folder>/<app>/tests/features/
cd ~/workspace/<folder>
bash cmd-tools-testing.sh <app> --run --path tests/features/session.feature
```

| Feature | What it shows |
| --- | --- |
| `examples/session.feature` | Logging in with the form, a wrong password with the error message, the banned account, logging out, a remembered login that outlives the session, one that does not |
| `examples/login-link.feature` | The login link from the request to the mail and the login, a link used twice, an address with no account |
| `examples/forms-and-pages.feature` | Registration refused for a taken address and a confirmation that differs, an empty user name the browser refuses, a login form sent from another site, the 404 page, the welcome page |

## The book

For any automated functional testing in this work (a Gherkin feature, a step definition, choosing a
step, a test run and its failures), read the book *Automated Functional Testing Recipes* first.

- **Where.** Use the first that exists: `.claude/automated-functional-testing-recipes/` in the project,
  `~/.claude/automated-functional-testing-recipes/` (installed by webship/webship-js-ai-agent,
  webship/webship-js-skills or webship/ai-agents), or
  https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes
- **How.** Its `README.md` first, then the chapter that matches the task (one file per chapter,
  named by its subject), not the single complete file.
- **Which wins.** The installed webship-js package and the step pack are the source of truth for
  step phrasing. When they differ from the book, follow them and say so.
- **For CodeIgniter.** Start with `ch10-authentication-authorization.md` (logins, sessions, roles
  and protected pages), `ch06-form-testing-recipes.md` (forms, validation and their messages),
  `ch33-complete-step-definition-reference.md` (every built-in step) and `ch21-when-tests-go-bad.md`
  (flaky, brittle and slow scenarios).
