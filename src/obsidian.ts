import { 
  ObsidianTask, 
  ObsidianTaskFormat, 
  ObsidianDateFormat,
  ObsidianRecurrence,
  OBSIDIAN_EMOJI_PATTERNS,
  OBSIDIAN_STATUS_SYMBOLS,
  ObsidianTaskMapping
} from './types/obsidian';
import { TodoistTask, ThingsInboxTask } from './types';
import { generateContentHash, createTaskFingerprint } from './utils';

export function parseObsidianTask(line: string, filePath: string, lineNumber: number): ObsidianTask | null {
  const taskMatch = line.match(/^(\s*)-\s*\[(.)\]\s+(.+)$/);
  if (!taskMatch) return null;

  const [, indent, status, content] = taskMatch;
  const indentLevel = indent.length;
  
  let cleanContent = content;
  const task: ObsidianTask = {
    id: `${filePath}:${lineNumber}`,
    content: '',
    completed: status.toLowerCase() === 'x',
    status: OBSIDIAN_STATUS_SYMBOLS[status] || status,
    tags: [],
    file: {
      path: filePath,
      line: lineNumber,
      position: {
        start: 0,
        end: line.length
      }
    }
  };

  const dueMatch = OBSIDIAN_EMOJI_PATTERNS.due.exec(cleanContent);
  if (dueMatch) {
    task.due = dueMatch[1];
    cleanContent = cleanContent.replace(dueMatch[0], '').trim();
  }

  const scheduledMatch = OBSIDIAN_EMOJI_PATTERNS.scheduled.exec(cleanContent);
  if (scheduledMatch) {
    task.scheduled = scheduledMatch[1];
    cleanContent = cleanContent.replace(scheduledMatch[0], '').trim();
  }

  const doneMatch = OBSIDIAN_EMOJI_PATTERNS.done.exec(cleanContent);
  if (doneMatch) {
    task.done = doneMatch[1];
    cleanContent = cleanContent.replace(doneMatch[0], '').trim();
  }

  const recurrenceMatch = OBSIDIAN_EMOJI_PATTERNS.recurrence.exec(cleanContent);
  if (recurrenceMatch) {
    task.recurrence = recurrenceMatch[1].trim();
    cleanContent = cleanContent.replace(recurrenceMatch[0], '').trim();
  }

  if (OBSIDIAN_EMOJI_PATTERNS.priority.high.test(cleanContent)) {
    task.priority = 1;
    cleanContent = cleanContent.replace(OBSIDIAN_EMOJI_PATTERNS.priority.high, '').trim();
  } else if (OBSIDIAN_EMOJI_PATTERNS.priority.medium.test(cleanContent)) {
    task.priority = 2;
    cleanContent = cleanContent.replace(OBSIDIAN_EMOJI_PATTERNS.priority.medium, '').trim();
  } else if (OBSIDIAN_EMOJI_PATTERNS.priority.low.test(cleanContent)) {
    task.priority = 3;
    cleanContent = cleanContent.replace(OBSIDIAN_EMOJI_PATTERNS.priority.low, '').trim();
  }

  const tagMatches = cleanContent.match(/#[\w-]+/g);
  if (tagMatches) {
    task.tags = tagMatches.map(tag => tag.substring(1));
    tagMatches.forEach(tag => {
      cleanContent = cleanContent.replace(tag, '').trim();
    });
  }

  task.content = cleanContent;

  return task;
}

export function formatObsidianTask(task: ObsidianTask): string {
  const status = task.completed ? 'x' : ' ';
  let line = `- [${status}] ${task.content}`;

  if (task.priority === 1) {
    line += ' 🔺';
  } else if (task.priority === 2) {
    line += ' 🔼';
  } else if (task.priority === 3) {
    line += ' 🔽';
  }

  if (task.due) {
    line += ` 📅 ${task.due}`;
  }

  if (task.scheduled) {
    line += ` ⏳ ${task.scheduled}`;
  }

  if (task.recurrence) {
    line += ` 🔁 ${task.recurrence}`;
  }

  if (task.done && task.completed) {
    line += ` ✅ ${task.done}`;
  }

  if (task.tags.length > 0) {
    line += ' ' + task.tags.map(tag => `#${tag}`).join(' ');
  }

  return line;
}

export function obsidianToTodoist(task: ObsidianTask): Partial<TodoistTask> {
  const todoistTask: Partial<TodoistTask> = {
    content: task.content,
    description: task.notes || '',
    is_completed: task.completed,
    labels: task.tags
  };

  if (task.priority) {
    todoistTask.priority = 5 - task.priority;
  }

  if (task.due) {
    todoistTask.due = {
      date: task.due,
      string: task.due,
      lang: 'en',
      is_recurring: !!task.recurrence
    };
  }

  return todoistTask;
}

export function todoistToObsidian(task: TodoistTask, filePath?: string, lineNumber?: number): ObsidianTask {
  const obsidianTask: ObsidianTask = {
    id: filePath && lineNumber ? `${filePath}:${lineNumber}` : `todoist:${task.id}`,
    content: task.content,
    notes: task.description,
    completed: task.is_completed,
    tags: task.labels || [],
    file: {
      path: filePath || '',
      line: lineNumber || 0,
      position: {
        start: 0,
        end: 0
      }
    }
  };

  if (task.priority) {
    obsidianTask.priority = 5 - task.priority;
  }

  if (task.due) {
    obsidianTask.due = task.due.date;
    if (task.due.is_recurring) {
      obsidianTask.recurrence = task.due.string;
    }
  }

  return obsidianTask;
}

export function obsidianToThings(task: ObsidianTask): ThingsInboxTask {
  const thingsTask: ThingsInboxTask = {
    id: task.id,
    title: task.content,
    notes: task.notes || '',
    due: task.due || null,
    tags: task.tags
  };

  if (task.priority === 1) {
    thingsTask.tags.push('high-priority');
  }

  return thingsTask;
}

export function thingsToObsidian(task: ThingsInboxTask, filePath?: string, lineNumber?: number): ObsidianTask {
  const obsidianTask: ObsidianTask = {
    id: filePath && lineNumber ? `${filePath}:${lineNumber}` : `things:${task.id}`,
    content: task.title,
    notes: task.notes,
    completed: false,
    tags: task.tags || [],
    due: task.due || undefined,
    file: {
      path: filePath || '',
      line: lineNumber || 0,
      position: {
        start: 0,
        end: 0
      }
    }
  };

  if (task.tags.includes('high-priority')) {
    obsidianTask.priority = 1;
    obsidianTask.tags = obsidianTask.tags.filter(t => t !== 'high-priority');
  }

  return obsidianTask;
}

export function parseRecurrence(recurrenceString: string): ObsidianRecurrence {
  const recurrence: ObsidianRecurrence = {
    pattern: recurrenceString,
    raw: recurrenceString
  };

  const dailyMatch = recurrenceString.match(/every\s+(\d+\s+)?day/i);
  if (dailyMatch) {
    recurrence.unit = 'daily';
    recurrence.interval = dailyMatch[1] ? parseInt(dailyMatch[1]) : 1;
    return recurrence;
  }

  const weeklyMatch = recurrenceString.match(/every\s+(\d+\s+)?week/i);
  if (weeklyMatch) {
    recurrence.unit = 'weekly';
    recurrence.interval = weeklyMatch[1] ? parseInt(weeklyMatch[1]) : 1;
    
    const weekdayMatch = recurrenceString.match(/(monday|tuesday|wednesday|thursday|friday|saturday|sunday)/gi);
    if (weekdayMatch) {
      recurrence.weekdays = weekdayMatch.map(d => d.toLowerCase());
    }
    return recurrence;
  }

  const monthlyMatch = recurrenceString.match(/every\s+(\d+\s+)?month/i);
  if (monthlyMatch) {
    recurrence.unit = 'monthly';
    recurrence.interval = monthlyMatch[1] ? parseInt(monthlyMatch[1]) : 1;
    
    const dayMatch = recurrenceString.match(/on\s+the\s+(\d+)/);
    if (dayMatch) {
      recurrence.monthDay = parseInt(dayMatch[1]);
    }
    return recurrence;
  }

  const yearlyMatch = recurrenceString.match(/every\s+(\d+\s+)?year/i);
  if (yearlyMatch) {
    recurrence.unit = 'yearly';
    recurrence.interval = yearlyMatch[1] ? parseInt(yearlyMatch[1]) : 1;
    return recurrence;
  }

  return recurrence;
}

export function createObsidianTaskFingerprint(task: ObsidianTask): string {
  const normalizedContent = task.content.toLowerCase().trim();
  const normalizedNotes = (task.notes || '').toLowerCase().trim();
  const normalizedDue = task.due || '';
  
  return generateContentHash(`${normalizedContent}|${normalizedNotes}|${normalizedDue}`);
}

export function createObsidianTaskMapping(
  obsidianTask: ObsidianTask,
  todoistId?: string,
  thingsId?: string
): ObsidianTaskMapping {
  return {
    obsidianId: obsidianTask.id,
    todoistId,
    thingsId,
    fingerprint: createObsidianTaskFingerprint(obsidianTask),
    lastSynced: new Date().toISOString(),
    file: {
      path: obsidianTask.file.path,
      line: obsidianTask.file.line
    },
    contentHash: generateContentHash(JSON.stringify({
      content: obsidianTask.content,
      notes: obsidianTask.notes,
      due: obsidianTask.due,
      tags: obsidianTask.tags,
      priority: obsidianTask.priority
    }))
  };
}

export function mergeObsidianTask(
  local: ObsidianTask,
  remote: Partial<ObsidianTask>,
  strategy: 'local_wins' | 'remote_wins' | 'merge' = 'merge'
): ObsidianTask {
  if (strategy === 'local_wins') {
    return local;
  }

  if (strategy === 'remote_wins') {
    return {
      ...local,
      ...remote,
      file: local.file
    };
  }

  return {
    ...local,
    content: remote.content || local.content,
    notes: remote.notes !== undefined ? remote.notes : local.notes,
    completed: remote.completed !== undefined ? remote.completed : local.completed,
    due: remote.due !== undefined ? remote.due : local.due,
    scheduled: remote.scheduled !== undefined ? remote.scheduled : local.scheduled,
    recurrence: remote.recurrence !== undefined ? remote.recurrence : local.recurrence,
    priority: remote.priority !== undefined ? remote.priority : local.priority,
    tags: [...new Set([...local.tags, ...(remote.tags || [])])],
    file: local.file
  };
}

export function extractObsidianTasksFromContent(
  content: string,
  filePath: string
): ObsidianTask[] {
  const lines = content.split('\n');
  const tasks: ObsidianTask[] = [];

  for (let i = 0; i < lines.length; i++) {
    const task = parseObsidianTask(lines[i], filePath, i + 1);
    if (task) {
      tasks.push(task);
    }
  }

  return tasks;
}

export function updateObsidianTaskInContent(
  content: string,
  lineNumber: number,
  newTask: ObsidianTask
): string {
  const lines = content.split('\n');
  if (lineNumber > 0 && lineNumber <= lines.length) {
    lines[lineNumber - 1] = formatObsidianTask(newTask);
  }
  return lines.join('\n');
}