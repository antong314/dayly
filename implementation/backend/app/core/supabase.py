from supabase import create_client, Client
from app.core.config import settings

supabase_client: Client = None

def init_supabase():
    global supabase_client
    supabase_client = create_client(
        settings.SUPABASE_URL,
        settings.SUPABASE_SERVICE_KEY
    )
    return supabase_client

def get_supabase() -> Client:
    return supabase_client
