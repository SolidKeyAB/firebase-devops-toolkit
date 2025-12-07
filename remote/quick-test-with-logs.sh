#!/bin/bash

# 🚀 QUICK TEST WITH REAL-TIME LOGS
# This script provides instructions for watching logs during pipeline execution

echo "🚀 Quick Test with Real-Time Logs"
echo "================================"
echo ""

echo "📋 Instructions for watching logs during execution:"
echo ""
echo "1. 🎯 Open a new terminal window and run:"
echo "   firebase functions:log --project \"${PROJECT_ID:-your-firebase-project-id}\" --lines 20"
echo "   (This will show recent logs - run it repeatedly to see new logs)"
echo ""
echo "2. 🧪 In this terminal, run the test:"
echo "   node test-complete-pipeline.js"
echo ""
echo "3. 📊 Or watch specific function logs:"
echo "   firebase functions:log --project \"${PROJECT_ID:-your-firebase-project-id}\" --only triggerOrchestratorOnBrandUpdate --lines 10"
echo "   firebase functions:log --project \"${PROJECT_ID:-your-firebase-project-id}\" --only orchestratorService --lines 10"
echo "   firebase functions:log --project \"${PROJECT_ID:-your-firebase-project-id}\" --only categoryExtraction --lines 10"
echo ""
echo "4. 🎮 Or use the interactive watcher (polling every 5 seconds):"
echo "   ./watch-logs.sh"
echo ""
echo "5. 🔄 Or manually poll for new logs:"
echo "   while true; do firebase functions:log --project \"${PROJECT_ID:-your-firebase-project-id}\" --lines 5; sleep 3; clear; done"
echo ""

read -p "Press Enter to run a test now and see logs in action..."

echo ""
echo "🧪 Running test now..."
node test-complete-pipeline.js

echo ""
echo "📊 Test completed! Check the logs by running:"
echo "   firebase functions:log --project \"${PROJECT_ID:-your-firebase-project-id}\" --lines 20"
echo ""
echo "You should see:"
echo "  🎯 Brand document created, triggering orchestrator..."
echo "  🎯 Control document created, triggering orchestrator..."
echo "  🎯 Category extraction request created, triggering service..."
echo "  🎯 Product extraction request created, triggering service..."
echo ""
echo "💡 Tip: Run the log command multiple times to see new logs as they appear" 