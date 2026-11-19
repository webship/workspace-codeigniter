Feature: The CodeIgniter plugin on the dashboard
  Once the plugin is activated and installed, the sites folders offer the CodeIgniter builder, each
  AI folder lists the items of its kind the plugin ships, and the Plugins page lists the plugin
  with its steps.

  # Settings lists every plugin that was added; the package and what the plugin ships are on its own page.
  Scenario: Settings lists the plugin, and its own page names its package and what it ships
    Given I am on "/settings"
     Then I should see "CodeIgniter"
     When I go to "/settings/plugin/codeigniter"
     Then I should see "@webship.co/workspace-codeigniter"
      And I should see "cmd-codeigniter-project.sh"
      And I should see "codeigniter-site-builder"

  Scenario: A sites folder offers the CodeIgniter builder
    Given I am on "/dev"
     Then "option[value='cmd-codeigniter-project.sh']" should be attached

  # The AI folders are searched by name: with every plugin on, a folder lists more than one page of items.
  Scenario: The AI Agents folder lists the agents the plugin ships
    Given I am on "/ai-agents?q=codeigniter-"
     Then I should see "codeigniter-site-builder"
      And I should see "codeigniter-tester"

  Scenario: The AI Skills folder lists the skill the plugin ships
    Given I am on "/ai-skills?q=codeigniter-scenarios"
     Then I should see "codeigniter-scenarios"

  Scenario: The AI Commands folder lists the command the plugin ships
    Given I am on "/ai-commands?q=codeigniter-test"
     Then I should see "codeigniter-test"

  Scenario: The AI Prompts folder lists the prompts the plugin ships
    Given I am on "/ai-prompts?q=codeigniter-"
     Then I should see "codeigniter-build-and-test"
      And I should see "codeigniter-scenarios-for-a-group"
