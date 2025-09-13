from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # Supabase
    SUPABASE_URL: str
    SUPABASE_SERVICE_KEY: str
    SUPABASE_ANON_KEY: str
    
    # App
    ENVIRONMENT: str = "development"
    
    class Config:
        env_file = ".env"

settings = Settings()
