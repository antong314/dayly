from typing import Optional, BinaryIO
from uuid import uuid4
from app.core.supabase import get_supabase_client
import mimetypes

class StorageService:
    def __init__(self):
        self.bucket_name = "photos"
        self.client = get_supabase_client()
        
    async def upload_photo(self, file: BinaryIO, group_id: str, user_id: str) -> Optional[str]:
        """Upload photo to Supabase storage"""
        # Generate unique filename
        file_extension = "jpg"  # Default, will be determined from file in Phase 5
        filename = f"{group_id}/{user_id}/{uuid4()}.{file_extension}"
        
        try:
            # Upload to Supabase storage
            # To be fully implemented in Phase 5
            # response = self.client.storage.from_(self.bucket_name).upload(filename, file)
            return filename
        except Exception as e:
            print(f"Error uploading photo: {e}")
            return None
    
    def get_photo_url(self, storage_path: str) -> str:
        """Get signed URL for photo"""
        try:
            # Get signed URL from Supabase
            # To be fully implemented in Phase 6
            # url = self.client.storage.from_(self.bucket_name).get_public_url(storage_path)
            return f"https://placeholder.com/{storage_path}"
        except Exception as e:
            print(f"Error getting photo URL: {e}")
            return ""
    
    async def delete_photo(self, storage_path: str) -> bool:
        """Delete photo from storage"""
        try:
            # Delete from Supabase storage
            # To be implemented when needed
            # self.client.storage.from_(self.bucket_name).remove([storage_path])
            return True
        except Exception as e:
            print(f"Error deleting photo: {e}")
            return False

# Singleton instance
storage_service = StorageService()
