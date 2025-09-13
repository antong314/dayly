from fastapi import APIRouter, HTTPException, Depends
from app.core.supabase import get_supabase
from app.models.schemas import PhoneVerification, VerifyCode

router = APIRouter()

@router.post("/request-verification")
async def request_verification(data: PhoneVerification, supabase = Depends(get_supabase)):
    """Send OTP to phone number via Supabase Auth"""
    try:
        response = supabase.auth.sign_in_with_otp({
            "phone": data.phone_number
        })
        return {"message": "Verification code sent", "expires_in": 300}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/verify")
async def verify_code(data: VerifyCode, supabase = Depends(get_supabase)):
    """Verify OTP and return session"""
    try:
        response = supabase.auth.verify_otp({
            "phone": data.phone_number,
            "token": data.code,
            "type": "sms"
        })
        
        # Create/update profile
        profile_data = {"first_name": data.first_name} if data.first_name else {}
        supabase.table("profiles").upsert({
            "id": response.user.id,
            **profile_data
        }).execute()
        
        return {
            "access_token": response.session.access_token,
            "refresh_token": response.session.refresh_token,
            "user": {
                "id": response.user.id,
                "phone": response.user.phone
            }
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/refresh")
async def refresh_token(refresh_token: str, supabase = Depends(get_supabase)):
    """Refresh access token using Supabase"""
    try:
        response = supabase.auth.refresh_session(refresh_token)
        return {
            "access_token": response.session.access_token,
            "refresh_token": response.session.refresh_token
        }
    except Exception as e:
        raise HTTPException(status_code=401, detail="Invalid refresh token")
