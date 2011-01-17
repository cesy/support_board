Feature: Release notes explain the code tickets which have been deployed

Scenario: volunteers can create new release notes
  When I am logged in as "blair"
    And I follow "Support Board"
    And I follow "create new release note"
    And I fill in "Release" with "0.8.4.7"
    And I fill in "Content" with "bug fix release"
    And I press "Create Release note"
  Then I should see "Release: 0.8.4.7"
    And I should see "bug fix release"
  When I follow "Edit"
    And I fill in "Release" with "0.8.4.8"
    And I press "Update Release note"
  Then I should see "Release: 0.8.4.8"

Scenario: support admins can edit release notes which have been posted
  When I am logged in as "bofh"
    And I am on the support page
    And I follow "Release Notes"
    And I follow "1.0"
  When I follow "Edit"
    And I fill in "Release" with "1.0.1"
    And I fill in "Content" with "some stuff"
    And I press "Update Release note"
  Then I should see "Release: 1.0.1"
    And I should see "some stuff"
  When I am logged in as "sam"
    And I am on the support page
    And I follow "Release Notes"
    And I follow "1.0"
  Then I should see "some stuff"
    But I should not see "Edit"
