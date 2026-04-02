-- ============================================================
-- Supabase Schema: Appointments Log für Physiotherapie-Voice-Agent
-- ============================================================

-- Termine Log
CREATE TABLE IF NOT EXISTS appointments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  patient_name TEXT NOT NULL,
  patient_phone TEXT NOT NULL,
  appointment_date DATE NOT NULL,
  appointment_time TIME NOT NULL,
  patient_type TEXT CHECK (patient_type IN ('new_patient', 'existing_patient')),
  prescription BOOLEAN DEFAULT false,
  notes TEXT,
  calendar_event_id TEXT,
  sms_sent BOOLEAN DEFAULT false,
  source TEXT DEFAULT 'retell_ai',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Index für schnelle Abfragen nach Datum
CREATE INDEX IF NOT EXISTS idx_appointments_date ON appointments(appointment_date);

-- Index für Telefonnummer-Suche
CREATE INDEX IF NOT EXISTS idx_appointments_phone ON appointments(patient_phone);

-- Row Level Security aktivieren
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;

-- Policy: Nur authentifizierte Nutzer dürfen lesen
CREATE POLICY "Authenticated users can read appointments"
  ON appointments FOR SELECT
  TO authenticated
  USING (true);

-- Policy: Service-Rolle (n8n Webhook) darf einfügen
CREATE POLICY "Service role can insert appointments"
  ON appointments FOR INSERT
  TO service_role
  WITH CHECK (true);

-- Policy: Service-Rolle darf sms_sent aktualisieren
CREATE POLICY "Service role can update appointments"
  ON appointments FOR UPDATE
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Policy: Authentifizierte Nutzer dürfen aktualisieren
CREATE POLICY "Authenticated users can update appointments"
  ON appointments FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);
