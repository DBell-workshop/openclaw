import "./styles.css";
import "./ui/app.ts";
import { startVoiceWidget } from "./ui/controllers/voice-widget";

const enableVoiceWidget = import.meta.env.VITE_ENABLE_VOICE_WIDGET !== "false";
if (enableVoiceWidget) {
  startVoiceWidget();
}
