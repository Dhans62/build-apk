import requests
import json
import os

# --- MODEL CONSTANTS (PATEN) ---
MODELS = {
    "primary": "gemini-3.0-flash-preview",
    "backup": "gemini-2.5-flash",
    "logic": "deepseek/deepseek-r1", # via OpenRouter
    "speed": "llama-3.3-70b-versatile" # via Groq
}

class AIEngine:
    def __init__(self, system_prompt):
        self.system_prompt = system_prompt
        # Ambil kunci dari environment Termux
        self.google_keys = [k.strip() for k in os.environ.get('GEMINI_KEYS', '').split(',') if k.strip()]
        self.groq_key = os.environ.get('GROQ_KEY', '')
        self.openrouter_key = os.environ.get('OPENROUTER_KEY', '')

    def call_gemini(self, prompt, history):
        """Rotasi Otomatis 5 Akun Google Gemini"""
        if not self.google_keys:
            return None, "ERROR: No Google Keys"

        for i, key in enumerate(self.google_keys):
            # Akun 1 pake Primary, Akun lainnya pake Backup untuk stabilitas
            model_name = MODELS["primary"] if i == 0 else MODELS["backup"]
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={key}"
            
            payload = {
                "contents": history + [{"role": "user", "parts": [{"text": prompt}]}],
                "systemInstruction": {"parts": [{"text": self.system_prompt}]}
            }
            
            try:
                res = requests.post(url, json=payload, timeout=30)
                if res.status_code == 200:
                    return res.json()['candidates'][0]['content']['parts'][0]['text'], model_name
                elif res.status_code == 429:
                    print(f"--- Key {i+1} Limit (429), Mencoba Key Berikutnya... ---")
                    continue
            except:
                continue
        return None, "ALL_GOOGLE_LIMIT"

    def call_groq(self, prompt, history):
        """Speed Debugger (Llama 3.3)"""
        if not self.groq_key: return None, "No Groq Key"
        
        url = "https://api.groq.com/openai/v1/chat/completions"
        headers = {"Authorization": f"Bearer {self.groq_key}", "Content-Type": "application/json"}
        
        # Konversi history format Gemini ke OpenAI format
        messages = [{"role": "system", "content": self.system_prompt}]
        for h in history:
            role = "assistant" if h["role"] == "model" else "user"
            messages.append({"role": role, "content": h["parts"][0]["text"]})
        messages.append({"role": "user", "content": prompt})

        try:
            res = requests.post(url, headers=headers, json={
                "model": MODELS["speed"],
                "messages": messages
            }, timeout=20)
            if res.status_code == 200:
                return res.json()['choices'][0]['message']['content'], MODELS["speed"]
        except: pass
        return None, "GROQ_FAILED"

    def execute_chat(self, prompt, history, mode="auto"):
        """Orchestrator utama untuk memilih model"""
        # 1. Coba Gemini dulu (Sesuai kesepakatan Architect Utama)
        if mode in ["auto", "gemini"]:
            resp, model = self.call_gemini(prompt, history)
            if resp: return resp, model
        
        # 2. Jika Gemini Limit, Lempar ke Groq (Speed)
        if mode == "auto" or mode == "speed":
            resp, model = self.call_groq(prompt, history)
            if resp: return resp, model

        return "Sistem Overload. Semua Provider Limit.", "NONE"
      
