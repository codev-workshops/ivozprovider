Feature: Unlink DDIs
  In order to release DDIs from their routing
  As a brand admin
  I need to be able to unlink DDIs through the API.

  Scenario: Unlink a DDI from its configuration
    Given I add Brand Authorization header
     When I add "Content-Type" header equal to "application/json"
      And I send a "POST" request to "ddis/unlink" with body:
      """
      [1]
      """
     Then the response status code should be 200
      And the response should be in JSON
      And the JSON node "status" should be equal to "OK"
