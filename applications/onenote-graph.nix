{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    # Additional tools (Python packages defined in python.nix)
    pandoc
    nodejs
    jq
  ];

  # Main OneNote Graph API client
  home.file.".local/lib/onenote-graph/onenote_sync.py" = {
    text = ''
      #!/usr/bin/env python3
      """
      OneNote Graph API Sync Tool
      Exports OneNote notebooks to markdown with directory structure
      """

      import os
      import json
      import requests
      import html2text
      import yaml
      from pathlib import Path
      from datetime import datetime
      from msal import PublicClientApplication, ConfidentialClientApplication
      from bs4 import BeautifulSoup
      import click
      from rich.console import Console
      from rich.progress import Progress, TaskID
      import re
      import time

      console = Console()

      class OneNoteSyncManager:
          def __init__(self, config_path="~/.config/onenote-sync/config.yaml"):
              self.config_path = Path(config_path).expanduser()
              self.config = self.load_config()
              self.access_token = None
              self.app = None
              self.output_dir = Path(self.config.get('output_directory', '~/Documents/OneNote-Export')).expanduser()
              
          def load_config(self):
              """Load configuration from YAML file"""
              if not self.config_path.exists():
                  self.create_default_config()
              
              with open(self.config_path, 'r') as f:
                  return yaml.safe_load(f)
                
                def create_default_config(self):
                    """Create default configuration file"""
                    self.config_path.parent.mkdir(parents=True, exist_ok=True)
                    
                    default_config = {
                        'client_id': 'YOUR_CLIENT_ID_HERE',
                        'tenant_id': 'common',  # Use 'common' for personal accounts
                        'output_directory': '~/Documents/OneNote-Export',
                        'scopes': ['Notes.Read', 'Notes.ReadWrite'],
                        'excluded_notebooks': [],
                        'sync_interval': 3600,  # 1 hour in seconds
                        'markdown_options': {
                            'body_width': 0,
                            'unicode_snob': True,
                            'escape_all': False
                        }
                    }
                    
                    with open(self.config_path, 'w') as f:
                        yaml.dump(default_config, f, default_flow_style=False)
                    
                    console.print(f"[yellow]Created default config at {self.config_path}")
                    console.print("[yellow]Please edit the config file and add your client_id")
                    return default_config
                
                def authenticate(self):
                    """Authenticate with Microsoft Graph"""
                    client_id = self.config.get('client_id')
                    tenant_id = self.config.get('tenant_id', 'common')
                    
                    if not client_id or client_id == 'YOUR_CLIENT_ID_HERE':
                        console.print("[red]Please configure your client_id in the config file")
                        console.print(f"[yellow]Config file: {self.config_path}")
                        return False
                    
                    # Use public client application for delegated permissions
                    self.app = PublicClientApplication(
                        client_id,
                        authority=f"https://login.microsoftonline.com/{tenant_id}"
                    )
                    
                    # Try to get token from cache first
                    accounts = self.app.get_accounts()
                    if accounts:
                        result = self.app.acquire_token_silent(
                            self.config.get('scopes', ['Notes.Read']),
                            account=accounts[0]
                        )
                    else:
                        result = None
                    
                    # If no cached token, get new one interactively
                    if not result:
                        console.print("[yellow]Opening browser for authentication...")
                        result = self.app.acquire_token_interactive(
                            scopes=self.config.get('scopes', ['Notes.Read'])
                        )
                    
                    if "access_token" in result:
                        self.access_token = result["access_token"]
                        console.print("[green]Authentication successful!")
                        return True
                    else:
                        console.print(f"[red]Authentication failed: {result.get('error_description')}")
                        return False
                
                def make_graph_request(self, endpoint, params=None):
                    """Make authenticated request to Microsoft Graph"""
                    if not self.access_token:
                        raise Exception("Not authenticated")
                    
                    headers = {
                        'Authorization': f'Bearer {self.access_token}',
                        'Content-Type': 'application/json'
                    }
                    
                    url = f'https://graph.microsoft.com/v1.0{endpoint}'
                    response = requests.get(url, headers=headers, params=params)
                    
                    if response.status_code == 401:
                        # Token expired, try to refresh
                        if self.authenticate():
                            headers['Authorization'] = f'Bearer {self.access_token}'
                            response = requests.get(url, headers=headers, params=params)
                    
                    if response.status_code == 200:
                        return response.json()
                    else:
                        raise Exception(f"Graph API request failed: {response.status_code} - {response.text}")
                
                def get_notebooks(self):
                    """Get all OneNote notebooks"""
                    notebooks = self.make_graph_request('/me/onenote/notebooks')
                    excluded = self.config.get('excluded_notebooks', [])
                    
                    # Filter out excluded notebooks
                    filtered_notebooks = [
                        nb for nb in notebooks.get('value', [])
                        if nb.get('displayName') not in excluded
                    ]
                    
                    return filtered_notebooks
                
                def get_sections(self, notebook_id):
                    """Get sections for a notebook"""
                    sections = self.make_graph_request(f'/me/onenote/notebooks/{notebook_id}/sections')
                    return sections.get('value', [])
                
                def get_pages(self, section_id):
                    """Get pages for a section"""
                    pages = self.make_graph_request(f'/me/onenote/sections/{section_id}/pages')
                    return pages.get('value', [])
                
                def get_page_content(self, page_id):
                    """Get content of a specific page"""
                    if not self.access_token:
                        raise Exception("Not authenticated")
                    
                    headers = {
                        'Authorization': f'Bearer {self.access_token}',
                        'Accept': 'text/html'
                    }
                    
                    url = f'https://graph.microsoft.com/v1.0/me/onenote/pages/{page_id}/content'
                    response = requests.get(url, headers=headers)
                    
                    if response.status_code == 200:
                        return response.text
                    else:
                        console.print(f"[yellow]Warning: Could not get content for page {page_id}")
                        return ""
                
                def html_to_markdown(self, html_content):
                    """Convert HTML content to Markdown"""
                    if not html_content:
                        return ""
                    
                    # Parse HTML and clean it up
                    soup = BeautifulSoup(html_content, 'html.parser')
                    
                    # Remove script and style elements
                    for script in soup(["script", "style"]):
                        script.decompose()
                    
                    # Convert to markdown
                    h = html2text.HTML2Text()
                    h.body_width = self.config.get('markdown_options', {}).get('body_width', 0)
                    h.unicode_snob = self.config.get('markdown_options', {}).get('unicode_snob', True)
                    h.escape_all = self.config.get('markdown_options', {}).get('escape_all', False)
                    
                    markdown = h.handle(str(soup))
                    
                    # Clean up the markdown
                    markdown = re.sub(r'\n\s*\n\s*\n', '\n\n', markdown)  # Remove excessive newlines
                    markdown = markdown.strip()
                    
                    return markdown
                
                def sanitize_filename(self, filename):
                    """Sanitize filename for filesystem"""
                    # Replace invalid characters
                    filename = re.sub(r'[<>:"/\\|?*]', '_', filename)
                    # Remove leading/trailing dots and spaces
                    filename = filename.strip('. ')
                    # Limit length
                    if len(filename) > 100:
                        filename = filename[:100]
                    return filename
                
                def sync_notebooks(self):
                    """Sync all notebooks to local directory structure"""
                    if not self.authenticate():
                        return False
                    
                    console.print("[blue]Starting OneNote sync...")
                    
                    try:
                        notebooks = self.get_notebooks()
                        console.print(f"[green]Found {len(notebooks)} notebooks")
                        
                        # Create output directory
                        self.output_dir.mkdir(parents=True, exist_ok=True)
                        
                        # Create sync metadata
                        sync_info = {
                            'last_sync': datetime.now().isoformat(),
                            'notebooks_synced': len(notebooks),
                            'notebooks': []
                        }
                        
                        with Progress() as progress:
                            notebooks_task = progress.add_task("Syncing notebooks...", total=len(notebooks))
                            
                            for notebook in notebooks:
                                notebook_name = self.sanitize_filename(notebook['displayName'])
                                notebook_dir = self.output_dir / notebook_name
                                notebook_dir.mkdir(exist_ok=True)
                                
                                console.print(f"[cyan]Syncing notebook: {notebook['displayName']}")
                                
                                # Get sections
                                sections = self.get_sections(notebook['id'])
                                
                                sections_task = progress.add_task(f"Sections in {notebook_name}...", total=len(sections))
                                
                                notebook_info = {
                                    'name': notebook['displayName'],
                                    'id': notebook['id'],
                                    'sections': []
                                }
                                
                                for section in sections:
                                    section_name = self.sanitize_filename(section['displayName'])
                                    section_dir = notebook_dir / section_name
                                    section_dir.mkdir(exist_ok=True)
                                    
                                    # Get pages
                                    pages = self.get_pages(section['id'])
                                    
                                    section_info = {
                                        'name': section['displayName'],
                                        'id': section['id'],
                                        'pages': len(pages)
                                    }
                                    
                                    for page in pages:
                                        page_name = self.sanitize_filename(page['title'])
                                        page_file = section_dir / f"{page_name}.md"
                                        
                                        # Get page content and convert to markdown
                                        html_content = self.get_page_content(page['id'])
                                        markdown_content = self.html_to_markdown(html_content)
                                        
                                        # Add metadata header
                                        metadata = f"""---
      title: {page['title']}
      created: {page.get('createdDateTime', 'Unknown')}
      modified: {page.get('lastModifiedDateTime', 'Unknown')}
      onenote_id: {page['id']}
      notebook: {notebook['displayName']}
      section: {section['displayName']}
      ---

      """
                                        
                                        # Write to file
                                        with open(page_file, 'w', encoding='utf-8') as f:
                                            f.write(metadata + markdown_content)
                                    
                                    notebook_info['sections'].append(section_info)
                                    progress.update(sections_task, advance=1)
                                    
                                    # Small delay to avoid rate limiting
                                    time.sleep(0.1)
                                
                                sync_info['notebooks'].append(notebook_info)
                                progress.update(notebooks_task, advance=1)
                        
                        # Save sync metadata
                        with open(self.output_dir / 'sync_info.json', 'w') as f:
                            json.dump(sync_info, f, indent=2)
                        
                        console.print(f"[green]Sync completed! Files saved to: {self.output_dir}")
                        return True
                        
                    except Exception as e:
                        console.print(f"[red]Sync failed: {str(e)}")
                        return False
                
                def search_pages(self, query):
                    """Search across all OneNote pages"""
                    if not self.authenticate():
                        return []
                    
                    try:
                        results = self.make_graph_request(f'/me/onenote/pages', {'search': query})
                        return results.get('value', [])
                    except Exception as e:
                        console.print(f"[red]Search failed: {str(e)}")
                        return []
            
            @click.group()
            def cli():
                """OneNote Graph API Sync Tool"""
                pass
            
            @cli.command()
            def sync():
                """Sync all OneNote notebooks to local markdown files"""
                manager = OneNoteSyncManager()
                manager.sync_notebooks()
            
            @cli.command()
            @click.argument('query')
            def search(query):
                """Search OneNote pages"""
                manager = OneNoteSyncManager()
                results = manager.search_pages(query)
                
                if results:
                    console.print(f"[green]Found {len(results)} results for '{query}':")
                    for result in results:
                        console.print(f"- {result.get('title', 'Untitled')} ({result.get('id')})")
                else:
                    console.print(f"[yellow]No results found for '{query}'")
            
            @cli.command()
            def config():
                """Show configuration file location"""
                manager = OneNoteSyncManager()
                console.print(f"Config file: {manager.config_path}")
                console.print(f"Output directory: {manager.output_dir}")
            
            if __name__ == '__main__':
                cli()
    '';
    executable = true;
  };

  # Wrapper script for easier access
  home.file.".local/bin/onenote-sync" = {
    text = ''
      #!/usr/bin/env bash
      # OneNote Graph API Sync wrapper

      SCRIPT_DIR="$HOME/.local/lib/onenote-graph"

      # Run the Python script
      exec python3 "$SCRIPT_DIR/onenote_sync.py" "$@"
    '';
    executable = true;
  };

  # Auto-sync service
  home.file.".local/bin/onenote-auto-sync" = {
    text = ''
      #!/usr/bin/env bash
      # Auto-sync OneNote every hour

      CONFIG_FILE="$HOME/.config/onenote-sync/config.yaml"

      # Get sync interval from config (default 1 hour)
      SYNC_INTERVAL=3600
      if [ -f "$CONFIG_FILE" ]; then
        SYNC_INTERVAL=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE')).get('sync_interval', 3600))" 2>/dev/null || echo 3600)
      fi

      echo "Starting OneNote auto-sync with interval: $SYNC_INTERVAL seconds"

      while true; do
        echo "$(date): Running OneNote sync..."
        onenote-sync sync > "$HOME/.local/share/onenote-sync.log" 2>&1
        
        if [ $? -eq 0 ]; then
          echo "$(date): Sync completed successfully"
        else
          echo "$(date): Sync failed, check log at ~/.local/share/onenote-sync.log"
        fi
        
        sleep "$SYNC_INTERVAL"
      done
    '';
    executable = true;
  };

  # Setup script for Azure app registration
  home.file.".local/bin/onenote-setup" = {
    text = ''
      #!/usr/bin/env bash
      # OneNote Graph API setup helper

      echo "OneNote Graph API Setup Helper"
      echo "=============================="
      echo ""
      echo "STEP 1: Create App Registration in Microsoft Entra ID"
      echo "====================================================="
      echo ""
      echo "1. Go to https://portal.azure.com/"
      echo "2. Navigate to 'Microsoft Entra ID' → 'App registrations'"
      echo "3. Click 'New registration'"
      echo "4. Fill in:"
      echo "   - Name: OneNote Sync Tool"
      echo "   - Supported account types: Accounts in any organizational directory and personal Microsoft accounts"
      echo "   - Redirect URI: Public client/native (mobile & desktop) → http://localhost"
      echo "5. Click 'Register'"
      echo ""
      echo "STEP 2: Configure API Permissions"
      echo "================================="
      echo ""
      echo "6. In your new app, go to 'API permissions'"
      echo "7. Click 'Add a permission'"
      echo "8. Select 'Microsoft Graph' → 'Delegated permissions'"
      echo "9. Search for and add these permissions:"
      echo "   - Notes.Read"
      echo "   - Notes.ReadWrite"
      echo "10. Click 'Add permissions'"
      echo "11. Click 'Grant admin consent for [Your Organization]' (if available)"
      echo ""
      echo "STEP 3: Copy the Client ID"
      echo "=========================="
      echo ""
      echo "12. Go to 'Overview' tab"
      echo "13. Copy the 'Application (client) ID' (it looks like: 12345678-1234-1234-1234-123456789012)"
      echo ""
      echo "STEP 4: Configure the OneNote Sync Tool"
      echo "======================================="
      echo ""
      echo "14. Run: onenote-sync config"
      echo "15. Edit the config file: ~/.config/onenote-sync/config.yaml"
      echo "16. Replace 'YOUR_CLIENT_ID_HERE' with your actual client ID"
      echo "17. Save the file"
      echo ""
      echo "STEP 5: Test the Setup"
      echo "====================="
      echo ""
      echo "18. Run: onenote-sync sync"
      echo "19. Your browser will open for authentication"
      echo "20. Sign in with your Microsoft account"
      echo "21. Grant permissions when prompted"
      echo "22. Your OneNote notebooks will be synced to ~/Documents/OneNote-Export"
      echo ""
      echo "TROUBLESHOOTING:"
      echo "==============="
      echo "- If authentication fails, double-check your client ID"
      echo "- If permissions are denied, make sure you granted admin consent"
      echo "- For corporate accounts, use your tenant ID instead of 'common'"
      echo ""
    '';
    executable = true;
  };

  # Desktop entry for OneNote sync
  xdg.desktopEntries.onenote-sync = {
    name = "OneNote Sync";
    exec = "gnome-terminal -- onenote-sync sync";
    icon = "accessories-text-editor";
    comment = "Sync OneNote notebooks to markdown";
    categories = [ "Office" "Network" ];
  };

  # VS Code workspace configuration for OneNote
  home.file.".local/share/onenote-workspace.code-workspace" = {
    text = builtins.toJSON {
      folders = [{
        name = "OneNote Export";
        path = "~/Documents/OneNote-Export";
      }];
      settings = {
        "markdown.preview.enhanced" = true;
        "markdown.extension.toc.enabled" = true;
        "files.associations" = { "*.md" = "markdown"; };
        "search.exclude" = {
          "**/node_modules" = true;
          "**/bower_components" = true;
          "**/.git" = true;
          "**/.DS_Store" = true;
          "**/sync_info.json" = true;
        };
        "markdown.extension.preview.autoShowPreviewToSide" = false;
        "workbench.colorTheme" = "Default Light+";
        "editor.wordWrap" = "on";
        "editor.minimap.enabled" = false;
        "files.defaultLanguage" = "markdown";
        "markdown.preview.breaks" = true;
      };
      extensions = {
        recommendations = [
          "yzhang.markdown-all-in-one"
          "shd101wyy.markdown-preview-enhanced"
          "bierner.markdown-mermaid"
          "davidanson.vscode-markdownlint"
        ];
      };
    };
  };

  # Script to open OneNote workspace in VS Code
  home.file.".local/bin/onenote-vscode" = {
    text = ''
      #!/usr/bin/env bash
      # Open OneNote workspace in VS Code

      WORKSPACE_FILE="$HOME/.local/share/onenote-workspace.code-workspace"
      ONENOTE_DIR="$HOME/Documents/OneNote-Export"

      # Create OneNote directory if it doesn't exist
      mkdir -p "$ONENOTE_DIR"

      # Open VS Code with the OneNote workspace
      if command -v code &> /dev/null; then
        exec code "$WORKSPACE_FILE"
      else
        echo "VS Code not found. Please install it first."
        echo "You can manually open the workspace file: $WORKSPACE_FILE"
      fi
    '';
    executable = true;
  };
}
