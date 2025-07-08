import asyncio
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.routes import router
from app.core.config import settings
from fastapi_limiter import FastAPILimiter
from redis.asyncio import Redis

app = FastAPI(title=settings.APP_NAME)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
async def startup():
    redis = Redis.from_url(settings.REDIS_URL)
    await FastAPILimiter.init(redis)

app.include_router(router, prefix="/api/v1")

# 🔹 Windows : Utiliser asyncio à la place d'uvloop
if __name__ == "__main__":
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
