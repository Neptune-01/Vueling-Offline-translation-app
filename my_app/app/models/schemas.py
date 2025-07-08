from pydantic import BaseModel, Field
from typing import Optional
from enum import Enum

class WhisperModel(str, Enum):
    TINY = "tiny"
    BASE = "base"
    SMALL = "small"
    MEDIUM = "medium"
    LARGE = "large"

class TranscriptionResponse(BaseModel):
    text: str
    language: str
    duration: float

class TranslationRequest(BaseModel):
    text: str = Field(..., min_length=1)
    target_language: str = Field(..., min_length=2)
    source_language: Optional[str] = Field(default="auto")

class TranslationResponse(BaseModel):
    translation: str
    source_language: str
    target_language: str
