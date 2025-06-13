# OneNote Graph API Sync Tool

This tool synchronizes your OneNote notebooks to local markdown files using the Microsoft Graph API, creating a directory structure that works perfectly with VS Code.

## Features

- **Multi-account support** - Works with both personal and corporate accounts
- **Markdown export** - Converts OneNote pages to clean markdown
- **Directory structure** - Organizes notes by Notebook > Section > Page
- **Search capabilities** - Full-text search across all exported notes
- **Auto-sync** - Configurable automatic synchronization
- **VS Code integration** - Pre-configured workspace for optimal editing
- **Metadata preservation** - Keeps creation dates, modification dates, and OneNote IDs

## Setup Instructions

### 1. Rebuild Your Nix Configuration

```bash
cd ~/.nix-config && NIXPKGS_ALLOW_UNFREE=1 nix run --impure .#homeConfigurations.$USER.activationPackage
```

### 2. Register Azure Application

Since you have the Application developer role, you can create the app registration directly:

1. Go to [Azure Portal](https://portal.azure.com/)
2. Navigate to **Microsoft Entra ID** → **App registrations**
3. Click **New registration**
4. Fill in:
   - **Name**: OneNote Sync Tool
   - **Supported account types**: Accounts in any organizational directory and personal Microsoft accounts
   - **Redirect URI**: Public client/native (mobile & desktop) → `http://localhost`
5. Click **Register**
6. In your new app, go to **API permissions**
7. Click **Add a permission**
8. Select **Microsoft Graph** → **Delegated permissions**
9. Search for and add these permissions:
   - `Notes.Read`
   - `Notes.ReadWrite`
10. Click **Add permissions**
11. Click **Grant admin consent for [Your Organization]** (if available)
12. Go to **Overview** tab and copy the **Application (client) ID**

### 3. Configure the Tool

```bash
# Show config file location
onenote-sync config

# Edit the config file and add your client ID
nano ~/.config/onenote-sync/config.yaml
```

Example configuration:
```yaml
client_id: "your-client-id-here"
tenant_id: "common"  # Use "common" for personal accounts, or your tenant ID for corporate
output_directory: "~/Documents/OneNote-Export"
scopes:
  - "Notes.Read"
  - "Notes.ReadWrite"
excluded_notebooks: []
sync_interval: 3600  # 1 hour
markdown_options:
  body_width: 0
  unicode_snob: true
  escape_all: false
```

### 4. Run Initial Sync

```bash
onenote-sync sync
```

This will:
- Authenticate with Microsoft (opens browser)
- Download all your OneNote notebooks
- Convert them to markdown files
- Organize them in a directory structure

## Usage

### Manual Sync
```bash
onenote-sync sync
```

### Search Notes
```bash
onenote-sync search "meeting notes"
```

### Auto-sync (Background)
```bash
nohup onenote-auto-sync &
```

### Open in VS Code
```bash
onenote-vscode
```

## Directory Structure

Your OneNote notebooks will be exported to a structure like this:

```
~/Documents/OneNote-Export/
├── Work Notebook/
│   ├── Meeting Notes/
│   │   ├── 2025-01-15 Team Meeting.md
│   │   └── Project Planning.md
│   └── Documentation/
│       └── API Reference.md
├── Personal Notebook/
│   └── Ideas/
│       └── App Concepts.md
└── sync_info.json
```

Each markdown file includes metadata:
```markdown
---
title: Team Meeting
created: 2025-01-15T10:30:00Z
modified: 2025-01-15T11:45:00Z
onenote_id: 1-abc123...
notebook: Work Notebook
section: Meeting Notes
---

# Meeting Notes
...
```

## VS Code Integration

The tool creates a VS Code workspace with:
- Markdown preview enhancements
- Search optimizations
- Recommended extensions
- OneNote-friendly settings

Open the workspace with:
```bash
onenote-vscode
```

## Troubleshooting

### Authentication Issues
- Make sure your client ID is correct in the config
- Check that redirect URI is set to `http://localhost`
- Verify API permissions are granted

### Sync Errors
- Check the log: `~/.local/share/onenote-sync.log`
- Verify internet connection
- Check Microsoft Graph service status

### Empty/Missing Content
- Some OneNote content may not convert perfectly to markdown
- Check the original OneNote page for complex formatting
- Try syncing again as Graph API can be sometimes inconsistent

## Configuration Options

### Exclude Notebooks
Add notebook names to exclude them from sync:
```yaml
excluded_notebooks:
  - "Temporary Notes"
  - "Archive"
```

### Customize Output Directory
```yaml
output_directory: "~/Workspace/Notes"
```

### Adjust Sync Interval
```yaml
sync_interval: 1800  # 30 minutes
```

### Markdown Options
```yaml
markdown_options:
  body_width: 80        # Line wrap width (0 = no wrap)
  unicode_snob: true    # Use unicode characters
  escape_all: false     # Escape all markdown characters
```

## Corporate Account Notes

For corporate accounts:
1. You may need IT approval for the Azure app registration
2. Use your organization's tenant ID instead of "common"
3. Some features might be restricted by your organization's policies

## Comparison with Other Solutions

| Feature | OneNote Graph API | Web OneNote | P3X-OneNote |
|---------|------------------|-------------|-------------|
| Multi-account | ✅ | ❌ | ⚠️ (unreliable) |
| Offline access | ✅ | ❌ | ✅ |
| Search quality | ✅ | ⚠️ | ⚠️ |
| Corporate support | ✅ | ✅ | ❌ |
| Linux native | ✅ | ❌ | ✅ |
| Export capability | ✅ | ❌ | ❌ |

This Graph API solution provides the most reliable access to OneNote data while giving you full control over your notes in a format that works perfectly with modern development tools.
