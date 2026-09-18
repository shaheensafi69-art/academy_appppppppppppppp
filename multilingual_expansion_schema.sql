-- ====================================================================
-- SAFI ACADEMY - MULTILINGUAL (19 LANGUAGES) EXPANSION SCHEMA
-- Supported Languages (Matching Safi Academy Official Website):
-- 1. English (en) - GB
-- 2. Persian / Dari (fa) - AF
-- 3. Pashto (ps) - AF
-- 4. Russian (ru) - RU
-- 5. Turkish (tr) - TR
-- 6. German (de) - DE
-- 7. French (fr) - FR
-- 8. Arabic (ar) - SA
-- 9. Urdu (ur) - PK
-- 10. Spanish (es) - ES
-- 11. Chinese (zh) - CN
-- 12. Hindi (hi) - IN
-- 13. Italian (it) - IT
-- 14. Portuguese (pt) - PT
-- 15. Japanese (ja) - JP
-- 16. Korean (ko) - KR
-- 17. Dutch (nl) - NL
-- 18. Uzbek (uz) - UZ
-- 19. Indonesian (id) - ID
-- ====================================================================

-- 1. 👤 ذخیره زبان انتخابی و کاورپیج کاربر در جدول پروفایل
ALTER TABLE IF EXISTS public.profiles 
ADD COLUMN IF NOT EXISTS preferred_language VARCHAR(10) DEFAULT 'en',
ADD COLUMN IF NOT EXISTS cover_url TEXT;

CREATE INDEX IF NOT EXISTS idx_profiles_preferred_language 
ON public.profiles(preferred_language);


-- 2. 🎓 پشتیبانی از چندزبانه در دوره‌ها (Courses)
ALTER TABLE IF EXISTS public.courses 
ADD COLUMN IF NOT EXISTS language VARCHAR(10) DEFAULT 'en',
ADD COLUMN IF NOT EXISTS translation_group_id UUID DEFAULT gen_random_uuid();

CREATE INDEX IF NOT EXISTS idx_courses_language 
ON public.courses(language);

CREATE INDEX IF NOT EXISTS idx_courses_translation_group 
ON public.courses(translation_group_id, language);


-- 3. 🌍 جدول بورسیه‌ها (Scholarships)
ALTER TABLE IF EXISTS public.scholarships 
ADD COLUMN IF NOT EXISTS language VARCHAR(10) DEFAULT 'en',
ADD COLUMN IF NOT EXISTS translation_group_id UUID DEFAULT gen_random_uuid();

CREATE INDEX IF NOT EXISTS idx_scholarships_language 
ON public.scholarships(language);

CREATE INDEX IF NOT EXISTS idx_scholarships_trans_group 
ON public.scholarships(translation_group_id, language);


-- 4. 📰 جدول وبلاگ‌ها و مقالات (Blogs)
ALTER TABLE IF EXISTS public.blogs 
ADD COLUMN IF NOT EXISTS language VARCHAR(10) DEFAULT 'en',
ADD COLUMN IF NOT EXISTS translation_group_id UUID DEFAULT gen_random_uuid();

CREATE INDEX IF NOT EXISTS idx_blogs_language 
ON public.blogs(language);

CREATE INDEX IF NOT EXISTS idx_blogs_trans_group 
ON public.blogs(translation_group_id, language);


-- 5. 🤝 جدول شرکا و همکاران (Partners)
ALTER TABLE IF EXISTS public.partners 
ADD COLUMN IF NOT EXISTS language VARCHAR(10) DEFAULT 'en',
ADD COLUMN IF NOT EXISTS translation_group_id UUID DEFAULT gen_random_uuid();

CREATE INDEX IF NOT EXISTS idx_partners_language 
ON public.partners(language);


-- 6. 📢 جدول اطلاعیه‌ها و اعلانات عمومی (Announcements)
ALTER TABLE IF EXISTS public.announcements 
ADD COLUMN IF NOT EXISTS language VARCHAR(10) DEFAULT 'all',
ADD COLUMN IF NOT EXISTS translation_group_id UUID;

CREATE INDEX IF NOT EXISTS idx_announcements_language 
ON public.announcements(language);


-- 7. 🎁 جدول کمپین‌های اهدایی و خیریه (Donation Campaigns)
ALTER TABLE IF EXISTS public.donation_campaigns 
ADD COLUMN IF NOT EXISTS language VARCHAR(10) DEFAULT 'en',
ADD COLUMN IF NOT EXISTS translation_group_id UUID DEFAULT gen_random_uuid();

CREATE INDEX IF NOT EXISTS idx_donation_campaigns_language 
ON public.donation_campaigns(language);


-- 8. 📝 جدول درخواست‌های تدریس مدرسین (Instructor Applications)
ALTER TABLE IF EXISTS public.instructor_applications 
ADD COLUMN IF NOT EXISTS language VARCHAR(10) DEFAULT 'en';


-- 9. ⚡ فانکشن کمکی برای خواندن محتوا با فال‌بک خودکار به انگلیسی (Fallback to 'en')
-- اگر ترجمه‌ای به زبان انتخابی کاربر وجود نداشت، نسخه انگلیسی را برمی‌گرداند
CREATE OR REPLACE FUNCTION get_localized_scholarships(target_lang VARCHAR(10))
RETURNS SETOF public.scholarships AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT ON (COALESCE(s.translation_group_id, s.id)) s.*
    FROM public.scholarships s
    WHERE s.is_active = true
    ORDER BY COALESCE(s.translation_group_id, s.id), 
             CASE WHEN s.language = target_lang THEN 1 
                  WHEN s.language = 'en' THEN 2 
                  ELSE 3 END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
