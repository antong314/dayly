-- Create photos storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'photos',
    'photos',
    false, -- Not public, requires authentication
    10485760, -- 10MB file size limit
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/heic', 'image/heif']
)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for photos bucket
CREATE POLICY "Users can upload photos to their groups"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'photos' 
    AND auth.uid()::text = (storage.foldername(name))[1]
    AND EXISTS (
        SELECT 1 FROM group_members
        WHERE group_members.group_id::text = (storage.foldername(name))[2]
        AND group_members.user_id = auth.uid()
        AND group_members.is_active = true
    )
);

CREATE POLICY "Users can view photos in their groups"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'photos'
    AND EXISTS (
        SELECT 1 FROM group_members
        WHERE group_members.group_id::text = (storage.foldername(name))[2]
        AND group_members.user_id = auth.uid()
        AND group_members.is_active = true
    )
);

CREATE POLICY "Users can delete their own photos"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'photos'
    AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Function to clean up orphaned storage files when photos are deleted
CREATE OR REPLACE FUNCTION delete_storage_on_photo_delete()
RETURNS TRIGGER AS $$
BEGIN
    -- Delete the file from storage when photo record is deleted
    DELETE FROM storage.objects
    WHERE bucket_id = 'photos'
    AND name = OLD.storage_path;
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to automatically clean up storage
CREATE TRIGGER delete_photo_storage
BEFORE DELETE ON photos
FOR EACH ROW
EXECUTE FUNCTION delete_storage_on_photo_delete();
