-- ============================================================
-- Supabase Schema: Leads-Tabelle für Physiotherapie-Voice-Agent
-- ============================================================

-- Tabelle für eingehende Leads aus dem Retell AI Voice Agent
CREATE TABLE IF NOT EXISTS leads (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  reason TEXT,
  prescription TEXT CHECK (prescription IN ('Verordnung', 'Selbstzahler')),
  new_patient BOOLEAN DEFAULT true,
  timestamp TIMESTAMPTZ DEFAULT now(),
  source TEXT DEFAULT 'retell_ai',
  status TEXT DEFAULT 'new' CHECK (status IN ('new', 'contacted', 'booked', 'cancelled')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Index für schnelle Abfragen nach Status (z.B. alle neuen Leads)
CREATE INDEX IF NOT EXISTS idx_leads_status ON leads(status);

-- Index für zeitbasierte Abfragen
CREATE INDEX IF NOT EXISTS idx_leads_created_at ON leads(created_at DESC);

-- Row Level Security aktivieren
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;

-- Policy: Nur authentifizierte Nutzer dürfen lesen
CREATE POLICY "Authenticated users can read leads"
  ON leads FOR SELECT
  TO authenticated
  USING (true);

-- Policy: Service-Rolle (n8n Webhook) darf Leads einfügen
CREATE POLICY "Service role can insert leads"
  ON leads FOR INSERT
  TO service_role
  WITH CHECK (true);

-- Policy: Authentifizierte Nutzer dürfen Status aktualisieren
CREATE POLICY "Authenticated users can update lead status"
  ON leads FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- ============================================================
-- Appointments-Tabelle für gebuchte Termine
-- ============================================================

CREATE TABLE IF NOT EXISTS appointments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  patient_name TEXT NOT NULL,
  patient_phone TEXT NOT NULL,
  reason TEXT,
  prescription TEXT CHECK (prescription IN ('Verordnung', 'Selbstzahler')),
  new_patient BOOLEAN DEFAULT true,
  slot_start TIMESTAMPTZ NOT NULL,
  slot_end TIMESTAMPTZ NOT NULL,
  google_event_id TEXT,
  sms_sent BOOLEAN DEFAULT false,
  source TEXT DEFAULT 'retell_ai',
  status TEXT DEFAULT 'confirmed' CHECK (status IN ('confirmed', 'cancelled', 'completed', 'no_show')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_appointments_status ON appointments(status);
CREATE INDEX IF NOT EXISTS idx_appointments_slot_start ON appointments(slot_start);
CREATE INDEX IF NOT EXISTS idx_appointments_patient_phone ON appointments(patient_phone);

-- Row Level Security
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read appointments"
  ON appointments FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Service role can insert appointments"
  ON appointments FOR INSERT
  TO service_role
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update appointments"
  ON appointments FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);
