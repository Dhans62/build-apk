import os, json, re, requests, subprocess, shutil
from flask import Flask, render_template_string, request, jsonify

app = Flask(__name__)

# --- CONFIGURATION (STRICTLY 2025 MODELS) ---
PRIMARY_MODEL = "gemini-3.0-flash-preview"
BACKUP_MODEL = "gemini-2.5-flash"
HISTORY_FILE = "ds_history.json"

# System Prompt yang diperkuat untuk Kesadaran Konteks
SYSTEM_PROMPT = """Anda adalah DS-AI v4.1 Architect. 
Tugas: Koding Flutter/Dart dan bahasa lainnya tapi fokusnya untuk saat ini flutter/dart, Manajemen File, dan Debugging.

ATURAN OUTPUT:
1. Setiap jawaban WAJIB dimulai dengan [LOG: alasan tindakan].
2. Gunakan format otonom berikut untuk perubahan file:
   - Menulis: [WRITE_FILE: path] kode [/WRITE_FILE]
   - Menghapus: [REMOVE: path]
   - Folder: [CREATE_FOLDER: path]
4. DILARANG MENGGUNAKAN TABEL MARKDOWN (| --- |).
5. Gunakan DAFTAR BERPOIN (Bullet Points) tanpa Emoji!!!.
6. Gunakan Garis Pembatas (---) antar bagian agar mudah dibaca di layar HP.
Contoh Gaya Laporan:
---
📂 **STATUS FOLDER**
* **lib/**: ✅ Terdeteksi (Ready)
* **assets/**: ⚠️ Ada file tanpa ekstensi
---
distatus folder hanya mengizinkan 2 emoji "✅ dan ⚠️" selain itu tidak boleh dan jika bukan file utama/penting lebih baik tidak usah dikasih emoji hanya teks saja!!

Gunakan 'STRUKTUR FILE SAAT INI' yang dikirim user untuk memvalidasi keberadaan file. 
DILARANG memberikan paragraf panjang. Jadilah singkat, padat, dan teknis.
PENTING: Gunakan 'STRUKTUR FILE SAAT INI' yang diberikan untuk menentukan lokasi file secara akurat. Jangan menghapus ai_gui.py."""
def get_api_keys():
    keys_raw = os.environ.get('GEMINI_KEYS')
    if not keys_raw: return []
    return [k.strip() for k in keys_raw.split(',') if k.strip()]

def get_current_context():
    """Fungsi Mata: Memberikan AI pandangan real-time terhadap folder"""
    files_context = []
    for root, dirs, files in os.walk('.'):
        if '.git' in dirs: dirs.remove('.git')
        if 'build' in dirs: dirs.remove('build')
        
        level = root.replace('.', '').count(os.sep)
        indent = ' ' * 4 * level
        folder_name = os.path.basename(root) or "ROOT"
        files_context.append(f"{indent}[FOLDER] {folder_name}/")
        
        for f in files:
            # Sembunyikan file besar atau tidak relevan agar hemat token
            if f not in [HISTORY_FILE, 'get-pip.py']:
                files_context.append(f"{indent}    [FILE] {f}")
            
    return "\n".join(files_context[:60])

def run_flutter_check(filename):
    if not filename.endswith('.dart'): return True, ""
    try:
        result = subprocess.run(['dart', 'analyze', filename], capture_output=True, text=True)
        if "no issues found" in result.stdout.lower() or result.returncode == 0:
            return True, "Syntax OK"
        return False, result.stdout
    except:
        return True, "Dart SDK not found"
def call_gemini_smart(prompt, history, keys):
    if not keys: return "ERROR: API Keys tidak terdeteksi!", "None"
    
    for i, key in enumerate(keys):
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
                continue
        except Exception:
            continue
    return "Semua API Keys Limit.", "None"

def execute_extended_actions(response_text):
    actions = []
    
    # 1. CREATE FOLDER
    folder_matches = re.findall(r'\[CREATE_FOLDER:\s*(.*?)\]', response_text)
    for folder in folder_matches:
        folder = folder.strip()
        if folder:
            os.makedirs(folder, exist_ok=True)
            actions.append(f"📂 Folder: {folder}")

    # 2. WRITE FILE (FIXED: Handling root path)
    write_matches = re.findall(r'\[WRITE_FILE:\s*(.*?)\](.*?)\[/WRITE_FILE\]', response_text, re.DOTALL)
    for filename, content in write_matches:
        filename = filename.strip()
        dir_name = os.path.dirname(filename)
        if dir_name: # Hanya buat folder jika ada path-nya
            os.makedirs(dir_name, exist_ok=True)
        
        with open(filename, 'w') as f:
            f.write(content.strip())
        
        passed, _ = run_flutter_check(filename)
        actions.append(f"{'✅' if passed else '❌'} Saved: {filename}")

    # 3. RENAME & 4. REMOVE
    rename_matches = re.findall(r'\[RENAME:\s*(.*?)\s*->\s*(.*?)\]', response_text)
    for old, new in rename_matches:
        if os.path.exists(old.strip()):
            os.rename(old.strip(), new.strip())
            actions.append(f"🚚 Moved: {old} -> {new}")

    remove_matches = re.findall(r'\[REMOVE:\s*(.*?)\]', response_text)
    for path in remove_matches:
        path = path.strip()
        if os.path.exists(path) and path != "ai_gui.py": # Proteksi file utama
            if os.path.isdir(path): shutil.rmtree(path)
            else: os.remove(path)
            actions.append(f"🔥 Removed: {path}")
            
    return actions

@app.route('/')
def index():
    return render_template_string("""
<!DOCTYPE html>
<html class="dark">
<head>
    <title>DS-AI v4.1 ARCHITECT</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/themes/prism-tomorrow.min.css">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/prism.min.js"></script>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <style>
        body { background: #050505; color: #cbd5e1; font-family: 'Inter', sans-serif; height: 100dvh; display: flex; flex-direction: column; }
        .markdown-content table { width: 100%; border-collapse: collapse; margin: 15px 0; font-size: 11px; border: 1px solid #1e293b; }
        .markdown-content th { background: #1e293b; color: #22d3ee; padding: 10px; text-align: left; border-bottom: 2px solid #0891b2; }
        .markdown-content td { padding: 10px; border: 1px solid #1e293b; line-height: 1.4; vertical-align: top; }
        .markdown-content tr:nth-child(even) { background: #0f172a; }
        pre { background: #000 !important; padding: 10px; border-radius: 5px; border: 1px solid #334155; overflow-x: auto; }
    </style>
</head>
<body class="p-2 overflow-hidden">
    <div class="border-b border-cyan-900/50 pb-2 mb-2 flex justify-between items-center bg-[#050505]">
        <div class="flex flex-col">
            <span class="text-cyan-500 font-bold text-sm tracking-tighter uppercase">DS-AI v4.1 Architect</span>
            <div id="model-tag" class="text-[8px] text-slate-500 uppercase">SYSTEM: {{ model_used }}</div>
        </div>
        <button onclick="finalPush()" class="bg-green-600 text-white text-[10px] px-3 py-1.5 rounded font-bold active:scale-95">PUSH TO GITHUB</button>
    </div>

    <div class="flex-1 flex flex-col min-h-0 bg-[#0a0a0a] border border-slate-800 rounded-lg">
        <div id="chat-container" class="flex-1 overflow-y-auto p-4 space-y-4 text-[12px]">
            <div class="text-cyan-800 italic border-b border-slate-900 pb-2 text-[10px]">--- SESSION ACTIVE ---</div>
        </div>
        <div id="status-bar" class="bg-black/50 border-t border-slate-800 px-3 py-2 text-[10px] text-amber-500 font-mono h-16 overflow-y-auto italic">
            > Standby...
        </div>
        <div class="p-2 bg-slate-900/80 border-t border-slate-700">
            <div class="flex gap-2">
                <input type="text" id="user-input" placeholder="Ketik perintah..." class="flex-1 bg-black border-2 border-slate-700 rounded px-4 py-3 text-sm text-cyan-400 focus:border-cyan-500 outline-none">
                <button onclick="send()" id="btn" class="bg-cyan-600 text-black font-black px-5 rounded active:scale-90">GO</button>
            </div>
        </div>
    </div>

    <script>
        async function send() {
            const input = document.getElementById('user-input');
            const chat = document.getElementById('chat-container');
            const btn = document.getElementById('btn');
            const status = document.getElementById('status-bar');

            if(!input.value) return;
            const prompt = input.value;
            input.value = ''; btn.disabled = true;
            
            chat.innerHTML += `<div class="text-right"><span class="bg-slate-800 px-4 py-2 rounded-lg inline-block max-w-[85%]">${prompt}</span></div>`;
            status.innerHTML = `<span class="animate-pulse text-cyan-400">> PROCESSING...</span>`;

            try {
                const res = await fetch('/chat', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({prompt: prompt})
                });
                const data = await res.json();
                
                // RENDER MARKDOWN KE HTML
                const rendered = marked.parse(data.response);
                chat.innerHTML += `<div class="bg-slate-900/40 border-l-2 border-cyan-600 p-4 rounded text-slate-300 markdown-content">${rendered}</div>`;
                
                status.innerHTML = data.actions.map(a => `<div class="text-green-400">> ${a}</div>`).join('') || "> Task Finished.";
                Prism.highlightAll();
                chat.scrollTop = chat.scrollHeight;
            } catch (e) {
                status.innerHTML = `<span class="text-red-500">> ERROR CONNECTION</span>`;
            } finally { btn.disabled = false; }
        }

        async function finalPush() {
            if(!confirm("Push to GitHub?")) return;
            const res = await fetch('/commit', {method: 'POST'});
            const data = await res.json(); alert(data.log);
        }
        document.getElementById('user-input').addEventListener('keypress', (e) => { if(e.key === 'Enter') send(); });
    </script>
</body>
</html>
""")
@app.route('/chat', methods=['POST'])
def chat():
    data = request.json
    user_prompt = data.get('prompt')
    keys = get_api_keys()
    
    # --- PROSES AUTO-CONTEXT (MATA AI) ---
    # Memberikan peta folder real-time ke AI
    current_files = get_current_context()
    enhanced_prompt = f"STRUKTUR FILE SAAT INI:\n{current_files}\n\nPERINTAH USER: {user_prompt}"
    
    # Handle Context manual jika user menggunakan tag @filename
    manual_context = ""
    for filename in re.findall(r'@([\w.-]+)', user_prompt):
        if os.path.exists(filename):
            with open(filename, 'r') as f:
                manual_context += f"\n\n[FILE: {filename}]\n{f.read()}"

    # Load History
    if os.path.exists(HISTORY_FILE):
        try:
            with open(HISTORY_FILE, 'r') as f: history = json.load(f)
        except: history = []
    else: history = []

    # Panggil Gemini dengan Enhanced Prompt (Peta Folder + Pesan User)
    response, model_used = call_gemini_smart(enhanced_prompt + manual_context, history, keys)
    
    # Eksekusi Perubahan File/Folder secara Otonom
    actions = execute_extended_actions(response)
    
    # Bersihkan teks dari tag koding agar enak dibaca di Chat
    clean_text = re.sub(r'\[LOG:.*?\]|\[WRITE_FILE:.*?\].*?\[/WRITE_FILE\]|\[REMOVE:.*?\]|\[RENAME:.*?\]|\[CREATE_FOLDER:.*?\]', '', response, flags=re.DOTALL).strip()
    
    # Update History (Dibatasi 10 turn agar tidak lemot/overload token)
    history.append({"role": "user", "parts": [{"text": user_prompt}]})
    history.append({"role": "model", "parts": [{"text": response}]})
    with open(HISTORY_FILE, 'w') as f: json.dump(history[-10:], f)

    return jsonify({
        "response": clean_text, 
        "actions": actions, 
        "model": model_used
    })

@app.route('/commit', methods=['POST'])
def commit():
    """Mengirim hasil koding AI ke GitHub untuk Build APK"""
    try:
        # Pastikan berada di root folder proyek
        subprocess.run(['git', 'add', '.'], check=True)
        # Commit dengan timestamp agar unik
        from datetime import datetime
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        subprocess.run(['git', 'commit', '-m', f'Architectural Update: {now}'], check=True)
        subprocess.run(['git', 'push'], check=True)
        return jsonify({"success": True, "log": "🚀 PUSH BERHASIL: GitHub Actions mulai membangun APK."})
    except Exception as e:
        return jsonify({"success": False, "log": f"❌ GAGAL PUSH: {str(e)}"})

if __name__ == '__main__':
    # Inisialisasi file history jika belum ada
    if not os.path.exists(HISTORY_FILE):
        with open(HISTORY_FILE, 'w') as f: json.dump([], f)
    
    print("--- DS-AI v4.1 ARCHITECT SEDANG BERJALAN ---")
    print("Akses GUI di: http://localhost:5000")
    # Jalankan server
    app.run(host='0.0.0.0', port=5000, debug=False)
