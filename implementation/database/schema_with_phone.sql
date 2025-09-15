-- Drop existing tables if they exist (CASCADE will drop dependent objects)
DROP TABLE IF EXISTS daily_sends CASCADE;
DROP TABLE IF EXISTS photos CASCADE;
DROP TABLE IF EXISTS group_members CASCADE;
DROP TABLE IF EXISTS groups CASCADE;
DROP TABLE IF EXISTS invites CASCADE;
DROP TABLE IF EXISTS user_devices CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- User profiles (with phone for WhatsApp auth)
CREATE TABLE profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone VARCHAR(20) UNIQUE NOT NULL,
    first_name VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_active TIMESTAMP
);

-- Create index for phone lookups
CREATE INDEX idx_profiles_phone ON profiles(phone);

-- Groups table
CREATE TABLE groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) NOT NULL,
    created_by UUID REFERENCES profiles(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Group members
CREATE TABLE group_members (
    group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (group_id, user_id)
);

-- Photos table with automatic expiration
CREATE TABLE photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES profiles(id),
    storage_path VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP DEFAULT (CURRENT_TIMESTAMP + INTERVAL '48 hours')
);

-- Track daily sends
CREATE TABLE daily_sends (
    user_id UUID REFERENCES profiles(id),
    group_id UUID REFERENCES groups(id),
    sent_date DATE DEFAULT CURRENT_DATE,
    PRIMARY KEY (user_id, group_id, sent_date)
);

-- Invites
CREATE TABLE invites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(6) UNIQUE NOT NULL,
    group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
    phone_number VARCHAR(20) NOT NULL,
    invited_by UUID REFERENCES profiles(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    used_at TIMESTAMP,
    used_by UUID REFERENCES profiles(id)
);

-- Push notification tokens
CREATE TABLE user_devices (
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    device_token VARCHAR(255) NOT NULL,
    platform VARCHAR(20) DEFAULT 'ios',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, device_token)
);

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_sends ENABLE ROW LEVEL SECURITY;
ALTER TABLE invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

-- RLS Policies for profiles
CREATE POLICY "Service role can manage all profiles"
    ON profiles FOR ALL
    USING (auth.role() = 'service_role');

CREATE POLICY "Users can view their own profile"
    ON profiles FOR SELECT
    USING (auth.uid()::text = id::text);

CREATE POLICY "Users can update their own profile"
    ON profiles FOR UPDATE
    USING (auth.uid()::text = id::text);

-- RLS Policies for groups
CREATE POLICY "Users can view groups they belong to"
    ON groups FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM group_members
            WHERE group_members.group_id = groups.id
            AND group_members.user_id::text = auth.uid()::text
            AND group_members.is_active = true
        )
    );

CREATE POLICY "Users can create groups"
    ON groups FOR INSERT
    WITH CHECK (created_by::text = auth.uid()::text);

-- RLS Policies for group_members
CREATE POLICY "Users can view members of their groups"
    ON group_members FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM group_members gm2
            WHERE gm2.group_id = group_members.group_id
            AND gm2.user_id::text = auth.uid()::text
            AND gm2.is_active = true
        )
    );

-- RLS Policies for photos
CREATE POLICY "Users can view photos in their groups"
    ON photos FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM group_members
            WHERE group_members.group_id = photos.group_id
            AND group_members.user_id::text = auth.uid()::text
            AND group_members.is_active = true
        )
    );

CREATE POLICY "Users can upload photos to their groups"
    ON photos FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM group_members
            WHERE group_members.group_id = photos.group_id
            AND group_members.user_id::text = auth.uid()::text
            AND group_members.is_active = true
        )
    );

-- Service role bypass for all operations
CREATE POLICY "Service role bypass" ON profiles FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Service role bypass" ON groups FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Service role bypass" ON group_members FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Service role bypass" ON photos FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Service role bypass" ON daily_sends FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Service role bypass" ON invites FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Service role bypass" ON user_devices FOR ALL USING (auth.role() = 'service_role');
