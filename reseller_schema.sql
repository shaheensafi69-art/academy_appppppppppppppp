-- ====================================================================
-- SAFI ACADEMY - RESELLER PRODUCTS, ORDERS & SYNC LOGS SCHEMA
-- ====================================================================

-- 1. 🛍️ جدول محصولات ریسیلر (Reseller Products)
CREATE TABLE IF NOT EXISTS public.reseller_products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    external_product_id TEXT UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    category TEXT DEFAULT 'Trading Gear',
    cost_price NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    profit_type TEXT DEFAULT 'percentage', -- 'fixed' or 'percentage'
    profit_margin NUMERIC(12, 2) NOT NULL DEFAULT 20.00,
    selling_price NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    currency TEXT DEFAULT 'USD',
    in_stock BOOLEAN NOT NULL DEFAULT true,
    is_active BOOLEAN NOT NULL DEFAULT true,
    last_synced_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reseller_products_active 
ON public.reseller_products(is_active);

CREATE INDEX IF NOT EXISTS idx_reseller_products_category 
ON public.reseller_products(category);


-- 2. 🧾 جدول سفارشات ثبت شده ریسیلر (Reseller Orders)
CREATE TABLE IF NOT EXISTS public.reseller_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    product_id UUID REFERENCES public.reseller_products(id) ON DELETE SET NULL,
    external_order_id TEXT UNIQUE,
    cost_price NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    sale_price NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    profit_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    order_payload JSONB DEFAULT '{}'::jsonb,
    api_response JSONB DEFAULT '{}'::jsonb,
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'approved', 'completed', 'cancelled'
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reseller_orders_student 
ON public.reseller_orders(student_id);

CREATE INDEX IF NOT EXISTS idx_reseller_orders_status 
ON public.reseller_orders(status);


-- 3. 🔄 جدول لاگ‌های همگام‌سازی (Reseller Sync Logs)
CREATE TABLE IF NOT EXISTS public.reseller_sync_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    items_updated INT DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'success', -- 'success', 'failed', 'partial'
    log_details JSONB DEFAULT '{}'::jsonb,
    synced_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reseller_sync_logs_date 
ON public.reseller_sync_logs(synced_at DESC);


-- امنیت RLS
ALTER TABLE public.reseller_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reseller_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reseller_sync_logs ENABLE ROW LEVEL SECURITY;

-- قوانین خواندن محصولات (برای عموم کاربران لاگین شده و مهمان)
CREATE POLICY "Public Read Reseller Products" ON public.reseller_products 
FOR SELECT USING (is_active = true);

-- قوانین سفارشات: هر کاربر سفارشات خودش را ببیند
CREATE POLICY "Users Read Own Orders" ON public.reseller_orders 
FOR SELECT USING (auth.uid() = student_id);

CREATE POLICY "Users Insert Own Orders" ON public.reseller_orders 
FOR INSERT WITH CHECK (auth.uid() = student_id OR auth.role() = 'authenticated' OR auth.role() = 'anon');

-- قوانین ادمین: دسترسی کامل
CREATE POLICY "Admin All Reseller Products" ON public.reseller_products 
FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Admin All Reseller Orders" ON public.reseller_orders 
FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Admin All Reseller Sync Logs" ON public.reseller_sync_logs 
FOR ALL USING (auth.role() = 'authenticated');
