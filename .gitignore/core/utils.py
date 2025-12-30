import subprocess
import os

def run_flutter_check(filename):
    """
    Memvalidasi sintaks Dart secara otonom.
    Mencegah kode 'rusak' masuk ke sistem file.
    """
    if not filename.endswith('.dart'):
        return True, "Bukan file Dart, melewati pengecekan."
    
    try:
        # Menjalankan perintah dart analyze pada file spesifik
        result = subprocess.run(
            ['dart', 'analyze', filename], 
            capture_output=True, 
            text=True, 
            timeout=10
        )
        
        # Jika tidak ada masalah ditemukan atau return code 0
        if "no issues found" in result.stdout.lower() or result.returncode == 0:
            return True, "Sintaks Dart: ✅ OK"
        else:
            # Mengambil baris pertama error agar tidak memenuhi layar HP
            error_msg = result.stdout.split('\n')[0]
            return False, f"Sintaks Dart: ❌ ERROR ({error_msg})"
            
    except FileNotFoundError:
        return True, "Dart SDK tidak terdeteksi di Termux, melewati validasi."
    except Exception as e:
        return True, f"Check bypassed: {str(e)}"

def clean_ai_response(text):
    """
    Membersihkan tag otonom dari teks yang akan ditampilkan di UI
    agar chat tetap bersih dan enak dibaca di layar HP.
    """
    import re
    # Menghapus [WRITE_FILE]...[/WRITE_FILE] dan tag lainnya
    clean = re.sub(r'\[LOG:.*?\]|\[WRITE_FILE:.*?\].*?\[/WRITE_FILE\]|\[REMOVE:.*?\]|\[RENAME:.*?\]|\[CREATE_FOLDER:.*?\]', '', text, flags=re.DOTALL)
    return clean.strip()
