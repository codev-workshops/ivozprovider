Feature: Retrieve companies not assigned within a corporation
  In order to manage inter-company friends
  As a brand admin
  I need to retrieve the companies of a corporation that are still unassigned.

  Scenario: Retrieve companies unassigned for a corporate company
    Given I add Brand Authorization header
     When I add "Accept" header equal to "application/json"
      And I send a "GET" request to "companies/corporate/unassigned?_companyId=1"
     Then the response status code should be 200
      And the response should be in JSON

  Scenario: Retrieve companies unassigned including a specific company
    Given I add Brand Authorization header
     When I add "Accept" header equal to "application/json"
      And I send a "GET" request to "companies/corporate/unassigned?_companyId=1&_includeId=2"
     Then the response status code should be 200
      And the response should be in JSON
