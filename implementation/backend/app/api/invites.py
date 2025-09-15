from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from typing import List, Dict, Any
from app.core.supabase import get_supabase
from app.core.security import get_current_user
from app.models.schemas import CheckUsersRequest, SendInvitesRequest, InviteResponse
import secrets
import string
from datetime import datetime, timedelta

router = APIRouter(prefix="/api/invites", tags=["invites"])

def generate_invite_code():
    """Generate 6-character invite code"""
    return ''.join(secrets.choice(string.ascii_uppercase + string.digits) for _ in range(6))

@router.post("/check-users")
async def check_users(
    data: CheckUsersRequest,
    user_id: str = Depends(get_current_user),
    supabase = Depends(get_supabase)
):
    """Check which phone numbers are existing users"""
    existing_users = []
    needs_invite = []
    
    for phone in data.phone_numbers:
        # Check if user exists in profiles table
        # In production, you'd check against Supabase Auth
        result = supabase.table("profiles") \
            .select("id, first_name, phone_number") \
            .eq("phone_number", phone) \
            .execute()
        
        if result.data:
            user_data = result.data[0]
            existing_users.append({
                "phone_number": phone,
                "user_id": user_data["id"],
                "first_name": user_data.get("first_name", "Unknown")
            })
        else:
            needs_invite.append(phone)
    
    return {
        "existing": existing_users,
        "needs_invite": needs_invite
    }

@router.post("/send")
async def send_invites(
    data: SendInvitesRequest,
    background_tasks: BackgroundTasks,
    user_id: str = Depends(get_current_user),
    supabase = Depends(get_supabase)
):
    """Send invite SMS to non-users"""
    # Verify user is member of group
    membership = supabase.table("group_members") \
        .select("*") \
        .eq("group_id", data.group_id) \
        .eq("user_id", user_id) \
        .eq("is_active", True) \
        .execute()
    
    if not membership.data:
        raise HTTPException(status_code=403, detail="Not a member of this group")
    
    # Get group and sender info
    group = supabase.table("groups") \
        .select("name") \
        .eq("id", data.group_id) \
        .single() \
        .execute()
    
    sender = supabase.table("profiles") \
        .select("first_name") \
        .eq("id", user_id) \
        .single() \
        .execute()
    
    if not group.data:
        raise HTTPException(status_code=404, detail="Group not found")
    
    group_name = group.data["name"]
    sender_name = sender.data["first_name"] if sender.data else "Someone"
    
    sent_invites = []
    
    for phone in data.phone_numbers:
        # Check if already invited recently (last 24 hours)
        recent_invite = supabase.table("invites") \
            .select("*") \
            .eq("phone_number", phone) \
            .eq("group_id", data.group_id) \
            .gte("created_at", (datetime.now() - timedelta(days=1)).isoformat()) \
            .execute()
        
        if recent_invite.data:
            continue  # Skip if already invited recently
        
        # Generate unique invite code
        invite_code = generate_invite_code()
        
        # Store invite
        invite_result = supabase.table("invites").insert({
            "code": invite_code,
            "group_id": data.group_id,
            "phone_number": phone,
            "invited_by": user_id,
            "expires_at": (datetime.now() + timedelta(days=7)).isoformat()
        }).execute()
        
        if invite_result.data:
            # Queue SMS sending in background
            background_tasks.add_task(
                send_invite_sms_task,
                phone,
                sender_name,
                group_name,
                invite_code
            )
            
            sent_invites.append({
                "phone_number": phone,
                "invite_code": invite_code
            })
    
    # Add existing users directly to group
    added_count = 0
    for user_data in data.existing_users:
        # Check if already a member
        existing_member = supabase.table("group_members") \
            .select("*") \
            .eq("group_id", data.group_id) \
            .eq("user_id", user_data["user_id"]) \
            .execute()
        
        if not existing_member.data:
            # Add to group
            supabase.table("group_members").insert({
                "group_id": data.group_id,
                "user_id": user_data["user_id"]
            }).execute()
            added_count += 1
    
    return {
        "sent_invites": sent_invites,
        "added_members": added_count
    }

@router.get("/pending/{group_id}")
async def get_pending_invites(
    group_id: str,
    user_id: str = Depends(get_current_user),
    supabase = Depends(get_supabase)
):
    """Get pending invites for a group"""
    # Verify membership
    membership = supabase.table("group_members") \
        .select("*") \
        .eq("group_id", group_id) \
        .eq("user_id", user_id) \
        .eq("is_active", True) \
        .execute()
    
    if not membership.data:
        raise HTTPException(status_code=403, detail="Not a member of this group")
    
    # Get pending invites with inviter info
    invites = supabase.table("invites") \
        .select("*, profiles!invited_by(first_name)") \
        .eq("group_id", group_id) \
        .is_("used_at", "null") \
        .gte("expires_at", datetime.now().isoformat()) \
        .execute()
    
    return {"invites": invites.data}

@router.post("/redeem/{code}")
async def redeem_invite(
    code: str,
    user_id: str = Depends(get_current_user),
    supabase = Depends(get_supabase)
):
    """Redeem invite code to join group"""
    # Find valid invite
    invite = supabase.table("invites") \
        .select("*, groups(name)") \
        .eq("code", code.upper()) \
        .gte("expires_at", datetime.now().isoformat()) \
        .is_("used_at", "null") \
        .single() \
        .execute()
    
    if not invite.data:
        raise HTTPException(status_code=404, detail="Invalid or expired invite code")
    
    invite_data = invite.data
    
    # Check if already a member
    existing_member = supabase.table("group_members") \
        .select("*") \
        .eq("group_id", invite_data["group_id"]) \
        .eq("user_id", user_id) \
        .execute()
    
    if existing_member.data:
        # Reactivate if inactive
        if not existing_member.data[0]["is_active"]:
            supabase.table("group_members").update({
                "is_active": True
            }).eq("group_id", invite_data["group_id"]) \
              .eq("user_id", user_id) \
              .execute()
        else:
            raise HTTPException(status_code=400, detail="Already a member of this group")
    else:
        # Add user to group
        supabase.table("group_members").insert({
            "group_id": invite_data["group_id"],
            "user_id": user_id
        }).execute()
    
    # Mark invite as used
    supabase.table("invites").update({
        "used_at": datetime.now().isoformat(),
        "used_by": user_id
    }).eq("code", code.upper()).execute()
    
    return {
        "group_id": invite_data["group_id"],
        "group_name": invite_data["groups"]["name"] if invite_data.get("groups") else "Unknown"
    }

# Background task for sending SMS
async def send_invite_sms_task(
    phone_number: str,
    sender_name: str,
    group_name: str,
    invite_code: str
):
    """Background task to send invite SMS"""
    from app.services.sms_service import send_invite_sms
    
    app_store_link = "https://apps.apple.com/app/dayly/id..."  # Replace with actual
    
    message = (
        f"{sender_name} invited you to share daily photos "
        f"with '{group_name}' on Dayly.\n\n"
        f"Download: {app_store_link}\n"
        f"Invite code: {invite_code}"
    )
    
    try:
        await send_invite_sms(phone_number, message)
    except Exception as e:
        print(f"Failed to send SMS to {phone_number}: {e}")