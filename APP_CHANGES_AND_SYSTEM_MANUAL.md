# مستندات جامع تغییرات، قابلیت‌ها و پیکربندی‌های اپلیکیشن صافی اکادمی
# (Safi Academy App - Comprehensive Changelog & System Documentation)

این سند شامل گزارش و ثبت کلیه تغییرات، قابلیت‌های جدید، اصلاحات ساختاری، کدهای دیتابیس (SQL)، تنظیمات دیپ‌لینک (Deep Linking)، سیاست‌های امنیتی (RLS)، و معماری کدهای اپلیکیشن می‌باشد.

---

## فهرست مطالب (Table of Contents)
1. [خلاصه تغییرات کلیدی (Executive Summary)](#1-خلاصه-تغییرات-کلیدی)
2. [سیستم ویدیوی کوتاه و ریلز (Reels Viewer & Upload)](#2-سیستم-ویدیوی-کوتاه-و-ریلز)
3. [سیستم دیپ‌لینک و رفع خطای ۴۰۴ (Deep Linking & URL Routing)](#3-سیستم-دیپ‌لینک-و-رفع-خطای-۴۰۴)
4. [سیستم دانلود ویدیو و حل دسترسی حافظه اندروید (Scoped Storage)](#4-سیستم-دانلود-ویدیو-و-حل-دسترسی-حافظه-اندروید)
5. [اشتراک‌گذاری، پیام‌رسان دایرکت و چت (Direct Chat & Sharing)](#5-اشتراک‌گذاری-پیام‌رسان-دایرکت-و-چت)
6. [یکپارچه‌سازی معماری فید، استوری و دوستان (Unified Feed & Social Core)](#6-یکپارچه‌سازی-معماری-فید-استوری-و-دوستان)
7. [دستیار هوش مصنوعی و پشتیبانی آنلاین (AI Assistant & Live Support)](#7-دستیار-هوش-مصنوعی-و-پشتیبانی-آنلاین)
8. [تنظیمات مانیفست اندروید و دسترسی‌ها (AndroidManifest Permissions)](#8-تنظیمات-مانیفست-اندروید-و-دسترسی‌ها)
9. [طرح کامل دیتابیس سوپابیس، پالیسی‌ها و کدهای SQL (Supabase Schema & RLS)](#9-طرح-کامل-دیتابیس-سوپابیس-پالیسی‌ها-و-کدهای-sql)
10. [سیستم طراحی و تم ظاهری (Design System & Theme)](#10-سیستم-طراحی-و-تم-ظاهری)
11. [فهرست فایل‌های تغییر یافته و اضافه شده (Modified & New Files)](#11-فهرست-فایل‌های-تغییر-یافته-و-اضافه-شده)

---

## ۱. خلاصه تغییرات کلیدی
در طول فازهای اخیر توسعه، بخش‌های مختلف اپلیکیشن صافی اکادمی از یک معماری سنتی و پراکنده به یک ساختار یکپارچه، سریع و کاملاً مدرن ارتقا یافت:
- **بازنویسی و ارتقای بخش ریلز (Reels):** مشابه اینستاگرام و تیک‌تاک با اسکرول عمودی روان، انیمیشن دو بار ضربه برای لایک، دانلود ویدیو در حافظه عمومی گوشی، تب‌بندی Explore، For You و Friends، و ثبت ماندگار بازدیدها.
- **اصلاح مسیردهی پیوندها (Deep Linking):** تغییر مسیر رسمی ریلزها به `https://www.safiacademy.org/en/feed/reels?id={id}` جهت تطابق با روتینگ وب‌سایت Next.js و باز شدن خودکار لینک در اپلیکیشن (یا وب‌سایت در صورت نبود اپ).
- **سیستم ویوی یکتا (Unique Views):** ثبت دائم بازدیدها برای هر کاربر در جدول `reel_views` و ممانعت از محاسبه تکراری بازدیدها حتی پس از خروج و ورود مجدد به اپلیکیشن.
- **تغییر اعلان‌های سیستمی به پاپ‌آپ‌های مدرن:** حذف ارورهای خام سیستمی و نمایش پیام‌های فشرده انگلیسی ۲ ثانیه‌ای (مانند "Link copied to clipboard!" یا "Reel downloaded successfully!").
- **پشتیبانی رسانه‌ای کلودفلر (Cloudflare R2):** سازگاری کامل با استریم و دانلود ویدیوها از آدرس‌های رسانه‌ای مانند `media.safiacademy.org`.
- **یکپارچه‌سازی فید و استوری:** تجمیع فیدهای جداگانه ادمین، استاد و دانشجو در یک پکیج مرکزی مشترک (`lib/features/feed`).
- **دستیار هوش مصنوعی و تیکت پشتیبانی:** اتصال به هوش مصنوعی Google Gemini و سیستم چت زنده پشتیبانی با ادمین.

---

## ۲. سیستم ویدیوی کوتاه و ریلز (Reels Viewer & Upload)
**فایل‌های اصلی:**
- [reels_viewer_screen.dart](file:///Users/Safi_Sahib/safi_academy_app/lib/features/feed/screens/reels_viewer_screen.dart)
- [upload_reel_screen.dart](file:///Users/Safi_Sahib/safi_academy_app/lib/features/feed/screens/upload_reel_screen.dart)

### ویژگی‌های کلیدی پیاده‌سازی شده:
1. **تب‌بندی سه‌گانه پیشرفته (Triple Tab Navigation):**
   - **Explore:** نمایش کلیه ریلزهای تایید و منتشر شده.
   - **For You:** الگوریتم هوشمند رتبه‌بندی بر اساس محبوبیت و دسته‌بندی‌های تعاملی کاربر.
   - **Friends:** نمایش انحصاری ریلزهایی که دوستان تایید شده دانشجو/کاربر به اشتراک گذاشته‌اند.
2. **سیستم لایک پیشرفته و انیمیشن اینستاگرام (Double-Tap Like):**
   - با دو بار لمس سریع روی ویدیو، لایک ثبت می‌شود.
   - انیمیشن قلب نئونی با افکت اسکیل و فید در مرکز صفحه پدیدار شده و پس از چند لحظه محو می‌شود.
   - رابط کاربری به صورت خوش‌بینانه (Optimistic UI) بدون مکث به‌روزرسانی شده و سپس با جدول `reel_likes` در سوپابیس همگام‌سازی می‌گردد.
3. **ثبت ماندگار و یکتای بازدیدها (Unique View Tracking):**
   - به محض باز شدن اپ، لیست شناسه‌های ریلزهای قبلاً مشاهده شده کاربر از جدول `reel_views` بارگذاری می‌شود.
   - در زمان مشاهده ریلز، اعتبارسنجی دو مرحله‌ای انجام شده و تنها در صورتی که کاربر اولین بار ویدیو را می‌بیند، رکورد ثبت و فیلد `views_count` در جدول `reels` اضافه می‌شود. ریبوت یا بستن اپ تاثیری در این حافظه ندارد.
4. **بخش کامنت‌ها (Comments Bottom Sheet):**
   - قابلیت ارسال کامنت با قابلیت منشن و ریپلای (`Reply`).
   - جوین با جدول پروفایل‌ها (`profiles`) جهت نمایش عکس کاربر، نام کامل و بج هنرجو/استاد.
5. **ارسال ریلز به دوستان (Send Reel in Chat):**
   - باز شدن لیست دوستان و امکان ارسال آنی به پی‌وی دوست در قالب کارت ویدیویی جذاب در چت دایرکت (`direct_messages`).

---

## ۳. سیستم دیپ‌لینک و رفع خطای ۴۰۴ (Deep Linking & URL Routing)
**فایل‌های اصلی:**
- [deep_link_service.dart](file:///Users/Safi_Sahib/safi_academy_app/lib/core/services/deep_link_service.dart)
- [AndroidManifest.xml](file:///Users/Safi_Sahib/safi_academy_app/android/app/src/main/AndroidManifest.xml)

### علت خطای ۴۰۴ قبلی:
وب‌سایت اصلی صافی اکادمی مسیر ریلزها را در روت کلاینت فید به صورت `/en/feed/reels` مدیریت می‌کند. لینک قبلی که به صورت `/en/reels/...` تولید می‌شد در سرور موجود نبود و خطای ۴۰۴ دریافت می‌کرد.

### ساختار استاندارد جدید پیوندها:
- **فرمت لینک رسمی کپی شده:**
  `https://www.safiacademy.org/en/feed/reels?id={reel_id}`
- **عملکرد سیستم دیپ‌لینک:**
  - اگر اپلیکیشن روی گوشی نصب باشد: سیستم‌عامل از طریق **Android App Links** درخواست را دریافت کرده و مستقیماً صفحه ریلز را در اپلیکیشن با ویدیوی هدف باز می‌کند.
  - اگر اپلیکیشن نصب نباشد: مرورگر آدرس وب‌سایت `https://www.safiacademy.org/en/feed/reels?id=...` را باز کرده و خطای ۴۰۴ نخواهد داد (کد ۲۰۰ اوکی).
- **پشتیبانی از فرمت‌های متنوع در `DeepLinkService`:**
  - `https://www.safiacademy.org/en/feed/reels?id=<id>`
  - `https://safiacademy.org/en/feed/reels?id=<id>`
  - `https://safiacademy.org/reel/<id>`
  - `safiacademy://reel/<id>`

---

## ۴. سیستم دانلود ویدیو و حل دسترسی حافظه اندروید (Scoped Storage)
### مشکل دسترسی حافظه (Permission Denied):
در نسخه‌های اندروید ۱۰ به بالا (Android 10+) با فعال بودن Scoped Storage، اپلیکیشن‌ها اجازه نوشتن مستقیم روی مسیر `/storage/emulated/0/Download` بدون استفاده از Storage Access Framework یا دایرکتوری اختصاصی ندارند.

### راهکار پیاده‌سازی شده در اپ:
1. **تست خودکار دسترسی نوشتن (Permission Test Probe):**
   - پیش از شروع دانلود، اپلیکیشن ایجاد یک فایل موقت در پوشه دانلود عمومی را تست می‌کند. اگر سیستم‌عامل اجازه داد، مستقیماً ویدیو را در پوشه عمومی دانلود ذخیره می‌کند تا کاربر در گالری و فایل منیجر گوشی آن را ببیند.
2. **پشتیبان هوشمند (Fallback to Scoped External Storage):**
   - در صورت رد شدن دسترسی، متد `getExternalStorageDirectories(type: StorageDirectory.downloads)` یا `getExternalStorageDirectory()` فراخوانی می‌شود تا بدون خطا ویدیو دانلود گردد.
3. **دیالوگ پیشرفت دانلود و توست انگلیسی:**
   - نمایش پنجره درصد دانلود زنده.
   - پس از پایان دانلود، اعلان انگلیسی به مدت ۲ ثانیه نمایش داده می‌شود:
     `Reel downloaded successfully! Saved to Downloads: reel_xxxx.mp4`

---

## ۵. اشتراک‌گذاری، پیام‌رسان دایرکت و چت (Direct Chat & Sharing)
**فایل‌های اصلی:**
- [direct_chat_screen.dart](file:///Users/Safi_Sahib/safi_academy_app/lib/features/chat/screens/direct_chat_screen.dart)
- [direct_chat_list_screen.dart](file:///Users/Safi_Sahib/safi_academy_app/lib/features/chat/screens/direct_chat_list_screen.dart)

### قابلیت‌ها:
- پیام‌رسانی دایرکت بلادرنگ با جدول `direct_messages`.
- تشخیص خودکار لینک‌های ریلز درون چت (تشخیص دامنه `safiacademy.org/en/feed/reels` یا نوع پیوست `reel`).
- نمایش پیش‌نمایش تعاملی ریلز همراه با تامبنیل، عنوان و دکمه پلی درون حباب پیام چت.
- واکنش به پیام‌ها با ایموجی (`message_reactions`).
- وضعیت خوانده شدن پیام (`is_read` و `read_at`).

---

## ۶. یکپارچه‌سازی معماری فید، استوری و دوستان (Unified Feed & Social Core)
پیش از این، برای نقش‌های دانشجو (`student_feed_screen`)، استاد (`teacher_feed_screen`) و ادمین (`admin_feed_screen`) کدهای مجزا با بیش از ۴۰۰۰ خط تکراری وجود داشت. این بخش در یک بسته متمرکز بازسازی شد:
- **`lib/features/feed/screens/feed_viewer_screen.dart`**: صفحه اصلی فید یکپارچه با پشتیبانی از پست‌های متنی، تصویری، نظرسنجی و بوکمارک.
- **`lib/features/feed/screens/friends_viewer_screen.dart`**: مدیریت لیست دوستان، جستجو در بین کاربران و درخواست دوستی.
- **`lib/features/feed/screens/story_viewer_screen.dart`**: پلیر استوری‌های ۲۴ ساعته با نوار پیشرفت خودکار، افکت تعویض استوری و جدول `story_views`.
- **`lib/features/feed/screens/create_story_screen.dart`**: آپلود و ضبط استوری با ماندگاری ۲۴ ساعته در کلود و دیتابیس.
- **`lib/features/feed/screens/user_profile_screen.dart`**: صفحه پروفایل مدرن با نمایش تب‌های پست‌ها، ریلزها، نشان‌ها و دستاوردها.

---

## ۷. دستیار هوش مصنوعی و پشتیبانی آنلاین (AI Assistant & Live Support)
**فایل‌های اصلی:**
- [student_ai_assistant_screen.dart](file:///Users/Safi_Sahib/safi_academy_app/lib/features/dashboard/screens/student_ai_assistant_screen.dart)
- [gemini_ai_service.dart](file:///Users/Safi_Sahib/safi_academy_app/lib/core/services/gemini_ai_service.dart)
- [student_support_screen.dart](file:///Users/Safi_Sahib/safi_academy_app/lib/features/dashboard/screens/student_support_screen.dart)
- [student_support_chat_screen.dart](file:///Users/Safi_Sahib/safi_academy_app/lib/features/dashboard/screens/student_support_chat_screen.dart)
- [admin_support_requests_screen.dart](file:///Users/Safi_Sahib/safi_academy_app/lib/features/admin/screens/admin_support_requests_screen.dart)
- [admin_support_chat_screen.dart](file:///Users/Safi_Sahib/safi_academy_app/lib/features/admin/screens/admin_support_chat_screen.dart)

### قابلیت‌ها:
- گفت‌وگوی تعاملی دانشجو با هوش مصنوعی Google Gemini جهت رفع اشکالات درسی و مشاوره آموزشی.
- سیستم ایجاد تیکت پشتیبانی و گفت‌وگوی زنده با تیم ادمین آکادمی.
- پنل مدیریت پشتیبانی ویژه ادمین با قابلیت پاسخگویی زنده به تیکت‌های هنرجویان.

---

## ۸. تنظیمات مانیفست اندروید و دسترسی‌ها (AndroidManifest Permissions)
در فایل `android/app/src/main/AndroidManifest.xml` تغییرات زیر اعمال شده‌اند:

```xml
    <!-- دسترسی‌های اینترنت، صوت و شبکه -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    
    <!-- دسترسی سازگار با سیاست‌های گوگل‌پلی و Photo Picker استاندارد بدون نیاز به READ_MEDIA -->
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28" />

    <application
        ...
        android:requestLegacyExternalStorage="true">

        <!-- فیلترهای دیپ‌لینک اپلیکیشن برای سایت و ریلز -->
        <intent-filter android:autoVerify="true">
            <action android:name="android.intent.action.VIEW" />
            <category android:name="android.intent.category.DEFAULT" />
            <category android:name="android.intent.category.BROWSABLE" />
            <data
                android:scheme="https"
                android:host="www.safiacademy.org"
                android:pathPrefix="/en/feed/reels" />
        </intent-filter>

        <intent-filter android:autoVerify="true">
            <action android:name="android.intent.action.VIEW" />
            <category android:name="android.intent.category.DEFAULT" />
            <category android:name="android.intent.category.BROWSABLE" />
            <data
                android:scheme="https"
                android:host="safiacademy.org"
                android:pathPrefix="/en/feed/reels" />
        </intent-filter>

        <!-- اسکیمای سفارشی اپلیکیشن -->
        <intent-filter>
            <action android:name="android.intent.action.VIEW" />
            <category android:name="android.intent.category.DEFAULT" />
            <category android:name="android.intent.category.BROWSABLE" />
            <data
                android:scheme="safiacademy"
                android:host="reel" />
        </intent-filter>
    </application>
```

---

## ۹. طرح کامل دیتابیس سوپابیس، پالیسی‌ها و کدهای SQL (Supabase Schema & RLS)
برای اطمینان از عملکرد بدون نقص ریلز، لایک، کامنت، چت دایرکت، استوری و بازدیدها، کدهای SQL زیر در دیتابیس سوپابیس تعریف شده‌اند. می‌توانید هر زمان نیاز داشتید این اسکریپت را در SQL Editor سوپابیس اجرا فرمایید:

```sql
-- ====================================================================
-- SAFI ACADEMY - DATABASE TABLES, RLS POLICIES & COUNTER TRIGGERS
-- ====================================================================

-- ۱. جدول ریلز (Reels)
CREATE TABLE IF NOT EXISTS public.reels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    video_url TEXT NOT NULL,
    thumbnail_url TEXT,
    title TEXT NOT NULL,
    description TEXT,
    category TEXT DEFAULT 'Explore',
    duration_seconds INT DEFAULT 30,
    views_count INT NOT NULL DEFAULT 0,
    likes_count INT NOT NULL DEFAULT 0,
    comments_count INT NOT NULL DEFAULT 0,
    is_published BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ۲. جدول لایک‌های ریلز (Reel Likes)
CREATE TABLE IF NOT EXISTS public.reel_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reel_id UUID NOT NULL REFERENCES public.reels(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_reel_like UNIQUE (reel_id, user_id)
);

-- ۳. جدول کامنت‌های ریلز (Reel Comments)
CREATE TABLE IF NOT EXISTS public.reel_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reel_id UUID NOT NULL REFERENCES public.reels(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    comment_text TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ۴. جدول ثبت بازدیدهای یکتای ریلز (Reel Views Tracking)
CREATE TABLE IF NOT EXISTS public.reel_views (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reel_id UUID NOT NULL REFERENCES public.reels(id) ON DELETE CASCADE,
    viewer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    viewed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_reel_viewer UNIQUE (reel_id, viewer_id)
);

-- ۵. فعال‌سازی RLS و اعطای دسترسی‌های لازم
ALTER TABLE public.reels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reel_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reel_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reel_views ENABLE ROW LEVEL SECURITY;

-- حذف پالیسی‌های قبلی در صورت وجود جهت جلوگیری از تداخل
DROP POLICY IF EXISTS "Reels Select Policy" ON public.reels;
DROP POLICY IF EXISTS "Reels Insert Policy" ON public.reels;
DROP POLICY IF EXISTS "Reels Update Policy" ON public.reels;
DROP POLICY IF EXISTS "Reels Delete Policy" ON public.reels;

DROP POLICY IF EXISTS "Reel Likes Manage Policy" ON public.reel_likes;
DROP POLICY IF EXISTS "Reel Comments Manage Policy" ON public.reel_comments;
DROP POLICY IF EXISTS "Reel Views Manage Policy" ON public.reel_views;

-- پالیسی‌های دسترسی ریلز
CREATE POLICY "Reels Select Policy" ON public.reels
FOR SELECT USING (true);

CREATE POLICY "Reels Insert Policy" ON public.reels
FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Reels Update Policy" ON public.reels
FOR UPDATE USING (true);

CREATE POLICY "Reels Delete Policy" ON public.reels
FOR DELETE USING (auth.uid() = user_id);

-- پالیسی‌های لایک ریلز
CREATE POLICY "Reel Likes Manage Policy" ON public.reel_likes
FOR ALL USING (true);

-- پالیسی‌های کامنت ریلز
CREATE POLICY "Reel Comments Manage Policy" ON public.reel_comments
FOR ALL USING (true);

-- پالیسی‌های ثبت ویو ریلز
CREATE POLICY "Reel Views Manage Policy" ON public.reel_views
FOR ALL USING (true);

-- ۶. اعطای دسترسی به رول‌های authenticated و anon
GRANT ALL ON TABLE public.reels TO authenticated, anon;
GRANT ALL ON TABLE public.reel_likes TO authenticated, anon;
GRANT ALL ON TABLE public.reel_comments TO authenticated, anon;
GRANT ALL ON TABLE public.reel_views TO authenticated, anon;

-- ۷. تریگرهای خودکار شمارنده‌ها (Counter Triggers)

-- الف) تریگر لایک
CREATE OR REPLACE FUNCTION public.handle_reel_like_count()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE public.reels SET likes_count = likes_count + 1 WHERE id = NEW.reel_id;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE public.reels SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = OLD.reel_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_reel_likes_count ON public.reel_likes;
CREATE TRIGGER trg_reel_likes_count
AFTER INSERT OR DELETE ON public.reel_likes
FOR EACH ROW EXECUTE FUNCTION public.handle_reel_like_count();

-- ب) تریگر کامنت
CREATE OR REPLACE FUNCTION public.handle_reel_comment_count()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE public.reels SET comments_count = comments_count + 1 WHERE id = NEW.reel_id;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE public.reels SET comments_count = GREATEST(comments_count - 1, 0) WHERE id = OLD.reel_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_reel_comments_count ON public.reel_comments;
CREATE TRIGGER trg_reel_comments_count
AFTER INSERT OR DELETE ON public.reel_comments
FOR EACH ROW EXECUTE FUNCTION public.handle_reel_comment_count();

-- ج) تریگر بازدید
CREATE OR REPLACE FUNCTION public.handle_reel_view_count()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE public.reels SET views_count = views_count + 1 WHERE id = NEW.reel_id;
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_reel_views_count ON public.reel_views;
CREATE TRIGGER trg_reel_views_count
AFTER INSERT ON public.reel_views
FOR EACH ROW EXECUTE FUNCTION public.handle_reel_view_count();
```

---

## ۱۰. سیستم طراحی و تم ظاهری (Design System & Theme)
**فایل اصلی:**
- [app_theme.dart](file:///Users/Safi_Sahib/safi_academy_app/lib/core/theme/app_theme.dart)

- **رنگ‌های برند صافی اکادمی:**
  - صورتی شاخص (Primary Pink): `Color(0xFFF494AC)`
  - صورتی تیره / هاور: `Color(0xFFE07A94)`
  - پس‌زمینه لایت پینک: `Color(0xFFFAF4F6)`
  - مشکی و خاکستری متنی: `Color(0xFF111827)` و `Color(0xFF6B7280)`
- **کامپوننت‌های گلس‌مورفیسم و نئونی:**
  - `GlassContainer` در `lib/shared/widgets/glass_container.dart`
  - `GlowingButton` در `lib/shared/widgets/glowing_button.dart`
  - تم تاریک استاندارد برای پلیر ریلز جهت تمرکز کامل بر روی محتوای ویدیویی عمودی.

---

## ۱۱. فهرست فایل‌های تغییر یافته و اضافه شده (Modified & New Files)

| مسیر فایل | وضعیت | توضیحات |
| :--- | :--- | :--- |
| `lib/features/feed/screens/reels_viewer_screen.dart` | اصلاح و ارتقای کامل | پلیر تمام صفحه، لایک دوضربه، دانلود ایمن، تب‌های سه‌گانه، دیپ‌لینک، ویوی یکتا |
| `lib/features/feed/screens/upload_reel_screen.dart` | افزوده شد | آپلود ویدیوی کوتاه با دسته‌بندی و تولید تامبنیل |
| `lib/core/services/deep_link_service.dart` | اصلاح و ارتقا | پشتیبانی از روت `/en/feed/reels?id=` و هدایت خودکار در اپلیکیشن |
| `android/app/src/main/AndroidManifest.xml` | اصلاح | فیلترهای دیپ‌لینک، مجوزهای حافظه و legacy storage |
| `lib/features/chat/screens/direct_chat_screen.dart` | اصلاح و ارتقا | ارسال مستقیم ریلز، کارت نمایش درون چت، واکنش‌ها |
| `lib/features/feed/screens/feed_viewer_screen.dart` | اصلاح و استانداردسازی | فید اجتماعی مشترک بین کلیه نقش‌های کاربری |
| `lib/features/feed/screens/friends_viewer_screen.dart` | اصلاح و استانداردسازی | سیستم ارتباط با دوستان و هنرجویان |
| `lib/features/feed/screens/story_viewer_screen.dart` | اصلاح و استانداردسازی | نمایش استوری‌های ۲۴ ساعته |
| `lib/features/feed/screens/create_story_screen.dart` | اصلاح و استانداردسازی | ایجاد و ارسال استوری ۲۴ ساعته |
| `lib/features/dashboard/screens/student_ai_assistant_screen.dart` | ارتقای کامل | چت هوشمند با هوش مصنوعی Google Gemini |
| `lib/features/dashboard/screens/student_support_screen.dart` | افزوده / ارتقا | سیستم تیکت و چت آنلاین پشتیبانی |
| `lib/features/admin/screens/admin_support_requests_screen.dart` | افزوده / ارتقا | پنل ادمین برای مدیریت تیکت‌های پشتیبانی |
| `safi_academy_expansion_schema.sql` | افزوده شد | اسکریپت اولیه دیتابیس دایرکت، استوری و ریلز |
| `APP_CHANGES_AND_SYSTEM_MANUAL.md` | ایجاد شد | مستندات رسمی و مرجع فنی کلیه تغییرات اپلیکیشن |

---
**پایان مستندات** — این فایل برای آرشیو و نگهداری ثبت گردید.
