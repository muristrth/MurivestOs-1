-- ============================================================
-- MURIVEST EXECUTIVE OS — PRODUCTION SCHEMA
-- Run this in Supabase SQL Editor
-- Zero mock data. Clean slate for 50M mission.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. SETTINGS — Target configuration
-- ============================================================
CREATE TABLE IF NOT EXISTS settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  annual_target BIGINT DEFAULT 50000000,
  target_currency TEXT DEFAULT 'KES',
  target_year INT DEFAULT 2026,
  target_label TEXT DEFAULT '50M Command',
  daily_outreach_target INT DEFAULT 20,
  daily_content_target INT DEFAULT 2,
  daily_calls_target INT DEFAULT 1,
  daily_deal_moves_target INT DEFAULT 3,
  daily_points_target INT DEFAULT 30,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 2. PIPELINE — Deal tracking
-- ============================================================
CREATE TABLE IF NOT EXISTS pipeline (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  asset TEXT NOT NULL,
  market TEXT NOT NULL,
  size BIGINT NOT NULL DEFAULT 0,
  stage TEXT NOT NULL DEFAULT 'Origination'
    CHECK (stage IN ('Origination','Initial Underwriting','Site Tour','LOI Submitted','Due Diligence','Capital Call','Closed','Dead')),
  fee DECIMAL(6,4) NOT NULL DEFAULT 0.03,
  source TEXT DEFAULT 'Direct',
  next_action TEXT,
  probability DECIMAL(4,2) GENERATED ALWAYS AS (
    CASE stage
      WHEN 'Origination' THEN 0.05
      WHEN 'Initial Underwriting' THEN 0.15
      WHEN 'Site Tour' THEN 0.30
      WHEN 'LOI Submitted' THEN 0.50
      WHEN 'Due Diligence' THEN 0.75
      WHEN 'Capital Call' THEN 0.90
      WHEN 'Closed' THEN 1.00
      ELSE 0.00
    END
  ) STORED,
  gross_fee BIGINT GENERATED ALWAYS AS (ROUND(size * fee)) STORED,
  commission_earned BIGINT GENERATED ALWAYS AS (
    CASE WHEN stage = 'Closed' THEN ROUND(size * fee) ELSE 0 END
  ) STORED,
  priority INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 3. DAILY LOG — Execution tracking (points system)
-- ============================================================
CREATE TABLE IF NOT EXISTS daily_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  activity TEXT NOT NULL CHECK (activity IN (
    'Cold Outreach','Capital Intro Call','LOI Drafted / Submitted',
    'Underwriting Model','Strategy / Research','Site Tour',
    'Due Diligence','Investor Meeting','Content Published','Follow-up Call'
  )),
  counterparty TEXT NOT NULL,
  outcome TEXT NOT NULL,
  impact TEXT DEFAULT 'Medium' CHECK (impact IN ('High','Medium','Low')),
  follow_up_date DATE,
  points DECIMAL(6,2) NOT NULL DEFAULT 0,
  logged_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 4. FLAGSHIP TASKS — Critical path items
-- ============================================================
CREATE TABLE IF NOT EXISTS flagship_tasks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  asset TEXT NOT NULL,
  task TEXT NOT NULL,
  status TEXT DEFAULT 'Not Started' CHECK (status IN ('Not Started','In Progress','Blocked','Done')),
  deadline DATE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 5. CAPITAL PARTNERS — Investor/buyer relationships
-- ============================================================
CREATE TABLE IF NOT EXISTS capital_partners (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  entity_name TEXT NOT NULL,
  tier INT DEFAULT 2 CHECK (tier IN (1,2,3)),
  region TEXT DEFAULT 'Nairobi',
  mandate TEXT NOT NULL,
  target_deployment BIGINT NOT NULL DEFAULT 0,
  probability DECIMAL(4,2) NOT NULL DEFAULT 0.5 CHECK (probability >= 0 AND probability <= 1),
  weighted_value BIGINT GENERATED ALWAYS AS (ROUND(target_deployment * probability)) STORED,
  next_touchpoint DATE NOT NULL,
  contact_email TEXT,
  contact_phone TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 6. MANDATES — Authority to sell
-- ============================================================
CREATE TABLE IF NOT EXISTS mandates (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  mandate_ref TEXT UNIQUE NOT NULL,
  asset TEXT NOT NULL,
  asset_type TEXT DEFAULT 'Office' CHECK (asset_type IN (
    'Office','Retail','Mixed-Use','Hospitality','Industrial','Residential','Land'
  )),
  location TEXT NOT NULL,
  provider TEXT NOT NULL,
  mandate_type TEXT DEFAULT 'Exclusive' CHECK (mandate_type IN (
    'Exclusive','Non-Exclusive','Open Listing','Co-Broker'
  )),
  asking_price BIGINT NOT NULL DEFAULT 0,
  fee DECIMAL(6,4) NOT NULL DEFAULT 0.03,
  gross_fee BIGINT GENERATED ALWAYS AS (ROUND(asking_price * fee)) STORED,
  start_date DATE NOT NULL,
  expiry_date DATE NOT NULL,
  days_remaining INT GENERATED ALWAYS AS (
    (expiry_date - CURRENT_DATE)
  ) STORED,
  status TEXT GENERATED ALWAYS AS (
    CASE
      WHEN expiry_date < CURRENT_DATE THEN 'Expired'
      WHEN expiry_date < CURRENT_DATE + INTERVAL '60 days' THEN 'Expiring'
      ELSE 'Active'
    END
  ) STORED,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 7. PROSPECT TRAFFIC — Lead tracking
-- ============================================================
CREATE TABLE IF NOT EXISTS prospect_traffic (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  prospect_name TEXT NOT NULL,
  company TEXT,
  phone TEXT NOT NULL,
  email TEXT,
  property_shown TEXT NOT NULL,
  source TEXT DEFAULT 'Direct',
  temperature TEXT DEFAULT 'Warm — Reviewing' CHECK (temperature IN (
    'Hot — Ready','Warm — Reviewing','Cold','Offer Submitted','Dead'
  )),
  interaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
  last_contact DATE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 8. OUTREACH LOG — GC-style daily tracking
-- ============================================================
CREATE TABLE IF NOT EXISTS outreach_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  channel TEXT NOT NULL CHECK (channel IN (
    'LinkedIn','WhatsApp','Email','Phone','In-Person','Referral','Content'
  )),
  count INT NOT NULL DEFAULT 1,
  description TEXT,
  outreach_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 9. CONTENT TRACKER — Authority building
-- ============================================================
CREATE TABLE IF NOT EXISTS content_tracker (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  platform TEXT NOT NULL CHECK (platform IN (
    'LinkedIn','Instagram','Website/Blog','YouTube','WhatsApp Broadcast','Twitter/X','Email Newsletter'
  )),
  content_type TEXT NOT NULL CHECK (content_type IN (
    'Deal Breakdown','ROI Analysis','Market Insight','Property Feature','Investor Education','Personal Brand'
  )),
  title TEXT NOT NULL,
  url TEXT,
  published_at DATE NOT NULL DEFAULT CURRENT_DATE,
  reach INT DEFAULT 0,
  engagement INT DEFAULT 0,
  leads_generated INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- VIEWS — Dashboard aggregations
-- ============================================================

CREATE OR REPLACE VIEW commission_summary AS
SELECT
  user_id,
  COALESCE(SUM(commission_earned), 0) AS total_earned,
  COALESCE(SUM(CASE WHEN stage != 'Dead' AND stage != 'Closed' THEN gross_fee ELSE 0 END), 0) AS pipeline_commission,
  COALESCE(SUM(CASE WHEN stage != 'Dead' THEN ROUND(size * fee * probability) ELSE 0 END), 0) AS risk_adjusted,
  COUNT(CASE WHEN stage != 'Dead' AND stage != 'Closed' THEN 1 END) AS active_deals,
  COUNT(CASE WHEN stage = 'Closed' THEN 1 END) AS closed_deals
FROM pipeline
GROUP BY user_id;

CREATE OR REPLACE VIEW daily_points AS
SELECT
  user_id,
  DATE(logged_at) AS log_date,
  SUM(points) AS total_points,
  COUNT(*) AS activity_count
FROM daily_log
GROUP BY user_id, DATE(logged_at);

CREATE OR REPLACE VIEW weekly_momentum AS
SELECT
  user_id,
  DATE(logged_at) AS log_date,
  SUM(points) AS points,
  COUNT(*) AS activities
FROM daily_log
WHERE logged_at >= NOW() - INTERVAL '7 days'
GROUP BY user_id, DATE(logged_at)
ORDER BY log_date;

CREATE OR REPLACE VIEW pipeline_by_stage AS
SELECT
  user_id,
  stage,
  COUNT(*) AS deal_count,
  SUM(size) AS total_value,
  SUM(gross_fee) AS total_fee,
  SUM(ROUND(size * fee * probability)) AS risk_adjusted_fee
FROM pipeline
WHERE stage != 'Dead'
GROUP BY user_id, stage;

CREATE OR REPLACE VIEW overdue_touchpoints AS
SELECT
  cp.*,
  (CURRENT_DATE - next_touchpoint) AS days_overdue
FROM capital_partners cp
WHERE next_touchpoint < CURRENT_DATE
ORDER BY next_touchpoint ASC;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE pipeline ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE flagship_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE capital_partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE mandates ENABLE ROW LEVEL SECURITY;
ALTER TABLE prospect_traffic ENABLE ROW LEVEL SECURITY;
ALTER TABLE outreach_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_tracker ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Own data only" ON settings FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Own data only" ON pipeline FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Own data only" ON daily_log FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Own data only" ON flagship_tasks FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Own data only" ON capital_partners FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Own data only" ON mandates FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Own data only" ON prospect_traffic FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Own data only" ON outreach_log FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Own data only" ON content_tracker FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- FUNCTIONS
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_settings_updated BEFORE UPDATE ON settings FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_pipeline_updated BEFORE UPDATE ON pipeline FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_flagship_updated BEFORE UPDATE ON flagship_tasks FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_capital_updated BEFORE UPDATE ON capital_partners FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_mandates_updated BEFORE UPDATE ON mandates FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_traffic_updated BEFORE UPDATE ON prospect_traffic FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE OR REPLACE FUNCTION generate_mandate_ref()
RETURNS TRIGGER AS $$
BEGIN
  NEW.mandate_ref = 'MND-' || TO_CHAR(NOW(), 'YYYYMMDD-HH24MISS');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_mandate_ref BEFORE INSERT ON mandates FOR EACH ROW
WHEN (NEW.mandate_ref IS NULL OR NEW.mandate_ref = '') EXECUTE FUNCTION generate_mandate_ref();

-- ============================================================
-- INDEXES — Performance
-- ============================================================
CREATE INDEX idx_settings_user ON settings(user_id);
CREATE INDEX idx_pipeline_user_stage ON pipeline(user_id, stage);
CREATE INDEX idx_pipeline_created ON pipeline(user_id, created_at DESC);
CREATE INDEX idx_daily_log_user_date ON daily_log(user_id, logged_at DESC);
CREATE INDEX idx_flagship_user_status ON flagship_tasks(user_id, status);
CREATE INDEX idx_capital_user_tier ON capital_partners(user_id, tier);
CREATE INDEX idx_capital_touchpoint ON capital_partners(user_id, next_touchpoint);
CREATE INDEX idx_mandates_expiry ON mandates(user_id, expiry_date);
CREATE INDEX idx_traffic_user_date ON prospect_traffic(user_id, interaction_date DESC);
CREATE INDEX idx_outreach_date ON outreach_log(user_id, outreach_date DESC);
CREATE INDEX idx_content_date ON content_tracker(user_id, published_at DESC);

-- ============================================================
-- END OF SCHEMA
-- ============================================================
