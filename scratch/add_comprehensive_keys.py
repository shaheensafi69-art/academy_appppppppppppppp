import json
import os
import subprocess

l10n_dir = "/Users/Safi_Sahib/safi_academy_app/lib/l10n"

keys_data = {
    "classes": {
        "en": "Classes",
        "fa": "کلاس‌ها",
        "ps": "ټولګي",
        "de": "Klassen",
        "fr": "Classes",
        "ur": "کلاسز",
        "tr": "Sınıflar",
        "ru": "Классы",
        "ar": "الفصول"
    },
    "students": {
        "en": "Students",
        "fa": "دانشجویان",
        "ps": "زده کوونکي",
        "de": "Studenten",
        "fr": "Étudiants",
        "ur": "طلباء",
        "tr": "Öğrenciler",
        "ru": "Студенты",
        "ar": "الطلاب"
    },
    "courseTitle": {
        "en": "Course Title",
        "fa": "عنوان دوره",
        "ps": "د کورس سرلیک",
        "de": "Kurstitel",
        "fr": "Titre du cours",
        "ur": "کورس کا عنوان",
        "tr": "Kurs Başlığı",
        "ru": "Название курса",
        "ar": "عنوان الدورة"
    },
    "courseDescription": {
        "en": "Course Description",
        "fa": "توضیحات دوره",
        "ps": "د کورس تفصیل",
        "de": "Kursbeschreibung",
        "fr": "Description du cours",
        "ur": "کورس کی تفصیل",
        "tr": "Kurs Açıklaması",
        "ru": "Описание курса",
        "ar": "وصف الدورة"
    },
    "price": {
        "en": "Price",
        "fa": "قیمت",
        "ps": "بیه",
        "de": "Preis",
        "fr": "Prix",
        "ur": "قیمت",
        "tr": "Fiyat",
        "ru": "Цена",
        "ar": "السعر"
    },
    "primaryInstructor": {
        "en": "Primary Instructor",
        "fa": "استاد اصلی",
        "ps": "اصلي ښوونکی",
        "de": "Hauptdozent",
        "fr": "Instructeur principal",
        "ur": "بنیادی استاد",
        "tr": "Ana Eğitmen",
        "ru": "Основной преподаватель",
        "ar": "المعلم الرئيسي"
    },
    "coInstructor": {
        "en": "Co-Instructor",
        "fa": "استاد همکار",
        "ps": "همکار ښوونکی",
        "de": "Co-Dozent",
        "fr": "Co-instructeur",
        "ur": "معاون استاد",
        "tr": "Yardımcı Eğitmen",
        "ru": "Второй преподаватель",
        "ar": "المعلم المساعد"
    },
    "selectCoInstructor": {
        "en": "Select Co-Instructor",
        "fa": "انتخاب استاد همکار",
        "ps": "د همکار ښوونکي ټاکل",
        "de": "Co-Dozenten auswählen",
        "fr": "Sélectionner le co-instructeur",
        "ur": "معاون استاد منتخب کریں",
        "tr": "Yardımcı Eğitmen Seçin",
        "ru": "Выберите второго преподавателя",
        "ar": "اختر المعلم المساعد"
    },
    "runCourseSolo": {
        "en": "Run course solo",
        "fa": "اجرای مستقل دوره بدون همکار",
        "ps": "پرته له همکار د کورس پرمخ بیول",
        "de": "Kurs alleine leiten",
        "fr": "Gérer le cours en solo",
        "ur": "اکیلے کورس چلائیں",
        "tr": "Kursu tek başına yürüt",
        "ru": "Вести курс самостоятельно",
        "ar": "إدارة الدورة بشكل فردي"
    },
    "courseThumbnail": {
        "en": "Course Thumbnail",
        "fa": "تصویر بندانگشتی دوره",
        "ps": "د کورس تمبنیل عکس",
        "de": "Kurs-Vorschaubild",
        "fr": "Miniature du cours",
        "ur": "کورس کا تھمب نیل",
        "tr": "Kurs Küçük Resmi",
        "ru": "Миниатюра курса",
        "ar": "الصورة المصغرة للدورة"
    },
    "publishCourse": {
        "en": "Publish Course",
        "fa": "انتشار دوره",
        "ps": "د کورس خپرول",
        "de": "Kurs veröffentlichen",
        "fr": "Publier le cours",
        "ur": "کورس شائع کریں",
        "tr": "Kursu Yayınla",
        "ru": "Опубликовать курс",
        "ar": "نشر الدورة"
    },
    "makeVisibleToStudents": {
        "en": "Make it visible to academy students",
        "fa": "قابل مشاهده برای تمام دانشجویان آکادمی",
        "ps": "د اکاډمۍ ټولو زده کوونکو ته ښکاره کول",
        "de": "Für alle Studenten sichtbar machen",
        "fr": "Rendre visible aux étudiants de l''académie",
        "ur": "اکیڈمی کے طلباء کے لیے مرئی بنائیں",
        "tr": "Akademi öğrencilerine görünür yap",
        "ru": "Сделать видимым для студентов академии",
        "ar": "جعله مرئياً لطلاب الأكاديمية"
    },
    "creatingCourse": {
        "en": "Compiling Course...",
        "fa": "در حال ساخت دوره...",
        "ps": "د کورس جوړېدو په حال کې...",
        "de": "Kurs wird erstellt...",
        "fr": "Création du cours...",
        "ur": "کورس تیار کیا جا رہا ہے...",
        "tr": "Kurs oluşturuluyor...",
        "ru": "Создание курса...",
        "ar": "جارٍ إنشاء الدورة..."
    },
    "upload": {
        "en": "Upload",
        "fa": "بارگذاری",
        "ps": "اپلوډ",
        "de": "Hochladen",
        "fr": "Téléverser",
        "ur": "اپ لوڈ",
        "tr": "Yükle",
        "ru": "Загрузить",
        "ar": "رفع"
    },
    "saveChanges": {
        "en": "Save Changes",
        "fa": "ذخیره تغییرات",
        "ps": "بدلونونه خوندي کړئ",
        "de": "Änderungen speichern",
        "fr": "Enregistrer les modifications",
        "ur": "تبدیلیاں محفوظ کریں",
        "tr": "Değişiklikleri Kaydet",
        "ru": "Сохранить изменения",
        "ar": "حفظ التغييرات"
    },
    "addLesson": {
        "en": "Add Lesson",
        "fa": "افزودن درس",
        "ps": "درس زیاتول",
        "de": "Lektion hinzufügen",
        "fr": "Ajouter une leçon",
        "ur": "سبق شامل کریں",
        "tr": "Ders Ekle",
        "ru": "Добавить урок",
        "ar": "إضافة درس"
    },
    "lessonTitle": {
        "en": "Lesson Title",
        "fa": "عنوان درس",
        "ps": "د درس سرلیک",
        "de": "Lektionstitel",
        "fr": "Titre de la leçon",
        "ur": "سبق کا عنوان",
        "tr": "Ders Başlığı",
        "ru": "Название урока",
        "ar": "عنوان الدرس"
    },
    "lessonDuration": {
        "en": "Duration",
        "fa": "مدت زمان",
        "ps": "موده",
        "de": "Dauer",
        "fr": "Durée",
        "ur": "دورانیہ",
        "tr": "Süre",
        "ru": "Продолжительность",
        "ar": "المدة"
    },
    "videoUrl": {
        "en": "Video URL",
        "fa": "لینک ویدیو",
        "ps": "د ویډیو لینک",
        "de": "Video-URL",
        "fr": "URL de la vidéo",
        "ur": "ویڈیو کا لنک",
        "tr": "Video URL''si",
        "ru": "URL видео",
        "ar": "رابط الفيديو"
    },
    "lessons": {
        "en": "Lessons",
        "fa": "درس‌ها",
        "ps": "درسونه",
        "de": "Lektionen",
        "fr": "Leçons",
        "ur": "اسباق",
        "tr": "Dersler",
        "ru": "Уроки",
        "ar": "الدروس"
    },
    "liveClasses": {
        "en": "Live Classes",
        "fa": "کلاس‌های زنده",
        "ps": "ژوندۍ ټولګي",
        "de": "Live-Klassen",
        "fr": "Cours en direct",
        "ur": "لائیو کلاسز",
        "tr": "Canlı Dersler",
        "ru": "Онлайн-занятия",
        "ar": "الفصول المباشرة"
    },
    "assignments": {
        "en": "Assignments",
        "fa": "تکالیف",
        "ps": "دندې",
        "de": "Aufgaben",
        "fr": "Devoirs",
        "ur": "اسائنمنٹس",
        "tr": "Ödevler",
        "ru": "Задания",
        "ar": "الواجبات"
    },
    "quizzes": {
        "en": "Quizzes",
        "fa": "آزمون‌ها",
        "ps": "ازموینې",
        "de": "Quizze",
        "fr": "Quiz",
        "ur": "کوئز",
        "tr": "Sınavlar",
        "ru": "Тесты",
        "ar": "الاختبارات"
    },
    "tradingJournal": {
        "en": "Trading Journal",
        "fa": "ژورنال معاملات",
        "ps": "د معاملو ژورنال",
        "de": "Handelstagebuch",
        "fr": "Journal de trading",
        "ur": "ٹریڈنگ جرنل",
        "tr": "İşlem Günlüğü",
        "ru": "Журнал сделок",
        "ar": "سجل التداول"
    },
    "achievements": {
        "en": "Achievements",
        "fa": "دستاوردها",
        "ps": "لاسته راوړنې",
        "de": "Erfolge",
        "fr": "Réalisations",
        "ur": "کامیابیاں",
        "tr": "Başarılar",
        "ru": "Достижения",
        "ar": "الإنجازات"
    },
    "certificates": {
        "en": "Certificates",
        "fa": "گواهینامه‌ها",
        "ps": "سندونه",
        "de": "Zertifikate",
        "fr": "Certificats",
        "ur": "اسناد",
        "tr": "Sertifikalar",
        "ru": "Сертификаты",
        "ar": "الشهادات"
    },
    "reports": {
        "en": "Reports",
        "fa": "گزارش‌ها",
        "ps": "راپورونه",
        "de": "Berichte",
        "fr": "Rapports",
        "ur": "رپورٹس",
        "tr": "Raporlar",
        "ru": "Отчеты",
        "ar": "التقارير"
    },
    "helpCenter": {
        "en": "Help Center",
        "fa": "مرکز راهنمایی",
        "ps": "د مرستې مرکز",
        "de": "Hilfezentrum",
        "fr": "Centre d''aide",
        "ur": "امدادی مرکز",
        "tr": "Yardım Merkezi",
        "ru": "Центр помощи",
        "ar": "مركز المساعدة"
    },
    "settings": {
        "en": "Settings",
        "fa": "تنظیمات",
        "ps": "تنظیمات",
        "de": "Einstellungen",
        "fr": "Paramètres",
        "ur": "ترتیبات",
        "tr": "Ayarlar",
        "ru": "Настройки",
        "ar": "الإعدادات"
    },
    "search": {
        "en": "Search",
        "fa": "جستجو",
        "ps": "پلټنه",
        "de": "Suchen",
        "fr": "Rechercher",
        "ur": "تلاش",
        "tr": "Ara",
        "ru": "Поиск",
        "ar": "بحث"
    },
    "filter": {
        "en": "Filter",
        "fa": "فیلتر",
        "ps": "فلټر",
        "de": "Filtern",
        "fr": "Filtrer",
        "ur": "فلٹر",
        "tr": "Filtrele",
        "ru": "Фильтр",
        "ar": "تصفية"
    },
    "all": {
        "en": "All",
        "fa": "همه",
        "ps": "ټول",
        "de": "Alle",
        "fr": "Tous",
        "ur": "تمام",
        "tr": "Tümü",
        "ru": "Все",
        "ar": "الكل"
    },
    "totalEarnings": {
        "en": "Total Earnings",
        "fa": "مجموع درآمد",
        "ps": "ټول عاید",
        "de": "Gesamteinnahmen",
        "fr": "Revenus totaux",
        "ur": "کل آمدنی",
        "tr": "Toplam Kazanç",
        "ru": "Общий доход",
        "ar": "إجمالي الأرباح"
    },
    "activeStudents": {
        "en": "Active Students",
        "fa": "دانشجویان فعال",
        "ps": "فعال زده کوونکي",
        "de": "Aktive Studenten",
        "fr": "Étudiants actifs",
        "ur": "فعال طلباء",
        "tr": "Aktif Öğrenciler",
        "ru": "Активные студенты",
        "ar": "الطلاب النشطون"
    },
    "activeCourses": {
        "en": "Active Courses",
        "fa": "دوره‌های فعال",
        "ps": "فعال کورسونه",
        "de": "Aktive Kurse",
        "fr": "Cours actifs",
        "ur": "فعال کورسز",
        "tr": "Aktif Kurslar",
        "ru": "Активные курсы",
        "ar": "الدورات النشطة"
    },
    "activeClasses": {
        "en": "Active Classes",
        "fa": "کلاس‌های فعال",
        "ps": "فعال ټولګي",
        "de": "Aktive Klassen",
        "fr": "Classes actives",
        "ur": "فعال کلاسز",
        "tr": "Aktif Sınıflar",
        "ru": "Активные классы",
        "ar": "الفصول النشطة"
    },
    "question": {
        "en": "Question",
        "fa": "سوال",
        "ps": "پوښتنه",
        "de": "Frage",
        "fr": "Question",
        "ur": "سوال",
        "tr": "Soru",
        "ru": "Вопрос",
        "ar": "سؤال"
    },
    "score": {
        "en": "Score",
        "fa": "نمره",
        "ps": "نمره",
        "de": "Punktzahl",
        "fr": "Score",
        "ur": "اسکور",
        "tr": "Puan",
        "ru": "Баллы",
        "ar": "الدرجة"
    },
    "feedback": {
        "en": "Feedback",
        "fa": "بازخورد",
        "ps": "نظر",
        "de": "Rückmeldung",
        "fr": "Commentaire",
        "ur": "فیڈ بیک",
        "tr": "Geri bildirim",
        "ru": "Отзыв",
        "ar": "ملاحظات"
    },
    "progress": {
        "en": "Progress",
        "fa": "پیشرفت",
        "ps": "پرمختګ",
        "de": "Fortschritt",
        "fr": "Progrès",
        "ur": "پیش رفت",
        "tr": "İlerleme",
        "ru": "Прогресс",
        "ar": "التقدم"
    },
    "payout": {
        "en": "Payout",
        "fa": "تسویه حساب",
        "ps": "تادیه",
        "de": "Auszahlung",
        "fr": "Paiement",
        "ur": "ادائیگی",
        "tr": "Ödeme",
        "ru": "Выплата",
        "ar": "صرف الأرباح"
    },
    "analytics": {
        "en": "Analytics",
        "fa": "آمار و تحلیل",
        "ps": "تحلیل او احصائیه",
        "de": "Analytik",
        "fr": "Analytique",
        "ur": "تجزیات",
        "tr": "Analizler",
        "ru": "Аналитика",
        "ar": "التحليلات"
    },
    "createClass": {
        "en": "Create Class",
        "fa": "ایجاد کلاس",
        "ps": "ټولګی جوړول",
        "de": "Klasse erstellen",
        "fr": "Créer une classe",
        "ur": "کلاس بنائیں",
        "tr": "Sınıf Oluştur",
        "ru": "Создать класс",
        "ar": "إنشاء فصل"
    },
    "editClass": {
        "en": "Edit Class",
        "fa": "ویرایش کلاس",
        "ps": "ټولګی سمول",
        "de": "Klasse bearbeiten",
        "fr": "Modifier la classe",
        "ur": "کلاس میں ترمیم کریں",
        "tr": "Sınıfı Düzenle",
        "ru": "Редактировать класс",
        "ar": "تعديل الفصل"
    }
}

languages = ["en", "fa", "ps", "de", "fr", "ur", "tr", "ru", "ar"]

for lang in languages:
    filepath = os.path.join(l10n_dir, f"app_{lang}.arb")
    with open(filepath, "r", encoding="utf-8") as f:
        data = json.load(f)

    for key, trans in keys_data.items():
        val = trans.get(lang, trans["en"])
        # Escape single quotes for ICU
        val = val.replace("'", "''") if "'" in val and "''" not in val else val
        data[key] = val

    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

print("Keys added successfully!")
