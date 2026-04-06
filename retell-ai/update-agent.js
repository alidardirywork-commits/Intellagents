const fs = require("fs");
const path = require("path");

const RETELL_API_KEY = "key_55f2f2fdf2a5f7cd089ac849f413";
const AGENT_ID = "agent_f113cae1869bf5df11d0c58681";

async function updateAgent() {
  // Read the system prompt from file
  const systemPrompt = fs.readFileSync(
    path.join(__dirname, "system-prompt.md"),
    "utf-8"
  );

  const payload = {
    agent_name: "Jana – Physiotherapie im Sprengelkiez",
    voice_id: "rKiu7lQ4c5P3az3745s3",
    language: "de-DE",
    voice_temperature: 0.4,
    voice_speed: 1.0,
    responsiveness: 1.0,
    interruption_sensitivity: 0.5,
    enable_backchannel: true,
    backchannel_words: ["mhm", "ja", "verstehe", "okay"],
    max_call_duration_ms: 600000,
    end_call_after_silence_ms: 30000,
    begin_message:
      "Guten Tag, hier ist Jana von der Physiotherapie im Sprengelkiez. Was kann ich für Sie tun?",
    llm_websocket_url: null,
    response_engine: {
      type: "retell-llm",
      llm_id: null,
    },
    llm: {
      model: "claude-sonnet-4-20250514",
      s2s_model: null,
      general_prompt: systemPrompt,
      general_tools: [
        {
          type: "make_api_call",
          name: "get_available_slots",
          description:
            "Ruft die nächsten verfügbaren 20-Minuten-Terminslots aus dem Praxiskalender ab. Rufe dieses Tool auf, nachdem du die Kurzqualifizierung abgeschlossen hast (Neu-/Bestandspatient und Verordnung/Selbstzahler). Du erhältst bis zu 6 freie Slots zurück. Biete dem Patienten 3 davon an.",
          url: "https://intellagents.app.n8n.cloud/webhook/available-slots",
          method: "GET",
          header_params: [],
          body_params: [],
          body_type: "json",
          speak_during_execution: true,
          speak_after_execution: true,
          execution_message_description:
            "Ich schaue kurz im Kalender nach freien Terminen...",
        },
        {
          type: "make_api_call",
          name: "book_appointment",
          description:
            "Bucht einen Termin im Praxiskalender und speichert die Buchung in der Datenbank. Rufe dieses Tool auf, nachdem der Patient einen Slot ausgewählt hat und du Name sowie Telefonnummer erfragt hast.",
          url: "https://intellagents.app.n8n.cloud/webhook-test/book-appointment",
          method: "POST",
          header_params: [],
          body_params: [
            {
              name: "patient_name",
              type: "string",
              description: "Vollständiger Name des Patienten",
              required: true,
            },
            {
              name: "patient_phone",
              type: "string",
              description: "Telefonnummer des Patienten",
              required: true,
            },
            {
              name: "slot_start",
              type: "string",
              description: "ISO 8601 Startzeit des gewählten Slots",
              required: true,
            },
            {
              name: "slot_end",
              type: "string",
              description: "ISO 8601 Endzeit des gewählten Slots",
              required: true,
            },
            {
              name: "reason",
              type: "string",
              description:
                "Anliegen oder Beschwerden, falls vom Patienten genannt",
              required: false,
            },
            {
              name: "prescription",
              type: "string",
              description:
                "Hat der Patient eine ärztliche Verordnung oder kommt als Selbstzahler? Werte: Verordnung oder Selbstzahler",
              required: true,
            },
            {
              name: "new_patient",
              type: "boolean",
              description: "true wenn Neupatient, false wenn Bestandspatient",
              required: true,
            },
          ],
          body_type: "json",
          speak_during_execution: true,
          speak_after_execution: true,
          execution_message_description:
            "Einen Moment, ich trage den Termin ein...",
        },
        {
          type: "make_api_call",
          name: "send_sms_confirmation",
          description:
            "Sendet eine SMS-Terminbestätigung an den Patienten. Rufe dieses Tool direkt nach der erfolgreichen Buchung mit book_appointment auf.",
          url: "https://intellagents.app.n8n.cloud/webhook-test/book-appointment",
          method: "POST",
          header_params: [],
          body_params: [
            {
              name: "patient_name",
              type: "string",
              description: "Name des Patienten",
              required: true,
            },
            {
              name: "patient_phone",
              type: "string",
              description: "Telefonnummer für die SMS",
              required: true,
            },
            {
              name: "slot_start",
              type: "string",
              description: "ISO 8601 Startzeit des gebuchten Termins",
              required: true,
            },
            {
              name: "slot_end",
              type: "string",
              description: "ISO 8601 Endzeit des gebuchten Termins",
              required: true,
            },
          ],
          body_type: "json",
          speak_during_execution: false,
          speak_after_execution: true,
          execution_message_description: "",
        },
        {
          type: "transfer_call",
          name: "transfer_call",
          description:
            "Leitet den Anruf an das Praxis-Team der Physiotherapie im Sprengelkiez weiter. Nutze dieses Tool bei komplexen/medizinischen Fragen, oder wenn der Patient ausdrücklich mit einem Menschen sprechen möchte.",
          number: "+4917621647813",
          transfer_message:
            "Ich verbinde Sie jetzt mit unserem Team. Einen Moment bitte.",
        },
      ],
    },
  };

  console.log(`Updating Retell AI agent ${AGENT_ID}...`);
  console.log(`System prompt length: ${systemPrompt.length} characters`);
  console.log(`Tools: ${payload.llm.general_tools.map((t) => t.name).join(", ")}`);

  const response = await fetch(
    `https://api.retellai.com/v2/update-agent/${AGENT_ID}`,
    {
      method: "PATCH",
      headers: {
        Authorization: `Bearer ${RETELL_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    }
  );

  const responseText = await response.text();

  if (!response.ok) {
    console.error(`\nERROR ${response.status}: ${response.statusText}`);
    console.error(responseText);
    process.exit(1);
  }

  const data = JSON.parse(responseText);
  console.log(`\nSUCCESS – Agent updated.`);
  console.log(`Agent ID:      ${data.agent_id}`);
  console.log(`Agent Name:    ${data.agent_name}`);
  console.log(`Voice ID:      ${data.voice_id}`);
  console.log(`Language:      ${data.language}`);
  console.log(`Begin Message: ${data.begin_message}`);
  console.log(`LLM Model:     ${data.llm?.model || "N/A"}`);
}

updateAgent().catch((err) => {
  console.error("Fatal error:", err.message);
  process.exit(1);
});
