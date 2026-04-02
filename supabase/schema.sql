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
