# Todoist-Things Sync Engine

A powerful Cloudflare Worker that enables automatic three-way synchronization between Todoist, Things 3, and Obsidian.

## Overview

This is the core sync engine that runs on Cloudflare Workers, providing real-time synchronization between:
- **Todoist** - Cross-platform task management 
- **Things 3** - Native macOS/iOS task management
- **Obsidian** - Knowledge management with task support

## Features

- 🔄 **Three-Way Sync**: Tasks created in any app automatically appear in the others
- 🤝 **Conflict Resolution**: Smart detection and resolution when tasks are modified in multiple apps
- 🎯 **Selective Sync**: Filter by projects and tags - sync only what you need
- 🚫 **Duplicate Prevention**: Advanced fingerprint-based deduplication
- 📊 **Performance Metrics**: Track sync performance and monitor health
- ⚡ **Idempotency**: Safe request retry with automatic deduplication
- 🔧 **Configuration API**: Customize sync behavior via REST API
- 🪝 **Webhook Integration**: Real-time sync from GitHub, Notion, Slack, and custom services
- 📡 **Outbound Webhooks**: Get notified of sync events in real-time
- ⏰ **CF Workers Cron**: Server-side sync coordination running every 2 minutes
- 📝 **Comprehensive Testing**: 55+ unit tests and integration tests

## Architecture

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────┐
│   Todoist   │────▶│ Cloudflare Worker│◀────│  Things 3   │
│   (Inbox)   │     │   with D1 Store  │     │  (Inbox)    │
└─────────────┘     └──────────────────┘     └─────────────┘
       ▲                    │ ▲                       ▲
       │                    │ │                       │
       │                    │ │                       │
       └────────────────────┼─────────────────────────┘
                           │
                    ┌──────────────┐
                    │   Obsidian   │
                    │   (Tasks)    │
                    └──────────────┘
```

## Prerequisites

- Cloudflare account (free tier works)
- Todoist account with API access
- macOS with Things 3 (for Things sync)
- Node.js 16+ and npm

## Installation

```bash
# Clone the repository
git clone https://github.com/thalysguimaraes/todoist-things-sync-engine.git
cd todoist-things-sync-engine

# Install dependencies
npm install

# Configure your environment
cp wrangler.toml.example wrangler.toml
# Edit wrangler.toml with your settings

# Deploy to Cloudflare
npm run deploy
```

## Configuration

### Environment Variables

Set these in your `wrangler.toml`:

```toml
[vars]
TODOIST_API_TOKEN = "your-todoist-api-token"
WEBHOOK_SECRET = "your-webhook-secret"
```

### API Endpoints

- `GET /health` - Health check endpoint
- `POST /todoist/sync` - Trigger Todoist sync
- `POST /things/sync` - Receive Things sync data
- `POST /obsidian/sync` - Receive Obsidian sync data
- `GET /metrics` - View sync metrics
- `POST /config` - Update sync configuration

## Development

```bash
# Run tests
npm test

# Run locally with Wrangler
npm run dev

# Deploy to Cloudflare
npm run deploy
```

## Related Projects

- [obsidian-sync-plugin](https://github.com/thalysguimaraes/obsidian-sync-plugin) - Obsidian plugin for three-way sync
- [sync-tui](https://github.com/thalysguimaraes/sync-tui) - Terminal UI for managing sync

## License

MIT