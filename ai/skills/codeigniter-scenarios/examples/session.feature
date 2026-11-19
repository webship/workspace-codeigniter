Feature: The session of an account
  As an account of the app
  I want to log in, stay logged in while I ask to be remembered, and log out
  So that only I use my account, and only while I mean to

  Scenario: An account logs in with the login form
    Given I am an anonymous user
    When I log in as "user" with the login form
    Then I should be on the homepage
    And I should be logged in

  Scenario: A wrong password is refused with the error message of the login page
    Given I am an anonymous user
    When I go to "/login"
    And I fill in "Email Address" with the email of "user"
    And I fill in "Password" with "wrong-password"
    And I click the "Login" button
    Then I should see the login form
    And I should see the error message "Unable to log you in. Please check your password."
    And the "Email Address" field should hold the email of "user"
    And I should not be logged in

  Scenario: The banned account is refused
    Given I am an anonymous user
    When I go to "/login"
    And I fill in "Email Address" with the email of "banned"
    And I fill in "Password" with the password of "banned"
    And I click the "Login" button
    Then I should see the error message "Can not log you in as you are currently banned."
    And I should not be logged in

  Scenario: Logging out ends the session and says so
    Given I am a logged in user with the "developer" user
    When I log out
    Then I should see the login form
    And I should see the success message "You have successfully logged out."
    And I should not be logged in

  Scenario: A remembered login outlives the session, and logging out ends it for good
    Given I am an anonymous user
    When I log in as "user" with the login form and ask to be remembered
    Then a cookie with the name "remember" should exist
    When my session expires
    Then I should be logged in
    When I log out
    And my session expires
    Then I should not be logged in

  Scenario: A login that was not remembered ends with the session
    Given I am an anonymous user
    When I log in as "admin" with the login form
    And my session expires
    Then I should not be logged in
