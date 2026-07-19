import os
from pathlib import Path
from tkinter import filedialog, Tk

# ==========================================
# FILE TYPE & COMMENT SYNTAX LIBRARY
# ==========================================
COMMENT_REGISTRY = {
    '.py': '# {}', '.sh': '# {}', '.pl': '# {}', '.rb': '# {}', 
    '.yaml': '# {}', '.yml': '# {}', '.r': '# {}', '.cfg': '# {}', '.ini': '# {}',
    '.js': '// {}', '.ts': '// {}', '.jsx': '// {}', '.tsx': '// {}',
    '.java': '// {}', '.c': '// {}', '.cpp': '// {}', '.h': '// {}', 
    '.cs': '// {}', '.go': '// {}', '.rs': '// {}', '.swift': '// {}',
    '.kt': '// {}', '.scala': '// {}', '.css': '// {}',
    '.html': '', '.htm': '', '.xml': '', '.svg': '',
    '.sql': '-- {}', '.tex': '% {}', '.bat': 'REM {}', '.cmd': 'REM {}'
}

# ==========================================
# IGNORE LIBRARY (Files and Folders)
# ==========================================
IGNORE_FOLDERS = {
    'venv', '.venv', 'env', '.env', 'node_modules', '.git', '.github', 
    '__pycache__', '.pytest_cache', '.idea', '.vscode', 'build', 'dist'
}

IGNORE_FILES = {
    '.ds_store', 'thumbs.db', '.gitignore', 'package-lock.json', 'yarn.lock'
}

def get_comment_line(extension, text):
    """Looks up the correct comment syntax for a given file extension."""
    fmt = COMMENT_REGISTRY.get(extension.lower(), '# {}')
    return fmt.format(text) + '\n'

def setup_gui():
    root = Tk()
    root.withdraw()
    root.attributes('-topmost', True)
    return root

def get_user_inputs():
    setup_gui()
    
    # 1. Get extensions
    ext_input = input("Enter file extensions to copy (separated by commas, e.g., py, js): ")
    extensions = {f".{ext.strip().lower().lstrip('.')}" for ext in ext_input.split(",") if ext.strip()}
    if not extensions:
        print("No valid extensions entered. Exiting.")
        return None, None, None, None

    # 2. Get Source Folder (Defaults to current directory)
    print(f"\nSelect SOURCE folder [Press ENTER to default to current directory '{Path.cwd()}']...")
    source_dir = filedialog.askdirectory(title="Select Source Folder", initialdir=os.getcwd())
    source_path = Path(source_dir) if source_dir else Path.cwd()
    print(f"-> Source set to: {source_path}")

    # 3. Get Whitelisted Folders
    print("\n--- Whitelisted Folders Options ---")
    print("Specify subfolders to scan (separated by commas, e.g., src, utils, tests/unit).")
    whitelist_input = input("Whitelisted paths [Press ENTER to scan entire folder recursively]: ")
    
    whitelist_paths = []
    if whitelist_input.strip():
        # Build clean absolute paths for the whitelisted locations
        for p in whitelist_input.split(","):
            clean_p = p.strip().lstrip("./")  # clean up any user raw syntax typing
            if clean_p:
                whitelist_paths.append(source_path / clean_p)
        print(f"-> Restricting scan to {len(whitelist_paths)} specific subfolder(s).")
    else:
        print("-> No whitelist specified. Defaulting to full recursive scan.")

    # 4. Get Destination Folder
    print("\nPlease select the OUTSIDE DESTINATION folder where files will be copied...")
    dest_dir = filedialog.askdirectory(title="Select Destination Folder")
    if not dest_dir:
        print("Destination selection cancelled. Exiting.")
        return None, None, None, None
    
    dest_path = Path(dest_dir)
    if source_path == dest_path or any(dest_path == wp for wp in whitelist_paths):
        print("Error: Destination folder cannot be inside the source or whitelist areas.")
        return None, None, None, None

    return extensions, source_path, whitelist_paths, dest_path

def process_directory(scan_root, source_path, extensions, dest_path, collision_counters):
    """Scans a specific directory tree and copies valid files."""
    success_count = 0
    
    for current_dir, dirnames, files in os.walk(scan_root):
        # Modify dirnames in-place to drop ignored environments entirely
        dirnames[:] = [d for d in dirnames if d.lower() not in IGNORE_FOLDERS]
        
        for file in files:
            if file.lower() in IGNORE_FILES:
                continue
                
            file_path = Path(current_dir) / file
            ext = file_path.suffix.lower()
            
            if ext in extensions:
                # Always track the path relative to the primary root source folder
                relative_path = file_path.relative_to(source_path)
                
                # Double-check to ensure we aren't scanning inside the destination folder itself
                if dest_path in file_path.parents or file_path == dest_path:
                    continue

                # Handle filename collisions in flat destination directory
                dest_file_name = file
                if (dest_path / dest_file_name).exists():
                    collision_counters[file] = collision_counters.get(file, 0) + 1
                    dest_file_name = f"{file_path.stem}_{collision_counters[file]}{ext}"
                
                target_file_path = dest_path / dest_file_name
                
                try:
                    content = file_path.read_text(encoding='utf-8', errors='ignore')
                    comment_text = f"Original relative path: {relative_path}"
                    comment_line = get_comment_line(ext, comment_text)
                    
                    target_file_path.write_text(comment_line + content, encoding='utf-8')
                    print(f"Copied: {relative_path} -> {dest_file_name}")
                    success_count += 1
                    
                except Exception as e:
                    print(f"Failed to copy {relative_path}. Error: {e}")
                    
    return success_count

def copy_and_comment_files():
    inputs = get_user_inputs()
    if not inputs or not inputs[0]:
        return
    extensions, source_path, whitelist_paths, dest_path = inputs

    print("\nScanning and copying files...")
    total_copied = 0
    collision_counters = {}

    # Execution branches depending on whether whitelist directories were provided
    if whitelist_paths:
        for target_folder in whitelist_paths:
            if target_folder.exists() and target_folder.is_dir():
                print(f"\n--- Scanning Whitelisted Folder: {target_folder.relative_to(source_path)} ---")
                total_copied += process_directory(target_folder, source_path, extensions, dest_path, collision_counters)
            else:
                print(f"\n[Warning] Whitelisted path skipped (does not exist): {target_folder}")
    else:
        # Full scan from the base source folder
        total_copied += process_directory(source_path, source_path, extensions, dest_path, collision_counters)

    print(f"\nTask complete! Successfully copied {total_copied} files to '{dest_path}'.")

if __name__ == "__main__":
    copy_and_comment_files()