from fastapi import APIRouter, Depends, HTTPException
from typing import List, Optional
from datetime import datetime
from app.core.security import get_current_user
from app.core.supabase import get_supabase
from app.models.schemas import GroupCreate, GroupResponse, MemberResponse, LastPhotoResponse

router = APIRouter(prefix="/api/groups", tags=["groups"])

@router.get("/", response_model=List[GroupResponse])
async def get_groups(
    user_id: str = Depends(get_current_user),
    supabase = Depends(get_supabase)
):
    """Get all groups for authenticated user"""
    try:
        # Get user's groups with member information
        response = supabase.table("group_members") \
            .select("group_id, groups(id, name, created_at)") \
            .eq("user_id", user_id) \
            .eq("is_active", True) \
            .execute()
        
        groups = []
        today = datetime.now().date().isoformat()
        
        for item in response.data:
            if item.get("groups"):
                group_data = item["groups"]
                
                # Get all members for this group
                member_response = supabase.table("group_members") \
                    .select("user_id, profiles(id, first_name)") \
                    .eq("group_id", group_data["id"]) \
                    .eq("is_active", True) \
                    .execute()
                
                # Check if user sent today
                today_send = supabase.table("daily_sends") \
                    .select("sent_date") \
                    .eq("user_id", user_id) \
                    .eq("group_id", group_data["id"]) \
                    .eq("sent_date", today) \
                    .execute()
                
                # Get last photo info
                last_photo_response = supabase.table("photos") \
                    .select("created_at, sender_id, profiles!sender_id(first_name)") \
                    .eq("group_id", group_data["id"]) \
                    .order("created_at", desc=True) \
                    .limit(1) \
                    .execute()
                
                last_photo = None
                if last_photo_response.data:
                    photo = last_photo_response.data[0]
                    sender_name = "Unknown"
                    if photo.get("profiles") and photo["profiles"].get("first_name"):
                        sender_name = photo["profiles"]["first_name"]
                    
                    last_photo = LastPhotoResponse(
                        created_at=datetime.fromisoformat(photo["created_at"].replace('Z', '+00:00')),
                        sender_id=photo["sender_id"],
                        sender_name=sender_name
                    )
                
                # Build member list
                members = []
                for member in member_response.data:
                    member_data = MemberResponse(
                        id=member["user_id"],
                        first_name=member["profiles"]["first_name"] if member.get("profiles") else None
                    )
                    members.append(member_data)
                
                group_response = GroupResponse(
                    id=group_data["id"],
                    name=group_data["name"],
                    created_at=datetime.fromisoformat(group_data["created_at"].replace('Z', '+00:00')),
                    member_count=len(members),
                    members=members,
                    last_photo=last_photo,
                    has_sent_today=len(today_send.data) > 0
                )
                groups.append(group_response)
        
        return groups
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/")
async def create_group(
    data: GroupCreate,
    user_id: str = Depends(get_current_user),
    supabase = Depends(get_supabase)
):
    """Create new group and invite members"""
    try:
        # Check group limit (5 max)
        existing_groups = supabase.table("group_members") \
            .select("group_id") \
            .eq("user_id", user_id) \
            .eq("is_active", True) \
            .execute()
        
        if len(existing_groups.data) >= 5:
            raise HTTPException(status_code=400, detail="Maximum 5 groups allowed")
        
        # Check group name length
        if len(data.name) > 50:
            raise HTTPException(status_code=400, detail="Group name too long")
        
        # Create group
        group_result = supabase.table("groups").insert({
            "name": data.name,
            "created_by": user_id
        }).execute()
        
        if not group_result.data:
            raise HTTPException(status_code=500, detail="Failed to create group")
        
        group_id = group_result.data[0]["id"]
        
        # Add creator as member
        supabase.table("group_members").insert({
            "group_id": group_id,
            "user_id": user_id
        }).execute()
        
        # Process member phone numbers
        # For now, we'll just validate the phone numbers
        # Full invite system will be implemented in Phase 8
        for phone in data.member_phone_numbers:
            if not phone.startswith("+"):
                raise HTTPException(status_code=400, detail=f"Invalid phone number format: {phone}")
        
        return {"id": group_id, "name": data.name}
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/{group_id}")
async def update_group(
    group_id: str,
    name: str,
    user_id: str = Depends(get_current_user),
    supabase = Depends(get_supabase)
):
    """Update group name"""
    try:
        # Verify user is member
        membership = supabase.table("group_members") \
            .select("*") \
            .eq("group_id", group_id) \
            .eq("user_id", user_id) \
            .eq("is_active", True) \
            .execute()
        
        if not membership.data:
            raise HTTPException(status_code=403, detail="Not a member of this group")
        
        # Check name length
        if len(name) > 50:
            raise HTTPException(status_code=400, detail="Group name too long")
        
        # Update group
        result = supabase.table("groups").update({
            "name": name
        }).eq("id", group_id).execute()
        
        if not result.data:
            raise HTTPException(status_code=404, detail="Group not found")
        
        return {"success": True}
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/{group_id}")
async def leave_group(
    group_id: str,
    user_id: str = Depends(get_current_user),
    supabase = Depends(get_supabase)
):
    """Leave a group (soft delete membership)"""
    try:
        result = supabase.table("group_members").update({
            "is_active": False
        }).eq("group_id", group_id).eq("user_id", user_id).execute()
        
        if not result.data:
            raise HTTPException(status_code=404, detail="Membership not found")
        
        return {"success": True}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{group_id}/daily-status")
async def get_daily_status(
    group_id: str,
    user_id: str = Depends(get_current_user),
    supabase = Depends(get_supabase)
):
    """Check if user has sent photo today for this group"""
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
        
        # Check daily sends for today
        today = datetime.now().date().isoformat()
        daily_send = supabase.table("daily_sends") \
            .select("*") \
            .eq("user_id", user_id) \
            .eq("group_id", group_id) \
            .eq("sent_date", today) \
            .execute()
        
        return {"has_sent_today": len(daily_send.data) > 0}
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/{group_id}/mark-sent")
async def mark_sent_today(
    group_id: str,
    user_id: str = Depends(get_current_user),
    supabase = Depends(get_supabase)
):
    """Mark that user has sent photo today for this group"""
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
        
        # Insert daily send record
        today = datetime.now().date().isoformat()
        supabase.table("daily_sends").upsert({
            "user_id": user_id,
            "group_id": group_id,
            "sent_date": today
        }).execute()
        
        return {"success": True}
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
