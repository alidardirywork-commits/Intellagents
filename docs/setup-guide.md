# Setup-Anleitung: Jana – Voice Agent für Physiotherapie im Sprengelkiez

## Übersicht

Dieses Projekt implementiert einen KI-gestützten Telefonassistenten ("Jana") für die Physiotherapie im Sprengelkiez. Der Agent nimmt eingehende Anrufe entgegen, beantwortet häufige Fragen, qualifiziert Terminanfragen und leitet bei Bedarf an echte Mitarbeiter weiter.

### Architektur

```
Anruf → Retell AI (Voice) → Claude Sonnet (LLM) → Tools:
                                                     ├── save_lead → n8n Webhook → Supabase
                                                     └── transfer_call → Praxis-Telefon
```

---

## 1. Supabase einrichten

### 1.1 Projekt erstellen

1. Gehe zu [supabase.com](https://supabase.com) und erstelle ein neues Projekt
2. Wähle die Region `eu-central-1` (Frankfurt) für niedrige Latenz

### 1.2 Tabelle anlegen

1. Öffne den **SQL Editor** in Supabase
2. Kopiere den Inhalt von `supabase/schema.sql` und führe ihn aus
3. Überprüfe unter **Table Editor**, dass die Tabelle `leads` erstellt wurde

### 1.3 API-Schlüssel notieren

Unter **Settings → API** findest du:
- **Project URL** → z.B. `https://xxxxx.supabase.co`
- **service_role Key** → wird für n8n benötigt (nicht den anon Key!)

---

## 2. n8n einrichten

### 2.1 Workflow importieren

1. Öffne deine n8n-Instanz
2. Gehe zu **Workflows → Import from File**
3. Importiere `n8n/workflow.json`

### 2.2 Credentials konfigurieren

#### Supabase-Credential:
1. Gehe zu **Credentials → New Credential → Supabase**
2. Trage ein:
   - **Host:** Deine Supabase Project URL
   - **Service Role Key:** Der service_role Key aus Schritt 1.3

#### SMTP-Credential (für E-Mail-Benachrichtigung):
1. Gehe zu **Credentials → New Credential → SMTP**
2. Trage die SMTP-Daten des Praxis-E-Mail-Kontos ein
3. Alternativ: Lösche den E-Mail-Node und verbinde "Supabase – Lead speichern" direkt mit "Response – Erfolg"

### 2.3 Workflow aktivieren

1. Öffne den importierten Workflow
2. Aktualisiere die Credential-Referenzen in den Nodes
3. Klicke auf **Active** (Toggle oben rechts)
4. Notiere die **Webhook-URL** → z.B. `https://deine-n8n-instanz.com/webhook/retell-lead`

### 2.4 Webhook testen

```bash
curl -X POST https://DEINE-N8N-URL/webhook/retell-lead \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Max Mustermann",
    "phone": "+491701234567",
    "reason": "Rückenschmerzen",
    "prescription": "Verordnung",
    "new_patient": true
  }'
```

Erwartete Antwort: `{ "success": true, "message": "Lead gespeichert", "lead_id": "..." }`

---

## 3. Retell AI einrichten

### 3.1 Agent erstellen

1. Gehe zu [retellai.com](https://retellai.com) und logge dich ein
2. Erstelle einen neuen **Agent**

### 3.2 LLM konfigurieren

1. Wähle **Custom LLM** → **Claude** als Provider
2. Modell: `claude-sonnet-4-20250514`
3. Kopiere den gesamten Inhalt von `retell-ai/system-prompt.md` als System Prompt

### 3.3 Voice konfigurieren

1. Wähle **ElevenLabs** als Voice Provider
2. Wähle eine natürlich klingende deutsche Stimme (z.B. "Anna")
3. Sprache: `de-DE`
4. Stability: `0.6`
5. Similarity Boost: `0.8`

### 3.4 Conversation Settings

| Einstellung | Wert |
|---|---|
| Responsiveness | 1.0 |
| Interruption Sensitivity | 0.5 (Medium) |
| Backchannel | Aktiviert |
| Max Call Duration | 600 Sekunden |
| Begin Message | Deaktiviert (Agent beginnt mit Begrüßung aus System Prompt) |
| End Call After Silence | 30 Sekunden |

### 3.5 Tools konfigurieren

#### Tool 1: `save_lead`

1. Erstelle ein neues **Custom Tool** vom Typ **Webhook**
2. Name: `save_lead`
3. Beschreibung: `Speichert die Lead-Daten eines Patienten, der einen Termin vereinbaren möchte. Rufe dieses Tool auf, nachdem du alle Qualifizierungsfragen gestellt und beantwortet bekommen hast.`
4. URL: Deine n8n Webhook-URL aus Schritt 2.3
5. Method: `POST`
6. Header: `Content-Type: application/json`
7. Parameter (siehe `retell-ai/agent-config.json` für das vollständige Schema):
   - `name` (string, required)
   - `phone` (string, required)
   - `reason` (string, required)
   - `prescription` (string, enum: Verordnung/Selbstzahler, required)
   - `new_patient` (boolean, required)

#### Tool 2: `transfer_call`

1. Erstelle ein neues Tool vom Typ **Transfer Call**
2. Name: `transfer_call`
3. Beschreibung: `Leitet den Anruf an das Praxis-Team weiter.`
4. Zielnummer: `+493045364460`

### 3.6 Telefonnummer zuweisen

1. Gehe zu **Phone Numbers** in Retell AI
2. Kaufe eine deutsche Nummer oder verbinde eine bestehende (z.B. via Twilio)
3. Weise die Nummer dem Agent "Jana" zu

---

## 4. Testen

### Test-Szenarien

| # | Szenario | Erwartetes Ergebnis |
|---|---|---|
| 1 | Terminwunsch mit Verordnung (Neupatient) | 5 Fragen → Lead gespeichert → Transfer |
| 2 | Terminwunsch als Selbstzahler (Bestandspatient) | 5 Fragen → Lead gespeichert → Transfer |
| 3 | Preisfrage Massage | Direkte Antwort: 30 € / 20 Min |
| 4 | Frage nach Öffnungszeiten | Mo–Fr 09:00–18:00 |
| 5 | Frage nach Adresse/ÖPNV | Sprengelstraße 47, U6/U9 Leopoldplatz |
| 6 | Patient fragt nach Diagnose | Sofortiger Transfer |
| 7 | Unklare Aussage | Agent fragt nach |
| 8 | Patient will sofort Menschen | Sofortiger Transfer ohne Qualifizierung |
| 9 | Lead in Supabase prüfen | Datensatz mit allen Feldern vorhanden |
| 10 | Transfer landet bei richtiger Nummer | 030 453 64 46 |

### Checkliste

- [ ] Supabase-Tabelle `leads` existiert
- [ ] n8n Workflow ist aktiv
- [ ] Webhook-Test liefert `{ "success": true }`
- [ ] Retell Agent ist konfiguriert mit System Prompt
- [ ] Tools `save_lead` und `transfer_call` sind angelegt
- [ ] Telefonnummer ist dem Agent zugewiesen
- [ ] Testanruf: FAQ-Frage wird korrekt beantwortet
- [ ] Testanruf: Lead wird vollständig gespeichert
- [ ] Testanruf: Transfer funktioniert
- [ ] E-Mail-Benachrichtigung kommt an (optional)

---

## 5. Platzhalter ersetzen

Vor der Inbetriebnahme müssen diese Platzhalter ersetzt werden:

| Platzhalter | Datei | Beschreibung |
|---|---|---|
| `{{N8N_WEBHOOK_URL}}` | `retell-ai/agent-config.json` | n8n Webhook-URL |
| `REPLACE_WITH_GERMAN_VOICE_ID` | `retell-ai/agent-config.json` | ElevenLabs Voice ID |
| `REPLACE_WITH_CREDENTIAL_ID` | `n8n/workflow.json` | n8n Supabase Credential ID |
| `REPLACE_WITH_SMTP_CREDENTIAL_ID` | `n8n/workflow.json` | n8n SMTP Credential ID |

---

## 6. Produktionsbetrieb

### Monitoring

- Retell AI Dashboard: Anruf-Logs, Dauer, Erfolgsrate
- Supabase Dashboard: Neue Leads, Status-Verteilung
- n8n Execution Log: Webhook-Aufrufe, Fehler

### Empfohlene Erweiterungen

- **Slack-Benachrichtigung** statt/zusätzlich E-Mail
- **Kalender-Integration** (Cal.com / Google Calendar) für echte Terminbuchung
- **CRM-Integration** für Lead-Nachverfolgung
- **Analytics-Dashboard** für KPIs (Anrufe/Tag, Conversion, avg. Dauer)
