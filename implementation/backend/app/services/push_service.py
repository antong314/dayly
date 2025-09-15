import asyncio
from typing import List, Optional
from datetime import datetime
import json
import os
from app.core.supabase import get_supabase
from app.core.config import settings

# For production, you'd use a proper APNS library like aioapns
# This is a simplified implementation for demonstration

class PushNotificationService:
    def __init__(self):
        self.supabase = get_supabase()
        # In production, initialize APNS client here
        # self.apns_client = self._initialize_apns()
        self.is_production = settings.ENVIRONMENT == "production"
    
    async def send_group_notification(
        self, 
        group_id: str, 
        sender_id: str
    ):
        """Send notification for new photos in group"""
        try:
            # Check if this is the first photo of the day for this group
            if not await self._is_first_photo_today(group_id):
                print(f"Not the first photo today for group {group_id}, skipping notification")
                return
            
            # Get group details
            group_data = await self._get_group_details(group_id)
            if not group_data:
                print(f"Group {group_id} not found")
                return
            
            group_name = group_data["name"]
            
            # Get sender name
            sender_name = await self._get_user_name(sender_id)
            
            # Get device tokens for all active members except sender
            device_tokens = await self._get_member_device_tokens(group_id, sender_id)
            
            if not device_tokens:
                print(f"No device tokens found for group {group_id}")
                return
            
            # Prepare notification payload
            notification = {
                "aps": {
                    "alert": {
                        "title": "Dayly",
                        "body": f"{group_name} has new photos"
                    },
                    "badge": 1,
                    "sound": "default",
                    "thread-id": group_id  # For notification grouping
                },
                "group_id": group_id,
                "type": "new_photos"
            }
            
            # Send notifications
            await self._send_notifications(device_tokens, notification)
            
            print(f"Sent {len(device_tokens)} notifications for group {group_id}")
            
        except Exception as e:
            print(f"Failed to send group notification: {str(e)}")
    
    async def _is_first_photo_today(self, group_id: str) -> bool:
        """Check if this is the first photo of the day for the group"""
        today_start = datetime.now().replace(
            hour=0, minute=0, second=0, microsecond=0
        )
        
        response = self.supabase.table("photos") \
            .select("id") \
            .eq("group_id", group_id) \
            .gte("created_at", today_start.isoformat()) \
            .execute()
        
        # If there's 1 or fewer photos, this is the first
        return len(response.data) <= 1
    
    async def _get_group_details(self, group_id: str) -> Optional[dict]:
        """Get group details"""
        response = self.supabase.table("groups") \
            .select("*") \
            .eq("id", group_id) \
            .single() \
            .execute()
        
        return response.data if response.data else None
    
    async def _get_user_name(self, user_id: str) -> str:
        """Get user's first name"""
        response = self.supabase.table("profiles") \
            .select("first_name") \
            .eq("id", user_id) \
            .single() \
            .execute()
        
        if response.data and response.data.get("first_name"):
            return response.data["first_name"]
        return "Someone"
    
    async def _get_member_device_tokens(self, group_id: str, exclude_user_id: str) -> List[dict]:
        """Get device tokens for all active group members except specified user"""
        # Get active group members
        members_response = self.supabase.table("group_members") \
            .select("user_id") \
            .eq("group_id", group_id) \
            .eq("is_active", True) \
            .neq("user_id", exclude_user_id) \
            .execute()
        
        if not members_response.data:
            return []
        
        member_ids = [m["user_id"] for m in members_response.data]
        
        # Get device tokens for these members
        devices_response = self.supabase.table("user_devices") \
            .select("device_token, platform") \
            .in_("user_id", member_ids) \
            .execute()
        
        return devices_response.data if devices_response.data else []
    
    async def _send_notifications(self, device_tokens: List[dict], payload: dict):
        """Send notifications to device tokens"""
        # In production, this would use APNS
        # For now, we'll just log what we would send
        for device in device_tokens:
            if device["platform"] == "ios":
                print(f"Would send APNS notification to {device['device_token'][:8]}...")
                print(f"Payload: {json.dumps(payload, indent=2)}")
                
                # In production:
                # await self.apns_client.send_notification(
                #     device_token=device["device_token"],
                #     notification=payload
                # )
    
    async def send_test_notification(self, user_id: str, title: str = "Test", body: str = "Test notification"):
        """Send a test notification to a specific user"""
        # Get user's devices
        devices_response = self.supabase.table("user_devices") \
            .select("device_token, platform") \
            .eq("user_id", user_id) \
            .execute()
        
        if not devices_response.data:
            print(f"No devices found for user {user_id}")
            return
        
        payload = {
            "aps": {
                "alert": {
                    "title": title,
                    "body": body
                },
                "sound": "default"
            },
            "type": "test"
        }
        
        await self._send_notifications(devices_response.data, payload)

# Global instance
push_service = PushNotificationService()

# Helper function for background task
async def schedule_group_notification(group_id: str, sender_id: str):
    """Schedule a group notification to be sent asynchronously"""
    await push_service.send_group_notification(group_id, sender_id)
