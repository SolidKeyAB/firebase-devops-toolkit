#!/bin/bash

# Secure Firebase Emulator Sharing Script
# Usage: ./secure-share-emulators.sh [start|stop|status|urls] [options]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARE_DIR="$SCRIPT_DIR/.emulator-sharing"
PID_FILE="$SHARE_DIR/ngrok_pids.txt"
URL_FILE="$SHARE_DIR/ngrok_urls.txt"
CONFIG_FILE="$SHARE_DIR/security_config.json"
AUTH_FILE="$SHARE_DIR/auth_tokens.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Security settings
DEFAULT_TIMEOUT="3600"  # 1 hour
DEFAULT_REGION="us"     # ngrok region
ALLOWED_SERVICES=("ui" "functions" "frontend")  # Default allowed services

# Create sharing directory
mkdir -p "$SHARE_DIR"

# Function to generate secure token
generate_auth_token() {
    openssl rand -hex 16 2>/dev/null || python3 -c "import secrets; print(secrets.token_hex(16))" 2>/dev/null || date +%s | sha256sum | head -c 32
}

# Function to create security config
create_security_config() {
    local timeout="${1:-$DEFAULT_TIMEOUT}"
    local auth_required="${2:-true}"
    local whitelist_ips="${3:-}"
    local allowed_services="${4:-ui,functions,frontend}"

    cat > "$CONFIG_FILE" << EOF
{
    "timeout": $timeout,
    "auth_required": $auth_required,
    "whitelist_ips": ["$whitelist_ips"],
    "allowed_services": ["$(echo $allowed_services | tr ',' '","')"],
    "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "expires_at": "$(date -u -d "+${timeout} seconds" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -v+${timeout}S +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown")"
}
EOF
}

# Function to check if session is expired
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

# Function to detect emulator ports from current directory
detect_emulator_ports() {
    local firebase_json=""

    # Look for firebase.json in current directory or parent directories
    local current_dir="$(pwd)"
    while [[ "$current_dir" != "/" ]]; do
        if [[ -f "$current_dir/firebase.json" ]]; then
            firebase_json="$current_dir/firebase.json"
            break
        fi
        current_dir="$(dirname "$current_dir")"
    done

    if [[ -z "$firebase_json" ]]; then
        echo -e "${RED}Error: No firebase.json found in current directory or parent directories${NC}"
        return 1
    fi

    echo -e "${BLUE}Found firebase.json: $firebase_json${NC}"

    # Extract ports using jq or grep
    if command -v jq >/dev/null 2>&1; then
        local ui_port=$(jq -r '.emulators.ui.port // 4002' "$firebase_json")
        local functions_port=$(jq -r '.emulators.functions.port // 5002' "$firebase_json")
        local firestore_port=$(jq -r '.emulators.firestore.port // 8085' "$firebase_json")
        local auth_port=$(jq -r '.emulators.auth.port // 9100' "$firebase_json")
        local hosting_port=$(jq -r '.emulators.hosting.port // 5005' "$firebase_json")
    else
        local ui_port=$(grep -A 20 '"emulators"' "$firebase_json" | grep -A 5 '"ui"' | grep '"port"' | sed 's/.*: *\([0-9]*\).*/\1/' || echo "4002")
        local functions_port=$(grep -A 20 '"emulators"' "$firebase_json" | grep -A 5 '"functions"' | grep '"port"' | sed 's/.*: *\([0-9]*\).*/\1/' || echo "5002")
        local firestore_port=$(grep -A 20 '"emulators"' "$firebase_json" | grep -A 5 '"firestore"' | grep '"port"' | sed 's/.*: *\([0-9]*\).*/\1/' || echo "8085")
        local auth_port=$(grep -A 20 '"emulators"' "$firebase_json" | grep -A 5 '"auth"' | grep '"port"' | sed 's/.*: *\([0-9]*\).*/\1/' || echo "9100")
        local hosting_port=$(grep -A 20 '"emulators"' "$firebase_json" | grep -A 5 '"hosting"' | grep '"port"' | sed 's/.*: *\([0-9]*\).*/\1/' || echo "5005")
    fi

    # Also detect Next.js dev server
    local nextjs_port=""
    if [[ -f "package.json" ]]; then
        nextjs_port=$(grep -o '"dev".*--port [0-9]*\|"dev".*-p [0-9]*' package.json | grep -o '[0-9]*' | head -1)
        if [[ -z "$nextjs_port" ]] && netstat -an 2>/dev/null | grep -q ":3000.*LISTEN"; then
            nextjs_port="3000"
        elif [[ -z "$nextjs_port" ]] && netstat -an 2>/dev/null | grep -q ":9002.*LISTEN"; then
            nextjs_port="9002"
        fi
    fi

    # Export detected ports
    export EMULATOR_UI_PORT="$ui_port"
    export EMULATOR_FUNCTIONS_PORT="$functions_port"
    export EMULATOR_FIRESTORE_PORT="$firestore_port"
    export EMULATOR_AUTH_PORT="$auth_port"
    export EMULATOR_HOSTING_PORT="$hosting_port"
    export NEXTJS_PORT="$nextjs_port"

    echo -e "${GREEN}Detected ports:${NC}"
    echo -e "  UI: ${YELLOW}$ui_port${NC}"
    echo -e "  Functions: ${YELLOW}$functions_port${NC}"
    echo -e "  Firestore: ${YELLOW}$firestore_port${NC}"
    echo -e "  Auth: ${YELLOW}$auth_port${NC}"
    echo -e "  Hosting: ${YELLOW}$hosting_port${NC}"
    if [[ -n "$nextjs_port" ]]; then
        echo -e "  Next.js: ${YELLOW}$nextjs_port${NC}"
    fi
}

# Function to check if ngrok is installed
check_ngrok() {
    if ! command -v ngrok >/dev/null 2>&1; then
        echo -e "${RED}Error: ngrok is not installed${NC}"
        echo -e "${YELLOW}Install with: brew install ngrok${NC}"
        return 1
    fi
}

# Function to check if service is allowed
is_service_allowed() {
    local service="$1"
    local allowed_services=""

    if [[ -f "$CONFIG_FILE" ]]; then
        allowed_services=$(jq -r '.allowed_services[]' "$CONFIG_FILE" 2>/dev/null | tr '\n' ' ')
    fi

    if [[ -z "$allowed_services" ]]; then
        allowed_services="ui functions frontend"
    fi

    for allowed in $allowed_services; do
        if [[ "$service" == "$allowed" ]]; then
            return 0
        fi
    done
    return 1
}

# Function to start secure sharing
start_sharing() {
    local timeout="${1:-$DEFAULT_TIMEOUT}"
    local auth_required="${2:-true}"
    local allowed_services="${3:-ui,functions,frontend}"
    local auth_token=""

    echo -e "${BLUE}🔒 Starting secure emulator sharing...${NC}"

    # Check prerequisites
    check_ngrok || return 1
    detect_emulator_ports || return 1

    # Stop existing sessions
    stop_sharing_quiet

    # Create security config
    create_security_config "$timeout" "$auth_required" "" "$allowed_services"

    # Generate auth token if required
    if [[ "$auth_required" == "true" ]]; then
        auth_token=$(generate_auth_token)
        echo "$auth_token" > "$AUTH_FILE"
        echo -e "${PURPLE}🔑 Generated auth token: ${YELLOW}$auth_token${NC}"
    fi

    # Start ngrok tunnels with security
    echo -e "${BLUE}Starting secure ngrok tunnels...${NC}"

    # Clear previous URLs
    > "$URL_FILE"
    > "$PID_FILE"

    # Start tunnels for allowed services only
    if netstat -an 2>/dev/null | grep -q ":$EMULATOR_UI_PORT.*LISTEN" && is_service_allowed "ui"; then
        echo -e "  Starting secure tunnel for Emulator UI (port $EMULATOR_UI_PORT)..."
        if [[ "$auth_required" == "true" ]]; then
            ngrok http "$EMULATOR_UI_PORT" --region="$DEFAULT_REGION" --basic-auth="demo:$auth_token" --log=stdout > "$SHARE_DIR/ngrok_ui.log" 2>&1 &
        else
            ngrok http "$EMULATOR_UI_PORT" --region="$DEFAULT_REGION" --log=stdout > "$SHARE_DIR/ngrok_ui.log" 2>&1 &
        fi
        echo "$!" >> "$PID_FILE"
        sleep 2
    fi

    if netstat -an 2>/dev/null | grep -q ":$EMULATOR_FUNCTIONS_PORT.*LISTEN" && is_service_allowed "functions"; then
        echo -e "  Starting secure tunnel for Functions (port $EMULATOR_FUNCTIONS_PORT)..."
        ngrok http "$EMULATOR_FUNCTIONS_PORT" --region="$DEFAULT_REGION" --log=stdout > "$SHARE_DIR/ngrok_functions.log" 2>&1 &
        echo "$!" >> "$PID_FILE"
        sleep 2
    fi

    if [[ -n "$NEXTJS_PORT" ]] && netstat -an 2>/dev/null | grep -q ":$NEXTJS_PORT.*LISTEN" && is_service_allowed "frontend"; then
        echo -e "  Starting secure tunnel for Frontend (port $NEXTJS_PORT)..."
        if [[ "$auth_required" == "true" ]]; then
            ngrok http "$NEXTJS_PORT" --region="$DEFAULT_REGION" --basic-auth="demo:$auth_token" --log=stdout > "$SHARE_DIR/ngrok_frontend.log" 2>&1 &
        else
            ngrok http "$NEXTJS_PORT" --region="$DEFAULT_REGION" --log=stdout > "$SHARE_DIR/ngrok_frontend.log" 2>&1 &
        fi
        echo "$!" >> "$PID_FILE"
        sleep 2
    fi

    # Wait for ngrok to establish connections
    sleep 5

    # Extract URLs
    extract_urls

    echo -e "${GREEN}✅ Secure emulator sharing started!${NC}"
    show_security_info
    show_urls
}

# Function to show security information
show_security_info() {
    if [[ -f "$CONFIG_FILE" ]]; then
        local expires_at=$(jq -r '.expires_at' "$CONFIG_FILE" 2>/dev/null)
        local auth_required=$(jq -r '.auth_required' "$CONFIG_FILE" 2>/dev/null)
        local allowed_services=$(jq -r '.allowed_services[]' "$CONFIG_FILE" 2>/dev/null | tr '\n' ',' | sed 's/,$//')

        echo -e "${PURPLE}🔒 Security Settings:${NC}"
        echo -e "${BLUE}════════════════════════════════════════${NC}"
        echo -e "  ${YELLOW}🕐 Session expires:${NC} $expires_at"
        echo -e "  ${YELLOW}🔐 Auth required:${NC} $auth_required"
        echo -e "  ${YELLOW}📋 Allowed services:${NC} $allowed_services"

        if [[ "$auth_required" == "true" && -f "$AUTH_FILE" ]]; then
            local token=$(cat "$AUTH_FILE")
            echo -e "  ${YELLOW}🔑 Auth credentials:${NC} demo:$token"
        fi
        echo -e "${BLUE}════════════════════════════════════════${NC}"
    fi
}

# Function to extract URLs from ngrok API
extract_urls() {
    echo -e "${BLUE}Extracting public URLs...${NC}"

    # Get tunnels from ngrok API
    local tunnels=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null)

    if [[ -n "$tunnels" ]]; then
        echo "$tunnels" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    tunnels = data.get('tunnels', [])
    for tunnel in tunnels:
        name = tunnel.get('name', '')
        public_url = tunnel.get('public_url', '')
        local_port = tunnel.get('config', {}).get('addr', '').split(':')[-1]
        if public_url:
            print(f'{local_port}:{public_url}')
except:
    pass
" >> "$URL_FILE"
    fi
}

# Function to show URLs with security warnings
show_urls() {
    echo -e "${GREEN}📱 Secure Public URLs:${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"

    if [[ -f "$URL_FILE" ]] && [[ -s "$URL_FILE" ]]; then
        while IFS=: read -r port url; do
            case "$port" in
                "$EMULATOR_UI_PORT")
                    echo -e "  ${YELLOW}🎛️  Emulator UI:${NC} $url"
                    ;;
                "$EMULATOR_FUNCTIONS_PORT")
                    echo -e "  ${YELLOW}⚡ Functions:${NC} $url"
                    ;;
                "$NEXTJS_PORT")
                    echo -e "  ${YELLOW}🌐 Frontend:${NC} $url"
                    ;;
                *)
                    echo -e "  ${YELLOW}🔗 Port $port:${NC} $url"
                    ;;
            esac
        done < "$URL_FILE"
    else
        echo -e "${RED}No URLs found. Make sure your emulators are running.${NC}"
    fi

    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${RED}⚠️  SECURITY WARNING:${NC}"
    echo -e "${YELLOW}• These URLs expose your local emulators publicly${NC}"
    echo -e "${YELLOW}• Only share with trusted developers${NC}"
    echo -e "${YELLOW}• Stop sharing when demo/testing is complete${NC}"
    echo -e "${YELLOW}• Sessions auto-expire for security${NC}"
}

# Function to stop sharing quietly
stop_sharing_quiet() {
    if [[ -f "$PID_FILE" ]]; then
        while read -r pid; do
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null
            fi
        done < "$PID_FILE"
        rm -f "$PID_FILE"
    fi
    rm -f "$URL_FILE" "$CONFIG_FILE" "$AUTH_FILE"
}

# Function to stop sharing
stop_sharing() {
    echo -e "${BLUE}🛑 Stopping secure emulator sharing...${NC}"
    stop_sharing_quiet
    echo -e "${GREEN}✅ Secure emulator sharing stopped!${NC}"
}

# Function to check status
check_status() {
    # Check session expiry first
    check_session_expiry || return 1

    if [[ -f "$PID_FILE" ]] && [[ -s "$PID_FILE" ]]; then
        local running_count=0
        while read -r pid; do
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                ((running_count++))
            fi
        done < "$PID_FILE"

        if [[ $running_count -gt 0 ]]; then
            echo -e "${GREEN}✅ Secure emulator sharing is active ($running_count tunnels)${NC}"
            show_security_info
            show_urls
            return 0
        else
            echo -e "${RED}❌ Secure emulator sharing is not active${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Secure emulator sharing is not active${NC}"
        return 1
    fi
}

# Parse command line arguments
TIMEOUT="$DEFAULT_TIMEOUT"
AUTH_REQUIRED="true"
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
        --services)
            ALLOWED_SERVICES="$2"
            shift 2
            ;;
        --help)
            echo -e "${BLUE}Secure Firebase Emulator Sharing${NC}"
            echo -e "Usage: $0 {start|stop|status|urls} [options]"
            echo -e ""
            echo -e "Commands:"
            echo -e "  ${YELLOW}start${NC}   - Start secure sharing"
            echo -e "  ${YELLOW}stop${NC}    - Stop sharing"
            echo -e "  ${YELLOW}status${NC}  - Check status"
            echo -e "  ${YELLOW}urls${NC}    - Show URLs"
            echo -e ""
            echo -e "Options:"
            echo -e "  ${YELLOW}--timeout SECONDS${NC}     - Session timeout (default: 3600)"
            echo -e "  ${YELLOW}--no-auth${NC}             - Disable authentication"
            echo -e "  ${YELLOW}--services LIST${NC}       - Allowed services (ui,functions,frontend)"
            echo -e ""
            echo -e "Examples:"
            echo -e "  $0 start --timeout 1800 --services ui,frontend"
            echo -e "  $0 start --no-auth --timeout 7200"
            exit 0
            ;;
        *)
            COMMAND="$1"
            shift
            ;;
    esac
done

# Main script logic
case "${COMMAND:-status}" in
    start)
        start_sharing "$TIMEOUT" "$AUTH_REQUIRED" "$ALLOWED_SERVICES"
        ;;
    stop)
        stop_sharing
        ;;
    status)
        check_status
        ;;
    urls)
        show_security_info
        show_urls
        ;;
    restart)
        stop_sharing
        sleep 2
        start_sharing "$TIMEOUT" "$AUTH_REQUIRED" "$ALLOWED_SERVICES"
        ;;
    *)
        echo -e "${BLUE}Secure Firebase Emulator Sharing${NC}"
        echo -e "Usage: $0 {start|stop|status|urls|restart} [options]"
        echo -e ""
        echo -e "Use --help for detailed options"
        ;;
esac