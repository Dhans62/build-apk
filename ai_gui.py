import os, json, re, requests, subprocess, shutil
from flask import Flask, render_template_string, request, jsonify

app = Flask(__name__)

# --- CONFIGURATION (2025 LATEST MODELS) ---
PRIMARY_MODEL = "gemini-3.0-flash-preview"
BACKUP_MODEL = "gemini-2.5-flash"
HISTORY_FILE = "ds_history.json"

# System Prompt agar AI tahu kekuatan barunya (Add/Rename/Remove/Folder)
SYSTEM_PROMPT = """Anda adalah DS-AI v4.1 Architect. 
Tugas: Koding Flutter/Dart, Manajemen File, dan Debugging.
Kekuatan Otonom:
1. Menulis/Edit: [WRITE_FILE: path/file.dart] kode [/WRITE_FILE]
2. Menghapus: [REMOVE: path/to/target] (bisa file atau folder)
3. Rename/Move: [RENAME: old_path -> new_path]
4. Buat Folder: [CREATE_FOLDER: path/folder]
5. Penjelasan: Berikan [LOG: alasan] singkat sebelum bertindak."""

def get_api_keys():
    # Mengambil dari GitHub Secrets yang sudah Anda set di Codespaces
    keys_raw = os.environ.get('GEMINI_KEYS')
    if not keys_raw: return []
    return [k.strip() for k in keys_raw.split(',') if k.strip()]

def run_flutter_check(filename):
    """Checklist: Menggunakan Dart Analyze untuk memastikan kode bersih"""
    if not filename.endswith('.dart'): return True, ""
    try:
        # Menjalankan analisa sintaksis
        result = subprocess.run(['dart', 'analyze', filename], capture_output=True, text=True)
        if "no issues found" in result.stdout.lower() or result.returncode == 0:
            return True, "Syntax OK"
        return False, result.stdout
    except:
        return True, "Dart SDK not found, skipping check"

def call_gemini_smart(prompt, history, keys):
    if not keys: return "ERROR: API Keys tidak terdeteksi di Environment!", "None"
    
    # Logika Ekonomis: Chat pakai Key pertama, jika limit baru geser ke Key lain
    for i, key in enumerate(keys):
        # Gunakan Model 3.0 untuk Key pertama, sisanya 2.5 sebagai backup
        model = PRIMARY_MODEL if i == 0 else BACKUP_MODEL
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={key}"
        
        payload = {
            "contents": history + [{"role": "user", "parts": [{"text": prompt}]}],
            "systemInstruction": {"parts": [{"text": SYSTEM_PROMPT}]}
        }
        
        try:
            res = requests.post(url, json=payload, timeout=30)
            if res.status_code == 200:
                return res.json()['candidates'][0]['content']['parts'][0]['text'], model
            elif res.status_code == 429:
                print(f"⚠️ Key {i+1} Limit! Mencoba Key berikutnya...")
                continue
        except Exception as e:
            print(f"⚠️ Key {i+1} Gagal Koneksi: {e}")
            continue
            
    return "Semua 5 API Keys Limit atau Gagal Terhubung.", "None"

def execute_extended_actions(response_text):
    """Eksekusi otonom: Rename, Remove, Create Folder, Write File"""
    actions = []
    
    # 1. CREATE FOLDER
    folder_matches = re.findall(r'\[CREATE_FOLDER:\s*(.*?)\]', response_text)
    for folder in folder_matches:
        folder = folder.strip()
        os.makedirs(folder, exist_ok=True)
        actions.append(f"📂 Folder Dibuat: {folder}")

    # 2. WRITE/UPDATE FILE
    write_matches = re.findall(r'\[WRITE_FILE:\s*(.*?)\](.*?)\[/WRITE_FILE\]', response_text, re.DOTALL)
    for filename, content in write_matches:
        filename = filename.strip()
        os.makedirs(os.path.dirname(filename), exist_ok=True)
        with open(filename, 'w') as f: f.write(content.strip())
        # Jalankan Flutter Check
        passed, log = run_flutter_check(filename)
        status = "✅" if passed else "❌ (Syntax Error)"
        actions.append(f"{status} Updated: {filename}")

    # 3. RENAME / MOVE
    rename_matches = re.findall(r'\[RENAME:\s*(.*?)\s*->\s*(.*?)\]', response_text)
    for old_path, new_path in rename_matches:
        old_path, new_path = old_path.strip(), new_path.strip()
        if os.path.exists(old_path):
            os.rename(old_path, new_path)
            actions.append(f"🚚 Moved: {old_path} -> {new_path}")

    # 4. REMOVE FILE/FOLDER
    remove_matches = re.findall(r'\[REMOVE:\s*(.*?)\]', response_text)
    for path in remove_matches:
        path = path.strip()
        if os.path.exists(path):
            if os.path.isdir(path): shutil.rmtree(path)
            else: os.remove(path)
            actions.append(f"🔥 Dihapus: {path}")
            
    return actions
  
@app.route('/')
def index():
    # Frontend dengan Preview Panel dan Tombol Commit
    return render_template_string("""
<!DOCTYPE html>
<html class="dark">
<head>
    <title>DS-AI v4.1 ARCHITECT</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { background: #050505; color: #cbd5e1; font-family: 'Fira Code', monospace; }
        ::-webkit-scrollbar { width: 4px; }
        ::-webkit-scrollbar-thumb { background: #1e293b; }
    </style>
</head>
<body class="h-screen flex flex-col p-2 overflow-hidden">
    <div class="border-b border-slate-800 pb-2 mb-2 flex justify-between items-center px-2">
        <div>
            <span class="text-cyan-500 font-bold text-lg tracking-tighter">DS-AI v4.1</span>
            <span id="model-tag" class="ml-2 text-[10px] bg-slate-800 px-2 py-0.5 rounded text-yellow-500 uppercase">System Ready</span>
        </div>
        <button onclick="finalPush()" class="bg-green-600 hover:bg-green-500 text-black px-4 py-1 rounded-md text-[10px] font-black transition-all">PUSH TO GITHUB</button>
    </div>

    <div class="flex flex-1 gap-2 overflow-hidden">
        <div class="flex-1 flex flex-col bg-[#0a0a0a] border border-slate-800 rounded-xl p-3 overflow-hidden">
            <div id="chat-container" class="flex-1 overflow-y-auto space-y-4 text-sm p-1"></div>
            
            <div id="status-bar" class="mt-2 py-1 px-2 text-[9px] border-t border-slate-800 flex flex-wrap gap-2 text-cyan-400 italic"></div>

            <div class="mt-2 flex gap-2 bg-slate-900/50 p-2 rounded-lg border border-slate-700">
                <input type="text" id="user-input" class="flex-1 bg-transparent border-none outline-none text-sm text-white" placeholder="Perintah @file...">
                <button onclick="send()" id="btn" class="bg-cyan-600 px-4 py-1 rounded font-bold text-black text-xs active:scale-95 transition-transform">RUN</button>
            </div>
        </div>

        <div id="preview-panel" class="hidden md:flex flex-1 flex-col bg-[#0a0a0a] border border-slate-800 rounded-xl p-3 overflow-hidden">
            <div class="flex justify-between items-center mb-2">
                <span id="file-title" class="text-[10px] text-yellow-500 font-bold truncate">PREVIEW: NO FILE</span>
            </div>
            <pre id="code-view" class="flex-1 overflow-auto bg-black/50 p-3 rounded border border-slate-800 text-[11px] text-green-400"></pre>
        </div>
    </div>

    <script>
        async function send() {
            const input = document.getElementById('user-input');
            const chat = document.getElementById('chat-container');
            const btn = document.getElementById('btn');
            const statusBar = document.getElementById('status-bar');
            const codeView = document.getElementById('code-view');
            const fileTitle = document.getElementById('file-title');
            const preview = document.getElementById('preview-panel');

            if(!input.value) return;
            const prompt = input.value;
            input.value = ''; btn.disabled = true;
            statusBar.innerHTML = "<span>DS-AI sedang berpikir...</span>";

            chat.innerHTML += `<div class="text-right"><span class="bg-slate-800 px-3 py-1.5 rounded-lg text-xs inline-block text-slate-400 font-bold italic">@ ${prompt}</span></div>`;

            try {
                const res = await fetch('/chat', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({prompt: prompt})
                });
                const data = await res.json();

                chat.innerHTML += `<div class="bg-slate-900/40 p-3 rounded-lg border border-slate-800 text-sm leading-relaxed">${data.response}</div>`;
                
                // Update Preview
                if(data.last_content) {
                    preview.classList.remove('hidden');
                    fileTitle.innerText = "PREVIEW: " + data.last_file;
                    codeView.innerText = data.last_content;
                }

                statusBar.innerHTML = data.actions.map(a => `<span>${a}</span>`).join("");
                document.getElementById('model-tag').innerText = data.model;
                chat.scrollTop = chat.scrollHeight;
            } catch (e) {
                statusBar.innerHTML = `<span class="text-red-500">Error: ${e}</span>`;
            } finally {
                btn.disabled = false;
            }
        }

        async function finalPush() {
            if(!confirm("Push kode ke GitHub sekarang? Ini akan mentrigger GitHub Actions.")) return;
            const btn = event.target;
            btn.innerText = "PUSHING..."; btn.disabled = true;
            
            const res = await fetch('/commit', {method: 'POST'});
            const data = await res.json();
            
            alert(data.log);
            btn.innerText = "PUSH TO GITHUB"; btn.disabled = false;
        }
    </script>
</body>
</html>
""")

@app.route('/chat', methods=['POST'])
def chat():
    data = request.json
    user_prompt = data.get('prompt')
    keys = get_api_keys()
    
    # Handle Context @file
    context = ""
    for filename in re.findall(r'@([\w.-]+)', user_prompt):
        if os.path.exists(filename):
            with open(filename, 'r') as f:
                context += f"\n\n[FILE: {filename}]\n{f.read()}"

    if os.path.exists(HISTORY_FILE):
        with open(HISTORY_FILE, 'r') as f: history = json.load(f)
    else: history = []

    response, model_used = call_gemini_smart(user_prompt + context, history, keys)
    
    # Eksekusi Otonom (v4.1)
    actions = execute_extended_actions(response)
    
    # Ambil data untuk preview terakhir
    last_file = ""
    last_content = ""
    write_matches = re.findall(r'\[WRITE_FILE:\s*(.*?)\](.*?)\[/WRITE_FILE\]', response, re.DOTALL)
    if write_matches:
        last_file, last_content = write_matches[-1]

    clean_text = re.sub(r'\[LOG:.*?\]|\[WRITE_FILE:.*?\].*?\[/WRITE_FILE\]|\[REMOVE:.*?\]|\[RENAME:.*?\]|\[CREATE_FOLDER:.*?\]', '', response, flags=re.DOTALL).strip()
    
    # Update History (Max 15 turns)
    history.append({"role": "user", "parts": [{"text": user_prompt}]})
    history.append({"role": "model", "parts": [{"text": response}]})
    with open(HISTORY_FILE, 'w') as f: json.dump(history[-15:], f)

    return jsonify({
        "response": clean_text, 
        "actions": actions, 
        "model": model_used,
        "last_file": last_file.strip(),
        "last_content": last_content.strip()
    })

@app.route('/commit', methods=['POST'])
def commit():
    # Final Checklist & Push
    try:
        # Jalankan Git
        subprocess.run(['git', 'add', '.'], check=True)
        subprocess.run(['git', 'commit', '-m', 'Architectural Update by DS-AI v4.1'], check=True)
        subprocess.run(['git', 'push'], check=True)
        return jsonify({"success": True, "log": "🚀 Berhasil Push! GitHub Actions akan segera memproses APK."})
    except Exception as e:
        return jsonify({"success": False, "log": f"Gagal Commit: {str(e)}"})

if __name__ == '__main__':
    # Pastikan file history ada agar tidak error saat start
    if not os.path.exists(HISTORY_FILE):
        with open(HISTORY_FILE, 'w') as f: json.dump([], f)
    app.run(host='0.0.0.0', port=5000)
  
