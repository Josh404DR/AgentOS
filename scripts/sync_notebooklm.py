import asyncio
import os
import argparse
import datetime
import hashlib
from pathlib import Path

# Default Configuration
DEFAULT_NOTEBOOK_ID = "79ef4683-f7d2-43da-b8d3-7298858949e5"
DEFAULT_EXPORT_DIR = "E:/AgentOS/exports/notebooklm_v1"
DEFAULT_LOG_DIR = "E:/AgentOS/data/memory/sync_logs"


def build_source_title(export_path, file_rel, mode):
    file_path = export_path / file_rel
    rel_title = Path(file_rel).as_posix()

    if mode == "name":
        return file_path.name

    if mode == "relpath":
        return rel_title

    if mode == "relpath-hash":
        digest = hashlib.sha256(file_path.read_bytes()).hexdigest()[:10]
        return f"{rel_title} [{digest}]"

    if mode == "bundle-hash":
        digest = hashlib.sha256(file_path.read_bytes()).hexdigest()[:12]
        return f"{file_path.stem} [{digest}]"

    raise ValueError(f"Unsupported title mode: {mode}")

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
        "old_versions_deleted": [],
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
    for root, _, files in os.walk(export_path):
        for file in files:
            if file.endswith(".md"):
                rel_path = Path(root).relative_to(export_path) / file
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
        try:
            from notebooklm.client import NotebookLMClient
        except ImportError:
            msg = "NotebookLM package missing. Cannot perform live sync."
            print(msg)
            log_data["errors"].append(msg)
            log_data["final_status"] = "live_sync_failed"
            write_log(log_file, log_data)
            return

        async with NotebookLMClient.from_storage() as client:
            print(f"Fetching existing sources for notebook {args.notebook_id}...")
            existing_sources = await client.sources.list(args.notebook_id)
            existing_titles = {s.title for s in existing_sources}

            for file_rel in log_data["files_discovered"]:
                file_path = export_path / file_rel
                title = build_source_title(export_path, file_rel, args.title_mode)
                
                if title in existing_titles:
                    log_data["files_skipped"].append(title)
                    print(f"Skipping {title} (already exists)")
                    continue

                log_data["files_planned"].append(title)
                print(f"Uploading {title}...")
                try:
                    content = file_path.read_text(encoding="utf-8")
                    uploaded = await client.sources.add_text(
                        args.notebook_id,
                        title,
                        content,
                        wait=True,
                        wait_timeout=180.0,
                    )
                    log_data["files_uploaded"].append(title)
                    print(f"Successfully uploaded {title}")

                    if args.title_mode == "bundle-hash":
                        prefix = f"{file_path.stem} ["
                        old_versions = [
                            source for source in existing_sources
                            if source.title != title and source.title.startswith(prefix)
                        ]
                        for old_source in old_versions:
                            await client.sources.delete(args.notebook_id, old_source.id)
                            log_data["old_versions_deleted"].append(old_source.title)
                            print(f"Deleted old ready version {old_source.title}")
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
    errors_list = [f"- {e}" for e in data['errors']]
    errors_str = "\n".join(errors_list) if errors_list else "None"
    
    content = f"""# NotebookLM Sync Log - {data['run_id']}

- **Timestamp**: {data['timestamp']}
- **Mode**: {data['mode']}
- **Export Dir**: `{data['export_dir']}`
- **Notebook ID**: `{data['notebook_id']}`
- **Discovered**: {len(data['files_discovered'])}
- **Planned**: {len(data['files_planned'])}
- **Uploaded**: {len(data['files_uploaded'])}
- **Skipped**: {len(data['files_skipped'])}
- **Old Ready Versions Deleted**: {len(data['old_versions_deleted'])}
- **Final Status**: `{data['final_status']}`

## Files Discovered
{chr(10).join(['- ' + f for f in data['files_discovered']])}

## Errors
{errors_str}

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
    parser.add_argument(
        "--title-mode",
        choices=["name", "relpath", "relpath-hash", "bundle-hash"],
        default="name",
        help="How source titles are generated. relpath-hash uploads changed files as new versions.",
    )
    
    args = parser.parse_args()
    asyncio.run(sync_files(args))
