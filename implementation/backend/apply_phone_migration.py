#!/usr/bin/env python3
"""Apply phone column migration to profiles table"""

import os
from dotenv import load_dotenv
from supabase import create_client, Client

load_dotenv('env.local')

# Get Supabase credentials
url = os.getenv('SUPABASE_URL')
key = os.getenv('SUPABASE_SERVICE_KEY')

supabase: Client = create_client(url, key)

# Run the migration SQL
migration_sql = """
-- Add phone column to profiles table for custom WhatsApp authentication
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone VARCHAR(20) UNIQUE;

-- Create index for faster phone lookups (if not exists)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_profiles_phone') THEN
        CREATE INDEX idx_profiles_phone ON profiles(phone);
    END IF;
END $$;
"""

try:
    # Execute the migration
    result = supabase.rpc('execute_sql', {'sql': migration_sql}).execute()
    print("✅ Migration applied successfully!")
except Exception as e:
    # Try alternative approach
    print(f"First attempt failed: {e}")
    print("Trying alternative approach...")
    
    # Check if column already exists
    check_sql = """
    SELECT column_name 
    FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'phone';
    """
    
    try:
        # For now, let's just acknowledge the migration needs to be applied manually
        print("\n⚠️  Please apply this migration manually in Supabase Dashboard:")
        print("ALTER TABLE profiles ADD COLUMN phone VARCHAR(20) UNIQUE;")
        print("CREATE INDEX idx_profiles_phone ON profiles(phone);")
    except Exception as e2:
        print(f"Error checking column: {e2}")
