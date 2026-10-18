import Foundation

enum BundledPatchSeeder {

    // MARK: - Legacy bundled projects

    // Estos UUID pertenecen únicamente a los proyectos que antiguamente
    // venían integrados dentro de la IPA.
    //
    // Ya NO se crean automáticamente.
    // Supabase / Panel es ahora la fuente de contenido.

    private static let retiredBundledProjectIDs: Set<UUID> = [
        UUID(uuidString: "A55E0001-3105-4A55-9001-00000000BEEF")!, // Asset Indexer
        UUID(uuidString: "A55E0003-3105-4A55-9001-00000000BEEF")!, // Shaders
        UUID(uuidString: "A55E0002-0144-4A55-9001-00000000BEEF")!, // 144 fps
        UUID(uuidString: "A55E0004-3105-4A55-9001-00000000BEEF")!  // TIO GREEG
    ]

    // MARK: - Public API

    // Ya no existen proyectos obligatorios integrados en la IPA.
    // Todo el contenido visible debe venir del panel.
    static var projectIDs: Set<UUID> {
        []
    }

    // Ya no existen proyectos bundled que necesiten prioridad especial.
    static func sortRank(for id: UUID) -> Int {
        Int.max
    }

    // RemoteContentSyncService todavía llama esta función.
    //
    // Ahora NO crea proyectos.
    // Solo limpia los proyectos bundled antiguos que pudieran
    // quedar instalados por una versión anterior de GREEG APP.
    static func seedIfNeeded(
        fileManager: FileManager = .default
    ) {
        cleanupRetiredBundledProjects(
            fileManager: fileManager
        )
    }

    // MARK: - Cleanup

    private static func cleanupRetiredBundledProjects(
        fileManager: FileManager
    ) {

        let items = PatchProjectLibrary.load(
            fileManager: fileManager
        )

        var removedCount = 0

        for item in items {

            guard let project = item.project else {
                continue
            }

            // IMPORTANTE:
            // Solo eliminamos los UUID exactos que pertenecían
            // a los proyectos incluidos antiguamente en la IPA.
            //
            // NO eliminamos por nombre.
            // Así un proyecto nuevo creado desde el panel puede llamarse
            // "144 fps", "Shaders", "Asset Indexer", etc. sin ser borrado.
            guard retiredBundledProjectIDs.contains(project.id) else {
                continue
            }

            do {

                // PatchProjectLibrary.delete() elimina:
                // - el paquete .3105
                // - su workspace
                // - la key local asociada
                try PatchProjectLibrary.delete(
                    item,
                    fileManager: fileManager
                )

                removedCount += 1

                log(
                    "patch cleanup: eliminado proyecto bundled antiguo: " +
                    "\(project.name); id=\(project.id.uuidString)"
                )

            } catch {

                log(
                    "patch cleanup: ERROR eliminando " +
                    "\(project.name); id=\(project.id.uuidString); " +
                    "\(error.localizedDescription)"
                )
            }
        }

        if removedCount > 0 {

            log(
                "patch cleanup: \(removedCount) " +
                "proyecto(s) bundled antiguo(s) eliminado(s)"
            )

        } else {

            log(
                "patch cleanup: no quedan proyectos bundled antiguos"
            )
        }
    }
}
