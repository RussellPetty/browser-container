#!/bin/bash

# Health Check Script for Browser-in-Container System
# Usage: ./health-check.sh [domain] [auth-token]

DOMAIN="${1:-localhost:3000}"
AUTH_TOKEN="${2:-your-auth-token}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔍 Browser-in-Container Health Check"
echo "===================================="
echo "Domain: $DOMAIN"
echo "Time: $(date)"
echo ""

# Helper function for checks
check_endpoint() {
    local name="$1"
    local url="$2"
    local expected_status="${3:-200}"
    local headers="$4"
    
    echo -n "Checking $name... "
    
    if [ -n "$headers" ]; then
        response=$(curl -s -o /dev/null -w "%{http_code}" -H "$headers" "$url" 2>/dev/null)
    else
        response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
    fi
    
    if [ "$response" = "$expected_status" ]; then
        echo -e "${GREEN}✅ OK (HTTP $response)${NC}"
        return 0
    else
        echo -e "${RED}❌ FAIL (HTTP $response, expected $expected_status)${NC}"
        return 1
    fi
}

# System checks
echo "📊 SYSTEM HEALTH"
echo "----------------"

# Check if URL is accessible
if [[ $DOMAIN == *"localhost"* ]]; then
    BASE_URL="http://$DOMAIN"
else
    BASE_URL="https://$DOMAIN"
fi

# API Health Checks
check_endpoint "API Base" "$BASE_URL/health" "200"
check_endpoint "Admin Endpoint (Unauthorized)" "$BASE_URL/admin/users" "401"
check_endpoint "Admin Endpoint (Authorized)" "$BASE_URL/admin/users" "200" "Authorization: Bearer $AUTH_TOKEN"
check_endpoint "Session Creation (Unauthorized)" "$BASE_URL/session" "401"

echo ""
echo "🐳 DOCKER CONTAINERS"
echo "-------------------"

# Docker container checks
if command -v docker &> /dev/null; then
    session_manager_running=$(docker ps --filter "name=session-manager" --format "table {{.Names}}" | grep -c session-manager || true)
    total_containers=$(docker ps --filter "name=chrome-" --format "table {{.Names}}" | grep -c chrome- || true)
    
    echo "Session Manager: $([ $session_manager_running -gt 0 ] && echo -e "${GREEN}✅ Running${NC}" || echo -e "${RED}❌ Not Running${NC}")"
    echo "Browser Containers: $total_containers active"
    
    # Container resource usage
    echo ""
    echo "📈 RESOURCE USAGE"
    echo "----------------"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | head -10
else
    echo -e "${YELLOW}⚠️ Docker not available on this system${NC}"
fi

echo ""
echo "💾 DISK SPACE"
echo "------------"
df -h / | tail -1 | awk '{print "Root Filesystem: " $3 "/" $2 " (" $5 " used)"}'

if [ -d "/opt/browser-container/user-profiles" ]; then
    profiles_size=$(du -sh /opt/browser-container/user-profiles 2>/dev/null | cut -f1 || echo "N/A")
    echo "User Profiles: $profiles_size"
fi

echo ""
echo "🔒 SECURITY STATUS"
echo "-----------------"

# Check SSL certificate
if [[ $DOMAIN != *"localhost"* ]]; then
    echo -n "SSL Certificate... "
    if curl -s --head "https://$DOMAIN" | head -n 1 | grep -q "200 OK"; then
        echo -e "${GREEN}✅ Valid${NC}"
    else
        echo -e "${RED}❌ Invalid or Missing${NC}"
    fi
fi

# Check firewall (if available)
if command -v ufw &> /dev/null; then
    ufw_status=$(ufw status | head -1 | awk '{print $2}')
    echo "Firewall (UFW): $([ "$ufw_status" = "active" ] && echo -e "${GREEN}✅ Active${NC}" || echo -e "${YELLOW}⚠️ Inactive${NC}")"
fi

echo ""
echo "📊 SESSION STATISTICS"
echo "--------------------"

if curl -s -H "Authorization: Bearer $AUTH_TOKEN" "$BASE_URL/admin/users" > /dev/null 2>&1; then
    users_data=$(curl -s -H "Authorization: Bearer $AUTH_TOKEN" "$BASE_URL/admin/users" 2>/dev/null)
    if command -v jq &> /dev/null; then
        total_users=$(echo "$users_data" | jq '.totalUsers // 0')
        echo "Total Users: $total_users"
    else
        echo "Users: $(echo "$users_data" | grep -o '"totalUsers":[0-9]*' | cut -d: -f2 || echo "N/A")"
    fi
else
    echo -e "${RED}❌ Cannot retrieve session statistics${NC}"
fi

# Performance test
echo ""
echo "⚡ PERFORMANCE TEST"
echo "------------------"
echo -n "API Response Time... "
start_time=$(date +%s%N)
curl -s -H "Authorization: Bearer $AUTH_TOKEN" "$BASE_URL/admin/users" > /dev/null 2>&1
end_time=$(date +%s%N)
response_time=$(( (end_time - start_time) / 1000000 ))

if [ $response_time -lt 1000 ]; then
    echo -e "${GREEN}✅ ${response_time}ms${NC}"
elif [ $response_time -lt 5000 ]; then
    echo -e "${YELLOW}⚠️ ${response_time}ms (slow)${NC}"
else
    echo -e "${RED}❌ ${response_time}ms (very slow)${NC}"
fi

echo ""
echo "📋 SUMMARY"
echo "----------"

# Overall health score
health_score=0
total_checks=5

# Count successful checks (simplified)
curl -s "$BASE_URL/health" > /dev/null 2>&1 && ((health_score++))
curl -s -H "Authorization: Bearer $AUTH_TOKEN" "$BASE_URL/admin/users" > /dev/null 2>&1 && ((health_score++))
[ $session_manager_running -gt 0 ] 2>/dev/null && ((health_score++))
[ $response_time -lt 5000 ] 2>/dev/null && ((health_score++))
[[ $DOMAIN == *"localhost"* ]] || (curl -s --head "https://$DOMAIN" | head -n 1 | grep -q "200 OK" && ((health_score++)))

health_percentage=$(( health_score * 100 / total_checks ))

if [ $health_percentage -ge 80 ]; then
    echo -e "Overall Health: ${GREEN}✅ Healthy ($health_percentage%)${NC}"
elif [ $health_percentage -ge 60 ]; then
    echo -e "Overall Health: ${YELLOW}⚠️ Warning ($health_percentage%)${NC}"
else
    echo -e "Overall Health: ${RED}❌ Critical ($health_percentage%)${NC}"
fi

echo ""
echo "🔧 TROUBLESHOOTING"
echo "-----------------"
echo "View logs: docker compose logs -f"
echo "Restart services: docker compose restart"
echo "Check containers: docker ps"
echo "Monitor resources: docker stats"
echo ""
echo "Health check completed at $(date)"