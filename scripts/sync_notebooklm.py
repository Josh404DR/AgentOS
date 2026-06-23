import asyncio
import os
import argparse
import datetime
from pathlib import Path
from notebooklm.client import NotebookLMClient

# Default Configuration
DEFAULT_NOTEBOOK_ID = "9af31a16-7984-428a-85ff-2d648d858560"
DEFAULT_EXPORT_DIR = "E:/AgentOS/exports/notebooklm_v1"
DEFAULT_LOG_DIR = "E:/AgentOS/data/memory/sync_logs"

async def sync_files(args):
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H%M%S")
    run_id = f"sync_{timestamp}"
    log_file = Path(args.log_dir) / f"notebooklm_sync_{timestamp}.md"
    os.makedirs(args.log_dir, exist_ok=True)

    export_path = Path(args.export_dir)
    mode = "dry_run" if args.dry_run else "live_sync"
    
    log_data = {
        "run_id": run_id,
        "timestamp": datetime.datetime.now().isoformat(),
        "mode": mode,
        "export_dir": str(export_path),
        "notebook_id": args.notebook_id,
        "files_discovered": [],
        "files_planned": [],
        "files_uploaded": [],
        "files_skipped": [],
        "errors": [],
        "final_status": "in_progress"
    }

    if not export_path.exists():
        msg = f"Export directory {args.export_dir} does not exist."
        print(msg)
        log_data["errors"].append(msg)
        log_data["final_status"] = "failed"
        write_log(log_file, log_data)
        return

    # Find all markdown files
    for root, _, files in os.walk(args.export_dir):
        for file in files:
            if file.endswith(".md"):
                rel_path = Path(root).relative_to(args.export_dir) / file
                log_data["files_discovered"].append(str(rel_path))

    print(f"Discovered {len(log_data['files_discovered'])} markdown files.")

    if args.dry_run:
        log_data["files_planned"] = log_data["files_discovered"]
        log_data["final_status"] = "dry_run_ok"
        print("Dry run completed. No files uploaded.")
        write_log(log_file, log_data)
        return

    # Live Sync Logic
    try:
        async with NotebookLMClient.from_storage() as client:
            print(f"Fetching existing sources for notebook {args.notebook_id}...")
            existing_sources = await client.sources.list(args.notebook_id)
            existing_titles = {s.title for s in existing_sources}

            for file_rel in log_data["files_discovered"]:
                file_path = export_path / file_rel
                title = file_path.name
                
                if title in existing_titles:
                    log_data["files_skipped"].append(title)
                    print(f"Skipping {title} (already exists)")
                    continue

                log_data["files_planned"].append(title)
                print(f"Uploading {title}...")
                try:
                    content = file_path.read_text(encoding="utf-8")
                    await client.sources.add_text(args.notebook_id, title, content)
                    log_data["files_uploaded"].append(title)
                    print(f"Successfully uploaded {title}")
                except Exception as e:
                    err_msg = f"Failed to upload {title}: {e}"
                    log_data["errors"].append(err_msg)
                    print(err_msg)

        if not log_data["errors"]:
            log_data["final_status"] = "live_sync_success"
        elif log_data["files_uploaded"]:
            log_data["final_status"] = "live_sync_partial"
        else:
            log_data["final_status"] = "live_sync_failed"

    except Exception as e:
        log_data["errors"].append(f"Connection error: {e}")
        log_data["final_status"] = "live_sync_failed"
        print(f"Authentication or connection failure: {e}")

    write_log(log_file, log_data)

def write_log(path, data):
    content = f"""# NotebookLM Sync Log - {data['run_id']}

- **Timestamp**: {data['timestamp']}
- **Mode**: {data['mode']}
- **Export Dir**: `{data['export_dir']}`
- **Notebook ID**: `{data['notebook_id']}`
- **Discovered**: {len(data['files_discovered'])}
- **Planned**: {len(data['files_planned'])}
- **Uploaded**: {len(data['files_uploaded'])}
- **Skipped**: {len(data['files_skipped'])}
- **Final Status**: `{data['final_status']}`

## Files Discovered
{chr(10).join(['- ' + f for f in data['files_discovered']])}

## Errors
{chr(10).join(['- ' + e for f in data['errors']]) if data['errors'] else "None"}

---
**Note**: NotebookLM remains retrieval layer; AgentOS files remain source of truth.
"""
    path.write_text(content, encoding="utf-8")
    print(f"Log written to {path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Sync AgentOS files to NotebookLM.")
    parser.add_argument("--dry-run", action="store_true", help="Do not upload, just log discovered files.")
    parser.add_argument("--export-dir", default=DEFAULT_EXPORT_DIR, help="Directory containing markdown files to sync.")
    parser.add_argument("--notebook-id", default=DEFAULT_NOTEBOOK_ID, help="Target NotebookLM notebook ID.")
    parser.add_argument("--log-dir", default=DEFAULT_LOG_DIR, help="Directory to save sync logs.")
    
    args = parser.parse_args()
    asyncio.run(sync_files(args))
