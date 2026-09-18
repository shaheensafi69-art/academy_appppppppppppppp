import os
import json

base_dir = "/Users/Safi_Sahib/safi_academy_app/lib/l10n"
template_path = os.path.join(base_dir, "app_en.arb")

with open(template_path, "r", encoding="utf-8") as f:
    template_data = json.load(f)

new_locales = {
    "es": "Spanish",
    "zh": "Chinese",
    "hi": "Hindi",
    "it": "Italian",
    "pt": "Portuguese",
    "ja": "Japanese",
    "ko": "Korean",
    "nl": "Dutch",
    "uz": "Uzbek",
    "id": "Indonesian"
}

# Some basic localized keywords for common UI items
quick_translations = {
    "es": {"welcome": "Bienvenido", "login": "Iniciar sesión", "register": "Registrarse", "appName": "Safi Academy", "save": "Guardar", "cancel": "Cancelar"},
    "zh": {"welcome": "欢迎", "login": "登录", "register": "注册", "appName": "Safi Academy", "save": "保存", "cancel": "取消"},
    "hi": {"welcome": "स्वागत है", "login": "लॉग इन करें", "register": "रजिस्टर करें", "appName": "Safi Academy", "save": "सहेजें", "cancel": "रद्द करें"},
    "it": {"welcome": "Benvenuto", "login": "Accedi", "register": "Registrati", "appName": "Safi Academy", "save": "Salva", "cancel": "Annulla"},
    "pt": {"welcome": "Bem-vindo", "login": "Entrar", "register": "Registar", "appName": "Safi Academy", "save": "Guardar", "cancel": "Cancelar"},
    "ja": {"welcome": "ようこそ", "login": "ログイン", "register": "新規登録", "appName": "Safi Academy", "save": "保存", "cancel": "キャンセル"},
    "ko": {"welcome": "환영합니다", "login": "로그인", "register": "회원가입", "appName": "Safi Academy", "save": "저장", "cancel": "취소"},
    "nl": {"welcome": "Welkom", "login": "Inloggen", "register": "Registreren", "appName": "Safi Academy", "save": "Opslaan", "cancel": "Annuleren"},
    "uz": {"welcome": "Xush kelibsiz", "login": "Kirish", "register": "Ro'yxatdan o'tish", "appName": "Safi Academy", "save": "Saqlash", "cancel": "Bekor qilish"},
    "id": {"welcome": "Selamat Datang", "login": "Masuk", "register": "Daftar", "appName": "Safi Academy", "save": "Simpan", "cancel": "Batal"}
}

for loc, lang_name in new_locales.items():
    loc_data = dict(template_data)
    loc_data["@@locale"] = loc
    if loc in quick_translations:
        for k, v in quick_translations[loc].items():
            if k in loc_data:
                loc_data[k] = v
    out_path = os.path.join(base_dir, f"app_{loc}.arb")
    with open(out_path, "w", encoding="utf-8") as out_f:
        json.dump(loc_data, out_f, ensure_ascii=False, indent=2)
    print(f"Generated app_{loc}.arb successfully")
