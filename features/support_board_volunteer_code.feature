Feature: volunteers working with code tickets

Scenario: pseuds don't have to be unique, but in progress tickets by pseud should be correct
  Given a volunteer exists with login: "rodney", id: 1
    And a volunteer exists with login: "hermione", id: 2
  When "rodney" has a support pseud "oracle"
    And "hermione" has a support pseud "oracle"
    And a code ticket exists with id: 1
    And a code ticket exists with id: 2
  When "rodney" takes code ticket 1
    And "hermione" takes code ticket 2
  When I am on rodney's user page
    And I follow "rodney's pseuds"
    And I follow "oracle"
    And I follow "Code Tickets in progress"
  Then I should see "Code Ticket #1"
    But I should not see "Code Ticket #2"
  When I am on hermione's user page
    And I follow "hermione's pseuds"
    And I follow "oracle"
    And I follow "Code Tickets in progress"
  Then I should not see "Code Ticket #1"
    But I should see "Code Ticket #2"

Scenario: pseuds don't have to be unique, but resolved tickets by pseud should be correct
  Given a volunteer exists with login: "rodney", id: 1
    And a volunteer exists with login: "hermione", id: 2
  When "rodney" has a support pseud "oracle"
    And "hermione" has a support pseud "oracle"
    And a code ticket exists with id: 1
    And a code ticket exists with id: 2
  When "rodney" resolves code ticket 1
    And "hermione" resolves code ticket 2
  When I am on rodney's user page
    And I follow "rodney's pseuds"
    And I follow "oracle"
    And I follow "Resolved Code Tickets"
  Then I should see "Code Ticket #1"
    But I should not see "Code Ticket #2"
  When I am on hermione's user page
    And I follow "hermione's pseuds"
    And I follow "oracle"
    And I follow "Resolved Code Tickets"
  Then I should not see "Code Ticket #1"
    But I should see "Code Ticket #2"

Scenario: volunteers can close a code ticket as a dupe
  Given a code ticket exists with summary: "original", id: 1
    And a code ticket exists with summary: "dupe", id: 2
  When I am logged in as volunteer "oracle"
    And I follow "Support Board"
    And I follow "Open Code Tickets"
    And I follow "Code Ticket #2"
    And I select "Code Ticket #1" from "Code Ticket"
    And I press "Dupe"
  Then I should see "Status: Closed as dupe Code Ticket #1"
  When I follow "Support Board"
    And I follow "Open Code Tickets"
  Then I should see "Code Ticket #1"
    But I should not see "Code Ticket #2"
  When I follow "Support Board"
    And I follow "Resolved Code Tickets"
  Then I should see "Code Ticket #2"
  When I follow "oracle"
    And I follow "oracle's pseuds"
    And I follow "oracle" within ".pseuds"
    And I follow "Resolved Code Tickets"
  Then I should see "Code Ticket #2"

# TODO
Scenario: code tickets can be sorted by votes

