#!/usr/bin/env osascript

-- Import missing tasks from Todoist to Things
-- Creates tasks directly without complex JSON parsing

on run
    tell application "Things3"
        -- Tasks to import from Todoist (the 4 Obsidian-originated tasks)
        set tasksToImport to {¬
            {title:"Rodar migration do serviço do Things/Todoist", dueDate:"2025-08-23", notes:"From Obsidian: 2025-08-22.md"}, ¬
            {title:"Cancel Cursor", dueDate:missing value, notes:"From Obsidian: 2025-08-24.md"}, ¬
            {title:"Downgrade Claude", dueDate:"2025-08-24", notes:"From Obsidian: 2025-08-24.md"}, ¬
            {title:"Upgrade GPT", dueDate:"2025-08-24", notes:"From Obsidian: 2025-08-24.md"} ¬
        }
        
        set importedCount to 0
        set skippedCount to 0
        
        repeat with taskData in tasksToImport
            set taskTitle to title of taskData
            set taskNotes to notes of taskData
            set taskDue to dueDate of taskData
            
            -- Check if task already exists in inbox
            set existingTasks to to dos of list "Inbox" whose name is taskTitle
            
            if (count of existingTasks) is 0 then
                -- Create new task
                if taskDue is not missing value then
                    set newTask to make new to do with properties {name:taskTitle, notes:taskNotes, due date:date taskDue}
                else
                    set newTask to make new to do with properties {name:taskTitle, notes:taskNotes}
                end if
                
                -- Move to inbox
                move newTask to list "Inbox"
                
                -- Add synced tag
                set tag names of newTask to tag names of newTask & "synced-from-todoist"
                
                set importedCount to importedCount + 1
                log "Imported: " & taskTitle
            else
                set skippedCount to skippedCount + 1
                log "Skipped (already exists): " & taskTitle
            end if
        end repeat
        
        return "Imported " & importedCount & " tasks, skipped " & skippedCount & " existing tasks"
    end tell
end run