#!/bin/bash

# Install global alias for emulator sharing
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARE_SCRIPT="$SCRIPT_DIR/share-emulators.sh"

# Detect shell
if [[ -n "$ZSH_VERSION" ]]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [[ -n "$BASH_VERSION" ]]; then
    SHELL_CONFIG="$HOME/.bashrc"
else
    SHELL_CONFIG="$HOME/.profile"
fi

# Create aliases
SECURE_SCRIPT="$SCRIPT_DIR/secure-share-emulators.sh"
AI_PROTECTED_SCRIPT="$SCRIPT_DIR/ai-protected-share-emulators.sh"
ALIAS_LINE="alias share-emulators='$SHARE_SCRIPT'"
SECURE_ALIAS_LINE="alias secure-share-emulators='$SECURE_SCRIPT'"
AI_ALIAS_LINE="alias ai-share-emulators='$AI_PROTECTED_SCRIPT'"

# Check if aliases already exist
if grep -q "alias share-emulators" "$SHELL_CONFIG" 2>/dev/null; then
    echo "✅ Aliases already exist in $SHELL_CONFIG"
else
    echo "# Firebase Emulator Sharing" >> "$SHELL_CONFIG"
    echo "$ALIAS_LINE" >> "$SHELL_CONFIG"
    echo "$SECURE_ALIAS_LINE" >> "$SHELL_CONFIG"
    echo "$AI_ALIAS_LINE" >> "$SHELL_CONFIG"
    echo "✅ Added aliases to $SHELL_CONFIG"
fi

echo ""
echo "🎉 Installation complete!"
echo ""
echo "Usage (3 security levels):"
echo ""
echo "  🟢 Basic sharing:"
echo "    share-emulators start    # No protection"
echo ""
echo "  🟡 Secure sharing:"
echo "    secure-share-emulators start                    # Password + timeouts"
echo "    secure-share-emulators start --timeout 1800     # 30min timeout"
echo ""
echo "  🔴 AI-Protected sharing (recommended for production):"
echo "    ai-share-emulators start                        # Full AI protection"
echo "    ai-share-emulators start --rate-limit 5         # 1 request per 5 seconds"
echo "    ai-share-emulators start --max-requests 50      # Max 50 requests per session"
echo ""
echo "AI Protection features:"
echo "  🤖 Bot detection and blocking"
echo "  ⏱️  Rate limiting (1 action per 10 seconds)"
echo "  🛡️  User-agent filtering"
echo "  📊 Automation pattern detection"
echo "  🔍 Suspicious behavior analysis"
echo ""
echo "Restart your terminal or run: source $SHELL_CONFIG"