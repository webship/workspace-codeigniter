Feature: The app answers and its accounts work
  As the owner of the app
  I want the welcome page, the login page and each default account to work
  So that a build that came out broken is caught before anything else is tested

  # Placed by the workspace's testing setup as a starting point: it is yours to change.
  # The accounts are the default ones (cmd-tools-codeigniter-spark.sh --add-users); a scenario logs in
  # by a handle of the users registry in cucumber.js, so no password is written here.

  @critical
  Scenario: The welcome page is served
    Given I am an anonymous user
    When I go to the homepage
    Then the response status code should be 200
    And I should see the welcome page

  @critical
  Scenario: The login page is served with its form
    Given I am an anonymous user
    When I go to "/login"
    Then the response status code should be 200
    And I should see the login form

  Scenario Outline: The <account> account logs in
    Given I am a logged in user with the "<account>" user
    Then I should be logged in

    Examples:
      | account   |
      | admin     |
      | developer |
      | user      |

  Scenario: The banned account is refused
    Given I am an anonymous user
    When I go to "/login"
    And I fill in "Email Address" with the email of "banned"
    And I fill in "Password" with the password of "banned"
    And I click the "Login" button
    Then I should see the error message "Can not log you in as you are currently banned."
    And I should not be logged in

  Scenario: Logging out says so
    Given I am a logged in user with the "user" user
    When I log out
    Then I should see the login form
    And I should see the success message "You have successfully logged out."

  @js-off
  Scenario: An address the app does not have answers with the 404 page
    Given I am an anonymous user
    When I go to "/no-such-page-of-the-app"
    Then I should see the 404 error page
