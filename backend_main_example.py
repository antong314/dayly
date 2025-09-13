# app/main.py - Example FastAPI application structure for Dayly

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import sentry_sdk
from sentry_sdk.integrations.fastapi import FastApiIntegration

from app.core.config import settings
from app.core.supabase import init_supabase
from app.api import auth, groups, photos, invites, devices
from app.middleware.auth import AuthMiddleware


# Initialize Sentry for error tracking
if settings.SENTRY_DSN:
    sentry_sdk.init(
        dsn=settings.SENTRY_DSN,
        integrations=[FastApiIntegration()],
        environment=settings.ENVIRONMENT,
        traces_sample_rate=0.1,
    )


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Handle startup and shutdown events"""
    # Startup
    print("Starting Dayly API...")
    init_supabase()
    yield
    # Shutdown
    print("Shutting down Dayly API...")


# Create FastAPI app
app = FastAPI(
    title="Dayly API",
    description="Backend API for Dayly - One photo. Once a day. To the people who matter.",
    version="1.0.0",
    lifespan=lifespan,
)

# Configure CORS for iOS app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Add custom auth middleware
app.add_middleware(AuthMiddleware)

# Include routers
app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])
app.include_router(groups.router, prefix="/api/groups", tags=["Groups"])
app.include_router(photos.router, prefix="/api/photos", tags=["Photos"])
app.include_router(invites.router, prefix="/api/invites", tags=["Invites"])
app.include_router(devices.router, prefix="/api/devices", tags=["Devices"])


@app.get("/")
async def root():
    """Health check endpoint"""
    return {"status": "healthy", "app": "Dayly API"}


@app.get("/api/health")
async def health_check():
    """Detailed health check"""
    try:
        # Check Supabase connection
        from app.core.supabase import supabase_client
        
        # Simple query to verify connection
        result = supabase_client.table("groups").select("id").limit(1).execute()
        
        return {
            "status": "healthy",
            "database": "connected",
            "version": "1.0.0",
        }
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Service unavailable: {str(e)}")


# Example of Supabase client initialization (app/core/supabase.py)
"""
from supabase import create_client, Client
from app.core.config import settings

supabase_client: Client = None

def init_supabase():
    global supabase_client
    supabase_client = create_client(
        settings.SUPABASE_URL,
        settings.SUPABASE_SERVICE_KEY  # Use service key for backend
    )
    return supabase_client

def get_supabase() -> Client:
    return supabase_client
"""

# Example of settings (app/core/config.py)
"""
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # Supabase
    SUPABASE_URL: str
    SUPABASE_SERVICE_KEY: str
    SUPABASE_ANON_KEY: str
    
    # App
    ENVIRONMENT: str = "development"
    
    # Monitoring
    SENTRY_DSN: str = None
    
    # SMS (Twilio)
    TWILIO_ACCOUNT_SID: str = None
    TWILIO_AUTH_TOKEN: str = None
    TWILIO_PHONE_NUMBER: str = None
    
    class Config:
        env_file = ".env"

settings = Settings()
"""
