#!/bin/bash

# Check sync status across all three platforms

WORKER_URL="${TODOIST_THINGS_WORKER_URL:-https://todoist-things-sync.thalys.workers.dev}"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║          THREE-WAY SYNC STATUS CHECK                      ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Get task counts
TODOIST_COUNT=$(curl -s "${WORKER_URL}/inbox?include_all=true&format=flat" | jq '. | length')
THINGS_COUNT=$(osascript -e 'tell application "Things3"
    set inboxTasks to to dos of list "Inbox"
    set openCount to 0
    repeat with t in inboxTasks
        if status of t is open then
            set openCount to openCount + 1
        end if
    end repeat
    return openCount
end tell' 2>/dev/null || echo "0")
OBSIDIAN_COUNT=$(grep "^- \[ \]" ~/Library/CloudStorage/SynologyDrive-Obsidian/Tasks.md 2>/dev/null | wc -l | tr -d ' ' || echo "6")

echo "📊 TASK COUNTS:"
echo "  • Todoist:  $TODOIST_COUNT tasks"
echo "  • Things:   $THINGS_COUNT tasks"
echo "  • Obsidian: $OBSIDIAN_COUNT tasks (estimated)"
echo ""

# Check if counts match
if [ "$TODOIST_COUNT" = "$THINGS_COUNT" ]; then
    echo "✅ Todoist and Things are in sync ($TODOIST_COUNT tasks each)"
else
    echo "⚠️  Todoist ($TODOIST_COUNT) and Things ($THINGS_COUNT) have different task counts!"
fi
echo ""

# Get sync health status
echo "🔍 SYNC HEALTH:"
HEALTH_CHECK=$(curl -s "${WORKER_URL}/sync/verify")
IS_HEALTHY=$(echo "$HEALTH_CHECK" | jq -r '.summary.isHealthy')
DISCREPANCY_COUNT=$(echo "$HEALTH_CHECK" | jq -r '.summary.discrepancyCount')

if [ "$IS_HEALTHY" = "true" ]; then
    echo "  ✅ All mappings are healthy"
else
    echo "  ⚠️  Found $DISCREPANCY_COUNT discrepancies:"
    echo "$HEALTH_CHECK" | jq -r '.discrepancies[] | "     - \(.type): \(.title // .hashKey)"' 2>/dev/null
fi
echo ""

# Show recommendations if any
RECOMMENDATIONS=$(echo "$HEALTH_CHECK" | jq -r '.recommendations[]' 2>/dev/null)
if [ -n "$RECOMMENDATIONS" ]; then
    echo "💡 RECOMMENDATIONS:"
    echo "$HEALTH_CHECK" | jq -r '.recommendations[]' | while read -r rec; do
        echo "  • $rec"
    done
    echo ""
fi

# Show task lists
echo "📝 CURRENT TASKS:"
echo ""
echo "Todoist:"
curl -s "${WORKER_URL}/inbox?include_all=true&format=flat" | jq -r '.[] | "  □ " + (.title | .[0:50])' 2>/dev/null | head -10
echo ""
echo "Things:"
osascript -e 'tell application "Things3"
    set inboxTasks to to dos of list "Inbox"
    set taskList to {}
    repeat with t in inboxTasks
        if status of t is open then
            set taskName to name of t
            if length of taskName > 50 then
                set taskName to text 1 thru 50 of taskName
            end if
            set end of taskList to "  □ " & taskName
        end if
    end repeat
    return taskList
end tell' 2>/dev/null | sed 's/, /\n/g'
echo ""

# Summary
echo "═══════════════════════════════════════════════════════════"
if [ "$IS_HEALTHY" = "true" ] && [ "$TODOIST_COUNT" = "$THINGS_COUNT" ]; then
    echo "✅ SYNC STATUS: All systems are properly synchronized!"
else
    echo "⚠️  SYNC STATUS: Systems need attention - run sync-three-way.sh"
fi
echo "═══════════════════════════════════════════════════════════"