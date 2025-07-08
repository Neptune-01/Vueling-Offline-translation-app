import redis
from app.core.config import settings
import json

class RedisCache:
    def __init__(self):
        self.redis_client = redis.from_url(settings.REDIS_URL)

    def get_cached_translation(self, key: str) -> dict | None:
        cached = self.redis_client.get(key)
        return json.loads(cached) if cached else None

    def cache_translation(self, key: str, translation: dict):
        self.redis_client.setex(
            key,
            settings.CACHE_EXPIRATION,
            json.dumps(translation)
        )
