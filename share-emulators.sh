#!/bin/bash

# Firebase Emulator Sharing Script
# Usage: ./share-emulators.sh [start|stop|status|urls]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARE_DIR="$SCRIPT_DIR/.emulator-sharing"
PID_FILE="$SHARE_DIR/ngrok_pids.txt"
URL_FILE="$SHARE_DIR/ngrok_urls.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create sharing directory
mkdir -p "$SHARE_DIR"

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
        # Use jq for better JSON parsing
        local ui_port=$(jq -r '.emulators.ui.port // 4002' "$firebase_json")
        local functions_port=$(jq -r '.emulators.functions.port // 5002' "$firebase_json")
        local firestore_port=$(jq -r '.emulators.firestore.port // 8085' "$firebase_json")
        local auth_port=$(jq -r '.emulators.auth.port // 9100' "$firebase_json")
        local hosting_port=$(jq -r '.emulators.hosting.port // 5005' "$firebase_json")
    else
        # Fallback to grep/sed
        local ui_port=$(grep -A 20 '"emulators"' "$firebase_json" | grep -A 5 '"ui"' | grep '"port"' | sed 's/.*: *\([0-9]*\).*/\1/' || echo "4002")
        local functions_port=$(grep -A 20 '"emulators"' "$firebase_json" | grep -A 5 '"functions"' | grep '"port"' | sed 's/.*: *\([0-9]*\).*/\1/' || echo "5002")
        local firestore_port=$(grep -A 20 '"emulators"' "$firebase_json" | grep -A 5 '"firestore"' | grep '"port"' | sed 's/.*: *\([0-9]*\).*/\1/' || echo "8085")
        local auth_port=$(grep -A 20 '"emulators"' "$firebase_json" | grep -A 5 '"auth"' | grep '"port"' | sed 's/.*: *\([0-9]*\).*/\1/' || echo "9100")
        local hosting_port=$(grep -A 20 '"emulators"' "$firebase_json" | grep -A 5 '"hosting"' | grep '"port"' | sed 's/.*: *\([0-9]*\).*/\1/' || echo "5005")
    fi

    # Also detect Next.js dev server (common patterns)
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

# Function to start sharing
start_sharing() {
    echo -e "${BLUE}🚀 Starting emulator sharing...${NC}"

    # Check prerequisites
    check_ngrok || return 1
    detect_emulator_ports || return 1

    # Stop existing sessions
    stop_sharing_quiet

    # Start ngrok tunnels
    echo -e "${BLUE}Starting ngrok tunnels...${NC}"

    # Clear previous URLs
    > "$URL_FILE"
    > "$PID_FILE"

    # Start tunnels for detected services
    if netstat -an 2>/dev/null | grep -q ":$EMULATOR_UI_PORT.*LISTEN"; then
        echo -e "  Starting tunnel for Emulator UI (port $EMULATOR_UI_PORT)..."
        ngrok http "$EMULATOR_UI_PORT" --log=stdout > "$SHARE_DIR/ngrok_ui.log" 2>&1 &
        echo "$!" >> "$PID_FILE"
        sleep 2
    fi

    if netstat -an 2>/dev/null | grep -q ":$EMULATOR_FUNCTIONS_PORT.*LISTEN"; then
        echo -e "  Starting tunnel for Functions (port $EMULATOR_FUNCTIONS_PORT)..."
        ngrok http "$EMULATOR_FUNCTIONS_PORT" --log=stdout > "$SHARE_DIR/ngrok_functions.log" 2>&1 &
        echo "$!" >> "$PID_FILE"
        sleep 2
    fi

    if [[ -n "$NEXTJS_PORT" ]] && netstat -an 2>/dev/null | grep -q ":$NEXTJS_PORT.*LISTEN"; then
        echo -e "  Starting tunnel for Frontend (port $NEXTJS_PORT)..."
        ngrok http "$NEXTJS_PORT" --log=stdout > "$SHARE_DIR/ngrok_frontend.log" 2>&1 &
        echo "$!" >> "$PID_FILE"
        sleep 2
    fi

    # Wait a moment for ngrok to establish connections
    sleep 5

    # Extract URLs from ngrok API
    extract_urls

    echo -e "${GREEN}✅ Emulator sharing started!${NC}"
    show_urls
}

# Function to extract URLs from ngrok API
extract_urls() {
    echo -e "${BLUE}Extracting public URLs...${NC}"

    # Get tunnels from ngrok API
    local tunnels=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null)

    if [[ -n "$tunnels" ]]; then
        # Parse tunnels and save URLs
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

# Function to show URLs
show_urls() {
    echo -e "${GREEN}📱 Public URLs:${NC}"
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
    echo -e "${YELLOW}💡 Share these URLs with other developers!${NC}"
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
    rm -f "$URL_FILE"
}

# Function to stop sharing
stop_sharing() {
    echo -e "${BLUE}🛑 Stopping emulator sharing...${NC}"
    stop_sharing_quiet
    echo -e "${GREEN}✅ Emulator sharing stopped!${NC}"
}

# Function to check status
check_status() {
    if [[ -f "$PID_FILE" ]] && [[ -s "$PID_FILE" ]]; then
        local running_count=0
        while read -r pid; do
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                ((running_count++))
            fi
        done < "$PID_FILE"

        if [[ $running_count -gt 0 ]]; then
            echo -e "${GREEN}✅ Emulator sharing is active ($running_count tunnels)${NC}"
            show_urls
            return 0
        else
            echo -e "${RED}❌ Emulator sharing is not active${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Emulator sharing is not active${NC}"
        return 1
    fi
}

# Main script logic
case "${1:-status}" in
    start)
        start_sharing
        ;;
    stop)
        stop_sharing
        ;;
    status)
        check_status
        ;;
    urls)
        show_urls
        ;;
    restart)
        stop_sharing
        sleep 2
        start_sharing
        ;;
    *)
        echo -e "${BLUE}Firebase Emulator Sharing${NC}"
        echo -e "Usage: $0 {start|stop|status|urls|restart}"
        echo -e ""
        echo -e "Commands:"
        echo -e "  ${YELLOW}start${NC}   - Start sharing emulators via ngrok"
        echo -e "  ${YELLOW}stop${NC}    - Stop sharing"
        echo -e "  ${YELLOW}status${NC}  - Check if sharing is active"
        echo -e "  ${YELLOW}urls${NC}    - Show current public URLs"
        echo -e "  ${YELLOW}restart${NC} - Restart sharing"
        echo -e ""
        echo -e "This script auto-detects emulator ports from firebase.json"
        echo -e "Run from any Firebase project directory."
        ;;
esac