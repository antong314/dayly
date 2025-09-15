from fastapi import APIRouter, HTTPException, Depends
from app.core.supabase import get_supabase
from app.models.schemas import PhoneVerification, VerifyCode
from app.services.whatsapp_otp_service import whatsapp_otp_service
import secrets
from datetime import datetime, timedelta
import jwt
import os

router = APIRouter()

@router.post("/verify")
async def request_verification(data: PhoneVerification, supabase = Depends(get_supabase)):
    """Send OTP to phone number via WhatsApp using Twilio Verify"""
    try:
        # Use WhatsApp OTP service
        result = whatsapp_otp_service.send_otp(data.phone_number)
        
        if not result["success"]:
            raise HTTPException(status_code=400, detail=result.get("error", "Failed to send OTP"))
            
        return {
            "message": "Verification code sent via WhatsApp", 
            "expires_in": result.get("expires_in", 600)
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/verify/confirm")
async def verify_code(data: VerifyCode, supabase = Depends(get_supabase)):
    """Verify WhatsApp OTP and create custom session"""
    try:
        # Verify OTP with Twilio
        result = whatsapp_otp_service.verify_otp(data.phone_number, data.code)
        
        if not result["success"]:
            raise HTTPException(status_code=400, detail="Invalid verification code")
        
        # Check if user exists in profiles table
        existing_user = supabase.table("profiles").select("*").eq("phone", data.phone_number).execute()
        
        if existing_user.data:
            # Update existing user
            user_id = existing_user.data[0]["id"]
            if data.first_name:
                supabase.table("profiles").update({
                    "first_name": data.first_name,
                    "last_active": datetime.utcnow().isoformat()
                }).eq("id", user_id).execute()
        else:
            # Create new user with UUID
            import uuid
            user_id = str(uuid.uuid4())
            supabase.table("profiles").insert({
                "id": user_id,
                "phone": data.phone_number,
                "first_name": data.first_name,
                "created_at": datetime.utcnow().isoformat(),
                "last_active": datetime.utcnow().isoformat()
            }).execute()
        
        # Generate custom JWT tokens (mimicking Supabase's token structure)
        # Note: In production, use proper JWT secret from Supabase
        jwt_secret = os.getenv("SUPABASE_JWT_SECRET", "your-super-secret-jwt-token")
        
        # Access token (expires in 1 hour)
        access_token_payload = {
            "aud": "authenticated",
            "exp": int((datetime.utcnow() + timedelta(hours=1)).timestamp()),
            "sub": user_id,
            "phone": data.phone_number,
            "role": "authenticated",
            "iat": int(datetime.utcnow().timestamp())
        }
        access_token = jwt.encode(access_token_payload, jwt_secret, algorithm="HS256")
        
        # Refresh token (expires in 30 days)
        refresh_token_payload = {
            "aud": "authenticated",
            "exp": int((datetime.utcnow() + timedelta(days=30)).timestamp()),
            "sub": user_id,
            "phone": data.phone_number,
            "role": "authenticated",
            "iat": int(datetime.utcnow().timestamp())
        }
        refresh_token = jwt.encode(refresh_token_payload, jwt_secret, algorithm="HS256")
        
        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "user": {
                "id": user_id,
                "phone": data.phone_number
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/refresh")
async def refresh_token(refresh_token: str, supabase = Depends(get_supabase)):
    """Refresh access token using custom JWT"""
    try:
        jwt_secret = os.getenv("SUPABASE_JWT_SECRET", "your-super-secret-jwt-token")
        
        # Decode and verify the refresh token
        try:
            payload = jwt.decode(refresh_token, jwt_secret, algorithms=["HS256"])
        except jwt.ExpiredSignatureError:
            raise HTTPException(status_code=401, detail="Refresh token expired")
        except jwt.InvalidTokenError:
            raise HTTPException(status_code=401, detail="Invalid refresh token")
        
        # Generate new access token
        access_token_payload = {
            "aud": "authenticated",
            "exp": int((datetime.utcnow() + timedelta(hours=1)).timestamp()),
            "sub": payload["sub"],
            "phone": payload.get("phone"),
            "role": "authenticated",
            "iat": int(datetime.utcnow().timestamp())
        }
        new_access_token = jwt.encode(access_token_payload, jwt_secret, algorithm="HS256")
        
        return {
            "access_token": new_access_token,
            "refresh_token": refresh_token  # Return same refresh token
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=401, detail="Invalid refresh token")
