# Setup-Anleitung: Jana – KI-Rezeptionistin für Physiotherapie im Sprengelkiez

## Übersicht

KI-Rezeptionistin, die Anrufe entgegennimmt und Termine direkt bucht – ohne Rückruf, ohne Wartezeit.

**Ablauf:** Patient ruft an → Jana bucht Termin → SMS-Bestätigung → fertig. Unter 3 Minuten.

### Architektur

```
Anruf → Retell AI (Voice + ElevenLabs) → Claude Sonnet (LLM)
                                            ├── get_available_slots → n8n → Google Calendar API
                                            ├── book_appointment   → n8n → Google Calendar + Twilio SMS + Supabase + E-Mail
                                            ├── send_sms_confirmation → n8n → Twilio
                                            └── transfer_call      → Praxis-Telefon (030 453 64 46)
```

### Dateistruktur

```
retell-ai/
  system-prompt.md       ← System Prompt für Jana
  agent-config.json      ← Retell AI Agent-Konfiguration
  test-scenarios.json    ← 10 Testszenarien
n8n/
  workflow-slots.json    ← Workflow A: Freie Slots abrufen
  workflow-booking.json  ← Workflow B: Buchen + SMS + Calendar + Log
supabase/
  schema.sql             ← Datenbank-Schema (Appointments Log)
docs/
  setup-guide.md         ← Diese Datei
```

---

## 1. Google Calendar API einrichten

### 1.1 Google Cloud Projekt

1. Gehe zu [console.cloud.google.com](https://console.cloud.google.com)
2. Erstelle ein neues Projekt: **Physio Sprengelkiez**
3. Aktiviere die **Google Calendar API** unter APIs & Services → Library

### 1.2 OAuth 2.0 Credentials

1. Gehe zu **APIs & Services → Credentials**
2. Erstelle **OAuth 2.0 Client ID** (Typ: Web Application)
3. Redirect URI hinzufügen: `https://DEINE-N8N-URL/rest/oauth2-credential/callback`
4. Notiere **Client ID** und **Client Secret**

### 1.3 Praxis-Kalender

1. Erstelle einen Google Calendar für die Praxis (oder nutze einen bestehenden)
2. Notiere die **Calendar ID** (unter Kalender-Einstellungen → Kalender integrieren)
   - Format: `xxxxxxx@group.calendar.google.com` oder E-Mail-Adresse

---

## 2. Twilio Account einrichten

### 2.1 Account erstellen

1. Registriere bei [twilio.com](https://www.twilio.com)
2. Notiere **Account SID** und **Auth Token** (Dashboard)

### 2.2 Telefonnummer kaufen

1. Gehe zu **Phone Numbers → Buy a Number**
2. Kaufe eine deutsche Nummer (+49) mit SMS-Fähigkeit
3. Notiere die Nummer (Format: `+49...`)

### 2.3 SMS testen

```bash
curl -X POST "https://api.twilio.com/2010-04-01/Accounts/ACCOUNT_SID/Messages.json" \
  -u "ACCOUNT_SID:AUTH_TOKEN" \
  -d "From=+49TWILIO_NUMMER" \
  -d "To=+49DEINE_NUMMER" \
  -d "Body=Testmeldung von Jana"
```

---

## 3. Supabase einrichten

### 3.1 Projekt erstellen

1. Gehe zu [supabase.com](https://supabase.com)
2. Neues Projekt erstellen, Region: **eu-central-1** (Frankfurt)

### 3.2 Schema anlegen

1. Öffne **SQL Editor**
2. Kopiere den Inhalt von `supabase/schema.sql` und führe aus
3. Prüfe unter **Table Editor**: Tabelle `appointments` existiert

### 3.3 API-Schlüssel notieren

Unter **Settings → API**:
- **Project URL** → `https://xxxxx.supabase.co`
- **service_role Key** → wird für n8n benötigt (NICHT den anon Key)

---

## 4. n8n Credentials konfigurieren

### 4.1 Google Calendar Credential

1. **Credentials → New → Google Calendar (OAuth2)**
2. Trage Client ID und Client Secret ein
3. Klicke **Connect** und autorisiere den Zugriff

### 4.2 Twilio Credential

1. **Credentials → New → Twilio**
2. Trage ein:
   - Account SID
   - Auth Token

### 4.3 Supabase Credential

1. **Credentials → New → Supabase**
2. Trage ein:
   - Host: Deine Supabase Project URL
   - Service Role Key

### 4.4 SMTP Credential (für E-Mail-Benachrichtigung)

1. **Credentials → New → SMTP**
2. Trage SMTP-Daten des Praxis-E-Mail-Kontos ein
3. *Optional:* Kann auch weggelassen werden – E-Mail-Node dann aus Workflow entfernen

---

## 5. n8n Workflows importieren & aktivieren

### 5.1 Workflow A – Freie Slots

1. **Workflows → Import from File** → `n8n/workflow-slots.json`
2. Öffne den Workflow und ersetze Platzhalter:
   - `{{GOOGLE_CALENDAR_ID}}` → Deine Calendar ID
   - Google Calendar Credential zuweisen
3. Klicke **Active** (Toggle oben rechts)
4. Notiere die **Webhook-URL**: `https://DEINE-N8N-URL/webhook/retell-slots`

### 5.2 Workflow B – Termin buchen

1. **Workflows → Import from File** → `n8n/workflow-booking.json`
2. Öffne den Workflow und ersetze Platzhalter:
   - `{{GOOGLE_CALENDAR_ID}}` → Deine Calendar ID
   - `{{TWILIO_PHONE_NUMBER}}` → Deine Twilio-Nummer (+49...)
   - Alle Credentials zuweisen (Google Calendar, Twilio, Supabase, SMTP)
3. Klicke **Active**
4. Notiere die **Webhook-URL**: `https://DEINE-N8N-URL/webhook/retell-book`

### 5.3 Workflows testen

**Slots testen:**
```bash
curl -X POST https://DEINE-N8N-URL/webhook/retell-slots \
  -H "Content-Type: application/json" \
  -d '{"duration_minutes": 20, "days_ahead": 5}'
```

Erwartete Antwort: `{ "slots": [{ "date": "Montag, 7. April", "time": "09:00", "slot_id": "2026-04-07_0900" }, ...] }`

**Buchung testen:**
```bash
curl -X POST https://DEINE-N8N-URL/webhook/retell-book \
  -H "Content-Type: application/json" \
  -d '{
    "slot_id": "2026-04-07_0900",
    "patient_name": "Max Mustermann",
    "patient_phone": "+491701234567",
    "patient_type": "new_patient",
    "prescription": true,
    "notes": "Testbuchung"
  }'
```

Erwartete Antwort: `{ "success": true, "calendar_event_id": "...", "sms_sent": true }`

Prüfe danach:
- [ ] Termin in Google Calendar sichtbar
- [ ] SMS auf dem Testhandy empfangen
- [ ] Eintrag in Supabase `appointments` Tabelle
- [ ] E-Mail an info@physio-sprengelkiez.de

---

## 6. Retell AI Agent einrichten

### 6.1 Agent erstellen

1. Gehe zu [retellai.com](https://retellai.com) → Dashboard → **New Agent**
2. Name: **Jana – Physio Sprengelkiez**

### 6.2 LLM konfigurieren

1. Wähle **Custom LLM → Claude** als Provider
2. Modell: `claude-sonnet-4-20250514`
3. Kopiere den gesamten Inhalt von `retell-ai/system-prompt.md` als System Prompt
4. Temperature: `0.4`

### 6.3 Voice konfigurieren

1. Voice Provider: **ElevenLabs**
2. Wähle eine natürlich klingende deutsche Stimme
3. Sprache: `de-DE`
4. Stability: `0.75`
5. Similarity Boost: `0.85`
6. Style: `0.3`
7. Notiere die **Voice ID** und trage sie in `agent-config.json` ein

### 6.4 Conversation Settings

| Einstellung | Wert |
|---|---|
| Responsiveness | 1.0 |
| Interruption Sensitivity | Medium (0.5) |
| Backchannel | Aktiviert: mhm, ja, verstehe, natürlich |
| Max Call Duration | 480 Sekunden (8 Min) |
| Begin Message | Deaktiviert |
| End Call After Silence | 30 Sekunden |

### 6.5 Tools konfigurieren

#### Tool 1: `get_available_slots`
- Typ: **Webhook**
- URL: `https://DEINE-N8N-URL/webhook/retell-slots`
- Method: POST
- Parameter: siehe `agent-config.json`

#### Tool 2: `book_appointment`
- Typ: **Webhook**
- URL: `https://DEINE-N8N-URL/webhook/retell-book`
- Method: POST
- Parameter: siehe `agent-config.json`

#### Tool 3: `send_sms_confirmation`
- Typ: **Webhook**
- URL: `https://DEINE-N8N-URL/webhook/retell-book` (SMS wird im Booking-Workflow mitgesendet)
- *Hinweis:* Die SMS wird bereits automatisch im `book_appointment` Workflow gesendet. Dieses Tool kann als Fallback dienen, falls die SMS im Hauptworkflow nicht verschickt wurde.

#### Tool 4: `transfer_call`
- Typ: **Transfer Call**
- Zielnummer: `+493045364446`

### 6.6 Telefonnummer zuweisen

1. **Phone Numbers** in Retell AI
2. Kaufe eine deutsche Nummer oder verbinde eine bestehende (z.B. via Twilio SIP)
3. Weise die Nummer dem Agent **Jana** zu

---

## 7. Ersten Testanruf machen

### Checkliste vor dem Test

- [ ] Supabase: Tabelle `appointments` existiert
- [ ] n8n: Workflow A (Slots) ist aktiv
- [ ] n8n: Workflow B (Booking) ist aktiv
- [ ] n8n: Alle Credentials sind konfiguriert
- [ ] Retell: Agent ist konfiguriert mit System Prompt
- [ ] Retell: Alle 4 Tools sind angelegt
- [ ] Retell: Telefonnummer ist zugewiesen

### Testszenarien durchspielen

| # | Test | Erwartet |
|---|---|---|
| 1 | Neupatient, Verordnung, Rücken | Termin gebucht, SMS erhalten |
| 2 | Bestandspatient, Selbstzahler, Massage | Termin gebucht, SMS erhalten |
| 3 | Erst Preise fragen, dann Termin | FAQ + Buchung |
| 4 | Gewünschter Slot belegt | Alternative angeboten |
| 5 | Andere Rückrufnummer | Korrekt übernommen |
| 6 | Medizinische Frage | Sofort Transfer |
| 7 | Bestimmten Therapeuten wünschen | Transfer |
| 8 | Keine Slots in 5 Tagen | Erklärung + Transfer |
| 9 | SMS-Bestätigung | Korrekt mit Datum/Zeit/Adresse |
| 10 | Google Calendar | Event mit allen Daten |

Detaillierte Testszenarien: siehe `retell-ai/test-scenarios.json`

---

## 8. Platzhalter-Übersicht

| Platzhalter | Datei(en) | Beschreibung |
|---|---|---|
| `{{N8N_WEBHOOK_SLOTS_URL}}` | `agent-config.json` | n8n Webhook-URL für Slots |
| `{{N8N_WEBHOOK_BOOK_URL}}` | `agent-config.json` | n8n Webhook-URL für Buchung |
| `{{N8N_WEBHOOK_SMS_URL}}` | `agent-config.json` | n8n Webhook-URL für SMS |
| `REPLACE_WITH_GERMAN_VOICE_ID` | `agent-config.json` | ElevenLabs Voice ID |
| `{{GOOGLE_CALENDAR_ID}}` | `workflow-slots.json`, `workflow-booking.json` | Google Calendar ID |
| `{{TWILIO_PHONE_NUMBER}}` | `workflow-booking.json` | Twilio Absender-Nummer |
| `REPLACE_WITH_GOOGLE_CREDENTIAL_ID` | `workflow-slots.json`, `workflow-booking.json` | n8n Google Calendar Credential |
| `REPLACE_WITH_TWILIO_CREDENTIAL_ID` | `workflow-booking.json` | n8n Twilio Credential |
| `REPLACE_WITH_SUPABASE_CREDENTIAL_ID` | `workflow-booking.json` | n8n Supabase Credential |
| `REPLACE_WITH_SMTP_CREDENTIAL_ID` | `workflow-booking.json` | n8n SMTP Credential |

---

## 9. Monitoring & Betrieb

- **Retell AI Dashboard:** Anruf-Logs, Dauer, Abschlussrate
- **n8n Execution Log:** Webhook-Aufrufe, Fehler, Laufzeiten
- **Supabase Dashboard:** Gebuchte Termine, Trend
- **Twilio Console:** SMS-Zustellrate, Kosten

### Empfohlene Erweiterungen

- **Terminabsage/Umbuchung** per SMS-Antwort oder Anruf
- **Warteliste** wenn keine Slots frei
- **Analytics-Dashboard** (Anrufe/Tag, Buchungsrate, Ø Gesprächsdauer)
- **Slack-Benachrichtigung** zusätzlich zu E-Mail
