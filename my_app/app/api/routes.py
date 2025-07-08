from fastapi import APIRouter, HTTPException
from starlette.responses import JSONResponse
from app.models.schemas import TranslationRequest, TranslationResponse
from app.services.translation import TranslationService
from app.services.transcription import TranscriptionService

router = APIRouter()
translation_service = TranslationService()
transcription_service = TranscriptionService()

# Base de données simulée pour stocker les messages
messages_db = {
    "passenger": [],
    "broadcast": [],
    "crew_conversation": []
}

@router.post("/translate", response_model=TranslationResponse)
async def translate_text(request: TranslationRequest):
    try:
        print(f"🟡 Requête reçue: {request.text} (de {request.source_language} vers {request.target_language})")

        result = await translation_service.translate(
            request.text,
            request.target_language,
            request.source_language
        )

        print(f"✅ Traduction réussie: {result}")

        return JSONResponse(content=result, media_type="application/json; charset=utf-8")
    except Exception as e:
        print(f"❌ Erreur de traduction: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/messages/{mode}")
async def get_messages(mode: str):
    if mode not in messages_db:
        raise HTTPException(status_code=404, detail="Mode non trouvé")

    translated_messages = []

    # Récupérer les messages du mode demandé
    messages_to_fetch = messages_db[mode]

    # 🔹 Ajouter aussi les messages broadcast pour les passagers
    if mode == "passenger":
        messages_to_fetch += messages_db["broadcast"]

    for msg in messages_to_fetch:
        if "translated" not in msg:  # Vérifie si le message a déjà été traduit
            try:
                translated_result = await translation_service.translate(
                    msg["text"], "fr", "auto"  # Traduction en français par défaut
                )
                msg["translated"] = translated_result["translation"]
            except Exception as e:
                msg["translated"] = msg["text"]  # Garde le message original si erreur
        
        translated_messages.append(msg)

    print(f"📩 Demande de messages pour {mode}. Messages trouvés: {len(translated_messages)}")
    return JSONResponse(content=translated_messages, media_type="application/json; charset=utf-8")

@router.post("/messages")
async def send_message(message: dict):
    mode = message.get("mode")
    text = message.get("text")
    target_lang = message.get("target_language", "en")
    source_lang = message.get("source_language", "fr")

    if mode not in messages_db:
        raise HTTPException(status_code=400, detail="Mode invalide")

    try:
        # 🔹 Traduire le message pour l'afficher correctement dans la conversation
        translated_result = await translation_service.translate(text, target_lang, source_lang)
        translated_text = translated_result["translation"]

        # 📤 Stocker le message traduit
        messages_db[mode].append({
            "text": text,
            "translated": translated_text,
            "source_language": source_lang,
            "target_language": target_lang
        })

        print(f"📦 Message enregistré pour {mode}: {messages_db[mode][-1]}")

        # 🔄 **Si c'est une réponse, traduire dans l'autre sens**
        if len(messages_db[mode]) > 1:  # Vérifie s'il y a déjà des messages (donc une conversation)
            last_message = messages_db[mode][-2]  # Récupérer le message précédent
            response_source = last_message["target_language"]  # La langue de la réponse
            response_target = last_message["source_language"]  # On inverse les langues

            # 🟡 Traduire la réponse pour que l'autre personne la voie dans sa langue
            response_translation = await translation_service.translate(text, response_target, response_source)

            # 📩 Ajouter la réponse traduite dans la conversation
            messages_db[mode].append({
                "text": text,
                "translated": response_translation["translation"],
                "source_language": response_source,
                "target_language": response_target
            })

            print(f"🔁 Réponse traduite et enregistrée : {messages_db[mode][-1]}")

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    return JSONResponse(content={"status": "Message enregistré", "message": message}, media_type="application/json; charset=utf-8")