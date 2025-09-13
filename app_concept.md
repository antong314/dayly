Core Concept: "Dayly"
One photo. Once a day. To the people who matter.
App Structure
Initial Setup (One-Time)

No account creation - just verify phone number via SMS
Phone number becomes your identifier
Access contacts to invite/add people
Create your first group in 30 seconds

Main Screen: Groups
Visual Design:

Pure white background
Large, touchable cards for each group (limit to 5 groups max)
Each card shows:

Group name (e.g., "Family", "College Friends")
Small profile bubbles of members (max 5 shown)
Subtle indicator if you've sent today (small green dot)
Last photo timestamp (e.g., "2 hours ago")


Bottom: Simple "+" button to create new group

Behavior:

Tap group → Camera opens immediately
Long press → View today's photos from this group
No pull-to-refresh, no loading spinners - everything cached locally

Camera Flow
Immediate Camera:

Opens directly to camera (no gallery option)
Single capture button
Flash toggle
Front/back camera toggle
"X" to cancel in top left

After Capture:

Shows preview for 3 seconds
Two options only:

"Send" (large, primary button)
"Retake" (small text link)


After sending: Brief "Sent ✓" confirmation, then back to Groups

Dayly Limit:

If already sent today to this group: Camera doesn't open
Instead, shows gentle message: "Already shared today. See you tomorrow!"
Shows countdown to midnight (local time)

Viewing Photos
Today's Photos View:

Accessed by long-pressing a group
Full-screen photo viewer
Swipe horizontally between today's photos from group members
Each photo shows:

Sender's first name only
Time sent (e.g., "3 hours ago")


No commenting, no reactions, no saving
Photos disappear after 48 hours

Notifications
Single Dayly Notification:

One notification per group per day: "[Group] has new photos"
Arrives when first photo is shared that day
Subsequent photos don't trigger notifications
Tap notification → Opens directly to that group's photos

Group Management
Creating a Group:

Tap "+" on main screen
Name the group (required, 20 char max)
Add people from contacts (2-12 people max)
Send invite via SMS with download link
Done

Inviting People:

If they have the app: Automatically added
If not: SMS with App Store link + invite code
When they join, they see last 24 hours of photos

Group Settings (Minimal):

Accessible via small "..." on group card
Options:

Rename group
Add people
Leave group
Mute notifications


No admin roles, no permissions - everyone equal

Technical Approach
No Sign-Up Flow:

Download app
Enter phone number
Verify via SMS code
Grant contacts permission
Ready to use

Privacy & Data:

Photos encrypted end-to-end
Stored locally + cloud backup for 48 hours only
No profile pictures, no usernames
Only first names from contacts

Constraints as Features:

One photo per day per group: Makes each photo intentional
No gallery access: Encourages in-the-moment sharing
No reactions: Removes social pressure
48-hour limit: Keeps it ephemeral and storage-light
Group size limit (12): Maintains intimacy

Visual Design Language
Typography:

SF Pro Display for group names (bold, large)
SF Pro Text for UI elements (regular, medium)
Minimal text throughout

Colors:

Primary: Pure white backgrounds
Text: Black and system grays
Accent: Soft green for "sent" states
Photos displayed edge-to-edge, no borders

Animations:

Subtle fade transitions
Camera slides up from bottom
Photos fade in when received
No bouncy or playful animations - calm and serene

Edge Cases Handled Simply
Missed a day?

No problem, no streaks, no guilt
Just pick up whenever

Want to save a photo?

Screenshot it (no save button)
App doesn't prevent or track this

Someone sends inappropriate content?

Long press their photo → "Block person"
They're removed from all your shared groups

International groups?

"Day" resets at each user's local midnight
Simple, no timezone complexity

What's Intentionally Missing

No profile pages
No captions or text
No filters or editing
No read receipts
No "stories" or public sharing
No search or hashtags
No archive or memories
No widgets or complications

The Experience
Opening the app feels like picking up a Polaroid camera - immediate, tactile, simple. The constraint of one photo makes you think: "What moment today do I want to share with these people?" It's not about documenting everything or getting validation - it's a digital tap on the shoulder saying "thinking of you."
The app respects your time and attention. No infinite scroll, no red notification badges, no FOMO. Just a simple, daily ritual of connection.