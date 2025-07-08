from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    APP_NAME: str = "My FastAPI App"
    REDIS_URL: str = "redis://localhost:6379"
    CACHE_EXPIRATION: int = 3600
    WORKER_POOL_SIZE: int = 5  # Nombre de threads pour ThreadPoolExecutor

    class Config:
        case_sensitive = True

settings = Settings()
