#!/usr/bin/env python3
"""Reset and apply complete schema with phone support for WhatsApp auth"""

import os
import psycopg2
from dotenv import load_dotenv
from urllib.parse import urlparse

load_dotenv('env.local')

# Parse Supabase connection URL
supabase_url = os.getenv('SUPABASE_URL')
parsed = urlparse(supabase_url.replace('https://', 'postgresql://postgres:'))

# Get database connection details
# The pattern is: postgresql://postgres:[YOUR-PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres
project_ref = supabase_url.split('//')[1].split('.')[0]  # Extract project ref from URL
db_host = f"db.{project_ref}.supabase.co"
db_password = os.getenv('SUPABASE_DB_PASSWORD', '')  # You'll need to add this to env.local

if not db_password:
    print("\n⚠️  Please add SUPABASE_DB_PASSWORD to your env.local file")
    print("You can find this in your Supabase project settings under Database")
    exit(1)

# Read the schema file
with open('../database/schema_with_phone.sql', 'r') as f:
    schema_sql = f.read()

try:
    # Connect to the database
    conn = psycopg2.connect(
        host=db_host,
        port=5432,
        database="postgres",
        user="postgres",
        password=db_password
    )
    conn.autocommit = True
    cur = conn.cursor()
    
    print("🔄 Connected to Supabase database")
    print("⚠️  WARNING: This will DROP and RECREATE all tables!")
    
    confirm = input("\nType 'yes' to continue: ")
    if confirm.lower() != 'yes':
        print("Cancelled.")
        exit(0)
    
    print("\n🗑️  Dropping existing tables...")
    print("📝 Creating new schema with phone support...")
    
    # Execute the schema
    cur.execute(schema_sql)
    
    print("✅ Schema applied successfully!")
    print("\nCreated tables:")
    print("- profiles (with phone column)")
    print("- groups")
    print("- group_members")
    print("- photos")
    print("- daily_sends")
    print("- invites")
    print("- user_devices")
    
    cur.close()
    conn.close()
    
except psycopg2.Error as e:
    print(f"\n❌ Database error: {e}")
    print("\nMake sure you have:")
    print("1. Added SUPABASE_DB_PASSWORD to env.local")
    print("2. The correct database password from Supabase settings")
except Exception as e:
    print(f"\n❌ Error: {e}")
