import json
import os

translations = {
  "backToCohorts": {
    "en": "Back to Cohorts",
    "fa": "بازگشت به صنف‌ها",
    "ps": "ټولګیو ته ستنېدل",
    "de": "Zurück zu den Kohorten",
    "fr": "Retour aux cohortes",
    "ur": "کلاسوں پر واپس",
    "tr": "Kohortlara Dön",
    "ru": "Назад к группам",
    "ar": "العودة إلى المجموعات"
  },
  "cohortManagement": {
    "en": "COHORT MANAGEMENT",
    "fa": "مدیریت صنف‌ها",
    "ps": "د ټولګیو مدیریت",
    "de": "KOHORTEN-VERWALTUNG",
    "fr": "GESTION DES COHORTES",
    "ur": "کلاس مینجمنٹ",
    "tr": "KOHORT YÖNETİMİ",
    "ru": "УПРАВЛЕНИЕ ГРУППАМИ",
    "ar": "إدارة المجموعات"
  },
  "createClassCohortSubtitle": {
    "en": "Assign course, instructor, schedule and online links for students.",
    "fa": "تعیین کورس، استاد، جدول زمانی و لینک‌های آنلاین برای دانشجویان.",
    "ps": "د زده کوونکو لپاره کورس، ښوونکی، مهالوېش او آنلاین لینکونه وټاکئ.",
    "de": "Kurs, Dozent, Zeitplan und Online-Links für Studenten zuweisen.",
    "fr": "Attribuer un cours, un instructeur, un horaire et des liens en ligne pour les étudiants.",
    "ur": "طلباء کے لیے کورس، استاد، شیڈول اور آن لائن لنکس تفویض کریں۔",
    "tr": "Öğrenciler için kurs, eğitmen, program ve çevrimiçi bağlantılar atayın.",
    "ru": "Назначьте курс, преподавателя, расписание и ссылки для студентов.",
    "ar": "تعيين الدورة والمدرس والجدول الزمني والروابط عبر الإنترنت للطلاب."
  },
  "classTimeSlot": {
    "en": "CLASS TIME SLOT",
    "fa": "زمان برگزاری صنف",
    "ps": "د ټولګي د وخت وقفه",
    "de": "UNTERRICHTSZEIT",
    "fr": "CRÉNEAU HORAIRE DU COURS",
    "ur": "کلاس کے اوقات",
    "tr": "DERS SAATİ",
    "ru": "ВРЕМЯ ЗАНЯТИЙ",
    "ar": "وقت الحصة"
  },
  "classDaysHint": {
    "en": "e.g. Sat, Mon, Wed",
    "fa": "مثلاً شنبه، دوشنبه، چهارشنبه",
    "ps": "لکه شنبه، دوشنبه، چهارشنبه",
    "de": "z.B. Sa, Mo, Mi",
    "fr": "ex. Sam, Lun, Mer",
    "ur": "مثلاً ہفتہ، پیر، بدھ",
    "tr": "örn. Cmt, Pzt, Çar",
    "ru": "напр., Сб, Пн, Ср",
    "ar": "مثال: السبت، الاثنين، الأربعاء"
  },
  "classTimeHint": {
    "en": "e.g. 18:00 - 20:00",
    "fa": "مثلاً ۱۸:۰۰ - ۲۰:۰۰",
    "ps": "لکه ۱۸:۰۰ - ۲۰:۰۰",
    "de": "z.B. 18:00 - 20:00",
    "fr": "ex. 18:00 - 20:00",
    "ur": "مثلاً 18:00 - 20:00",
    "tr": "örn. 18:00 - 20:00",
    "ru": "напр., 18:00 - 20:00",
    "ar": "مثال: 18:00 - 20:00"
  },
  "scheduleNotes": {
    "en": "SCHEDULE INFO (NOTES)",
    "fa": "یادداشت‌ها و جزییات تقسیم‌اوقات",
    "ps": "د مهالوېش معلومات (یادښتونه)",
    "de": "ZEITPLAN-DETAILS (NOTIZEN)",
    "fr": "INFOS D'HORAIRE (NOTES)",
    "ur": "شیڈول کی معلومات (نوٹس)",
    "tr": "PROGRAM BİLGİSİ (NOTLAR)",
    "ru": "ИНФОРМАЦИЯ О РАСПИСАНИИ (ЗАМЕТКИ)",
    "ar": "معلومات الجدول الزمني (ملاحظات)"
  },
  "meetingLinkHint": {
    "en": "https://zoom.us/j/...",
    "fa": "https://zoom.us/j/...",
    "ps": "https://zoom.us/j/...",
    "de": "https://zoom.us/j/...",
    "fr": "https://zoom.us/j/...",
    "ur": "https://zoom.us/j/...",
    "tr": "https://zoom.us/j/...",
    "ru": "https://zoom.us/j/...",
    "ar": "https://zoom.us/j/..."
  },
  "signalLinkHint": {
    "en": "https://t.me/+...",
    "fa": "https://t.me/+...",
    "ps": "https://t.me/+...",
    "de": "https://t.me/+...",
    "fr": "https://t.me/+...",
    "ur": "https://t.me/+...",
    "tr": "https://t.me/+...",
    "ru": "https://t.me/+...",
    "ar": "https://t.me/+..."
  },
  "activeLiveCohort": {
    "en": "Active (Live Cohort)",
    "fa": "فعال (صنف در حال برگزاری)",
    "ps": "فعال (روان ټولګی)",
    "de": "Aktiv (Laufende Kohorte)",
    "fr": "Actif (Cohorte en direct)",
    "ur": "فعال (لائیو کلاس)",
    "tr": "Aktif (Canlı Kohort)",
    "ru": "Активная (Текущая группа)",
    "ar": "نشط (فوج مباشر)"
  },
  "archivedCompleted": {
    "en": "Archived / Completed",
    "fa": "آرشیف‌شده / تکمیل‌شده",
    "ps": "آرشیف شوی / بشپړ شوی",
    "de": "Archiviert / Abgeschlossen",
    "fr": "Archivé / Terminé",
    "ur": "آرکائیو / مکمل",
    "tr": "Arşivlendi / Tamamlandı",
    "ru": "В архиве / Завершено",
    "ar": "مؤرشف / مكتمل"
  },
  "noLiveSessions": {
    "en": "No live sessions found.",
    "fa": "هیچ جلسه زنده‌ای یافت نشد.",
    "ps": "هیڅ ژوندی غونډه ونه موندل شوه.",
    "de": "Keine Live-Sitzungen gefunden.",
    "fr": "Aucune session en direct trouvée.",
    "ur": "کوئی لائیو سیشن نہیں ملا۔",
    "tr": "Canlı oturum bulunamadı.",
    "ru": "Прямые эфиры не найдены.",
    "ar": "لم يتم العثور على جلسات مباشرة."
  },
  "joinMeeting": {
    "en": "Join Meeting",
    "fa": "ورود به جلسه",
    "ps": "غونډې ته ننوتل",
    "de": "Meeting beitreten",
    "fr": "Rejoindre la réunion",
    "ur": "میٹنگ میں شامل ہوں",
    "tr": "Toplantıya Katıl",
    "ru": "Присоединиться",
    "ar": "الانضمام للاجتماع"
  },
  "noLink": {
    "en": "No Link",
    "fa": "بدون لینک",
    "ps": "بې لینکه",
    "de": "Kein Link",
    "fr": "Aucun lien",
    "ur": "کوئی لنک نہیں",
    "tr": "Bağlantı Yok",
    "ru": "Нет ссылки",
    "ar": "لا يوجد رابط"
  },
  "manageAction": {
    "en": "Manage",
    "fa": "مدیریت",
    "ps": "مدیریت",
    "de": "Verwalten",
    "fr": "Gérer",
    "ur": "انتظام کریں",
    "tr": "Yönet",
    "ru": "Управлять",
    "ar": "إدارة"
  },
  "manageClassModal": {
    "en": "Manage Class",
    "fa": "مدیریت صنف",
    "ps": "د ټولګي سمبالول",
    "de": "Klasse verwalten",
    "fr": "Gérer la classe",
    "ur": "کلاس کا انتظام",
    "tr": "Sınıfı Yönet",
    "ru": "Управление классом",
    "ar": "إدارة الفصل"
  },
  "saveAndUpdateAll": {
    "en": "SAVE & UPDATE ALL PROPERTIES 🚀",
    "fa": "ذخیره و به‌روزرسانی تمام مشخصات 🚀",
    "ps": "ټول مشخصات خوندي او تازه کړئ 🚀",
    "de": "ALLE EIGENSCHAFTEN SPEICHERN 🚀",
    "fr": "ENREGISTRER ET TOUT METTRE À JOUR 🚀",
    "ur": "تمام تفصیلات محفوظ کریں 🚀",
    "tr": "TÜM ÖZELLİKLERİ KAYDET VE GÜNCELLE 🚀",
    "ru": "СОХРАНИТЬ И ОБНОВИТЬ ВСЕ ДАННЫЕ 🚀",
    "ar": "حفظ وتحديث جميع الخصائص 🚀"
  },
  "liveSessionsAndCohorts": {
    "en": "Live Sessions & Cohorts",
    "fa": "جلسات زنده و صنف‌ها",
    "ps": "ژوندۍ غونډې او ټولګي",
    "de": "Live-Sitzungen & Kohorten",
    "fr": "Sessions en direct & cohortes",
    "ur": "لائیو سیشنز اور کلاسز",
    "tr": "Canlı Oturumlar ve Kohortlar",
    "ru": "Прямые эфиры и группы",
    "ar": "الجلسات المباشرة والأفواج"
  },
  "liveSessionsSubtitle": {
    "en": "Monitor active rooms, schedules, and manage all class properties securely.",
    "fa": "نظارت بر اتاق‌های فعال، تقسیم‌اوقات و مدیریت امن مشخصات صنف.",
    "ps": "فعالې خونې، مهالوېش او د ټولګي ټول مشخصات په خوندي توګه وڅارئ.",
    "de": "Aktive Räume und Zeitpläne überwachen und Klasseneigenschaften sicher verwalten.",
    "fr": "Surveillez les salles actives, les horaires et gérez les cours en toute sécurité.",
    "ur": "ایکٹو رومز، نظام الاوقات کی نگرانی کریں اور تمام پراپرٹیز کا انتظام کریں۔",
    "tr": "Aktif odaları, programları izleyin ve sınıf özelliklerini güvenle yönetin.",
    "ru": "Контролируйте активные комнаты, расписание и управляйте параметрами классов.",
    "ar": "مراقبة الغرف النشطة والجداول الزمنية وإدارة جميع خصائص الفصل بأمان."
  },
  "searchCohortsHint": {
    "en": "Search cohorts...",
    "fa": "جستجوی صنف‌ها...",
    "ps": "ټولګي وپلټئ...",
    "de": "Kohorten durchsuchen...",
    "fr": "Rechercher des cohortes...",
    "ur": "کلاسز تلاش کریں...",
    "tr": "Kohortlarda ara...",
    "ru": "Поиск групп...",
    "ar": "البحث في المجموعات..."
  },
  "establishingConnection": {
    "en": "ESTABLISHING LIVE CONNECTION...",
    "fa": "برقراری ارتباط زنده...",
    "ps": "د ژوندۍ اړیکې ټینګول...",
    "de": "LIVE-VERBINDUNG WIRD HERGESTELLT...",
    "fr": "CONNEXION EN DIRECT EN COURS...",
    "ur": "لائیو کنکشن قائم ہو رہا ہے...",
    "tr": "CANLI BAĞLANTI KURULUYOR...",
    "ru": "УСТАНОВКА СОЕДИНЕНИЯ...",
    "ar": "جارٍ إنشاء الاتصال المباشر..."
  },
  "auditingRecords": {
    "en": "AUDITING FINANCIAL RECORDS...",
    "fa": "در حال بررسی اسناد مالی...",
    "ps": "د مالي ریکارډونو ارزونه روانه ده...",
    "de": "FINANZDATEN WERDEN GEPRÜFT...",
    "fr": "AUDIT DES REGISTRES FINANCIERS...",
    "ur": "مالی ریکارڈز کا آڈٹ ہو رہا ہے...",
    "tr": "FİNANSAL KAYITLAR DENETLENİYOR...",
    "ru": "ПРОВЕРКА ФИНАНСОВЫХ ЗАПИСЕЙ...",
    "ar": "جارٍ تدقيق السجلات المالية..."
  },
  "financialLedgerSubtitle": {
    "en": "Audit global platform revenue and manage faculty payouts securely.",
    "fa": "بررسی درآمد کلی پلتفرم و مدیریت پرداخت‌های اساتید.",
    "ps": "د پلاتفارم ټولیز عاید وڅارئ او د ښوونکو تادیات تنظیم کړئ.",
    "de": "Plattformumsatz prüfen und Dozentenauszahlungen sicher verwalten.",
    "fr": "Vérifiez les revenus de la plateforme et gérez les paiements des professeurs.",
    "ur": "پلیٹ فارم کی آمدنی کی جانچ کریں اور اساتذہ کی ادائیگیوں کا انتظام کریں۔",
    "tr": "Platform gelirini denetleyin ve eğitmen ödemelerini güvenle yönetin.",
    "ru": "Аудит выручки платформы и управление выплатами преподавателям.",
    "ar": "تدقيق إيرادات المنصة وإدارة مدفوعات المعلمين بأمان."
  },
  "grossRevenue": {
    "en": "Gross Revenue",
    "fa": "درآمد ناخالص",
    "ps": "ناخالص عاید",
    "de": "Bruttoumsatz",
    "fr": "Revenu brut",
    "ur": "مجموعی آمدنی",
    "tr": "Brüt Gelir",
    "ru": "Валовый доход",
    "ar": "إجمالي الإيرادات"
  },
  "facultyLiability": {
    "en": "Faculty Liability",
    "fa": "بدهی به اساتید",
    "ps": "د ښوونکو پورونه",
    "de": "Verbindlichkeiten Dozenten",
    "fr": "Engagements envers les profs",
    "ur": "اساتذہ کی واجب الادا رقم",
    "tr": "Eğitmen Yükümlülüğü",
    "ru": "Обязательства перед преподавателями",
    "ar": "مستحقات المعلمين"
  },
  "distributedPayouts": {
    "en": "Distributed Payouts",
    "fa": "پرداخت‌های توزیع‌شده",
    "ps": "ویشل شوي تادیات",
    "de": "Ausgezahlte Beträge",
    "fr": "Paiements distribués",
    "ur": "تقسیم شدہ ادائیگیاں",
    "tr": "Dağıtılan Ödemeler",
    "ru": "Выплаченные средства",
    "ar": "المدفوعات الموزعة"
  },
  "netProfit": {
    "en": "Net Profit",
    "fa": "سود خالص",
    "ps": "خالص ګټه",
    "de": "Nettogewinn",
    "fr": "Bénéfice net",
    "ur": "خالص منافع",
    "tr": "Net Kâr",
    "ru": "Чистая прибыль",
    "ar": "صافي الربح"
  },
  "facultyTab": {
    "en": "Faculty",
    "fa": "اساتید",
    "ps": "ښوونکي",
    "de": "Dozenten",
    "fr": "Professeurs",
    "ur": "اساتذہ",
    "tr": "Eğitmenler",
    "ru": "Преподаватели",
    "ar": "هيئة التدريس"
  },
  "inflowsTab": {
    "en": "Inflows",
    "fa": "دریافتی‌ها",
    "ps": "راتلونکي عواید",
    "de": "Einnahmen",
    "fr": "Entrées",
    "ur": "آمدنی",
    "tr": "Girişler",
    "ru": "Поступления",
    "ar": "التدفقات الداخلة"
  },
  "outflowsTab": {
    "en": "Outflows",
    "fa": "پرداختی‌ها",
    "ps": "وتلي لګښتونه",
    "de": "Ausgaben",
    "fr": "Sorties",
    "ur": "اخراجات",
    "tr": "Çıkışlar",
    "ru": "Выплаты",
    "ar": "التدفقات الخارجة"
  },
  "findInstructorHint": {
    "en": "Find instructor...",
    "fa": "جستجوی استاد...",
    "ps": "ښوونکی وپلټئ...",
    "de": "Dozent finden...",
    "fr": "Trouver un professeur...",
    "ur": "استاد تلاش کریں...",
    "tr": "Eğitmen bul...",
    "ru": "Найти преподавателя...",
    "ar": "ابحث عن مدرس..."
  },
  "processPayout": {
    "en": "Process Payout",
    "fa": "انجام پرداخت",
    "ps": "تادیه کول",
    "de": "Auszahlung abwickeln",
    "fr": "Traiter le paiement",
    "ur": "ادائیگی کا عمل",
    "tr": "Ödemeyi İşle",
    "ru": "Оформить выплату",
    "ar": "معالجة الدفع"
  },
  "payoutAmount": {
    "en": "Payout Amount ($)",
    "fa": "مبلغ پرداختی (\$)",
    "ps": "د تادیې اندازه (\$)",
    "de": "Auszahlungsbetrag ($)",
    "fr": "Montant du paiement ($)",
    "ur": "ادائیگی کی رقم ($)",
    "tr": "Ödeme Tutarı ($)",
    "ru": "Сумма выплаты ($)",
    "ar": "مبلغ الدفعة ($)"
  },
  "confirmPayout": {
    "en": "CONFIRM PAYOUT 💸",
    "fa": "تأیید پرداخت 💸",
    "ps": "تادیه تایید کړئ 💸",
    "de": "AUSZAHLUNG BESTÄTIGEN 💸",
    "fr": "CONFIRMER LE PAIEMENT 💸",
    "ur": "ادائیگی کی تصدیق کریں 💸",
    "tr": "ÖDEMEYİ ONAYLA 💸",
    "ru": "ПОДТВЕРДИТЬ ВЫПЛАТУ 💸",
    "ar": "تأكيد الدفع 💸"
  },
  "studentPayments": {
    "en": "Student Inflows",
    "fa": "واریزی‌های دانشجویان",
    "ps": "د زده کوونکو تادیات",
    "de": "Studenteneinzahlungen",
    "fr": "Paiements étudiants",
    "ur": "طلباء کی ادائیگیاں",
    "tr": "Öğrenci Girişleri",
    "ru": "Платежи студентов",
    "ar": "مدفوعات الطلاب"
  },
  "payoutRecords": {
    "en": "Payout Outflows",
    "fa": "سوابق پرداخت به اساتید",
    "ps": "ښوونکو ته تادیات",
    "de": "Auszahlungsverlauf",
    "fr": "Historique des paiements",
    "ur": "ادائیگی کا ریکارڈ",
    "tr": "Ödeme Çıkışları",
    "ru": "История выплат",
    "ar": "سجلات المدفوعات"
  },
  "noTransactions": {
    "en": "No transactions found.",
    "fa": "هیچ تراکنشی یافت نشد.",
    "ps": "هیڅ معامله ونه موندل شوه.",
    "de": "Keine Transaktionen gefunden.",
    "fr": "Aucune transaction trouvée.",
    "ur": "کوئی لین دین نہیں ملا۔",
    "tr": "İşlem bulunamadı.",
    "ru": "Транзакции не найдены.",
    "ar": "لم يتم العثور على معاملات."
  },
  "awardsSubtitle": {
    "en": "Create, manage and distribute student achievement badges & rewards.",
    "fa": "ایجاد، مدیریت و اعطای مدال‌ها و جوایز موفقیت دانشجویان.",
    "ps": "د زده کوونکو د بریالیتوب مډالونه او جایزې جوړ او تنظیم کړئ.",
    "de": "Erfolge, Abzeichen und Belohnungen erstellen und verwalten.",
    "fr": "Créer, gérer et attribuer des badges et récompenses aux étudiants.",
    "ur": "طلباء کے کامیابی کے بیجز اور انعامات بنائیں اور تقسیم کریں۔",
    "tr": "Öğrenci başarı rozetlerini ve ödüllerini oluşturun ve yönetin.",
    "ru": "Создание, управление и выдача значков и наград студентам.",
    "ar": "إنشاء وإدارة وتوزيع شارات وجوائز إنجاز الطلاب."
  },
  "createAwardTitle": {
    "en": "Create New Award",
    "fa": "ایجاد جایزه جدید",
    "ps": "نوې جایزه جوړول",
    "de": "Neue Auszeichnung erstellen",
    "fr": "Créer une nouvelle récompense",
    "ur": "نیا انعام بنائیں",
    "tr": "Yeni Ödül Oluştur",
    "ru": "Создать новую награду",
    "ar": "إنشاء جائزة جديدة"
  },
  "awardTitle": {
    "en": "Award Title",
    "fa": "عنوان جایزه",
    "ps": "د جایزې سرلیک",
    "de": "Titel der Auszeichnung",
    "fr": "Titre de la récompense",
    "ur": "انعام کا عنوان",
    "tr": "Ödül Başlığı",
    "ru": "Название награды",
    "ar": "عنوان الجائزة"
  },
  "awardDescription": {
    "en": "Award Description",
    "fa": "توضیحات جایزه",
    "ps": "د جایزې تفصیل",
    "de": "Beschreibung",
    "fr": "Description",
    "ur": "انعام کی تفصیل",
    "tr": "Ödül Açıklaması",
    "ru": "Описание награды",
    "ar": "وصف الجائزة"
  },
  "awardIcon": {
    "en": "Icon / Emoji",
    "fa": "آیکون یا ایموجی",
    "ps": "آیکون یا ایموجي",
    "de": "Icon / Emoji",
    "fr": "Icône / Émoji",
    "ur": "آئیکن / ایموجی",
    "tr": "Simge / Emoji",
    "ru": "Значок / Эмодзи",
    "ar": "أيقونة / رمز تعبيري"
  },
  "pointsRequired": {
    "en": "Points Required",
    "fa": "امتیاز لازم",
    "ps": "اړین نمرې",
    "de": "Erforderliche Punkte",
    "fr": "Points requis",
    "ur": "مطلوبہ پوائنٹس",
    "tr": "Gerekli Puan",
    "ru": "Требуемые баллы",
    "ar": "النقاط المطلوبة"
  },
  "publishAwardAction": {
    "en": "CREATE NEW AWARD 🏆",
    "fa": "ایجاد جایزه جدید 🏆",
    "ps": "نوې جایزه جوړه کړئ 🏆",
    "de": "NEUE AUSZEICHNUNG ERSTELLEN 🏆",
    "fr": "CRÉER UNE RÉCOMPENSE 🏆",
    "ur": "نیا انعام بنائیں 🏆",
    "tr": "YENİ ÖDÜL OLUŞTUR 🏆",
    "ru": "СОЗДАТЬ НАГРАДУ 🏆",
    "ar": "إنشاء جائزة جديدة 🏆"
  },
  "availableAwards": {
    "en": "Available Badges & Awards",
    "fa": "مدال‌ها و جوایز موجود",
    "ps": "شته مډالونه او جایزې",
    "de": "Verfügbare Auszeichnungen & Abzeichen",
    "fr": "Badges et récompenses disponibles",
    "ur": "دستیاب بیجز اور انعامات",
    "tr": "Mevcut Rozetler ve Ödüller",
    "ru": "Доступные награды и значки",
    "ar": "الشارات والجوائز المتاحة"
  },
  "noAwardsFound": {
    "en": "No awards or badges found.",
    "fa": "هیچ مدال یا جایزه‌ای یافت نشد.",
    "ps": "هیڅ جایزه یا مډال ونه موندل شو.",
    "de": "Keine Auszeichnungen gefunden.",
    "fr": "Aucune récompense trouvée.",
    "ur": "کوئی انعام نہیں ملا۔",
    "tr": "Ödül veya rozet bulunamadı.",
    "ru": "Награды не найдены.",
    "ar": "لم يتم العثور على جوائز."
  },
  "deleteAward": {
    "en": "Delete Award",
    "fa": "حذف جایزه",
    "ps": "جایزه ړنګول",
    "de": "Auszeichnung löschen",
    "fr": "Supprimer la récompense",
    "ur": "انعام حذف کریں",
    "tr": "Ödülü Sil",
    "ru": "Удалить награду",
    "ar": "حذف الجائزة"
  },
  "announcementsSubtitle": {
    "en": "Broadcast system-wide notices, updates, or maintenance alerts to all users.",
    "fa": "ارسال اطلاعیه‌های سراسری سیستم، آپدیت‌ها و هشدارهای مهم به کاربران.",
    "ps": "د سیسټم خبرتیاوې، تازه معلومات او مهم خبرونه ټولو ته واستوئ.",
    "de": "Systemweite Mitteilungen, Updates oder Wartungsalarme senden.",
    "fr": "Diffuser des avis à l'échelle du système, des mises à jour ou des alertes.",
    "ur": "سسٹم کے تمام صارفین کو اعلانات اور الرٹس بھیجیں۔",
    "tr": "Sistem genelinde bildirimler ve güncellemeler yayınlayın.",
    "ru": "Публикация системных объявлений, обновлений и оповещений.",
    "ar": "بث إشعارات وتحديثات وتنبيهات على مستوى النظام لجميع المستخدمين."
  },
  "announcementTitle": {
    "en": "Announcement Title",
    "fa": "عنوان اطلاعیه",
    "ps": "د خبرتیا سرلیک",
    "de": "Titel der Mitteilung",
    "fr": "Titre de l'annonce",
    "ur": "اعلان کا عنوان",
    "tr": "Duyuru Başlığı",
    "ru": "Заголовок объявления",
    "ar": "عنوان الإعلان"
  },
  "announcementContent": {
    "en": "Announcement Message / Content",
    "fa": "متن و محتوای اطلاعیه",
    "ps": "د خبرتیا متن / منځپانګه",
    "de": "Nachricht / Inhalt",
    "fr": "Message / Contenu de l'annonce",
    "ur": "اعلان کا پیغام / مواد",
    "tr": "Duyuru Mesajı / İçeriği",
    "ru": "Содержание объявления",
    "ar": "رسالة / محتوى الإعلان"
  },
  "targetAudience": {
    "en": "TARGET AUDIENCE",
    "fa": "مخاطبان هدف",
    "ps": "هدفمند مخاطبین",
    "de": "ZIELGRUPPE",
    "fr": "PUBLIC CIBLE",
    "ur": "مطلوبہ سامعین",
    "tr": "HEDEF KİTLE",
    "ru": "ЦЕЛЕВАЯ АУДИТОРИЯ",
    "ar": "الجمهور المستهدف"
  },
  "allUsers": {
    "en": "All Users",
    "fa": "همه کاربران",
    "ps": "ټول کاروونکي",
    "de": "Alle Benutzer",
    "fr": "Tous les utilisateurs",
    "ur": "تمام صارفین",
    "tr": "Tüm Kullanıcılar",
    "ru": "Все пользователи",
    "ar": "جميع المستخدمين"
  },
  "studentsOnly": {
    "en": "Students Only",
    "fa": "فقط دانشجویان",
    "ps": "یوازې زده کوونکي",
    "de": "Nur Studenten",
    "fr": "Étudiants seulement",
    "ur": "صرف طلباء",
    "tr": "Yalnızca Öğrenciler",
    "ru": "Только студенты",
    "ar": "الطلاب فقط"
  },
  "teachersOnly": {
    "en": "Faculty Only",
    "fa": "فقط اساتید",
    "ps": "یوازې ښوونکي",
    "de": "Nur Dozenten",
    "fr": "Professeurs seulement",
    "ur": "صرف اساتذہ",
    "tr": "Yalnızca Eğitmenler",
    "ru": "Только преподаватели",
    "ar": "المعلمون فقط"
  },
  "broadcastNow": {
    "en": "BROADCAST ANNOUNCEMENT 📢",
    "fa": "ارسال همگانی اطلاعیه 📢",
    "ps": "خبرتیا خپره کړئ 📢",
    "de": "MITTEILUNG SENDEN 📢",
    "fr": "DIFFUSER L'ANNONCE 📢",
    "ur": "اعلان نشر کریں 📢",
    "tr": "DUYURUYU YAYINLA 📢",
    "ru": "ОПУБЛИКОВАТЬ ОБЪЯВЛЕНИЕ 📢",
    "ar": "بث الإعلان 📢"
  },
  "recentAnnouncements": {
    "en": "Broadcast History",
    "fa": "تاریخچه اطلاعیه‌ها",
    "ps": "د خبرتیاوو تاریخچه",
    "de": "Gesendete Mitteilungen",
    "fr": "Historique des diffusions",
    "ur": "اعلانات کی تاریخ",
    "tr": "Duyuru Geçmişi",
    "ru": "История объявлений",
    "ar": "سجل الإعلانات"
  },
  "noAnnouncements": {
    "en": "No announcements broadcast yet.",
    "fa": "هنوز هیچ اطلاعیه‌ای منتشر نشده است.",
    "ps": "تر اوسه هیڅ خبرتیا نه ده خپره شوې.",
    "de": "Noch keine Mitteilungen veröffentlicht.",
    "fr": "Aucune annonce publiée pour l'instant.",
    "ur": "ابھی تک کوئی اعلان نشر نہیں ہوا۔",
    "tr": "Henüz yayınlanan duyuru yok.",
    "ru": "Объявлений пока нет.",
    "ar": "لم يتم نشر أي إعلانات بعد."
  },
  "ticketsSubtitle": {
    "en": "Manage support desk inquiries, unresolved issues, and departmental tickets.",
    "fa": "مدیریت پیام‌های پشتیبانی، موارد حل‌نشده و تیکت‌های دپارتمان‌ها.",
    "ps": "د ملاتړ پوښتنې، ناحل شوې ستونزې او ټکټونه تنظیم کړئ.",
    "de": "Support-Anfragen und Tickets sicher verwalten.",
    "fr": "Gérer les demandes d'assistance et les tickets d'incidents.",
    "ur": "سپورٹ ڈیسک کے سوالات اور ٹکٹوں کا انتظام کریں۔",
    "tr": "Destek taleplerini ve departman biletlerini yönetin.",
    "ru": "Управление тикетами и запросами техподдержки.",
    "ar": "إدارة استفسارات الدعم وتذاكر الأقسام."
  },
  "searchTicketsHint": {
    "en": "Search by subject, student or department...",
    "fa": "جستجو بر اساس موضوع، دانشجو یا دپارتمان...",
    "ps": "د موضوع، زده کوونکي یا څانګې له مخې لټون...",
    "de": "Nach Betreff, Student oder Abteilung suchen...",
    "fr": "Rechercher par sujet, étudiant ou département...",
    "ur": "عنوان، طالب علم یا شعبہ کے لحاظ سے تلاش کریں...",
    "tr": "Konu, öğrenci veya departmana göre ara...",
    "ru": "Поиск по теме, студенту или отделу...",
    "ar": "البحث حسب الموضوع أو الطالب أو القسم..."
  },
  "filterStatusAll": {
    "en": "All Tickets",
    "fa": "همه تیکت‌ها",
    "ps": "ټول ټکټونه",
    "de": "Alle Tickets",
    "fr": "Tous les tickets",
    "ur": "تمام ٹکٹ",
    "tr": "Tüm Biletler",
    "ru": "Все тикеты",
    "ar": "جميع التذاكر"
  },
  "filterDepartment": {
    "en": "Department",
    "fa": "دپارتمان",
    "ps": "څانګه",
    "de": "Abteilung",
    "fr": "Département",
    "ur": "شعبہ",
    "tr": "Departman",
    "ru": "Отдел",
    "ar": "القسم"
  },
  "ticketDepartment": {
    "en": "Department",
    "fa": "دپارتمان",
    "ps": "څانګه",
    "de": "Abteilung",
    "fr": "Département",
    "ur": "شعبہ",
    "tr": "Departman",
    "ru": "Отдел",
    "ar": "القسم"
  },
  "pending": {
    "en": "Pending",
    "fa": "در انتظار بررسی",
    "ps": "په تمه",
    "de": "Ausstehend",
    "fr": "En attente",
    "ur": "زیر التواء",
    "tr": "Beklemede",
    "ru": "В ожидании",
    "ar": "معلق"
  },
  "ticketDetails": {
    "en": "Ticket Details",
    "fa": "جزییات تیکت",
    "ps": "د ټکټ تفصیالت",
    "de": "Ticket-Details",
    "fr": "Détails du ticket",
    "ur": "ٹکٹ کی تفصیلات",
    "tr": "Bilet Detayları",
    "ru": "Детали тикета",
    "ar": "تفاصيل التذكرة"
  },
  "typeYourReply": {
    "en": "Type your reply...",
    "fa": "پاسخ خود را بنویسید...",
    "ps": "خپل ځواب ولیکئ...",
    "de": "Antwort eingeben...",
    "fr": "Tapez votre réponse...",
    "ur": "اپنا جواب لکھیں...",
    "tr": "Yanıtınızı yazın...",
    "ru": "Введите ваш ответ...",
    "ar": "اكتب ردك..."
  },
  "sendReply": {
    "en": "Send Reply",
    "fa": "ارسال پاسخ",
    "ps": "ځواب لېږل",
    "de": "Antwort senden",
    "fr": "Envoyer la réponse",
    "ur": "جواب بھیجیں",
    "tr": "Yanıt Gönder",
    "ru": "Отправить ответ",
    "ar": "إرسال الرد"
  },
  "closeTicket": {
    "en": "Close Ticket",
    "fa": "بستن تیکت",
    "ps": "ټکټ بندول",
    "de": "Ticket schließen",
    "fr": "Fermer le ticket",
    "ur": "ٹکٹ بند کریں",
    "tr": "Bileti Kapat",
    "ru": "Закрыть тикет",
    "ar": "إغلاق التذكرة"
  },
  "reopenTicket": {
    "en": "Reopen Ticket",
    "fa": "بازگشایی مجدد تیکت",
    "ps": "ټکټ بېرته پرانیستل",
    "de": "Ticket wiedereröffnen",
    "fr": "Rouvrir le ticket",
    "ur": "ٹکٹ دوبارہ کھولیں",
    "tr": "Bileti Yeniden Aç",
    "ru": "Открыть тикет снова",
    "ar": "إعادة فتح التذكرة"
  },
  "noTicketsFound": {
    "en": "No support tickets found.",
    "fa": "هیچ تیکت پشتیبانی یافت نشد.",
    "ps": "د ملاتړ هیڅ ټکټ ونه موندل شو.",
    "de": "Keine Support-Tickets gefunden.",
    "fr": "Aucun ticket de support trouvé.",
    "ur": "کوئی سپورٹ ٹکٹ نہیں ملا۔",
    "tr": "Destek bileti bulunamadı.",
    "ru": "Тикеты поддержки не найдены.",
    "ar": "لم يتم العثور على تذاكر دعم."
  },
  "liveSupportSubtitle": {
    "en": "Handle live student & faculty assistance in real time.",
    "fa": "پاسخگویی به درخواست‌های زنده دانشجویان و اساتید به صورت لحظه‌ای.",
    "ps": "د محصلینو او استادانو پوښتنو ته په ژوندۍ بڼه رسیدګي وکړئ.",
    "de": "Live-Support für Studenten und Dozenten in Echtzeit.",
    "fr": "Assistance en direct pour étudiants et professeurs en temps réel.",
    "ur": "طلباء اور اساتذہ کی لائیو معاونت حقیقی وقت میں کریں۔",
    "tr": "Öğrenci ve eğitmenlere gerçek zamanlı canlı destek sağlayın.",
    "ru": "Живая поддержка студентов и преподавателей в реальном времени.",
    "ar": "تقديم الدعم المباشر للطلاب وأعضاء هيئة التدريس في الوقت الفعلي."
  },
  "searchSupportHint": {
    "en": "Search support requests...",
    "fa": "جستجوی درخواست‌های پشتیبانی...",
    "ps": "د ملاتړ غوښتنې وپلټئ...",
    "de": "Support-Anfragen durchsuchen...",
    "fr": "Rechercher des demandes d'assistance...",
    "ur": "سپورٹ کی درخواستیں تلاش کریں...",
    "tr": "Destek taleplerini ara...",
    "ru": "Поиск запросов поддержки...",
    "ar": "البحث في طلبات الدعم..."
  },
  "openChat": {
    "en": "Open Chat",
    "fa": "گفتگوی آنلاین",
    "ps": "چټ پرانیستل",
    "de": "Chat öffnen",
    "fr": "Ouvrir le chat",
    "ur": "چیٹ کھولیں",
    "tr": "Sohbeti Aç",
    "ru": "Открыть чат",
    "ar": "فتح الدردشة"
  },
  "noSupportRequests": {
    "en": "No support requests found.",
    "fa": "هیچ درخواست پشتیبانی یافت نشد.",
    "ps": "د ملاتړ هیڅ غوښتنه ونه موندل شوه.",
    "de": "Keine Support-Anfragen gefunden.",
    "fr": "Aucune demande d'assistance trouvée.",
    "ur": "کوئی سپورٹ درخواست نہیں ملی۔",
    "tr": "Destek talebi bulunamadı.",
    "ru": "Запросов поддержки не найдено.",
    "ar": "لم يتم العثور على طلبات دعم."
  },
  "supportChatTitle": {
    "en": "Support Chat",
    "fa": "چت پشتیبانی",
    "ps": "د ملاتړ چټ",
    "de": "Support-Chat",
    "fr": "Chat d'assistance",
    "ur": "سپورٹ چیٹ",
    "tr": "Destek Sohbeti",
    "ru": "Чат поддержки",
    "ar": "دردشة الدعم"
  },
  "markResolved": {
    "en": "Mark Resolved",
    "fa": "علامت‌گذاری به عنوان حل‌شده",
    "ps": "حل شوی په نښه کړئ",
    "de": "Als gelöst markieren",
    "fr": "Marquer comme résolu",
    "ur": "حل شدہ قرار دیں",
    "tr": "Çözüldü Olarak İşaretle",
    "ru": "Отметить как решено",
    "ar": "وضع علامة كمحلول"
  },
  "adminSettingsSubtitle": {
    "en": "Manage your administrator profile, system preferences, and security settings.",
    "fa": "مدیریت پروفایل مدیر، تنظیمات سیستم و پیکربندی‌های امنیتی.",
    "ps": "د مدیر پروفایل، د سیسټم غوره توبونه او امنیتي ترتیبات تنظیم کړئ.",
    "de": "Administratorprofil, Systemeinstellungen und Sicherheitseinstellungen verwalten.",
    "fr": "Gérer votre profil administrateur, les préférences système et la sécurité.",
    "ur": "ایڈمنسٹریٹر پروفائل، سسٹم کی ترجیحات اور سیکیورٹی سیٹنگز کا انتظام کریں۔",
    "tr": "Yönetici profilinizi, sistem tercihlerinizi ve güvenlik ayarlarınızı yönetin.",
    "ru": "Управление профилем администратора, настройками системы и безопасности.",
    "ar": "إدارة ملف تعريف المسؤول وتفضيلات النظام وإعدادات الأمان."
  },
  "systemAdmin": {
    "en": "System Administrator",
    "fa": "مدیر سیستم",
    "ps": "د سیسټم مدیر",
    "de": "Systemadministrator",
    "fr": "Administrateur système",
    "ur": "سسٹم ایڈمنسٹریٹر",
    "tr": "Sistem Yöneticisi",
    "ru": "Системный администратор",
    "ar": "مسؤول النظام"
  },
  "personalInfo": {
    "en": "Personal Profile",
    "fa": "پروفایل شخصی",
    "ps": "شخصي پروفایل",
    "de": "Persönliches Profil",
    "fr": "Profil personnel",
    "ur": "ذاتی پروفائل",
    "tr": "Kişisel Profil",
    "ru": "Личный профиль",
    "ar": "الملف الشخصي"
  },
  "adminRole": {
    "en": "Administrative Role",
    "fa": "نقش مدیریتی",
    "ps": "مدیریتي رول",
    "de": "Administrator-Rolle",
    "fr": "Rôle administratif",
    "ur": "انتظامی کردار",
    "tr": "Yönetici Rolü",
    "ru": "Административная роль",
    "ar": "الدور الإداري"
  },
  "logOutAccount": {
    "en": "Log Out Account",
    "fa": "خروج از حساب کاربری",
    "ps": "له حساب څخه وتل",
    "de": "Konto abmelden",
    "fr": "Se déconnecter",
    "ur": "اکاؤنٹ لاگ آؤٹ کریں",
    "tr": "Hesaptan Çıkış Yap",
    "ru": "Выйти из системы",
    "ar": "تسجيل الخروج"
  },
  "confirmLogout": {
    "en": "Are you sure you want to log out?",
    "fa": "آیا مطمئن هستید که می‌خواهید خارج شوید؟",
    "ps": "ایا ډاډه یاست چې غواړئ ووځئ؟",
    "de": "Möchten Sie sich wirklich abmelden?",
    "fr": "Êtes-vous sûr de vouloir vous déconnecter ?",
    "ur": "کیا آپ واقعی لاگ آؤٹ کرنا چاہتے ہیں؟",
    "tr": "Çıkış yapmak istediğinizden emin misiniz?",
    "ru": "Вы уверены, что хотите выйти?",
    "ar": "هل أنت متأكد أنك تريد تسجيل الخروج؟"
  }
}

l10n_dir = "/Users/Safi_Sahib/safi_academy_app/lib/l10n"
langs = ["en", "fa", "ps", "de", "fr", "ur", "tr", "ru", "ar"]

for lang in langs:
    filepath = os.path.join(l10n_dir, f"app_{lang}.arb")
    with open(filepath, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    count = 0
    for key, val in translations.items():
        if key not in data:
            data[key] = val[lang]
            count += 1
            
    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"Updated {lang} with {count} keys.")
