# Core Data Setup Instructions

Since Core Data model files (.xcdatamodeld) need to be created in Xcode, follow these steps:

## Creating the Core Data Model

1. **Open the project in Xcode**
2. **Create a new Core Data model**:
   - Right-click on the `Core/Storage` folder
   - Select "New File..."
   - Choose "Data Model" under the Core Data section
   - Name it "Dayly.xcdatamodeld"

3. **Add the following entities**:

### User Entity
- **Attributes**:
  - `id`: UUID
  - `phoneNumber`: String
  - `firstName`: String (Optional)

### Group Entity
- **Attributes**:
  - `id`: UUID
  - `name`: String
  - `createdAt`: Date
  - `lastPhotoDate`: Date (Optional)
  - `hasSentToday`: Boolean
- **Relationships**:
  - `members`: To Many relationship to GroupMember (Cascade delete)

### GroupMember Entity
- **Attributes**:
  - `userId`: UUID
  - `firstName`: String
  - `joinedAt`: Date
- **Relationships**:
  - `group`: To One relationship to Group (Nullify delete)

### Photo Entity
- **Attributes**:
  - `id`: UUID
  - `groupId`: UUID
  - `senderId`: UUID
  - `senderName`: String
  - `localPath`: String (Optional)
  - `remoteUrl`: String (Optional)
  - `createdAt`: Date
  - `expiresAt`: Date

### Daily_sends Entity
- **Attributes**:
  - `user_id`: String
  - `group_id`: String
  - `sent_date`: Date

## Important Settings

1. **Set the Module** to "Current Product Module" for all entities
2. **Set the Codegen** to "Manual/None" for all entities (we're using manual NSManagedObject subclasses)
3. **Save the model**

## Verify Setup

After creating the model, build the project to ensure:
- The CoreDataModels.swift file compiles without errors
- The app launches without Core Data errors

## Note
The CoreDataModels.swift file already contains the NSManagedObject extensions for these entities, so you don't need to generate them from Xcode.
