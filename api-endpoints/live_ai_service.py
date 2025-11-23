import os
import asyncio
import io
import wave
import tempfile
import librosa
import soundfile as sf
from google import genai
from google.genai import types
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class LiveAIService:
    def __init__(self):
        # Get API key from environment - try both possible keys
        api_key = os.getenv("GOOGLE_GENAI_API_KEY") or os.getenv("GEMINI_API_KEY")
        if not api_key:
            raise ValueError("Either GOOGLE_GENAI_API_KEY or GEMINI_API_KEY environment variable must be set")
        
        # Configure the client with API key
        try:
            self.client = genai.Client(api_key=api_key)
        except Exception as e:
            raise ValueError(f"Failed to initialize Google GenAI client: {e}. Please check your API key.")
        
        self.model = "gemini-2.5-flash-preview-native-audio-dialog"
        self.config = {
            "response_modalities": ["AUDIO"],
            "system_instruction": "You are PocketSage, a helpful AI financial assistant. Answer in a friendly tone and provide financial insights based on user's spending patterns and receipts.",
        }

    def convert_audio_format(self, input_path: str, output_path: str, target_sr: int = 16000) -> bool:
        """Convert audio file to required format for Live API"""
        try:
            # Load audio with librosa
            y, sr = librosa.load(input_path, sr=target_sr)
            
            # Save as WAV with specific format
            sf.write(output_path, y, sr, format='WAV', subtype='PCM_16')
            
            return True
        except Exception as e:
            print(f"Audio conversion error: {e}")
            return False

    async def process_audio_conversation(self, audio_file_path: str, output_path: str) -> dict:
        """Process audio conversation using Google's Live API"""
        try:
            # Convert audio to required format
            temp_converted = tempfile.NamedTemporaryFile(delete=False, suffix='.wav')
            temp_converted.close()
            
            if not self.convert_audio_format(audio_file_path, temp_converted.name):
                return {"success": False, "error": "Audio conversion failed"}

            # Load converted audio
            y, sr = librosa.load(temp_converted.name, sr=16000)
            
            # Convert to PCM format for Live API
            buffer = io.BytesIO()
            sf.write(buffer, y, sr, format='RAW', subtype='PCM_16')
            buffer.seek(0)
            audio_bytes = buffer.read()

            # Clean up temporary converted file
            os.unlink(temp_converted.name)

            # Process with Live API
            response_count = 0
            async with self.client.aio.live.connect(model=self.model, config=self.config) as session:
                # Send audio input
                await session.send_realtime_input(
                    audio=types.Blob(data=audio_bytes, mime_type="audio/pcm;rate=16000")
                )

                # Create output file
                wf = wave.open(output_path, "wb")
                wf.setnchannels(1)
                wf.setsampwidth(2)
                wf.setframerate(24000)  # Output is 24kHz

                # Receive responses
                async for response in session.receive():
                    if response.data is not None:
                        wf.writeframes(response.data)
                        response_count += 1

                wf.close()

            return {
                "success": True,
                "response_count": response_count,
                "output_path": output_path
            }

        except Exception as e:
            print(f"Live AI processing error: {e}")
            return {"success": False, "error": str(e)} 