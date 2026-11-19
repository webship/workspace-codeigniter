Write and run webship-js scenarios for what one group of accounts may do on a CodeIgniter app.

The launch command below is for Claude Code, the default; the text between the triple quotes can be given to another AI CLI as it is.

```
claude --permission-mode bypassPermissions """
Write scenarios for what the <admin|developer|user> group may and may not open on this app, and run them
# ~/workspace/<folder>/<app> · https://<app>.ddev.site · container-based (DDEV by default)
# the phrases are in the codeigniter-scenarios skill; the codeigniter-tester agent is the one to hand this work over to
# look at the app first: in the Playwright MCP browser, in a tab of your own, open each page as that account by hand once before writing its scenario
# a feature to write or a run to read: the book Automated Functional Testing Recipes first (its README.md, then the matching chapter), from .claude/automated-functional-testing-recipes/ in the project, ~/.claude/automated-functional-testing-recipes/ or https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes

What to cover:
<the pages of the app this group may open, and the ones it may not, one per line>

Read the routes and their filters first, and the installed steps:
bash cmd-tools-codeigniter-spark.sh <app> --run "routes"
grep -hE '^(Given|When|Then)\(' node_modules/@webship-js/codeigniter-steps/tests/step-definitions/*.steps.js

Write one feature in tests/features/<group>.feature, from phrases that exist: a table of who may open each page
(Then the access to "<page>" should be:), and a scenario per page for the account of the group.
Log in by the handle of the users registry (admin, developer, user, banned):
no password in the feature, no account created by a scenario (registration only through its refusals), no platform name in a step phrase.

Then, from the sites folder (cd ..):
bash cmd-tools-testing.sh <app> --dry-run --path tests/features/<group>.feature
bash cmd-tools-testing.sh <app> --run --path tests/features/<group>.feature

A failing scenario is a result: tell me what the app did, do not loosen the scenario.
When you are done: the scenarios, the result of the run, and any step you could not find in the pack
"""
```
