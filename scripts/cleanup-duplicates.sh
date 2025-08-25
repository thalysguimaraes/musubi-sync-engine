#!/bin/bash

# Script to clean up duplicate tasks in Todoist using the REST API directly
# Requires TODOIST_API_TOKEN environment variable

if [ -z "$TODOIST_API_TOKEN" ]; then
  echo "Error: TODOIST_API_TOKEN environment variable not set"
  echo "Please run: export TODOIST_API_TOKEN='your-token-here'"
  exit 1
fi

echo "Cleaning up duplicate tasks in Todoist..."

# Tasks to delete (keeping first occurrence of each)
TASKS_TO_DELETE=(
  # Cancel Cursor duplicates (keep 9472645434)
  9476172007 9476172009 9476172047 9476172111
  # Downgrade Claude duplicates (keep 9472645764)  
  9476172001 9476172039 9476172040 9476172082 9476172086
  # Rodar migration duplicates (keep 9468010927)
  9476172004 9476172014 9476172074 9476172079 9476172123
  # Upgrade GPT duplicates (keep 9472646165)
  9476172002 9476172042 9476172045 9476172083 9476172088
)

DELETED_COUNT=0
FAILED_COUNT=0

for task_id in "${TASKS_TO_DELETE[@]}"; do
  echo -n "Deleting task $task_id... "
  
  RESPONSE=$(curl -X DELETE "https://api.todoist.com/rest/v2/tasks/$task_id" \
    -H "Authorization: Bearer $TODOIST_API_TOKEN" \
    -s -w "\n%{http_code}")
  
  HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
  
  if [ "$HTTP_CODE" = "204" ]; then
    echo "✓ deleted"
    ((DELETED_COUNT++))
  elif [ "$HTTP_CODE" = "404" ]; then
    echo "⚠ already deleted or not found"
  else
    echo "✗ failed (HTTP $HTTP_CODE)"
    ((FAILED_COUNT++))
  fi
  
  sleep 0.3  # Rate limiting
done

echo ""
echo "Summary:"
echo "  Successfully deleted: $DELETED_COUNT tasks"
echo "  Failed or not found: $((${#TASKS_TO_DELETE[@]} - DELETED_COUNT)) tasks"

if [ $FAILED_COUNT -gt 0 ]; then
  echo ""
  echo "Note: Some deletions failed. This might be because:"
  echo "  - Tasks were already deleted"
  echo "  - API token doesn't have permission"
  echo "  - Network issues"
fi

echo ""
echo "Verifying remaining tasks..."
curl -s "https://todoist-things-sync.thalys.workers.dev/inbox?include_all=true&format=flat" | \
  jq -r '.[] | .title' | sort | uniq -c | sort -rn

echo ""
echo "Total tasks remaining: $(curl -s "https://todoist-things-sync.thalys.workers.dev/inbox?include_all=true&format=flat" | jq '. | length')"