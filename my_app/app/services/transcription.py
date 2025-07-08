import whisper
import torch
from pathlib import Path
from pydub import AudioSegment
import tempfile
import os
from typing import Optional

class TranscriptionService:
    def __init__(self):
        self.models = {}
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
    
    def get_model(self, model_name: str):
        if model_name not in self.models:
            self.models[model_name] = whisper.load_model(model_name, device=self.device)
        return self.models[model_name]

    async def transcribe_audio(
        self, 
        file_path: str, 
        model_name: str = "base",
        language: Optional[str] = None
    ) -> dict:
        # Convertir OGG en WAV si nécessaire
        if file_path.endswith('.ogg'):
            with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as temp_wav:
                audio = AudioSegment.from_ogg(file_path)
                audio.export(temp_wav.name, format='wav')
                file_path = temp_wav.name

        try:
            model = self.get_model(model_name)
            result = model.transcribe(file_path, language=language, fp16=False)
            return {
                "text": result["text"],
                "language": result["language"],
                "duration": result.get("duration", 0.0)
            }
        finally:
            if file_path.endswith('.wav'):
                os.unlink(file_path)
