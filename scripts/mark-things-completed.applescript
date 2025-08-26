#!/usr/bin/osascript

-- Mark tasks as completed in Things based on their IDs
-- Input: JSON array of task IDs to mark as completed

on run argv
    set json_input to item 1 of argv
    
    tell application "System Events"
        set json_data to make new property list item with data json_input
        set task_ids to value of json_data
    end tell
    
    set completed_count to 0
    
    tell application "Things3"
        repeat with task_id in task_ids
            try
                set target_todo to to do id task_id
                if status of target_todo is open then
                    set status of target_todo to completed
                    set completed_count to completed_count + 1
                end if
            on error
                -- Task not found, skip
            end try
        end repeat
    end tell
    
    return completed_count & " tasks marked as completed"
end run