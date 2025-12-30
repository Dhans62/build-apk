import os

def get_current_context(limit=50):
    """
    Fungsi Mata: Memberikan AI pandangan terhadap folder.
    Dioptimalkan untuk menghemat token (TPM).
    """
    files_context = []
    # Daftar folder yang wajib diabaikan agar tidak membakar token
    ignored_dirs = {'.git', 'build', '.dart_tool', '.idea', '__pycache__', 'node_modules'}
    
    for root, dirs, files in os.walk('.'):
        # Filter folder yang diabaikan
        dirs[:] = [d for d in dirs if d not in ignored_dirs]
        
        level = root.replace('.', '').count(os.sep)
        indent = ' ' * 4 * level
        folder_name = os.path.basename(root) or "ROOT"
        
        # Hanya tambahkan folder jika tidak terlalu dalam
        if level < 4:
            files_context.append(f"{indent}[FOLDER] {folder_name}/")
        
        for f in files:
            # Sembunyikan file sampah atau file besar
            if f.endswith(('.png', '.jpg', '.jpeg', '.lock', '.json')) and f != 'package.json':
                continue
            
            if len(files_context) < limit:
                files_context.append(f"{indent}    [FILE] {f}")
            else:
                break
                
    return "\n".join(files_context)

def read_file_content(filename):
    """Membaca file secara aman untuk injeksi context @filename"""
    if os.path.exists(filename) and os.path.isfile(filename):
        try:
            with open(filename, 'r', encoding='utf-8') as f:
                return f.read()
        except Exception as e:
            return f"Error reading file: {str(e)}"
    return "File tidak ditemukan."
  
