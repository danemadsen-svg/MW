import SwiftData

enum WardrobeMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

enum Persistence {
    /// The schema currently in use. Point this at the newest `VersionedSchema`.
    static let schema = Schema(versionedSchema: SchemaV1.self)

    /// Builds the app's store. The store is local only: CloudKit sync is explicitly off so
    /// no catalog data leaves the device, even if an iCloud entitlement is added later.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "Wardrobe",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: WardrobeMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
