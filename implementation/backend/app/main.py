from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from app.api import auth, groups, photos
from app.core.supabase import init_supabase

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    init_supabase()
    yield
    # Shutdown

app = FastAPI(title="Dayly API", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    return {"message": "Dayly API", "status": "healthy"}

@app.get("/api/health")
async def health_check():
    return {"status": "healthy", "version": "1.0.0"}

# Include routers
app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])
app.include_router(groups.router)
app.include_router(photos.router)
