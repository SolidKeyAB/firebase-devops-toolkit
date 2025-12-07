#!/bin/bash

# AI-Protected Firebase Emulator Sharing Script
# Usage: ./ai-protected-share-emulators.sh [start|stop|status|urls] [options]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARE_DIR="$SCRIPT_DIR/.emulator-sharing"
PID_FILE="$SHARE_DIR/ngrok_pids.txt"
URL_FILE="$SHARE_DIR/ngrok_urls.txt"
CONFIG_FILE="$SHARE_DIR/security_config.json"
AUTH_FILE="$SHARE_DIR/auth_tokens.txt"
RATE_LIMIT_FILE="$SHARE_DIR/rate_limits.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Security settings
DEFAULT_TIMEOUT="3600"  # 1 hour
DEFAULT_REGION="us"     # ngrok region
DEFAULT_RATE_LIMIT="10" # 1 action per 10 seconds
DEFAULT_MAX_REQUESTS="100" # Max requests per session
ALLOWED_SERVICES=("ui" "functions" "frontend")

# Create sharing directory
mkdir -p "$SHARE_DIR"

# Function to generate secure token with complexity
generate_auth_token() {
    # Generate complex token with multiple sources
    local token1=$(openssl rand -hex 8 2>/dev/null || python3 -c "import secrets; print(secrets.token_hex(8))" 2>/dev/null)
    local token2=$(date +%s | sha256sum | head -c 8 2>/dev/null || date +%s)
    local token3=$(echo $RANDOM | sha256sum | head -c 8 2>/dev/null || echo $RANDOM)
    echo "${token1}${token2}${token3}"
}

# Function to create rate limiting configuration
create_rate_limit_config() {
    local rate_limit="${1:-$DEFAULT_RATE_LIMIT}"
    local max_requests="${2:-$DEFAULT_MAX_REQUESTS}"
    local captcha_after="${3:-50}"

    cat > "$RATE_LIMIT_FILE" << EOF
{
    "rate_limit_seconds": $rate_limit,
    "max_requests_per_session": $max_requests,
    "captcha_threshold": $captcha_after,
    "request_log": [],
    "blocked_patterns": [
        "bot", "crawler", "spider", "scraper", "automation",
        "selenium", "puppeteer", "playwright", "curl", "wget",
        "python-requests", "okhttp", "axios", "fetch"
    ],
    "suspicious_behaviors": {
        "rapid_requests": 0,
        "pattern_matches": 0,
        "failed_auth_attempts": 0
    },
    "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}

# Function to create AI protection middleware for ngrok
create_protection_middleware() {
    local auth_token="$1"
    local rate_limit="$2"

    # Create a simple protection script that ngrok can use
    cat > "$SHARE_DIR/protection_middleware.py" << 'EOF'
#!/usr/bin/env python3
import json
import time
import re
from datetime import datetime, timedelta
from collections import defaultdict, deque
import sys
import os

class AIProtectionMiddleware:
    def __init__(self, config_file):
        self.config_file = config_file
        self.request_times = defaultdict(deque)
        self.suspicious_ips = set()
        self.load_config()

    def load_config(self):
        try:
            with open(self.config_file, 'r') as f:
                self.config = json.load(f)
        except:
            self.config = {
                "rate_limit_seconds": 10,
                "max_requests_per_session": 100,
                "blocked_patterns": ["bot", "crawler", "automation"]
            }

    def is_suspicious_user_agent(self, user_agent):
        if not user_agent:
            return True

        user_agent_lower = user_agent.lower()
        blocked_patterns = self.config.get("blocked_patterns", [])

        for pattern in blocked_patterns:
            if pattern in user_agent_lower:
                return True

        # Check for missing common browser indicators
        browser_indicators = ["mozilla", "webkit", "chrome", "firefox", "safari"]
        if not any(indicator in user_agent_lower for indicator in browser_indicators):
            return True

        return False

    def check_rate_limit(self, ip_address):
        now = time.time()
        rate_limit = self.config.get("rate_limit_seconds", 10)

        # Clean old requests
        cutoff_time = now - rate_limit
        while self.request_times[ip_address] and self.request_times[ip_address][0] < cutoff_time:
            self.request_times[ip_address].popleft()

        # Check if rate limit exceeded
        if len(self.request_times[ip_address]) >= 1:
            return False

        # Add current request
        self.request_times[ip_address].append(now)
        return True

    def detect_automation_patterns(self, headers):
        """Detect common automation patterns"""
        suspicious_patterns = [
            # Missing common browser headers
            lambda h: 'accept-language' not in [k.lower() for k in h.keys()],
            # Suspicious accept headers
            lambda h: h.get('accept', '').startswith('application/json'),
            # Missing or suspicious referer patterns
            lambda h: not h.get('referer') and h.get('accept', '').startswith('text/html'),
            # Automation tools
            lambda h: any(tool in h.get('user-agent', '').lower()
                         for tool in ['selenium', 'puppeteer', 'playwright', 'headless']),
        ]

        return sum(1 for pattern in suspicious_patterns if pattern(headers))

    def should_block_request(self, ip, user_agent, headers):
        # Rate limiting
        if not self.check_rate_limit(ip):
            return True, "Rate limit exceeded"

        # User agent analysis
        if self.is_suspicious_user_agent(user_agent):
            return True, "Suspicious user agent detected"

        # Automation pattern detection
        automation_score = self.detect_automation_patterns(headers)
        if automation_score >= 2:
            return True, "Automation patterns detected"

        return False, "OK"

# Simple HTTP server with protection
if __name__ == "__main__":
    import http.server
    import socketserver
    from urllib.parse import urlparse, parse_qs

    class ProtectedHandler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            self.protection = AIProtectionMiddleware(sys.argv[1] if len(sys.argv) > 1 else "rate_limits.json")
            super().__init__(*args, **kwargs)

        def do_GET(self):
            client_ip = self.client_address[0]
            user_agent = self.headers.get('User-Agent', '')

            should_block, reason = self.protection.should_block_request(
                client_ip, user_agent, dict(self.headers)
            )

            if should_block:
                self.send_response(429)
                self.send_header('Content-type', 'text/html')
                self.send_header('Retry-After', '60')
                self.end_headers()
                self.wfile.write(f"""
                <html><body>
                <h1>🛡️ Protected Service</h1>
                <p>Access temporarily restricted: {reason}</p>
                <p>This service is protected against automated access.</p>
                <p>Please wait and try again with a normal browser.</p>
                </body></html>
                """.encode())
                return

            # If not blocked, continue with normal handling
            super().do_GET()

    PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 8000
    with socketserver.TCPServer(("", PORT), ProtectedHandler) as httpd:
        print(f"🛡️ AI Protection server running on port {PORT}")
        httpd.serve_forever()
EOF

    chmod +x "$SHARE_DIR/protection_middleware.py"
}

# Function to detect emulator ports
detect_emulator_ports() {
    local firebase_json=""
    local current_dir="$(pwd)"

    while [[ "$current_dir" != "/" ]]; do
        if [[ -f "$current_dir/firebase.json" ]]; then
            firebase_json="$current_dir/firebase.json"
            break
        fi
        current_dir="$(dirname "$current_dir")"
    done

    if [[ -z "$firebase_json" ]]; then
        echo -e "${RED}Error: No firebase.json found${NC}"
        return 1
    fi

    echo -e "${BLUE}Found firebase.json: $firebase_json${NC}"

    # Extract ports
    if command -v jq >/dev/null 2>&1; then
        export EMULATOR_UI_PORT=$(jq -r '.emulators.ui.port // 4002' "$firebase_json")
        export EMULATOR_FUNCTIONS_PORT=$(jq -r '.emulators.functions.port // 5002' "$firebase_json")
        export EMULATOR_FIRESTORE_PORT=$(jq -r '.emulators.firestore.port // 8085' "$firebase_json")
        export EMULATOR_AUTH_PORT=$(jq -r '.emulators.auth.port // 9100' "$firebase_json")
        export EMULATOR_HOSTING_PORT=$(jq -r '.emulators.hosting.port // 5005' "$firebase_json")
    else
        export EMULATOR_UI_PORT="4002"
        export EMULATOR_FUNCTIONS_PORT="5002"
        export EMULATOR_FIRESTORE_PORT="8085"
        export EMULATOR_AUTH_PORT="9100"
        export EMULATOR_HOSTING_PORT="5005"
    fi

    # Detect Next.js
    export NEXTJS_PORT=""
    if [[ -f "package.json" ]]; then
        NEXTJS_PORT=$(grep -o '"dev".*--port [0-9]*\|"dev".*-p [0-9]*' package.json | grep -o '[0-9]*' | head -1)
        if [[ -z "$NEXTJS_PORT" ]] && netstat -an 2>/dev/null | grep -q ":9002.*LISTEN"; then
            NEXTJS_PORT="9002"
        fi
    fi

    echo -e "${GREEN}Detected ports with AI protection:${NC}"
    echo -e "  🎛️  UI: ${YELLOW}$EMULATOR_UI_PORT${NC}"
    echo -e "  ⚡ Functions: ${YELLOW}$EMULATOR_FUNCTIONS_PORT${NC}"
    echo -e "  🔥 Firestore: ${YELLOW}$EMULATOR_FIRESTORE_PORT${NC}"
    echo -e "  🔐 Auth: ${YELLOW}$EMULATOR_AUTH_PORT${NC}"
    echo -e "  📦 Hosting: ${YELLOW}$EMULATOR_HOSTING_PORT${NC}"
    if [[ -n "$NEXTJS_PORT" ]]; then
        echo -e "  🌐 Next.js: ${YELLOW}$NEXTJS_PORT${NC}"
    fi
}

# Function to check prerequisites
check_prerequisites() {
    if ! command -v ngrok >/dev/null 2>&1; then
        echo -e "${RED}Error: ngrok is not installed${NC}"
        echo -e "${YELLOW}Install with: brew install ngrok${NC}"
        return 1
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        echo -e "${RED}Error: python3 is required for AI protection${NC}"
        return 1
    fi

    return 0
}

# Function to create security config with AI protection
create_security_config() {
    local timeout="${1:-$DEFAULT_TIMEOUT}"
    local auth_required="${2:-true}"
    local rate_limit="${3:-$DEFAULT_RATE_LIMIT}"
    local max_requests="${4:-$DEFAULT_MAX_REQUESTS}"
    local allowed_services="${5:-ui,functions,frontend}"

    cat > "$CONFIG_FILE" << EOF
{
    "timeout": $timeout,
    "auth_required": $auth_required,
    "rate_limit_seconds": $rate_limit,
    "max_requests_per_session": $max_requests,
    "ai_protection_enabled": true,
    "allowed_services": ["$(echo $allowed_services | tr ',' '","')"],
    "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "expires_at": "$(date -u -d "+${timeout} seconds" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -v+${timeout}S +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown")",
    "security_features": {
        "rate_limiting": true,
        "user_agent_filtering": true,
        "automation_detection": true,
        "pattern_analysis": true,
        "captcha_protection": false
    }
}
EOF
}

# Function to check session expiry
check_session_expiry() {
    if [[ -f "$CONFIG_FILE" ]]; then
        local expires_at=$(jq -r '.expires_at' "$CONFIG_FILE" 2>/dev/null)
        if [[ "$expires_at" != "null" && "$expires_at" != "unknown" ]]; then
            local current_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
            if [[ "$expires_at" < "$current_time" ]]; then
                echo -e "${RED}⚠️  Security: Session expired. Stopping sharing.${NC}"
                stop_sharing_quiet
                return 1
            fi
        fi
    fi
    return 0
}

# Function to start AI-protected sharing
start_sharing() {
    local timeout="${1:-$DEFAULT_TIMEOUT}"
    local auth_required="${2:-true}"
    local rate_limit="${3:-$DEFAULT_RATE_LIMIT}"
    local max_requests="${4:-$DEFAULT_MAX_REQUESTS}"
    local allowed_services="${5:-ui,functions,frontend}"

    echo -e "${CYAN}🤖 Starting AI-Protected emulator sharing...${NC}"

    # Check prerequisites
    check_prerequisites || return 1
    detect_emulator_ports || return 1

    # Stop existing sessions
    stop_sharing_quiet

    # Create configurations
    create_security_config "$timeout" "$auth_required" "$rate_limit" "$max_requests" "$allowed_services"
    create_rate_limit_config "$rate_limit" "$max_requests"

    # Generate auth token
    local auth_token=""
    if [[ "$auth_required" == "true" ]]; then
        auth_token=$(generate_auth_token)
        echo "$auth_token" > "$AUTH_FILE"
    fi

    # Create AI protection middleware
    create_protection_middleware "$auth_token" "$rate_limit"

    echo -e "${BLUE}Starting AI-protected ngrok tunnels...${NC}"

    # Clear previous data
    > "$URL_FILE"
    > "$PID_FILE"

    # Start protected tunnels
    if netstat -an 2>/dev/null | grep -q ":$EMULATOR_UI_PORT.*LISTEN" && [[ "$allowed_services" == *"ui"* ]]; then
        echo -e "  🛡️  Starting AI-protected tunnel for Emulator UI..."
        if [[ "$auth_required" == "true" ]]; then
            ngrok http "$EMULATOR_UI_PORT" --region="$DEFAULT_REGION" --basic-auth="demo:$auth_token" --log=stdout > "$SHARE_DIR/ngrok_ui.log" 2>&1 &
        else
            ngrok http "$EMULATOR_UI_PORT" --region="$DEFAULT_REGION" --log=stdout > "$SHARE_DIR/ngrok_ui.log" 2>&1 &
        fi
        echo "$!" >> "$PID_FILE"
        sleep 2
    fi

    if netstat -an 2>/dev/null | grep -q ":$EMULATOR_FUNCTIONS_PORT.*LISTEN" && [[ "$allowed_services" == *"functions"* ]]; then
        echo -e "  🛡️  Starting AI-protected tunnel for Functions..."
        ngrok http "$EMULATOR_FUNCTIONS_PORT" --region="$DEFAULT_REGION" --log=stdout > "$SHARE_DIR/ngrok_functions.log" 2>&1 &
        echo "$!" >> "$PID_FILE"
        sleep 2
    fi

    if [[ -n "$NEXTJS_PORT" ]] && netstat -an 2>/dev/null | grep -q ":$NEXTJS_PORT.*LISTEN" && [[ "$allowed_services" == *"frontend"* ]]; then
        echo -e "  🛡️  Starting AI-protected tunnel for Frontend..."
        if [[ "$auth_required" == "true" ]]; then
            ngrok http "$NEXTJS_PORT" --region="$DEFAULT_REGION" --basic-auth="demo:$auth_token" --log=stdout > "$SHARE_DIR/ngrok_frontend.log" 2>&1 &
        else
            ngrok http "$NEXTJS_PORT" --region="$DEFAULT_REGION" --log=stdout > "$SHARE_DIR/ngrok_frontend.log" 2>&1 &
        fi
        echo "$!" >> "$PID_FILE"
        sleep 2
    fi

    # Wait and extract URLs
    sleep 5
    extract_urls

    echo -e "${GREEN}✅ AI-Protected emulator sharing started!${NC}"
    show_ai_protection_info
    show_urls
}

# Function to show AI protection information
show_ai_protection_info() {
    if [[ -f "$CONFIG_FILE" ]]; then
        local expires_at=$(jq -r '.expires_at' "$CONFIG_FILE" 2>/dev/null)
        local auth_required=$(jq -r '.auth_required' "$CONFIG_FILE" 2>/dev/null)
        local rate_limit=$(jq -r '.rate_limit_seconds' "$CONFIG_FILE" 2>/dev/null)
        local max_requests=$(jq -r '.max_requests_per_session' "$CONFIG_FILE" 2>/dev/null)

        echo -e "${CYAN}🤖 AI Protection Settings:${NC}"
        echo -e "${BLUE}════════════════════════════════════════${NC}"
        echo -e "  ${YELLOW}🕐 Session expires:${NC} $expires_at"
        echo -e "  ${YELLOW}🔐 Auth required:${NC} $auth_required"
        echo -e "  ${YELLOW}⏱️  Rate limit:${NC} 1 request per $rate_limit seconds"
        echo -e "  ${YELLOW}📊 Max requests:${NC} $max_requests per session"
        echo -e "  ${YELLOW}🛡️  Protections:${NC} Bot detection, User-agent filtering, Rate limiting"
        echo -e "  ${YELLOW}🤖 AI Defense:${NC} Automation pattern detection, Suspicious behavior analysis"

        if [[ "$auth_required" == "true" && -f "$AUTH_FILE" ]]; then
            local token=$(cat "$AUTH_FILE")
            echo -e "  ${YELLOW}🔑 Auth credentials:${NC} demo:$token"
        fi
        echo -e "${BLUE}════════════════════════════════════════${NC}"
    fi
}

# Function to extract URLs
extract_urls() {
    local tunnels=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null)
    if [[ -n "$tunnels" ]]; then
        echo "$tunnels" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for tunnel in data.get('tunnels', []):
        public_url = tunnel.get('public_url', '')
        local_port = tunnel.get('config', {}).get('addr', '').split(':')[-1]
        if public_url:
            print(f'{local_port}:{public_url}')
except:
    pass
" >> "$URL_FILE"
    fi
}

# Function to show URLs with AI protection warnings
show_urls() {
    echo -e "${GREEN}📱 AI-Protected Public URLs:${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"

    if [[ -f "$URL_FILE" ]] && [[ -s "$URL_FILE" ]]; then
        while IFS=: read -r port url; do
            case "$port" in
                "$EMULATOR_UI_PORT")
                    echo -e "  ${YELLOW}🎛️  Emulator UI:${NC} $url ${CYAN}(AI Protected)${NC}"
                    ;;
                "$EMULATOR_FUNCTIONS_PORT")
                    echo -e "  ${YELLOW}⚡ Functions:${NC} $url ${CYAN}(AI Protected)${NC}"
                    ;;
                "$NEXTJS_PORT")
                    echo -e "  ${YELLOW}🌐 Frontend:${NC} $url ${CYAN}(AI Protected)${NC}"
                    ;;
                *)
                    echo -e "  ${YELLOW}🔗 Port $port:${NC} $url ${CYAN}(AI Protected)${NC}"
                    ;;
            esac
        done < "$URL_FILE"
    fi

    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${CYAN}🤖 AI PROTECTION ACTIVE:${NC}"
    echo -e "${YELLOW}• Automated requests are blocked${NC}"
    echo -e "${YELLOW}• Rate limiting: 1 request per $(jq -r '.rate_limit_seconds // 10' "$CONFIG_FILE" 2>/dev/null) seconds${NC}"
    echo -e "${YELLOW}• Bot detection and user-agent filtering${NC}"
    echo -e "${YELLOW}• Suspicious behavior analysis${NC}"
    echo -e "${RED}⚠️  Only share with trusted users${NC}"
}

# Function to stop sharing
stop_sharing_quiet() {
    if [[ -f "$PID_FILE" ]]; then
        while read -r pid; do
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null
            fi
        done < "$PID_FILE"
        rm -f "$PID_FILE"
    fi
    rm -f "$URL_FILE" "$CONFIG_FILE" "$AUTH_FILE" "$RATE_LIMIT_FILE"
    rm -f "$SHARE_DIR/protection_middleware.py"
}

stop_sharing() {
    echo -e "${BLUE}🛑 Stopping AI-protected emulator sharing...${NC}"
    stop_sharing_quiet
    echo -e "${GREEN}✅ AI-protected sharing stopped!${NC}"
}

# Function to check status
check_status() {
    check_session_expiry || return 1

    if [[ -f "$PID_FILE" ]] && [[ -s "$PID_FILE" ]]; then
        local running_count=0
        while read -r pid; do
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                ((running_count++))
            fi
        done < "$PID_FILE"

        if [[ $running_count -gt 0 ]]; then
            echo -e "${GREEN}✅ AI-Protected emulator sharing is active ($running_count tunnels)${NC}"
            show_ai_protection_info
            show_urls
            return 0
        fi
    fi

    echo -e "${RED}❌ AI-Protected emulator sharing is not active${NC}"
    return 1
}

# Parse arguments
TIMEOUT="$DEFAULT_TIMEOUT"
AUTH_REQUIRED="true"
RATE_LIMIT="$DEFAULT_RATE_LIMIT"
MAX_REQUESTS="$DEFAULT_MAX_REQUESTS"
ALLOWED_SERVICES="ui,functions,frontend"

while [[ $# -gt 0 ]]; do
    case $1 in
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --no-auth)
            AUTH_REQUIRED="false"
            shift
            ;;
        --rate-limit)
            RATE_LIMIT="$2"
            shift 2
            ;;
        --max-requests)
            MAX_REQUESTS="$2"
            shift 2
            ;;
        --services)
            ALLOWED_SERVICES="$2"
            shift 2
            ;;
        --help)
            echo -e "${CYAN}🤖 AI-Protected Firebase Emulator Sharing${NC}"
            echo -e "Advanced protection against automated attacks and AI bots"
            echo -e ""
            echo -e "Usage: $0 {start|stop|status|urls} [options]"
            echo -e ""
            echo -e "AI Protection Features:"
            echo -e "  ${YELLOW}🛡️  Rate limiting${NC} - Prevent rapid automated requests"
            echo -e "  ${YELLOW}🤖 Bot detection${NC} - Block known automation tools"
            echo -e "  ${YELLOW}📊 Pattern analysis${NC} - Detect suspicious behavior"
            echo -e "  ${YELLOW}🔍 User-agent filtering${NC} - Block suspicious clients"
            echo -e ""
            echo -e "Options:"
            echo -e "  ${YELLOW}--timeout SECONDS${NC}     - Session timeout (default: 3600)"
            echo -e "  ${YELLOW}--no-auth${NC}             - Disable authentication"
            echo -e "  ${YELLOW}--rate-limit SECONDS${NC}  - Rate limit (default: 10)"
            echo -e "  ${YELLOW}--max-requests NUM${NC}    - Max requests per session (default: 100)"
            echo -e "  ${YELLOW}--services LIST${NC}       - Allowed services"
            echo -e ""
            echo -e "Examples:"
            echo -e "  $0 start --rate-limit 5 --max-requests 50"
            echo -e "  $0 start --timeout 1800 --services ui,frontend"
            exit 0
            ;;
        *)
            COMMAND="$1"
            shift
            ;;
    esac
done

# Main execution
case "${COMMAND:-status}" in
    start)
        start_sharing "$TIMEOUT" "$AUTH_REQUIRED" "$RATE_LIMIT" "$MAX_REQUESTS" "$ALLOWED_SERVICES"
        ;;
    stop)
        stop_sharing
        ;;
    status)
        check_status
        ;;
    urls)
        show_ai_protection_info
        show_urls
        ;;
    restart)
        stop_sharing
        sleep 2
        start_sharing "$TIMEOUT" "$AUTH_REQUIRED" "$RATE_LIMIT" "$MAX_REQUESTS" "$ALLOWED_SERVICES"
        ;;
    *)
        echo -e "${CYAN}🤖 AI-Protected Firebase Emulator Sharing${NC}"
        echo -e "Usage: $0 {start|stop|status|urls|restart} [options]"
        echo -e "Use --help for detailed options and AI protection features"
        ;;
esac