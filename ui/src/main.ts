import "./styles.css";
import "./ui/app.ts";
import { startVoiceWsDemo } from "./ui/controllers/voice-ws-demo";

if (import.meta.env.VITE_ENABLE_VOICE_DEMO === "true") {
  startVoiceWsDemo();
}
