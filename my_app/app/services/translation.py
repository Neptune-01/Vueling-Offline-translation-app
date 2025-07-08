from deep_translator import GoogleTranslator
import asyncio
from concurrent.futures import ThreadPoolExecutor
from app.core.config import settings

class TranslationService:
    _executor = ThreadPoolExecutor(max_workers=settings.WORKER_POOL_SIZE)
    
    def __init__(self):
        self.translators = {}
        self.language_codes = {
            "Français": "fr",
            "English": "en",
            "Español": "es",
            "Deutsch": "de",
            "Italiano": "it",
        }

    async def translate(self, text: str, target_language: str, source_language: str = "auto"):
        if not text or not target_language:
            raise ValueError("Texte ou langue cible manquants !")

        # 🔹 Convertir en code langue correct (ex: Français → fr)
        target_lang = self.language_codes.get(target_language, target_language)
        source_lang = self.language_codes.get(source_language, source_language)

        translated = await self._translate_segment(text, source_lang, target_lang)

        result = {
            "translation": translated,
            "source_language": source_lang,
            "target_language": target_lang
        }
        return result

    def _get_translator(self, source: str, target: str):
        key = f"{source}->{target}"
        if key not in self.translators:
            self.translators[key] = GoogleTranslator(source=source, target=target)
        return self.translators[key]
    
    async def _translate_segment(self, segment: str, source: str, target: str) -> str:
        loop = asyncio.get_event_loop()
        translator = self._get_translator(source, target)
        try:
            translated = await loop.run_in_executor(self._executor, translator.translate, segment)
            return translated.strip()
        except Exception as e:
            print(f"❌ Erreur de traduction '{segment}': {str(e)}")
            return segment
