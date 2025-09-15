from fastapi import APIRouter, Depends, HTTPException
from app.core.supabase import get_supabase
from app.core.security import get_current_user
from app.models.schemas import DeviceRegistration
from datetime import datetime

router = APIRouter(prefix="/api/devices", tags=["devices"])

@router.post("/register")
async def register_device(
    data: DeviceRegistration,
    user_id: str = Depends(get_current_user),
    supabase = Depends(get_supabase)
):
    """Register device for push notifications"""
    try:
        # Upsert device token - update if exists, insert if not
        result = supabase.table("user_devices").upsert({
            "user_id": user_id,
            "device_token": data.device_token,
            "platform": data.platform,
            "updated_at": datetime.now().isoformat()
        }, on_conflict="user_id,device_token").execute()
        
        if not result.data:
            raise HTTPException(status_code=500, detail="Failed to register device")
        
        return {"success": True}
        
    except Exception as e:
        print(f"Device registration error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/unregister")
async def unregister_device(
    device_token: str,
    user_id: str = Depends(get_current_user),
    supabase = Depends(get_supabase)
):
    """Remove device token"""
    try:
        result = supabase.table("user_devices").delete() \
            .eq("user_id", user_id) \
            .eq("device_token", device_token) \
            .execute()
        
        return {"success": True}
        
    except Exception as e:
        print(f"Device unregistration error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/")
async def get_user_devices(
    user_id: str = Depends(get_current_user),
    supabase = Depends(get_supabase)
):
    """Get all registered devices for the current user"""
    try:
        result = supabase.table("user_devices") \
            .select("*") \
            .eq("user_id", user_id) \
            .execute()
        
        return {"devices": result.data}
        
    except Exception as e:
        print(f"Get devices error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
