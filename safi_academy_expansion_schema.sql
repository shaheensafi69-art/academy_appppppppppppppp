-- ====================================================================
-- SAFIES ACADEMY - COMPREHENSIVE DATABASE EXPANSION SCHEMA
-- Tables for: Direct Messaging, 24h Stories, Reels (Short Videos),
-- Message Reactions, Story Views, Reel Likes/Comments, and Bookmarks.
-- ====================================================================

-- 1. 💬 جدول چت‌های دایرکت دوطرفه با پشتیبانی از متن، عکس، ویدیو، ویس و فایل
CREATE TABLE IF NOT EXISTS public.direct_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    message_text TEXT,
    attachment_url TEXT,
    attachment_type TEXT DEFAULT 'image', -- 'image', 'video', 'audio', 'document'
    is_delivered BOOLEAN NOT NULL DEFAULT true,
    is_read BOOLEAN NOT NULL DEFAULT false,
    delivered_at TIMESTAMPTZ DEFAULT now(),
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ایندکس‌های پرسرعت چت
CREATE INDEX IF NOT EXISTS idx_direct_messages_conversation 
ON public.direct_messages(sender_id, receiver_id);

CREATE INDEX IF NOT EXISTS idx_direct_messages_receiver_read 
ON public.direct_messages(receiver_id, is_read);

CREATE INDEX IF NOT EXISTS idx_direct_messages_created_at 
ON public.direct_messages(created_at DESC);


-- 2. 👍 جدول واکنش‌ها به پیام‌های دایرکت (Message Reactions)
CREATE TABLE IF NOT EXISTS public.message_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES public.direct_messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    emoji TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_message_user_reaction UNIQUE (message_id, user_id, emoji)
);


-- 3. 📸 جدول استوری‌های ۲۴ ساعته (User 24h Stories)
CREATE TABLE IF NOT EXISTS public.user_stories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    media_url TEXT NOT NULL,
    media_type TEXT NOT NULL DEFAULT 'image', -- 'image' یا 'video'
    caption TEXT,
    duration_seconds INT DEFAULT 15,
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '24 hours'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_stories_user_expires 
ON public.user_stories(user_id, expires_at);


-- 4. 👁️ جدول بازدیدکنندگان استوری (Story Views)
CREATE TABLE IF NOT EXISTS public.story_views (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    story_id UUID NOT NULL REFERENCES public.user_stories(id) ON DELETE CASCADE,
    viewer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    viewed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_story_viewer UNIQUE (story_id, viewer_id)
);


-- 5. 🎬 جدول ریلز و ویدیوهای کوتاه آموزشی (Reels & Short Videos)
CREATE TABLE IF NOT EXISTS public.reels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    video_url TEXT NOT NULL,
    thumbnail_url TEXT,
    title TEXT NOT NULL,
    description TEXT,
    category TEXT DEFAULT 'Educational',
    duration_seconds INT DEFAULT 30,
    views_count INT NOT NULL DEFAULT 0,
    likes_count INT NOT NULL DEFAULT 0,
    comments_count INT NOT NULL DEFAULT 0,
    is_published BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reels_created_at 
ON public.reels(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_reels_category 
ON public.reels(category);


-- 6. ❤️ جدول لایک‌های ریلز (Reel Likes)
CREATE TABLE IF NOT EXISTS public.reel_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reel_id UUID NOT NULL REFERENCES public.reels(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_reel_like UNIQUE (reel_id, user_id)
);


-- 7. 💬 جدول کامنت‌های ریلز (Reel Comments)
CREATE TABLE IF NOT EXISTS public.reel_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reel_id UUID NOT NULL REFERENCES public.reels(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    comment_text TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reel_comments_reel 
ON public.reel_comments(reel_id);


-- 8. 👁️ جدول بازدید ریلز (Reel Views Tracking)
CREATE TABLE IF NOT EXISTS public.reel_views (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reel_id UUID NOT NULL REFERENCES public.reels(id) ON DELETE CASCADE,
    viewer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    viewed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- 9. 🔖 جدول نشان‌کردن پست‌های فید (Discussion Bookmarks)
CREATE TABLE IF NOT EXISTS public.discussion_bookmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES public.discussion_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_discussion_bookmark UNIQUE (post_id, user_id)
);


-- ====================================================================
-- 🔐 فعال‌سازی امنیت سطح سطر (Row Level Security - RLS)
-- ====================================================================

ALTER TABLE public.direct_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.story_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reel_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reel_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reel_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discussion_bookmarks ENABLE ROW LEVEL SECURITY;

-- 1. قوانین چت دایرکت
CREATE POLICY "Direct Messages Select Policy" ON public.direct_messages 
FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "Direct Messages Insert Policy" ON public.direct_messages 
FOR INSERT WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Direct Messages Update Policy" ON public.direct_messages 
FOR UPDATE USING (auth.uid() = receiver_id OR auth.uid() = sender_id);

-- 2. قوانین استوری‌ها
CREATE POLICY "Stories Select Policy" ON public.user_stories 
FOR SELECT USING (expires_at > now());

CREATE POLICY "Stories Insert Policy" ON public.user_stories 
FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Stories Delete Policy" ON public.user_stories 
FOR DELETE USING (auth.uid() = user_id);

-- 3. قوانین ریلز (Reels)
CREATE POLICY "Reels Select Policy" ON public.reels 
FOR SELECT USING (is_published = true);

CREATE POLICY "Reels Insert Policy" ON public.reels 
FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Reels Delete Policy" ON public.reels 
FOR DELETE USING (auth.uid() = user_id);

-- 4. قوانین لایک‌ها و کامنت‌های ریلز
CREATE POLICY "Reel Likes Manage Policy" ON public.reel_likes 
FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Reel Comments Manage Policy" ON public.reel_comments 
FOR ALL USING (auth.uid() = user_id OR auth.role() = 'authenticated');

-- 5. قوانین بوکمارک‌ها
CREATE POLICY "Discussion Bookmarks Manage Policy" ON public.discussion_bookmarks 
FOR ALL USING (auth.uid() = user_id);
