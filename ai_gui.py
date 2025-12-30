import os, json, re, subprocess
from flask import Flask, render_template_string, request, jsonify
from core.engine import AIEngine
from core.actions import execute_extended_actions
from core.context import get_current_context
from core.utils import clean_ai_response

app = Flask(__name__)

HISTORY_FILE = "ds_history.json"
SYSTEM_PROMPT = """Anda adalah DS-AI v4.1 Architect. 
Tugas: Koding Flutter/Dart fokus utama, Manajemen File, dan Debugging.

ATURAN OUTPUT:
1. Setiap jawaban WAJIB dimulai dengan [LOG: alasan tindakan].
2. Gunakan format otonom:
   - Menulis: [WRITE_FILE: path] kode [/WRITE_FILE]
   - Menghapus: [REMOVE: path]
   - Folder: [CREATE_FOLDER: path]
3. DILARANG MENGGUNAKAN TABEL MARKDOWN. Gunakan Bullet Points tanpa Emoji.
4. Gunakan Garis Pembatas (---) antar bagian.
5. Status folder hanya 2 emoji: ✅ (Ready) dan ⚠️ (Warning).

PENTING: Gunakan 'STRUKTUR FILE SAAT INI' untuk akurasi lokasi file."""

engine = AIEngine(SYSTEM_PROMPT)

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
        pre { background: #000 !important; padding: 10px; border-radius: 5px; border: 1px solid #334155; overflow-x: auto; font-size: 10px; }
        .markdown-content ul { list-style-type: disc; margin-left: 20px; }
    </style>
</head>
<body class="p-2 overflow-hidden">
    <div class="border-b border-cyan-900/50 pb-2 mb-2 flex justify-between items-center bg-[#050505]">
        <div class="flex flex-col">
            <span class="text-cyan-500 font-bold text-sm tracking-tighter uppercase">DS-AI v4.1 Architect</span>
            <select id="model-select" class="bg-black text-[10px] text-cyan-400 border border-cyan-900 rounded px-1 outline-none">
                <option value="auto">MODE: AUTO FAILOVER</option>
                <option value="gemini">MODE: GEMINI ONLY</option>
                <option value="speed">MODE: LLAMA (SPEED)</option>
            </select>
        </div>
        <button onclick="finalPush()" class="bg-green-600 text-white text-[10px] px-3 py-1.5 rounded font-bold active:scale-95">PUSH TO GITHUB</button>
    </div>

    <div class="flex-1 flex flex-col min-h-0 bg-[#0a0a0a] border border-slate-800 rounded-lg">
        <div id="chat-container" class="flex-1 overflow-y-auto p-4 space-y-4 text-[12px]">
            <div class="text-cyan-800 italic border-b border-slate-900 pb-2 text-[10px]">--- ENGINE READY | MULTI-ACCOUNT ACTIVE ---</div>
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
            const mode = document.getElementById('model-select').value;

            if(!input.value) return;
            const prompt = input.value;
            input.value = ''; btn.disabled = true;
            
            chat.innerHTML += `<div class="text-right"><span class="bg-slate-800 px-4 py-2 rounded-lg inline-block max-w-[85%]">${prompt}</span></div>`;
            status.innerHTML = `<span class="animate-pulse text-cyan-400">> AI IS THINKING (${mode})...</span>`;

            try {
                const res = await fetch('/chat', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({prompt: prompt, mode: mode})
                });
                const data = await res.json();
                
                const rendered = marked.parse(data.response);
                chat.innerHTML += `<div><div class="text-[8px] text-slate-500 mb-1">MODEL: ${data.model}</div><div class="bg-slate-900/40 border-l-2 border-cyan-600 p-4 rounded text-slate-300 markdown-content">${rendered}</div></div>`;
                
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
    mode = data.get('mode', 'auto')
    
    # 1. Get Context
    current_files = get_current_context()
    enhanced_prompt = f"STRUKTUR FILE SAAT INI:\n{current_files}\n\nPERINTAH USER: {user_prompt}"

    # 2. Load History
    if os.path.exists(HISTORY_FILE):
        try:
            with open(HISTORY_FILE, 'r') as f: history = json.load(f)
        except: history = []
    else: history = []

    # 3. Call Brain Engine (Multi-Model & Multi-Account)
    response, model_used = engine.execute_chat(enhanced_prompt, history, mode=mode)
    
    # 4. Execute Actions
    actions = execute_extended_actions(response)
    
    # 5. UI Cleanup
    clean_text = clean_ai_response(response)
    
    # 6. Update History
    history.append({"role": "user", "parts": [{"text": user_prompt}]})
    history.append({"role": "model", "parts": [{"text": response}]})
    with open(HISTORY_FILE, 'w') as f: json.dump(history[-8:], f)

    return jsonify({"response": clean_text, "actions": actions, "model": model_used})

@app.route('/commit', methods=['POST'])
def commit():
    try:
        subprocess.run(['git', 'add', '.'], check=True)
        subprocess.run(['git', 'commit', '-m', 'DS-AI Architectural Update'], check=True)
        subprocess.run(['git', 'push'], check=True)
        return jsonify({"success": True, "log": "🚀 PUSH BERHASIL"})
    except Exception as e:
        return jsonify({"success": False, "log": f"❌ GAGAL: {str(e)}"})

if __name__ == '__main__':
    if not os.path.exists(HISTORY_FILE):
        with open(HISTORY_FILE, 'w') as f: json.dump([], f)
    app.run(host='0.0.0.0', port=5000)
  
