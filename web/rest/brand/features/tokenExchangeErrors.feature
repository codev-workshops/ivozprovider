Feature: Token exchange error handling
  In order to get meaningful feedback
  As a client software developer
  I need the token exchange endpoint to report errors as a JSON payload.

  Scenario: Exchanging without a token reports an error payload
     When I send a "POST" request to "token/exchange"
     Then the response should be in JSON
      And the JSON node "message" should be equal to "Token not found"

  Scenario: Exchanging without a username or brandId reports an error payload
     When I send a "POST" request to "token/exchange" with parameters:
      | key   | value            |
      | token | someopaquetoken  |
     Then the response should be in JSON
      And the JSON node "message" should be equal to "Either username or brandId must be set"
