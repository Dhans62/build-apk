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
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <style>
        body { 
            background: #050505; 
            color: #cbd5e1; 
            font-family: monospace;
            height: 100dvh; /* Dynamic Viewport Height untuk Mobile */
            display: flex;
            flex-direction: column;
        }
        ::-webkit-scrollbar { width: 3px; }
        ::-webkit-scrollbar-thumb { background: #334155; }
        .terminal-text { text-shadow: 0 0 5px rgba(6, 182, 212, 0.5); }
        #chat-container { scroll-behavior: smooth; }
    </style>
</head>
<body class="p-2 overflow-hidden">
    <div class="border-b border-cyan-900/50 pb-2 mb-2 flex justify-between items-center bg-[#050505]">
        <div class="flex flex-col">
            <span class="text-cyan-500 font-bold text-sm tracking-tighter terminal-text">DS-AI v4.1 ARCHITECT</span>
            <div id="model-tag" class="text-[8px] text-slate-500 uppercase">SYSTEM: IDLE</div>
        </div>
        <button onclick="finalPush()" class="bg-green-600 hover:bg-green-500 text-white text-[10px] px-3 py-1.5 rounded font-bold transition-all active:scale-95">
            PUSH TO GITHUB
        </button>
    </div>

    <div class="flex-1 flex flex-col min-h-0 bg-[#0a0a0a] border border-slate-800 rounded-lg overflow-hidden">
        <div id="chat-container" class="flex-1 overflow-y-auto p-3 space-y-4 text-xs">
            <div class="text-cyan-800 italic border-b border-slate-900 pb-2">--- SESSION STARTED IN TERMUX ---</div>
        </div>

        <div id="status-bar" class="bg-black/50 border-t border-slate-800 px-3 py-1.5 text-[9px] text-amber-500 font-mono h-12 overflow-y-auto">
            <span>READY: Menunggu perintah strategis...</span>
        </div>

        <div class="p-2 bg-slate-900/80 border-t border-slate-700">
            <div class="flex gap-2">
                <input type="text" id="user-input" 
                    placeholder="Ketik perintah (ex: buat file test.dart)..." 
                    class="flex-1 bg-black border-2 border-slate-700 rounded px-3 py-3 text-sm text-cyan-400 focus:outline-none focus:border-cyan-500 placeholder-slate-600">
                <button onclick="send()" id="btn" 
                    class="bg-cyan-600 hover:bg-cyan-500 text-black font-black px-4 rounded transition-all active:scale-90">
                    GO
                </button>
            </div>
        </div>
    </div>

    <script>
        // Masukkan kembali fungsi JavaScript kamu yang tadi di sini
        async function send() {
            const input = document.getElementById('user-input');
            const chat = document.getElementById('chat-container');
            const btn = document.getElementById('btn');
            const statusBar = document.getElementById('status-bar');

            if(!input.value) return;
            const prompt = input.value;
            input.value = ''; 
            btn.disabled = true;
            btn.classList.add('opacity-50');
            
            statusBar.innerHTML = `<span class="animate-pulse text-cyan-400">> ANALYZING: ${prompt}</span>`;
            chat.innerHTML += `<div class="text-right"><span class="bg-slate-800 px-3 py-1.5 rounded-lg inline-block max-w-[80%]">${prompt}</span></div>`;

            try {
                const res = await fetch('/chat', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({prompt: prompt})
                });
                const data = await res.json();

                chat.innerHTML += `<div class="bg-slate-900/40 border-l-2 border-cyan-600 p-3 rounded text-slate-300 leading-relaxed">${data.response}</div>`;
                
                // Terminal Log update
                statusBar.innerHTML = data.actions.map(a => `<div class="text-green-500">> EXECUTE: ${a}</div>`).join('') || "<span>> DONE: Task completed.</span>";
                document.getElementById('model-tag').innerText = "SYSTEM: " + data.model;
                chat.scrollTop = chat.scrollHeight;
                statusBar.scrollTop = statusBar.scrollHeight;
            } catch (e) {
                statusBar.innerHTML = `<span class="text-red-500">> ERROR: Connection failed. Check Termux!</span>`;
            } finally {
                btn.disabled = false;
                btn.classList.remove('opacity-50');
            }
        }

        async function finalPush() {
            if(!confirm("Push kode ke GitHub?")) return;
            const res = await fetch('/commit', {method: 'POST'});
            const data = await res.json();
            alert(data.log);
        }

        // Support Enter Key
        document.getElementById('user-input').addEventListener('keypress', function (e) {
            if (e.key === 'Enter') send();
        });
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
  
