-- Core Infrastructure Tables for Flow Into The Missions
-- Full property management + community platform

-- ============================================================
-- PROFILES (extends Supabase auth.users)
-- ============================================================
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  full_name TEXT,
  avatar_url TEXT,
  phone TEXT,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('admin', 'staff', 'member', 'resident', 'associate')),
  is_active BOOLEAN NOT NULL DEFAULT true,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public profiles are viewable by everyone" ON profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Admins can insert profiles" ON profiles FOR INSERT WITH CHECK (true);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, email, full_name, avatar_url)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', ''),
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', NEW.raw_user_meta_data->>'picture', '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- SPACES (rooms, units, common areas)
-- ============================================================
CREATE TABLE IF NOT EXISTS spaces (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'room' CHECK (type IN ('room', 'unit', 'common_area', 'office', 'outdoor', 'storage')),
  description TEXT,
  capacity INTEGER DEFAULT 1,
  floor TEXT,
  building TEXT,
  is_available BOOLEAN NOT NULL DEFAULT true,
  is_archived BOOLEAN NOT NULL DEFAULT false,
  amenities JSONB DEFAULT '[]',
  photos JSONB DEFAULT '[]',
  rate_daily NUMERIC(10,2),
  rate_weekly NUMERIC(10,2),
  rate_monthly NUMERIC(10,2),
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE spaces ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view spaces" ON spaces FOR SELECT USING (true);
CREATE POLICY "Authenticated can manage spaces" ON spaces FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================================
-- TENANTS / RESIDENTS
-- ============================================================
CREATE TABLE IF NOT EXISTS tenants (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id),
  full_name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  space_id UUID REFERENCES spaces(id),
  move_in_date DATE,
  move_out_date DATE,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'pending', 'archived')),
  emergency_contact JSONB DEFAULT '{}',
  notes TEXT,
  is_archived BOOLEAN NOT NULL DEFAULT false,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated can view tenants" ON tenants FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated can manage tenants" ON tenants FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================================
-- BOOKINGS
-- ============================================================
CREATE TABLE IF NOT EXISTS bookings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  space_id UUID REFERENCES spaces(id) NOT NULL,
  tenant_id UUID REFERENCES tenants(id),
  guest_name TEXT,
  guest_email TEXT,
  guest_phone TEXT,
  check_in DATE NOT NULL,
  check_out DATE NOT NULL,
  status TEXT NOT NULL DEFAULT 'confirmed' CHECK (status IN ('pending', 'confirmed', 'checked_in', 'checked_out', 'cancelled')),
  total_amount NUMERIC(10,2),
  payment_status TEXT DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'partial', 'paid', 'refunded')),
  notes TEXT,
  is_archived BOOLEAN NOT NULL DEFAULT false,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated can view bookings" ON bookings FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated can manage bookings" ON bookings FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================================
-- EVENTS
-- ============================================================
CREATE TABLE IF NOT EXISTS events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  location TEXT,
  space_id UUID REFERENCES spaces(id),
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ,
  is_public BOOLEAN NOT NULL DEFAULT true,
  max_attendees INTEGER,
  cover_image TEXT,
  organizer_id UUID REFERENCES profiles(id),
  status TEXT NOT NULL DEFAULT 'upcoming' CHECK (status IN ('upcoming', 'active', 'completed', 'cancelled')),
  is_archived BOOLEAN NOT NULL DEFAULT false,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public events viewable by all" ON events FOR SELECT USING (is_public = true);
CREATE POLICY "Authenticated can view all events" ON events FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated can manage events" ON events FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================================
-- EVENT REGISTRATIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS event_registrations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id UUID REFERENCES events(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES profiles(id),
  name TEXT,
  email TEXT,
  status TEXT NOT NULL DEFAULT 'registered' CHECK (status IN ('registered', 'attended', 'cancelled')),
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE event_registrations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated can view registrations" ON event_registrations FOR SELECT TO authenticated USING (true);
CREATE POLICY "Anyone can register for events" ON event_registrations FOR INSERT WITH CHECK (true);

-- ============================================================
-- DEVICES (smart home, equipment)
-- ============================================================
CREATE TABLE IF NOT EXISTS devices (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'other' CHECK (type IN ('lock', 'camera', 'thermostat', 'light', 'sensor', 'appliance', 'vehicle', 'other')),
  brand TEXT,
  model TEXT,
  serial_number TEXT,
  space_id UUID REFERENCES spaces(id),
  status TEXT NOT NULL DEFAULT 'online' CHECK (status IN ('online', 'offline', 'maintenance', 'retired')),
  last_seen_at TIMESTAMPTZ,
  config JSONB DEFAULT '{}',
  is_archived BOOLEAN NOT NULL DEFAULT false,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated can view devices" ON devices FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated can manage devices" ON devices FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================================
-- CONTACTS / CRM
-- ============================================================
CREATE TABLE IF NOT EXISTS contacts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  full_name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  company TEXT,
  role TEXT,
  type TEXT NOT NULL DEFAULT 'general' CHECK (type IN ('general', 'vendor', 'partner', 'donor', 'volunteer', 'lead')),
  notes TEXT,
  is_archived BOOLEAN NOT NULL DEFAULT false,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated can view contacts" ON contacts FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated can manage contacts" ON contacts FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================================
-- COMMUNICATIONS LOG (emails, SMS sent)
-- ============================================================
CREATE TABLE IF NOT EXISTS communications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  channel TEXT NOT NULL CHECK (channel IN ('email', 'sms', 'push', 'in_app')),
  direction TEXT NOT NULL DEFAULT 'outbound' CHECK (direction IN ('inbound', 'outbound')),
  recipient TEXT,
  sender TEXT,
  subject TEXT,
  body TEXT,
  status TEXT NOT NULL DEFAULT 'sent' CHECK (status IN ('queued', 'sent', 'delivered', 'failed', 'bounced')),
  related_type TEXT,
  related_id UUID,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE communications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated can view communications" ON communications FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated can insert communications" ON communications FOR INSERT TO authenticated WITH CHECK (true);

-- ============================================================
-- PAYMENTS
-- ============================================================
CREATE TABLE IF NOT EXISTS payments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  tenant_id UUID REFERENCES tenants(id),
  booking_id UUID REFERENCES bookings(id),
  amount NUMERIC(10,2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'USD',
  provider TEXT NOT NULL CHECK (provider IN ('square', 'stripe', 'cash', 'check', 'other')),
  provider_payment_id TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
  description TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated can view payments" ON payments FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated can manage payments" ON payments FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================================
-- DOCUMENTS (leases, agreements, e-signatures)
-- ============================================================
CREATE TABLE IF NOT EXISTS documents (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'general' CHECK (type IN ('lease', 'agreement', 'invoice', 'receipt', 'general', 'policy')),
  file_url TEXT,
  file_path TEXT,
  tenant_id UUID REFERENCES tenants(id),
  signwell_document_id TEXT,
  signature_status TEXT DEFAULT 'unsigned' CHECK (signature_status IN ('unsigned', 'pending', 'signed', 'declined', 'expired')),
  signed_at TIMESTAMPTZ,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated can view documents" ON documents FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated can manage documents" ON documents FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================================
-- PHOTOS / GALLERY
-- ============================================================
CREATE TABLE IF NOT EXISTS photos (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT,
  description TEXT,
  url TEXT NOT NULL,
  storage_path TEXT,
  space_id UUID REFERENCES spaces(id),
  event_id UUID REFERENCES events(id),
  uploaded_by UUID REFERENCES profiles(id),
  is_public BOOLEAN NOT NULL DEFAULT true,
  is_archived BOOLEAN NOT NULL DEFAULT false,
  tags JSONB DEFAULT '[]',
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE photos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public photos viewable by all" ON photos FOR SELECT USING (is_public = true);
CREATE POLICY "Authenticated can view all photos" ON photos FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated can manage photos" ON photos FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================================
-- SMS CONFIG (Telnyx)
-- ============================================================
CREATE TABLE IF NOT EXISTS telnyx_config (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  api_key TEXT NOT NULL,
  messaging_profile_id TEXT NOT NULL,
  phone_number TEXT NOT NULL,
  webhook_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE telnyx_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated can read telnyx config" ON telnyx_config FOR SELECT TO authenticated USING (true);

-- ============================================================
-- SMS MESSAGES LOG
-- ============================================================
CREATE TABLE IF NOT EXISTS sms_messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  direction TEXT NOT NULL DEFAULT 'outbound' CHECK (direction IN ('inbound', 'outbound')),
  from_number TEXT NOT NULL,
  to_number TEXT NOT NULL,
  body TEXT,
  status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'sent', 'delivered', 'failed', 'received')),
  provider_message_id TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE sms_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated can view sms messages" ON sms_messages FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated can insert sms messages" ON sms_messages FOR INSERT TO authenticated WITH CHECK (true);

-- ============================================================
-- SQUARE CONFIG
-- ============================================================
CREATE TABLE IF NOT EXISTS square_config (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  application_id TEXT NOT NULL,
  location_id TEXT NOT NULL,
  environment TEXT NOT NULL DEFAULT 'sandbox' CHECK (environment IN ('sandbox', 'production')),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE square_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated can read square config" ON square_config FOR SELECT TO authenticated USING (true);

-- ============================================================
-- STRIPE CONFIG
-- ============================================================
CREATE TABLE IF NOT EXISTS stripe_config (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  publishable_key TEXT NOT NULL,
  environment TEXT NOT NULL DEFAULT 'test' CHECK (environment IN ('test', 'live')),
  webhook_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE stripe_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated can read stripe config" ON stripe_config FOR SELECT TO authenticated USING (true);

-- ============================================================
-- STRIPE PAYMENTS LOG
-- ============================================================
CREATE TABLE IF NOT EXISTS stripe_payments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  payment_intent_id TEXT NOT NULL,
  amount INTEGER NOT NULL,
  currency TEXT NOT NULL DEFAULT 'usd',
  status TEXT NOT NULL,
  payment_method_type TEXT,
  customer_email TEXT,
  description TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE stripe_payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated can view stripe payments" ON stripe_payments FOR SELECT TO authenticated USING (true);
CREATE POLICY "Service can insert stripe payments" ON stripe_payments FOR INSERT WITH CHECK (true);

-- ============================================================
-- SIGNWELL CONFIG
-- ============================================================
CREATE TABLE IF NOT EXISTS signwell_config (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  api_key TEXT NOT NULL,
  webhook_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE signwell_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated can read signwell config" ON signwell_config FOR SELECT TO authenticated USING (true);

-- ============================================================
-- R2 STORAGE CONFIG
-- ============================================================
CREATE TABLE IF NOT EXISTS r2_config (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  account_id TEXT NOT NULL,
  bucket_name TEXT NOT NULL,
  public_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE r2_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated can read r2 config" ON r2_config FOR SELECT TO authenticated USING (true);

-- ============================================================
-- UPDATED_AT TRIGGER FUNCTION (reusable)
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOR tbl IN
    SELECT unnest(ARRAY[
      'profiles', 'spaces', 'tenants', 'bookings', 'events',
      'devices', 'contacts', 'documents', 'photos'
    ])
  LOOP
    EXECUTE format(
      'CREATE TRIGGER update_%s_updated_at BEFORE UPDATE ON %s FOR EACH ROW EXECUTE FUNCTION update_updated_at_column()',
      tbl, tbl
    );
  END LOOP;
END;
$$;
