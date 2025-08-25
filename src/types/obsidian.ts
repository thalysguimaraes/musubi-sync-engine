export interface ObsidianTask {
  id: string;
  content: string;
  notes?: string;
  completed: boolean;
  status?: string;
  priority?: number;
  due?: string;
  scheduled?: string;
  done?: string;
  recurrence?: string;
  tags: string[];
  file: {
    path: string;
    line: number;
    position: {
      start: number;
      end: number;
    };
  };
  metadata?: {
    created?: string;
    modified?: string;
  };
}

export interface ObsidianTaskFormat {
  raw: string;
  status: string;
  content: string;
  emojis: {
    due?: string;
    scheduled?: string;
    done?: string;
    recurrence?: string;
    priority?: string;
  };
  tags: string[];
  subtasks?: ObsidianTaskFormat[];
}

export interface ObsidianSyncRequest {
  tasks: ObsidianTask[];
  vault: {
    name: string;
    path?: string;
  };
  filter?: {
    tags?: string[];
    folders?: string[];
    status?: string[];
  };
  syncMode: 'full' | 'incremental';
  lastSyncedAt?: string;
}

export interface ObsidianSyncResponse {
  synced: number;
  created: number;
  updated: number;
  conflicts: ObsidianSyncConflict[];
  errors: string[];
  nextSyncToken?: string;
}

export interface ObsidianSyncConflict {
  obsidianTask: ObsidianTask;
  existingTask: {
    todoistId?: string;
    thingsId?: string;
    title: string;
    notes?: string;
    due?: string;
  };
  resolution?: 'obsidian_wins' | 'existing_wins' | 'merge' | 'skip';
}

export interface ObsidianTaskMapping {
  obsidianId: string;
  todoistId?: string;
  thingsId?: string;
  fingerprint: string;
  lastSynced: string;
  file: {
    path: string;
    line: number;
  };
  contentHash: string;
}

export interface ObsidianPluginSettings {
  apiUrl: string;
  apiKey?: string;
  syncInterval: number;
  autoSync: boolean;
  syncFolders: string[];
  excludeFolders: string[];
  syncTags: string[];
  excludeTags: string[];
  conflictResolution: 'ask' | 'obsidian_wins' | 'remote_wins' | 'newest_wins';
  debugMode: boolean;
}

export const OBSIDIAN_EMOJI_PATTERNS = {
  due: /📅\s*(\d{4}-\d{2}-\d{2})/,
  scheduled: /⏳\s*(\d{4}-\d{2}-\d{2})/,
  done: /✅\s*(\d{4}-\d{2}-\d{2})/,
  recurrence: /🔁\s*([^📅⏳✅🔼🔽]*)/,
  priority: {
    high: /[⏫🔺🔴]/,
    medium: /[🔼🟡]/,
    low: /[⏬🔽🟢]/
  }
};

export const OBSIDIAN_STATUS_SYMBOLS: Record<string, string> = {
  ' ': 'todo',
  'x': 'done',
  'X': 'done',
  '-': 'cancelled',
  '>': 'forwarded',
  '<': 'scheduled',
  '!': 'important',
  '?': 'question',
  '*': 'star',
  'l': 'location',
  'b': 'bookmark',
  'i': 'information',
  'S': 'savings',
  'I': 'idea',
  'p': 'pros',
  'c': 'cons',
  'f': 'fire',
  'k': 'key',
  'w': 'win',
  'u': 'up',
  'd': 'down'
};

export interface ObsidianDateFormat {
  type: 'due' | 'scheduled' | 'done' | 'created';
  date: string;
  hasTime: boolean;
  time?: string;
  emoji: string;
  raw: string;
}

export interface ObsidianRecurrence {
  pattern: string;
  interval?: number;
  unit?: 'daily' | 'weekly' | 'monthly' | 'yearly';
  weekdays?: string[];
  monthDay?: number;
  raw: string;
}