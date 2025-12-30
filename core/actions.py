import os
import re
import shutil
from core.utils import run_flutter_check

def execute_extended_actions(response_text):
    """
    Mesin Otonom: Membedah tag dari AI dan mengeksekusinya ke sistem file.
    Dilengkapi dengan safety guard untuk file inti.
    """
    actions = []
    
    # 1. CREATE FOLDER
    folder_matches = re.findall(r'\[CREATE_FOLDER:\s*(.*?)\]', response_text)
    for folder in folder_matches:
        folder = folder.strip()
        if folder:
            os.makedirs(folder, exist_ok=True)
            actions.append(f"📂 Folder: {folder}")

    # 2. WRITE FILE (Logic: Auto-create path if not exists)
    write_matches = re.findall(r'\[WRITE_FILE:\s*(.*?)\](.*?)\[/WRITE_FILE\]', response_text, re.DOTALL)
    for filename, content in write_matches:
        filename = filename.strip()
        
        # Safety Guard: Jangan biarkan AI menimpa file config utama lewat chat biasa
        if filename in ['ai_gui.py', '.env']:
            actions.append(f"🛡️ Protected: {filename} (Denied)")
            continue
            
        dir_name = os.path.dirname(filename)
        if dir_name:
            os.makedirs(dir_name, exist_ok=True)
        
        with open(filename, 'w', encoding='utf-8') as f:
            f.write(content.strip())
        
        # Jalankan validasi sintaks setelah menulis
        passed, msg = run_flutter_check(filename)
        actions.append(f"{'✅' if passed else '❌'} Saved: {filename} ({msg})")

    # 3. RENAME / MOVE
    rename_matches = re.findall(r'\[RENAME:\s*(.*?)\s*->\s*(.*?)\]', response_text)
    for old, new in rename_matches:
        old, new = old.strip(), new.strip()
        if os.path.exists(old):
            os.rename(old, new)
            actions.append(f"🚚 Moved: {old} -> {new}")

    # 4. REMOVE (Safety: Prevent accidental total wipeout)
    remove_matches = re.findall(r'\[REMOVE:\s*(.*?)\]', response_text)
    for path in remove_matches:
        path = path.strip()
        protected = ['ai_gui.py', 'core', 'ds_history.json']
        if os.path.exists(path) and path not in protected:
            if os.path.isdir(path):
                shutil.rmtree(path)
            else:
                os.remove(path)
            actions.append(f"🔥 Removed: {path}")
            
    return actions
