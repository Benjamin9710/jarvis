# Jarvis-Style Voice Control for LIFX and Mirabella Smart Lights

**Executive Summary:** Both LIFX and Mirabella Genio (Telstra) smart bulbs are Wi-Fi connected and *can* be voice-controlled, but via different approaches.  LIFX offers both an official cloud API and an open LAN protocol.  Its cloud HTTP API (v1) requires a LIFX account/token and is rate-limited (~120 requests/min/token【18†L754-L758】), while the local UDP-based LAN protocol is open and fully documented (supported by libraries like Python **lifxlan**【26†L251-L259】).  Mirabella Genio bulbs are essentially Tuya-based Wi-Fi lights【16†L40-L47】【16†L129-L137】. There is no public Mirabella API; control must go through the Tuya ecosystem (Smart Life/Telstra Smart Home cloud) or via local reverse-engineered methods.  In practice one can use the Tuya Cloud API (requiring a Tuya developer account) or local LAN libraries (e.g. **tinytuya**【31†L323-L332】) if the device’s key is obtained. 

For voice control, you have two broad paths: using cloud voice assistants (Alexa/Google Home) or a completely local speech system.  LIFX and Mirabella both integrate with Alexa/Google natively【46†L28-L30】【44†L99-L107】, but that relies on third-party cloud services.  Alternatively, a local voice assistant can use open-source ASR and NLU.  For example, **Vosk** (offline STT)【37†L29-L36】 or Whisper models for speech-to-text, plus a local intent parser (e.g. Rasa NLU【41†L560-L569】) can recognize commands.  A wake-word engine like Picovoice Porcupine【39†L16-L20】 (on-device keyword spotting) can trigger listening.  Text-to-speech replies can use an offline engine like MaryTTS【43†L68-L72】, eSpeak or pyttsx3. 

In all cases, design trade-offs matter: fully local operation (offline ASR + local LAN control) maximizes privacy and offline reliability, with low latency, but is more complex to implement.  A cloud-assisted approach (e.g. Alexa intents) is easier to setup but incurs network delays and depends on external services.  Overall, voice control is feasible.  The recommended architecture is to handle wake-word + ASR + intent parsing locally, and then issue commands via the local LAN protocols whenever possible (falling back to cloud APIs if needed).  Below we outline device capabilities, APIs, voice options, and a step-by-step plan. 

## Device Models & Capabilities

- **LIFX:** LIFX sells many Wi‑Fi smart lights (no hub required): color bulbs, white bulbs, multi-zone strips (LIFX Z/Beam), downlights, tiles, switches, etc.  Newer LIFX devices (2024+) support the Matter standard out-of-the-box【49†L366-L369】, improving interoperability.  All models can be controlled via the LIFX cloud or local network.  Common LIFX models (A19 bulbs, PAR38 flood, GU10, candle, etc.) use the same APIs.

- **Mirabella Genio:** Mirabella (Telstra) sells Wi‑Fi smart bulbs under the Genio brand.  Examples: dimmable RGB+CCT globe bulbs (E27, B22, candle, GU10), downlights, LED strips.  These are *rebranded generic Tuya Wi‑Fi* bulbs【16†L40-L47】【16†L129-L137】.  They have Alexa/Google support via the Tuya/Mirabella cloud.  No Zigbee/Z‑wave – all use Wi‑Fi.  Capabilities (RGBW, tunable white) depend on model; there is no difference in API between them, only different data-point IDs.

Below is a feature comparison: 

| Aspect             | **LIFX**                               | **Mirabella Genio (Tuya-based)**     |
|--------------------|-----------------------------------------|--------------------------------------|
| **Network**        | Wi-Fi (2.4GHz)                          | Wi-Fi (2.4GHz)                       |
| **Cloud API**      | Official HTTP API (v1); requires LIFX account & token【6†L38-L47】 | No public official API; uses Tuya IoT cloud (requires Tuya/Smart Life account) |
| **Local Protocol** | Open UDP LAN protocol【26†L251-L259】 (port 56700, no auth); lifxlan library available【26†L251-L259】 | Tuya LAN (JSON/CoAP over UDP) – can use TinyTuya/tinytuya libraries【31†L323-L332】 if local keys obtained |
| **Auth**           | Token (cloud); no auth needed (LAN is on LAN) | Tuya account credentials (cloud); local key (for LAN commands) |
| **SDK/Libs**       | Official LIFX HTTP API docs【6†L38-L47】; lifxlan (Python)【26†L251-L259】, LIFX HTTP libraries (various) | TinyTuya (Python)【31†L323-L332】, TuyAPI (Node.js), Home Assistant integrations (Tuya/LocalTuya) |
| **Voice Assistants**| Integrates with Alexa/Google (via cloud)【46†L28-L30】; Matter-capable devices work with Apple, Google, Amazon natively【49†L366-L369】 | Works with Alexa/Google via Tuya cloud【44†L99-L107】 (manufacturer app); no Matter support |
| **Rate Limits**    | ~120 requests/min per access token【18†L754-L758】 (cloud) | ~4 actions/s per device (Tuya Cloud)【33†L238-L247】; no known local rate limit beyond UDP throughput |
| **Pros**           | Full local control available; well-documented; strong color/multi-zone support; Matter support | Inexpensive bulbs widely available in AU; voice assistants built-in; can be flashed or used locally via third-party tools |
| **Cons**           | Need LIFX account for cloud; some older models need careful handling; cloud/token limits | Closed Tuya ecosystem; must extract keys for local control; cloud API setup is cumbersome; fewer community docs |

## LIFX Control Options

- **LIFX HTTP (Cloud) API:** LIFX provides a RESTful API (v1) at `https://api.lifx.com/v1/`【6†L38-L47】. You authenticate with a Bearer token (get one from the LIFX cloud dashboard).  Endpoints exist for listing lights, setting state, colors, etc. For example, `GET /v1/lights/all` and `PUT /v1/lights/id:<id>/state` to change a light.  This API requires internet, uses HTTPS, and is limited to ~120 req/min/token【18†L754-L758】. It is simple to use with standard HTTP libraries (cURL, Python `requests`, etc.).  E.g.: 

  ```python
  import requests
  token = "YOUR_LIFX_API_TOKEN"
  headers = {"Authorization": f"Bearer {token}"}
  # List all lights
  resp = requests.get("https://api.lifx.com/v1/lights/all", headers=headers)
  print(resp.json())
  # Turn a light on (selector could be id, label, group, etc.)
  requests.put("https://api.lifx.com/v1/lights/all/state",
               headers=headers, json={"power": "on"})
  ```

- **LIFX LAN Protocol:** LIFX devices listen on UDP port 56700 using an open binary protocol【26†L251-L259】. No account or internet is needed – any device on the LAN can send commands. The protocol is fully documented (headers, message types) at the LIFX developer site, and libraries like **lifxlan** (Python) implement it【26†L251-L259】. In lifxlan you do: 

  ```python
  from lifxlan import LifxLAN
  lan = LifxLAN()  
  lights = lan.get_lights()      # discovers bulbs on LAN
  light = lights[0]
  light.set_power("on")          # turn on (0 for off, 65535 for on)
  light.set_color([hue, sat, bright, kelvin], duration=500)
  ```

  The lifxlan library also supports groups, zones (for Z-Strip, Beam), and retrieving state.  Using LAN is faster (low latency) and works offline. You only need each bulb’s IP and MAC, which lifxlan discovery finds automatically.  (The header `target` field requires either broadcast or specific MAC.)  Because the LAN protocol was authored by LIFX, it is very reliable. See the official LIFX LAN docs for packet details【26†L251-L259】.

- **Authentication & Accounts:** For cloud API, you need a LIFX user account and generate a personal access token. For LAN control, there is no authentication – any client can send UDP packets to bulbs. However, the LAN protocol uses a `source` identifier (choose a unique non-zero number) and can request acknowledgements. No login is needed for LAN. LIFX does not impose LAN rate limits, but you should avoid flooding UDP.

- **Rate Limits:** The HTTP API is rate-limited: roughly 120 requests per minute per token【18†L754-L758】. LAN control has no official limit, but very rapid polling (hundreds per second) is not typical. In practice, using LAN avoids cloud throttling altogether.

- **Matter & Modern Devices:** Many new LIFX devices ship with Matter support pre-installed【49†L366-L369】. If you update them and connect to a Matter hub, you could control them via HomeKit, Google Home, etc., but for our Jarvis integration we typically use LIFX APIs or local LAN (Matter brings its own network protocol but that is beyond scope here).

## Mirabella (Genio/Tuya) Control Options

- **Mirabella = Tuya:**  Mirabella Genio smart bulbs use the Tuya IoT platform under the hood【16†L40-L47】【16†L129-L137】.  They *do* have Alexa/Google integration (through the Mirabella/Tuya cloud【44†L99-L107】), but no public Mirabella cloud API. Instead, one can either use the Tuya IoT Cloud API or use reverse-engineered local access.  

- **Tuya Cloud API:**  Tuya provides a cloud REST API (via the Tuya IoT Platform) for connected devices. To use it, you must register as a Tuya cloud developer, create a project, and authorize your Mirabella devices under that project (often via the Tuya Smart or Smart Life app).  The cloud API allows sending commands (`/thing/{device_id}/shadow/actions`)【33†L238-L247】.  However, it is relatively complex to set up, and requests are limited (~4 device actions/sec【33†L238-L247】).  You also need internet, and your Jarvis system must handle OAuth or API keys.  This path essentially routes commands through Tuya’s servers and back to the local device.

- **Local LAN (TinyTuya):**  Alternatively, because Mirabella/Tuya devices speak a local LAN protocol, one can control them directly if the *local key* is known.  The open-source **TinyTuya** (Python) or **tinytuya** library【31†L323-L332】 supports sending local UDP commands to Tuya bulbs (protocol versions 3.1–3.5).  Example usage: 

  ```python
  import tinytuya
  d = tinytuya.BulbDevice('DEVICE_ID', 'DEVICE_IP', 'LOCAL_KEY', version=3.3)
  status = d.status()
  print(status)
  # Turn on to warm white at 50%:
  d.set_white_percentage(50.0, 0.0)
  ```
  (There is also `tinytuya.BulbDevice` class for color bulbs, enabling `set_colour`).  You must supply the device’s Tuya ID, IP address, local_key and protocol version. The IP can be “Auto” to scan, and the key must be extracted (e.g. via Tuya IoT or by logging encryption). Home Assistant’s LocalTuya integration and tinytuya docs can help obtain these keys.  Once set up, local control is fast and works offline.  Note: Mirabella bulbs might appear as generic “2” or “3” stateTuya devices; tinytuya’s examples handle them.

- **Authentication:** The Tuya cloud approach needs a Tuya developer account (with access token) or Telstra SmartHome API (if one exists) – but no easy public Mirabella API is documented. The local approach requires no internet but *does* require the local key (a form of password) for encryption. This can be obtained by a Wi-Fi packet capture, smart-home app sniffing, or the official Tuya development console (if you hack your account).

- **Rate Limits:** In cloud mode, Tuya limits device control calls to about 4/sec per device【33†L238-L247】. In local mode, you are only limited by network congestion and the device’s ability to process state (often ~10–20 commands per second is fine).  Be cautious: very frequent local polling may still cause the device to not respond to each request.

- **Flashing to Tasmota (Optional):** As a last resort, Mirabella bulbs (which are ESP8266-based) can be reflashed with Tasmota or similar firmware【16†L53-L61】. This bypasses Tuya entirely and gives MQTT control, but it requires opening the bulb and soldering (or OTAs). For a Jarvis build, this is extreme and optional only if local Tuya fails.

## Voice Interface Options

**Cloud Voice Assistants:** The simplest voice interface is to use Alexa or Google Assistant as the “Jarvis” front end.  Both platforms natively support LIFX and Tuya devices.  For example, LIFX “Works with Google Home”【46†L28-L30】 allows Google voice commands (e.g. “Hey Google, turn on the kitchen”).  Mirabella Genio advertises built‑in Alexa/Google compatibility【44†L99-L107】 via the Tuya cloud.  You could write an Alexa Skill or Google Action that calls the LIFX and/or Tuya APIs.  Pros: high-quality ASR/intent from Google/Alexa and easy linking. Cons: you rely on Amazon/Google clouds (privacy, dependence, possible latency).  Also, using Alexa means speaking “Alexa…” which may conflict with Jarvis persona.

**Local Speech Recognition:** For full local control (no cloud), use an offline speech-to-text engine.  *Vosk* is a popular open-source toolkit【37†L29-L36】. It runs on Python (via pip `vosk`) and has lightweight language models (e.g. 50 MB). Vosk works on Raspberry Pi and common CPUs. It can do continuous dictation or one-shot commands.  Another option is OpenAI’s Whisper model (via the `whisper` Python lib), but it’s heavier (needs GPU or fast CPU) and has higher accuracy but slower performance. 

**Wake Word Detection:** To avoid listening 24/7, use a wake-word engine. Picovoice Porcupine【39†L16-L20】 is a lightweight on-device wake-word detector (e.g. “Hey Jarvis”) that triggers the ASR. It runs on microcontrollers up to desktop, with low CPU. (Alternatively, open-source options like Mycroft Precise or Porcupine’s free tier can be used.) 

**NLU/Intent Parsing:** After ASR provides text, you need to parse it into actions. Rasa (open-source) provides intent/entity extraction and can run locally【41†L560-L569】. For example, define intents like “light_on” with example phrases. Rasa can train a model to classify commands and extract which room/light. If that is too heavy, a simpler solution is to use rule-based matching or small intent classifiers. The choice depends on how natural your voice interface needs to be. (You could even use ChatGPT API, but that’s cloud.)

**Text-to-Speech:** To speak responses (e.g. “Okay, turning on the light”), you’ll want a TTS engine. MaryTTS is a fully open-source, multilingual TTS system【43†L68-L72】 with a Java API or HTTP interface. Pyttsx3 is a Python library that wraps eSpeak or SAPI (offline). Google Cloud or Amazon Polly voices are more natural but require internet. For an offline Jarvis, MaryTTS or espeak with a good voice is recommended.

**Summary:** An example local voice stack: Microphone input → Porcupine wake-word → Vosk ASR → Rasa NLU → intent/action → TTS reply.  Each component can run offline on a decent PC/RPi.  Optionally, replace Rasa with a simple rule engine if desired.  

## Integration Architecture

```mermaid
flowchart LR
    A[Microphone\n(Wake-word)] --> B[ASR\n(Vosk/Whisper)]
    B --> C[NLU/Intent Parser\n(Rasa/spaCy)]
    C --> D{Device\ Type?}
    D -->|LIFX| E[LIFX Control]
    D -->|Mirabella| F[Mirabella Control]
    E --> G[LIFX LAN / HTTP API]
    F --> H[Tuya LAN / Cloud API]
    G --> I[LIFX Bulb/Light]:::device
    H --> J[Mirabella Bulb]:::device

    classDef device fill:#FFD,stroke:#333,stroke-width:2px;
```

This flowchart illustrates a possible architecture.  The voice pipeline (left) is entirely local: the wake-word and ASR run on-device, then an intent parser maps text to commands.  The command branches to either LIFX or Mirabella control: for LIFX we can use either the LAN library or cloud API; for Mirabella we use TinyTuya (LAN) or the Tuya Cloud.  The bottom row shows the target devices.

**Cloud-Assisted Variation:** In a cloud-assisted design, the ASR/intent could be replaced by Alexa/Google (connected via a custom skill or webhook). Then Jarvis’s logic could be triggered by e.g. a Lambda or Dialogflow callback, which in turn calls the device APIs.  That diagram would have voice input → Amazon/Google Cloud → your server → LIFX/Mirabella API.  We recommend the local pipeline above for privacy, but note that Alexa/Google greatly simplify speech recognition.

## Step-by-Step Implementation Plan

1. **Choose Voice Tools:** Decide on libraries for wake-word (e.g. Porcupine), ASR (Vosk), NLU (Rasa or small intent matcher), and TTS.  Prototype microphone input and ASR: test that “turn on the light” is transcribed correctly.

2. **Voice Interface Prototype:** Build a simple loop: wake-word detection triggers ASR to a fixed phrase, run NLU to map phrase to intent (e.g. `("light_on", {"room": "kitchen"})`), then confirm via TTS.

3. **Device Discovery:** On your LAN, discover LIFX bulbs. If using `lifxlan`, call `lan.get_lights()`. Store light labels or IDs. For Mirabella, either manually note the device ID/IP (from your router or Tuya app), or use tinytuya’s wizard: 
   ```python
   devices = tinytuya.deviceScan()  # returns list of Tuya devices on LAN
   print(devices)
   ```
   Get each bulb’s `id`, `ip`, `local_key`.

4. **LIFX Control Implementation:** Write code to control LIFX.  Test local LAN first (no token needed): 
   ```python
   from lifxlan import LifxLAN
   lan = LifxLAN()
   lights = lan.get_lights()
   lights[0].set_power("on")
   lights[0].set_color([10000, 30000, 32768, 3500], duration=500)
   ```
   Verify the bulb responds.  Then optionally add HTTP cloud code (using `requests`) to provide a fallback if LAN fails. Log any API errors.

5. **Mirabella Control Implementation:** Using TinyTuya, connect to a Mirabella bulb locally. Example (adapted from [31]):
   ```python
   import tinytuya
   d = tinytuya.BulbDevice('DEVICE_ID', 'DEVICE_IP', 'LOCAL_KEY', version=3.3)
   print("Status:", d.status())
   d.set_power(True, 0)    # on/off
   d.set_colour([0, 0, 100], 0)  # set to blue (if supported)
   ```
   Test on/off and color.  If unsuccessful, check protocol version and DP mapping. As a backup, implement a cloud call to Tuya (if set up) using the documented cloud endpoints.

6. **Integrate Voice with Devices:** Connect intents to device actions. E.g. for intent `light_on` with entity `room=kitchen`, find the matching LIFX/Mirabella device and call its `set_power(True)`. Provide TTS feedback: “Turning on the kitchen light.” Include confirmation or error messages.

7. **Error Handling & Edge Cases:** Program fallbacks: if a device command fails or times out, catch exceptions and respond (“Sorry, I couldn’t reach the light.”). If ASR confidence is low, ask the user to repeat. If the wake-word falsely triggers, ensure silence or “I didn’t hear a command.”  

8. **Testing & Iteration:** Test voice commands for accuracy (e.g. “Dim the living room lights”, “Set bedroom to red”). Use a variety of accents and volumes. Test device unavailability (e.g. power off a bulb) to see error behavior. Check cloud vs local paths. Iterate on NLU training to improve parsing.

9. **Documentation and Maintenance:** Keep notes on required tokens/keys (LIFX token, Tuya keys) secure. Document voice command syntax for future users. Plan periodic firmware updates for devices if needed.

## Required Libraries & Tools

- **For LIFX:**  
  - *LIFX HTTP API:* none specific; any HTTP client (e.g. Python `requests`) can be used with the docs【6†L38-L47】.  
  - *LIFX LAN:* [**lifxlan**](https://github.com/mclarkk/lifxlan) (Python)【26†L251-L259】 or [**lifx-lan-client**](https://pypi.org/project/lifx-lan-client/) etc. These implement the UDP protocol.  
- **For Mirabella (Tuya):**  
  - [**TinyTuya/tinytuya**](https://github.com/jasonacox/tinytuya) (Python)【31†L323-L332】 for local LAN control. Use it to communicate via IP/local-key.  
  - [**pytuya**](https://pypi.org/project/pytuya/) (Python) or [**tuyapi**](https://www.npmjs.com/package/tuyapi) (Node.js) for cloud control or LAN.  
- **Voice & NLP:**  
  - [**vosk-api**](https://github.com/alphacep/vosk-api) (Python) for offline speech recognition【37†L29-L36】.  
  - [**Picovoice Porcupine**](https://picovoice.ai/products/porcupine/) (C/JS/Python) for wake-word detection【39†L16-L20】.  
  - [**Rasa Open Source**](https://rasa.com/) (Python) for intent parsing【41†L560-L569】.  
  - [**spaCy**](https://spacy.io/) or simple regex for quick intent matching (if Rasa is too heavy).  
  - **TTS:** MaryTTS (Java)【43†L68-L72】, [**pyttsx3**](https://pypi.org/project/pyttsx3/) (Python offline), or cloud TTS APIs.  
- **Development Tools:** Python 3.7+, `pip`, possibly Docker for services. Home Assistant’s code/repositories can be referenced but are optional.

## Sample Code Snippets

- **LIFX LAN Discovery & Control (Python):**  
  ```python
  from lifxlan import LifxLAN
  lan = LifxLAN()
  lights = lan.get_lights()
  for light in lights:
      print(light.get_label(), light.get_color())
      light.set_power(True)  # turn on
      # Set to blue (HSBK): hue=30000, sat=65535, bri=32768, kelvin=3500
      light.set_color([30000, 65535, 32768, 3500], duration=500)
  ```  
  *Source:* lifxlan library【26†L251-L259】.

- **LIFX HTTP API Control (Python):**  
  ```python
  import requests
  token = "YOUR_LIFX_TOKEN"
  headers = {"Authorization": f"Bearer {token}"}
  # Turn *all* lights off
  resp = requests.put("https://api.lifx.com/v1/lights/all/state",
                      headers=headers, json={"power":"off"})
  print(resp.status_code, resp.text)
  ```  
  (Requires LIFX account token; see LIFX API docs【6†L38-L47】.)

- **Mirabella/Tuya LAN Control (Python with tinytuya):**  
  ```python
  import tinytuya
  # Replace with your device's ID, IP, and key
  DEVICE_ID = "01234567891234567890"
  DEVICE_IP = "192.168.1.123"
  LOCAL_KEY = "abcdef0123456789"
  d = tinytuya.BulbDevice(DEVICE_ID, address=DEVICE_IP, local_key=LOCAL_KEY, version=3.3)
  print("Current status:", d.status())
  # Turn on to white at 100% brightness
  d.set_white_percentage(100.0, 0.0)  
  # Change to red color (HSBK format)
  d.set_colour([0, 0, 65535], 0)   # Hue=0 (red), Sat=0, Bright=100%
  ```  
  *Note:* Use `tinytuya.deviceScan()` or network scan to find `DEVICE_ID`/`IP`. Version (3.3) may vary. This is from the TinyTuya example【31†L323-L332】.

- **Wake-Word Example (Porcupine, Python):**  
  ```python
  import pvporcupine, pyaudio
  keywords = ["jarvis"]  # or custom wake-word
  porcupine = pvporcupine.create(keywords=keywords)
  pa = pyaudio.PyAudio()
  stream = pa.open(rate=porcupine.sample_rate, ...)

  while True:
      pcm = stream.read(porcupine.frame_length)
      result = porcupine.process(pcm)
      if result >= 0:
          print("Wake word detected!")
          # Trigger ASR here...
  ```  
  *(Requires `pvporcupine` library)*.

## Testing Checklist & Fallbacks

- **Voice Recognition:** Test with multiple speakers/accents and varying noise levels. Ensure the wake-word triggers reliably and ASR correctly transcribes known commands.  
- **Intent Parsing:** Verify intents map correctly (e.g. “lights up” vs “lights on”). Add synonyms or adjust NLU models as needed.  
- **Device Connectivity:** Confirm devices respond to both local and cloud commands. Test unplugging a device or the LAN to see error handling.  
- **Cloud vs Local:** Intentionally disable cloud (or internet) to ensure local LAN control still works. Conversely, disable LAN (e.g. on different subnet) to test cloud control fallback.  
- **Rate Limits:** If using the LIFX HTTP API heavily, ensure the app logs errors when rate limit is exceeded and backs off.  
- **Unrecognized Commands:** When the user says something off-topic (“play music”), Jarvis should politely say it can’t do that and return to listening.  
- **Emergency Handling:** If a bulb fails to respond or times out, Jarvis should respond (“I can’t reach the kitchen lamp right now.”) and log the error.  
- **Wake-Word False Positives:** Leave the system idle to measure how often it accidentally triggers on ambient speech; tune sensitivity or wake-word as needed.

## Fallback and Error Handling

- **Device Offline:** Catch exceptions from the LAN or HTTP commands. On failure, notify via TTS (“Light not responding”) and optionally retry or schedule a later retry.  
- **Rate Limiting:** If HTTP API returns a 429, pause requests (with exponential backoff). Prefer spreading out state queries.  
- **Missing Credentials:** If the LIFX token is invalid or Tuya key missing, the system should report “Configuration error” and guide the user to check account/token setup.  
- **No Wake-Word Match:** If ASR confidence is low, prompt user to repeat. Ensure a short timeout resets the recognizer.  
- **System Startup/Shutdown:** On launch, announce readiness (“Jarvis is online”). On shutdown or exceptions, cleanly close sockets and audio streams.  

**Conclusion:** In summary, voice-controlling LIFX and Mirabella (Tuya) lights is technically feasible. LIFX has strong native support (local LAN control via lifxlan【26†L251-L259】 and cloud API【6†L38-L47】), while Mirabella Genio requires leveraging the Tuya ecosystem or local hacks【16†L40-L47】【31†L323-L332】. Using offline voice recognition (Vosk/Porcupine) allows a fully local “Jarvis” assistant, whereas Alexa/Google can simplify voice integration at the cost of cloud dependence. The above tables, plan, and code snippets outline the steps to implement robust voice control. Ensure thorough testing of voice inputs and network calls, and implement error handling as described.  

**Sources:** Official LIFX LAN/API docs【6†L38-L47】【26†L251-L259】【49†L366-L369】; LIFX HTTP API rate limit (community)【18†L754-L758】; Home Assistant community (Mirabella=Tuya)【16†L40-L47】【16†L129-L137】; TinyTuya documentation【31†L323-L332】; Vosk site【37†L29-L36】; Picovoice Porcupine info【39†L16-L20】; Rasa docs【41†L560-L569】; MaryTTS info【43†L68-L72】; LIFX Google Home support【46†L28-L30】; Mirabella marketing【44†L99-L107】. These provide the API details and product capabilities needed for implementation.