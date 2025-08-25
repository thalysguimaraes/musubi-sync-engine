#!/bin/bash

# Three-way sync between Todoist, Things, and Obsidian
# This script ensures all three platforms stay in sync

# Configuration
WORKER_URL="${TODOIST_THINGS_WORKER_URL:-https://todoist-things-sync.thalys.workers.dev}"
LOG_FILE="$HOME/Library/Logs/todoist-things-sync.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "$1"  # Also output to console
}

# Function to check if Things is running
check_things_running() {
    if ! osascript -e 'tell application "System Events" to (name of processes) contains "Things3"' 2>/dev/null | grep -q "true"; then
        log "ERROR: Things3 is not running. Please open Things3 and try again."
        exit 1
    fi
}

# Start three-way sync
log "=== Starting Three-Way Sync (Todoist ↔ Things ↔ Obsidian) ==="

# Check if Things is running
check_things_running

# STEP 1: Get current state from all platforms
log "Step 1: Analyzing current state..."

# Get Todoist tasks
todoist_count=$(curl -s "${WORKER_URL}/inbox?include_all=true&format=flat" | jq '. | length')
log "  Todoist: $todoist_count tasks"

# Get Things tasks
things_count=$(osascript -e 'tell application "Things3"
    set inboxTasks to to dos of list "Inbox"
    set openCount to 0
    repeat with t in inboxTasks
        if status of t is open then
            set openCount to openCount + 1
        end if
    end repeat
    return openCount
end tell')
log "  Things: $things_count tasks"

# Get Obsidian tasks (estimate)
log "  Obsidian: Tasks tracked in vault"

# STEP 2: Run the existing bidirectional sync (Todoist ↔ Things)
log ""
log "Step 2: Syncing Todoist ↔ Things..."
"${SCRIPT_DIR}/sync-bidirectional.sh" > /dev/null 2>&1

# STEP 3: Sync Todoist → Things (Import missing tasks)
log ""
log "Step 3: Ensuring all Todoist tasks are in Things..."

# Get all Todoist tasks and import any missing ones to Things
todoist_tasks=$(curl -s "${WORKER_URL}/inbox?format=flat&include_all=true")

# Filter out tasks that are already from Things (have synced-from-things label)
tasks_to_import=$(echo "$todoist_tasks" | jq '[.[] | select(.tags | contains(["synced-from-things"]) | not)]')
import_count=$(echo "$tasks_to_import" | jq '. | length')

if [ "$import_count" -gt 0 ]; then
    log "  Found $import_count Todoist tasks to import to Things"
    
    # Import using AppleScript
    import_result=$(osascript "${SCRIPT_DIR}/import-todoist-tasks.applescript" "$tasks_to_import" 2>&1)
    
    if [ $? -eq 0 ]; then
        log "  Import complete: $import_result"
    else
        log "  ERROR: Failed to import tasks to Things"
    fi
else
    log "  All Todoist tasks already in Things"
fi

# STEP 4: Sync Things → Todoist (Export missing tasks)
log ""
log "Step 4: Ensuring all Things tasks are in Todoist..."

# Read ALL tasks from Things (not just untagged)
all_things_tasks=$(osascript -e 'tell application "Things3"
    set inboxTasks to to dos of list "Inbox"
    set taskList to {}
    repeat with t in inboxTasks
        if status of t is open then
            set taskInfo to {id:id of t, title:name of t, notes:(notes of t as string), tags:(tag names of t)}
            set end of taskList to taskInfo
        end if
    end repeat
    return taskList
end tell' | perl -pe 's/\{/\{"/g; s/:/":"/g; s/, /", "/g; s/\}/"\}/g; s/""/"/g' | sed 's/^/[/; s/$/]/')

if [ -n "$all_things_tasks" ] && [ "$all_things_tasks" != "[]" ]; then
    # Send to worker to check and create missing tasks
    sync_response=$(curl -s -X POST "${WORKER_URL}/things/sync" \
        -H "Content-Type: application/json" \
        -d "$all_things_tasks")
    
    created=$(echo "$sync_response" | jq '.summary.created // 0')
    existing=$(echo "$sync_response" | jq '.summary.existing // 0')
    
    log "  Things → Todoist: $created created, $existing already existed"
fi

# STEP 5: Sync with Obsidian (if plugin is configured)
log ""
log "Step 5: Syncing with Obsidian..."

# Check if Obsidian sync is configured
obsidian_configured=$(curl -s "${WORKER_URL}/obsidian/status" 2>/dev/null | jq -r '.configured // false')

if [ "$obsidian_configured" = "true" ]; then
    # Sync Obsidian tasks to the system
    obsidian_sync_response=$(curl -s -X POST "${WORKER_URL}/obsidian/sync")
    obsidian_synced=$(echo "$obsidian_sync_response" | jq '.synced // 0')
    log "  Synced $obsidian_synced tasks from Obsidian"
    
    # Get tasks for Obsidian
    obsidian_tasks_response=$(curl -s "${WORKER_URL}/obsidian/tasks")
    obsidian_new=$(echo "$obsidian_tasks_response" | jq '.tasks | length // 0')
    
    if [ "$obsidian_new" -gt 0 ]; then
        log "  Found $obsidian_new tasks to sync to Obsidian"
        # Mark them as synced
        curl -s -X POST "${WORKER_URL}/obsidian/mark-synced" > /dev/null
    fi
else
    log "  Obsidian sync not configured (use Obsidian plugin)"
fi

# STEP 6: Final verification
log ""
log "Step 6: Verifying sync state..."

verify_response=$(curl -s "${WORKER_URL}/sync/verify")
is_healthy=$(echo "$verify_response" | jq -r '.summary.isHealthy')
discrepancy_count=$(echo "$verify_response" | jq -r '.summary.discrepancyCount')

if [ "$is_healthy" = "true" ]; then
    log "  ✅ All systems are in sync!"
else
    log "  ⚠️  Found $discrepancy_count discrepancies"
    echo "$verify_response" | jq -r '.recommendations[]' | while read -r rec; do
        log "    - $rec"
    done
fi

# Summary
log ""
log "=== Three-Way Sync Complete ==="
log "Final counts:"
log "  Todoist: $(curl -s "${WORKER_URL}/inbox?include_all=true&format=flat" | jq '. | length') tasks"
log "  Things: $(osascript -e 'tell application "Things3"
    set inboxTasks to to dos of list "Inbox"
    set openCount to 0
    repeat with t in inboxTasks
        if status of t is open then
            set openCount to openCount + 1
        end if
    end repeat
    return openCount
end tell') tasks"
log ""
log "Logs saved to: $LOG_FILE"