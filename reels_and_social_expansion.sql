-- ==============================================================================
-- SAFI ACADEMY: REELS BOOKMARKS & FOLLOWERS EXPANSION MIGRATION
-- ==============================================================================

-- 1. جدول ذخیره / بوکمارک ریلزها (Reel Bookmarks)
CREATE TABLE IF NOT EXISTS public.reel_bookmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reel_id UUID NOT NULL REFERENCES public.reels(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(reel_id, user_id)
);

-- ایندکس‌های کارایی بالا
CREATE INDEX IF NOT EXISTS idx_reel_bookmarks_user ON public.reel_bookmarks(user_id);
CREATE INDEX IF NOT EXISTS idx_reel_bookmarks_reel ON public.reel_bookmarks(reel_id);

-- فعال‌سازی امنیت سطح سطر (RLS)
ALTER TABLE public.reel_bookmarks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own reel bookmarks" 
ON public.reel_bookmarks FOR SELECT 
TO authenticated 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own reel bookmarks" 
ON public.reel_bookmarks FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own reel bookmarks" 
ON public.reel_bookmarks FOR DELETE 
TO authenticated 
USING (auth.uid() = user_id);

-- 2. جدول فالوور و فالووینگ (Followers & Following مشابه اینستاگرام و تیک‌تاک)
CREATE TABLE IF NOT EXISTS public.user_follows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    follower_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    following_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(follower_id, following_id)
);

-- ایندکس‌های کارایی بالا
CREATE INDEX IF NOT EXISTS idx_user_follows_follower ON public.user_follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_user_follows_following ON public.user_follows(following_id);

-- فعال‌سازی امنیت سطح سطر (RLS)
ALTER TABLE public.user_follows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone authenticated can view follows" 
ON public.user_follows FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY "Users can follow other users" 
ON public.user_follows FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "Users can unfollow" 
ON public.user_follows FOR DELETE 
TO authenticated 
USING (auth.uid() = follower_id);

-- دسترسی به نقش کاربران وارد شده
GRANT ALL ON public.reel_bookmarks TO authenticated;
GRANT ALL ON public.user_follows TO authenticated;
