from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from typing import List, Optional
from datetime import datetime, timedelta
from app.core.security import get_current_user
from app.core.supabase import get_supabase
from app.models.schemas import PhotoUploadResponse, UploadURLRequest, PhotoResponse
import uuid
import io

router = APIRouter(prefix="/api/photos", tags=["photos"])

@router.post("/upload", response_model=PhotoUploadResponse)
async def upload_photo(
    file: UploadFile = File(...),
    group_id: str = Form(...),
    user_id: str = Depends(get_current_user),
    supabase = Depends(get_supabase)
):
    """Upload photo to Supabase Storage"""
    try:
        # Check if user is member of the group
        membership = supabase.table("group_members") \
            .select("*") \
            .eq("group_id", group_id) \
            .eq("user_id", user_id) \
            .eq("is_active", True) \
            .execute()
        
        if not membership.data:
            raise HTTPException(status_code=403, detail="Not a member of this group")
        
        # Check daily limit
        today = datetime.now().date().isoformat()
        existing_send = supabase.table("daily_sends") \
            .select("*") \
            .eq("user_id", user_id) \
            .eq("group_id", group_id) \
            .eq("sent_date", today) \
            .execute()
        
        if existing_send.data:
            raise HTTPException(
                status_code=400, 
                detail="Already sent photo to this group today"
            )
        
        # Validate file
        if file.size > 10 * 1024 * 1024:  # 10MB limit
            raise HTTPException(status_code=413, detail="File too large")
        
        if file.content_type not in ["image/jpeg", "image/jpg", "image/png", "image/heif", "image/heic"]:
            raise HTTPException(status_code=415, detail="Invalid file type")
        
        # Generate storage path
        file_extension = file.filename.split(".")[-1] if "." in file.filename else "jpg"
        photo_id = str(uuid.uuid4())
        storage_path = f"{group_id}/{user_id}/{photo_id}.{file_extension}"
        
        # Read file content
        file_content = await file.read()
        
        # Upload to Supabase Storage
        try:
            storage_response = supabase.storage.from_("photos").upload(
                storage_path,
                file_content,
                {"content-type": file.content_type}
            )
        except Exception as e:
            print(f"Storage upload error: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")
        
        # Create photo record
        photo_record = supabase.table("photos").insert({
            "id": photo_id,
            "group_id": group_id,
            "sender_id": user_id,
            "storage_path": storage_path
        }).execute()
        
        if not photo_record.data:
            # Try to clean up uploaded file
            try:
                supabase.storage.from_("photos").remove([storage_path])
            except:
                pass
            raise HTTPException(status_code=500, detail="Failed to create photo record")
        
        # Mark daily send
        supabase.table("daily_sends").insert({
            "user_id": user_id,
            "group_id": group_id,
            "sent_date": today
        }).execute()
        
        # TODO: Trigger notification for group members (Phase 7)
        
        return PhotoUploadResponse(
            photo_id=photo_record.data[0]["id"],
            expires_at=photo_record.data[0]["expires_at"]
        )
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Upload error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/upload-url")
async def get_upload_url(
    data: UploadURLRequest,
    user_id: str = Depends(get_current_user),
    supabase = Depends(get_supabase)
):
    """Get a signed URL for direct upload to storage"""
    try:
        # Verify membership and daily limit
        # ... (same checks as upload_photo)
        
        # Generate storage path
        photo_id = str(uuid.uuid4())
        storage_path = f"{data.group_id}/{user_id}/{photo_id}.jpg"
        
        # Create signed upload URL
        upload_url = supabase.storage.from_("photos").create_signed_upload_url(storage_path)
        
        return {
            "upload_url": upload_url["signedURL"],
            "photo_id": photo_id,
            "storage_path": storage_path
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/confirm-upload")
async def confirm_upload(
    photo_id: str = Form(...),
    group_id: str = Form(...),
    user_id: str = Depends(get_current_user),
    supabase = Depends(get_supabase)
):
    """Confirm photo upload and create database record"""
    try:
        # Create photo record
        storage_path = f"{group_id}/{user_id}/{photo_id}.jpg"
        
        photo_record = supabase.table("photos").insert({
            "id": photo_id,
            "group_id": group_id,
            "sender_id": user_id,
            "storage_path": storage_path
        }).execute()
        
        # Mark daily send
        today = datetime.now().date().isoformat()
        supabase.table("daily_sends").insert({
            "user_id": user_id,
            "group_id": group_id,
            "sent_date": today
        }).execute()
        
        return {"success": True}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{group_id}/today")
async def get_todays_photos(
    group_id: str,
    user_id: str = Depends(get_current_user),
    supabase = Depends(get_supabase)
):
    """Get today's photos for a group"""
    try:
        # First verify user is a member of the group
        member_check = supabase.table("group_members") \
            .select("user_id") \
            .eq("group_id", group_id) \
            .eq("user_id", user_id) \
            .eq("is_active", True) \
            .execute()
        
        if not member_check.data:
            raise HTTPException(status_code=403, detail="Not a member of this group")
        
        # Get photos from the last 48 hours (not expired)
        cutoff_time = (datetime.utcnow() - timedelta(hours=48)).isoformat()
        
        photos_response = supabase.table("photos") \
            .select("id, group_id, sender_id, storage_path, created_at, expires_at, profiles(first_name)") \
            .eq("group_id", group_id) \
            .gte("expires_at", datetime.utcnow().isoformat()) \
            .order("created_at", desc=True) \
            .execute()
        
        photos = []
        for photo in photos_response.data:
            # Generate signed URL for the photo
            storage_url = supabase.storage.from_("photos").create_signed_url(
                photo["storage_path"],
                expires_in=3600  # 1 hour expiry for signed URL
            )
            
            photos.append({
                "id": photo["id"],
                "group_id": photo["group_id"],
                "sender_id": photo["sender_id"],
                "sender_name": photo["profiles"]["first_name"] if photo.get("profiles") else "Unknown",
                "url": storage_url["signedURL"] if storage_url else None,
                "created_at": photo["created_at"],
                "expires_at": photo["expires_at"]
            })
        
        return {"photos": photos}
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
