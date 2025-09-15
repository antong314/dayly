from pydantic import BaseModel, validator, Field
from datetime import datetime
from typing import Optional, List, Dict
from uuid import UUID
import re

# Authentication schemas
class PhoneVerification(BaseModel):
    phone_number: str
    channel: str = "sms"  # Supabase only supports SMS for now
    
    @validator('channel')
    def validate_channel(cls, v):
        if v not in ["sms", "whatsapp"]:
            raise ValueError("Channel must be 'sms' or 'whatsapp'")
        return v
    
    @validator('phone_number')
    def validate_phone(cls, v):
        # Basic phone validation
        if not re.match(r'^\+[1-9]\d{1,14}$', v):
            raise ValueError('Invalid phone number format')
        return v

class VerifyCode(BaseModel):
    phone_number: str
    code: str
    first_name: Optional[str] = None
    
    @validator('code')
    def validate_code(cls, v):
        if not re.match(r'^\d{6}$', v):
            raise ValueError('Code must be 6 digits')
        return v

# User schemas
class UserBase(BaseModel):
    phone_number: str
    first_name: Optional[str] = None

class UserCreate(UserBase):
    pass

class User(UserBase):
    id: UUID
    created_at: datetime
    last_active: Optional[datetime] = None
    
    class Config:
        from_attributes = True

# Group schemas
class GroupBase(BaseModel):
    name: str

class GroupCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=50)
    member_phone_numbers: List[str] = []
    
    @validator('name')
    def validate_name(cls, v):
        return v.strip()
    
    @validator('member_phone_numbers')
    def validate_phone_numbers(cls, v):
        for phone in v:
            if not re.match(r'^\+[1-9]\d{1,14}$', phone):
                raise ValueError(f'Invalid phone number format: {phone}')
        return v

class Group(GroupBase):
    id: UUID
    created_by: UUID
    created_at: datetime
    member_count: Optional[int] = 0
    
    class Config:
        from_attributes = True

class MemberResponse(BaseModel):
    id: str
    first_name: Optional[str]

class LastPhotoResponse(BaseModel):
    created_at: datetime
    sender_id: str
    sender_name: str = "Unknown"

class GroupResponse(BaseModel):
    id: str
    name: str
    created_at: datetime
    member_count: int
    members: List[MemberResponse]
    has_sent_today: bool
    last_photo: Optional[LastPhotoResponse]

class AddMembers(BaseModel):
    phone_numbers: List[str]
    
    @validator('phone_numbers')
    def validate_phone_numbers(cls, v):
        for phone in v:
            if not re.match(r'^\+[1-9]\d{1,14}$', phone):
                raise ValueError(f'Invalid phone number format: {phone}')
        return v

# Photo schemas
class PhotoBase(BaseModel):
    group_id: UUID

class Photo(PhotoBase):
    id: UUID
    sender_id: UUID
    storage_path: str
    created_at: datetime
    expires_at: datetime
    
    class Config:
        from_attributes = True

class PhotoUploadResponse(BaseModel):
    photo_id: str
    expires_at: datetime
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

class UploadURLRequest(BaseModel):
    group_id: str

class PhotoResponse(BaseModel):
    id: str
    sender_id: str
    sender_name: str
    url: str
    created_at: datetime
    expires_at: datetime

# Device schemas
class DeviceRegistration(BaseModel):
    device_token: str
    platform: str = "ios"
    
    @validator('device_token')
    def validate_token(cls, v):
        # Basic validation for APNS token format (64 hex characters)
        if not re.match(r'^[a-fA-F0-9]{64}$', v):
            raise ValueError('Invalid device token format')
        return v
    
    @validator('platform')
    def validate_platform(cls, v):
        if v not in ['ios', 'android']:
            raise ValueError('Platform must be ios or android')
        return v

# Invite schemas
class CheckUsersRequest(BaseModel):
    phone_numbers: List[str]
    
    @validator('phone_numbers')
    def validate_phone_numbers(cls, v):
        for phone in v:
            if not re.match(r'^\+[1-9]\d{1,14}$', phone):
                raise ValueError(f'Invalid phone number format: {phone}')
        return v

class ExistingUserInfo(BaseModel):
    phone_number: str
    user_id: str
    first_name: str

class SendInvitesRequest(BaseModel):
    group_id: str
    phone_numbers: List[str]
    existing_users: List[Dict[str, str]] = []
    
    @validator('phone_numbers')
    def validate_phone_numbers(cls, v):
        for phone in v:
            if not re.match(r'^\+[1-9]\d{1,14}$', phone):
                raise ValueError(f'Invalid phone number format: {phone}')
        return v

class InviteCreate(BaseModel):
    group_id: UUID
    phone_number: str

class InviteResponse(BaseModel):
    id: str
    code: str
    phone_number: str
    invited_by_name: str
    created_at: datetime
    expires_at: datetime

class Invite(BaseModel):
    id: UUID
    code: str
    group_id: UUID
    phone_number: str
    invited_by: UUID
    created_at: datetime
    expires_at: datetime
    used_at: Optional[datetime] = None
    used_by: Optional[UUID] = None
    
    class Config:
        from_attributes = True
