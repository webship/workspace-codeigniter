Feature: Forms the app refuses, and its own pages
  As the owner of the app
  I want the app to refuse what it must, from its own forms and from elsewhere
  So that no account is made by mistake and no other site acts for an account

  # Registration is tested through its refusals only: the address is one the app already has.

  Scenario: A registration with an address that is taken is refused
    Given I am an anonymous user
    When I go to "/register"
    And I fill in "Email Address" with the email of "user"
    And I fill in "Username" with "new.person"
    And I fill in "Password" with "Strong-Pass-2026!"
    And I fill in "Password (again)" with "Other-Pass-2026!"
    And I click the "Register" button
    Then I should see the error message "The Email Address field must contain a unique value."
    And I should see the error message "The Password (again) field does not match the Password field."
    And I should not be logged in

  Scenario: An empty user name is refused by the browser before anything is sent
    Given I am an anonymous user
    When I go to "/register"
    And I fill in "Email Address" with the email of "user"
    And I click the "Register" button
    Then the "Username" field should block submission as required

  Scenario: A login form sent from a page of another site does not log the browser in
    Given I am an anonymous user
    When I go to "/login"
    And a page of another site sends the login form of "user" to "/login"
    Then I should not be logged in

  @js-off
  Scenario: An address the app does not have answers with the 404 page
    Given I am an anonymous user
    When I go to "/no-such-page-of-the-app"
    Then I should see the 404 error page
    And the response status code should be 404

  Scenario: The welcome page is the home page of a new app
    Given I am an anonymous user
    When I go to the homepage
    Then I should see the welcome page
