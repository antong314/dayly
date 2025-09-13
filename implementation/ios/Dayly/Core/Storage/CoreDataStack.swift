import CoreData
import Foundation

class CoreDataStack {
    static let shared = CoreDataStack()
    
    private init() {}
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Dayly")
        
        // Configure for better performance
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // In production, handle this error appropriately
                fatalError("Core Data failed to load: \(error), \(error.userInfo)")
            }
            
            // Configure for performance
            storeDescription.shouldMigrateStoreAutomatically = true
            storeDescription.shouldInferMappingModelAutomatically = true
        }
        
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    // Create a background context for heavy operations
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        return context
    }
    
    // MARK: - Core Data Operations
    
    func save(context: NSManagedObjectContext? = nil) throws {
        let context = context ?? viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                throw CoreDataError.saveFailed(nsError)
            }
        }
    }
    
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                do {
                    let result = try block(context)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Batch Operations
    
    func batchDelete<T: NSManagedObject>(_ entityType: T.Type, predicate: NSPredicate? = nil) throws {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: entityType))
        fetchRequest.predicate = predicate
        
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs
        
        let result = try viewContext.execute(deleteRequest) as? NSBatchDeleteResult
        
        if let objectIDs = result?.result as? [NSManagedObjectID] {
            let changes = [NSDeletedObjectsKey: objectIDs]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [viewContext])
        }
    }
    
    // MARK: - Utility Methods
    
    func deleteExpiredPhotos() throws {
        let predicate = NSPredicate(format: "expiresAt < %@", Date() as NSDate)
        try batchDelete(Photo.self, predicate: predicate)
    }
    
    func resetAllData() throws {
        // Delete all entities
        let entities = ["User", "Group", "GroupMember", "Photo"]
        
        for entity in entities {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try viewContext.execute(deleteRequest)
        }
        
        try save()
    }
}

// MARK: - Core Data Errors

enum CoreDataError: LocalizedError {
    case saveFailed(NSError)
    case fetchFailed(NSError)
    case invalidEntity
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch data: \(error.localizedDescription)"
        case .invalidEntity:
            return "Invalid entity configuration"
        }
    }
}
