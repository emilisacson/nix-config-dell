#!/usr/bin/env python3
"""
Final verification of accessible OneNote notebooks
"""

import json
import msal
import requests
from rich.console import Console
from rich.table import Table
from rich import print

console = Console()

# Configuration
CLIENT_ID = "8a52ee61-c61a-4873-bfc6-489fa574e92c"
SCOPES = [
    "https://graph.microsoft.com/User.Read",
    "https://graph.microsoft.com/Notes.Read.All",
    "https://graph.microsoft.com/Sites.Read.All",
    "https://graph.microsoft.com/Files.Read.All"
]

def get_access_token():
    """Get access token using device code flow"""
    app = msal.PublicClientApplication(
        CLIENT_ID,
        authority="https://login.microsoftonline.com/d8fe6df3-c89e-4fa6-a2f8-cfcc31dffb1c"
    )
    
    # Check if we have a cached token
    accounts = app.get_accounts()
    if accounts:
        print(f"Found cached account: {accounts[0].get('username', 'Unknown')}")
        result = app.acquire_token_silent(SCOPES, account=accounts[0])
        if result:
            print("✅ Using cached token")
            return result['access_token']
    
    # If no cached token, get a new one
    flow = app.initiate_device_flow(scopes=SCOPES)
    if "user_code" not in flow:
        print(f"❌ Failed to initiate device flow: {flow}")
        return None
        
    print(f"Please go to {flow['verification_uri']} and enter code: {flow['user_code']}")
    
    result = app.acquire_token_by_device_flow(flow)
    if "access_token" in result:
        return result["access_token"]
    else:
        print(f"❌ Error: {result.get('error_description', result)}")
        return None

def get_all_notebooks(token):
    """Get all accessible OneNote notebooks"""
    headers = {"Authorization": f"Bearer {token}"}
    notebooks = []
    
    # Method 1: Direct notebooks endpoint
    print("\n📚 Method 1: Direct notebooks endpoint")
    try:
        response = requests.get("https://graph.microsoft.com/v1.0/me/onenote/notebooks", headers=headers)
        if response.status_code == 200:
            data = response.json()
            for notebook in data.get('value', []):
                notebooks.append({
                    'id': notebook['id'],
                    'name': notebook['displayName'],
                    'source': 'direct',
                    'sections': len(notebook.get('sections', [])) if 'sections' in notebook else 'Unknown'
                })
            print(f"Found {len(data.get('value', []))} notebooks via direct endpoint")
        else:
            print(f"❌ Direct endpoint failed: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"❌ Direct endpoint error: {e}")
    
    # Method 2: Search for .one files in drives
    print("\n💾 Method 2: Search drives for .one files")
    try:
        search_url = "https://graph.microsoft.com/v1.0/search/query"
        search_body = {
            "requests": [{
                "entityTypes": ["driveItem"],
                "query": {
                    "queryString": "*.one"
                }
            }]
        }
        
        response = requests.post(search_url, headers=headers, json=search_body)
        if response.status_code == 200:
            data = response.json()
            drive_notebooks = set()
            for result in data.get('value', []):
                for hit in result.get('hitsContainers', []):
                    for item in hit.get('hits', []):
                        resource = item.get('resource', {})
                        if resource.get('name', '').endswith('.one'):
                            drive_notebooks.add(resource.get('name', '').replace('.one', ''))
            
            print(f"Found {len(drive_notebooks)} unique .one files via search")
            for name in sorted(drive_notebooks):
                if not any(nb['name'] == name for nb in notebooks):
                    notebooks.append({
                        'id': 'drive-search',
                        'name': name,
                        'source': 'drive-search',
                        'sections': 'Unknown'
                    })
        else:
            print(f"❌ Drive search failed: {response.status_code}")
    except Exception as e:
        print(f"❌ Drive search error: {e}")
    
    return notebooks

def main():
    print("🔍 Final OneNote Notebook Identification")
    print("=" * 50)
    
    token = get_access_token()
    if not token:
        print("❌ Failed to get access token")
        return
    
    notebooks = get_all_notebooks(token)
    
    # Display results
    print(f"\n📊 Summary: Found {len(notebooks)} accessible notebooks")
    
    table = Table(title="Accessible OneNote Notebooks")
    table.add_column("Name", style="cyan")
    table.add_column("Source", style="green")
    table.add_column("Sections", style="yellow")
    table.add_column("ID", style="dim")
    
    for nb in notebooks:
        table.add_row(
            nb['name'],
            nb['source'],
            str(nb['sections']),
            nb['id'][:20] + "..." if len(nb['id']) > 20 else nb['id']
        )
    
    console.print(table)
    
    # Save results
    with open('accessible_notebooks.json', 'w') as f:
        json.dump(notebooks, f, indent=2)
    
    print(f"\n💾 Results saved to accessible_notebooks.json")
    print(f"📈 Total accessible notebooks: {len(notebooks)}")

if __name__ == "__main__":
    main()
