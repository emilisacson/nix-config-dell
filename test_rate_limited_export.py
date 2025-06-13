#!/usr/bin/env python3
"""
Test Rate-Limited OneNote Export
Specifically test export of the personal notebook that's rate-limited due to >5000 items
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from onenote_exporter import OneNoteExporter

def test_rate_limited_export():
    """Test exporting only the rate-limited personal notebook"""
    print("🧪 Testing Rate-Limited OneNote Export")
    print("=" * 50)
    
    # Create exporter
    exporter = OneNoteExporter(output_dir="./test_rate_limited_export")
    
    # Authenticate
    if not exporter.authenticate():
        print("❌ Authentication failed")
        return False
    
    # Get personal notebooks (should include the rate-limited one)
    print("\n📓 Getting personal notebooks...")
    personal_notebooks = exporter.get_personal_notebooks()
    
    if not personal_notebooks:
        print("❌ No personal notebooks found or all are rate-limited")
        return False
    
    print(f"✅ Found {len(personal_notebooks)} personal notebooks")
    
    # Focus on the first (and likely only) personal notebook
    notebook_info = personal_notebooks[0]
    notebook = notebook_info['notebook']
    notebook_name = notebook.get('displayName', 'Unknown')
    
    print(f"\n🎯 Testing rate-limited notebook: {notebook_name}")
    
    # Try to get notebook structure (this should trigger rate limiting and alternatives)
    structure = exporter.get_notebook_structure(notebook_info)
    
    if structure:
        print(f"✅ Successfully got notebook structure via alternative methods!")
        print(f"   📚 Notebook: {structure['notebook']['displayName']}")
        print(f"   🌐 Site: {structure['site']}")
        print(f"   📁 Sections: {len(structure['sections'])}")
        
        total_pages = sum(len(section['pages']) for section in structure['sections'])
        print(f"   📄 Total pages: {total_pages}")
        
        if total_pages > 0:
            print(f"\n📝 Creating export file...")
            notebook_file = exporter.create_notebook_file(structure)
            print(f"✅ Export successful: {notebook_file}")
            return True
        else:
            print("⚠️  No pages found to export")
            return False
    else:
        print("❌ Failed to access notebook via all methods")
        return False

if __name__ == "__main__":
    success = test_rate_limited_export()
    if success:
        print("\n🎉 Rate-limited export test PASSED!")
        exit(0)
    else:
        print("\n❌ Rate-limited export test FAILED!")
        exit(1)
