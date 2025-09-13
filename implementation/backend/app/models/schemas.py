from pydantic import BaseModel, validator
from datetime import datetime
from typing import Optional, List
from uuid import UUID
import re

# Authentication schemas
class PhoneVerification(BaseModel):
    phone_number: str
    
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

class GroupCreate(GroupBase):
    pass

class Group(GroupBase):
    id: UUID
    created_by: UUID
    created_at: datetime
    member_count: Optional[int] = 0
    
    class Config:
        from_attributes = True

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

# Invite schemas
class InviteCreate(BaseModel):
    group_id: UUID
    phone_number: str

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
