Feature: the support board as seen by logged in support volunteers for support tickets

Scenario: support board volunteers can access and take private tickets
  Given the following support tickets exist
    | summary                           | private | id |
    | private support ticket            | true    |  1 |
  Given I am logged in as support volunteer "oracle"
  When I follow "Support Board"
    And I follow "Open Support Tickets"
    And I follow "Support Ticket #1"
  Then I should see "Add details"
  When I press "Take"
  Then I should see "Status: Being worked by support volunteer oracle"
    And I should see "Access: Private"

Scenario: support board volunteers can (un)take tickets.
  Given the following support tickets exist
    | summary                           | id |
    | publicly visible support ticket   | 1  |
  Given I am logged in as support volunteer "oracle"
  When I follow "Support Board"
    And I follow "Open Support Tickets"
    And I follow "Support Ticket #1"
  Then I should see "Status: Open"
  When I press "Take"
  Then I should see "Status: Being worked by support volunteer oracle"
    When I press "Untake"
  Then I should see "Status: Open"

Scenario: support board volunteers can steal owned tickets.
  Given the following support tickets exist
    | summary                           | id |
    | publicly visible support ticket   | 1  |
    And an activated support volunteer exists with login "oracle"
    And "oracle" takes support ticket 1
  Given I am logged in as support volunteer "hermione"
  When I follow "Support Board"
    And I follow "Claimed Support Tickets"
    And I follow "Support Ticket #1"
  Then I should see "support volunteer oracle"
    When I press "Take"
  Then I should see "support volunteer hermione"
    And 1 email should be delivered to "oracle@ao3.org"
    And the email should contain "has been stolen by"
    And the email should contain "hermione"

Scenario: support board volunteers can comment on owned tickets.
  Given the following support tickets exist
    | summary                           | id |
    | publicly visible support ticket   | 1  |
    And an activated support volunteer exists with login "oracle"
    And "oracle" takes support ticket 1
  Given I am logged in as support volunteer "hermione"
  When I follow "Support Board"
    And I follow "Open Support Tickets"
  Then I should not see "Support Ticket #1"
  When I follow "Support Board"
    And I follow "Claimed Support Tickets"
    And I follow "Support Ticket #1"
  Then I should see "support volunteer oracle"
    And I should see "Add details"

Scenario: support board volunteers can make tickets private, but not public again
  Given the following support tickets exist
    | summary                           | id |
    | publicly visible support ticket   | 1  |
  When I am logged in as support volunteer "oracle"
    And I go to the first support ticket page
    And I check "Private"
    And I press "Update Support ticket"
  Then I should see "Access: Private"
    And I should not see "Ticket will only be visible to"

Scenario: private user support tickets can't be made public by volunteers
  Given the following activated user exists
    | login     | id |
    | troubled  | 1  |
  And the following support tickets exist
    | summary      | private | user_id |
    | embarrassing | true    | 1       |
  When I am logged in as support volunteer "oracle"
    And I go to the first support ticket page
  Then I should see "embarrassing"
    And I should see "Access: Private"
    But I should not see "Ticket will only be visible to"
