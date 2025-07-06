#!/bin/bash

echo "🔐 Testing API Security Implementation"
echo "===================================="

# Set test variables
BASE_URL="http://localhost:3000"
VALID_TOKEN="test-auth-token"
INVALID_TOKEN="invalid-token"

echo ""
echo "1. Testing API without authentication (should fail with 401)"
echo "------------------------------------------------------------"
curl -X POST $BASE_URL/session \
  -H "Content-Type: application/json" \
  -d '{"url": "https://google.com", "email": "test@example.com"}' \
  -w "\nStatus: %{http_code}\n" \
  -s

echo ""
echo "2. Testing API with invalid token (should fail with 401)"
echo "-------------------------------------------------------"
curl -X POST $BASE_URL/session \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $INVALID_TOKEN" \
  -d '{"url": "https://google.com", "email": "test@example.com"}' \
  -w "\nStatus: %{http_code}\n" \
  -s

echo ""
echo "3. Testing API with valid token (should succeed with 200)"
echo "--------------------------------------------------------"
curl -X POST $BASE_URL/session \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $VALID_TOKEN" \
  -d '{"url": "https://google.com", "email": "test@example.com"}' \
  -w "\nStatus: %{http_code}\n" \
  -s

echo ""
echo "4. Testing admin endpoint without auth (should fail with 401)"
echo "------------------------------------------------------------"
curl -X GET $BASE_URL/admin/users \
  -w "\nStatus: %{http_code}\n" \
  -s

echo ""
echo "5. Testing admin endpoint with valid token (should succeed with 200)"
echo "-------------------------------------------------------------------"
curl -X GET $BASE_URL/admin/users \
  -H "Authorization: Bearer $VALID_TOKEN" \
  -w "\nStatus: %{http_code}\n" \
  -s

echo ""
echo "🔐 Security test completed!"
echo "Expected results:"
echo "- Tests 1, 2, 4: HTTP 401 (Unauthorized)"
echo "- Tests 3, 5: HTTP 200 (Success)"