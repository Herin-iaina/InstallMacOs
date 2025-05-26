import Foundation

// Configuration
let serverURL = "http://localhost:5001"
let tempDir = "/var/tmp"
let logFile = "/var/tmp/macos_installer_client.log"

// Structure pour les informations des fichiers
struct FileInfo: Codable {
    let name: String
    let size: Int64
    let modified: TimeInterval
}

struct FileList: Codable {
    let files: [FileInfo]
}

// Fonction de logging simplifiée
func log(_ message: String) {
    print("[DEBUG] \(message)")
    let logMessage = "[\(Date())] [DEBUG] \(message)"
    try? logMessage.appendLineToURL(fileURL: URL(fileURLWithPath: logFile))
}

// Test des fonctions une par une
func testPrerequisites() {
    print("\n=== Test des prérequis ===")
    
    // Test accès en écriture
    if FileManager.default.isWritableFile(atPath: tempDir) {
        log("✅ Dossier temporaire accessible en écriture")
    } else {
        log("❌ Dossier temporaire non accessible en écriture")
    }
    
    // Test espace disque
    let requiredSpace = 20 * 1024 * 1024 // 20 GB en KB
    let availableSpace = getAvailableDiskSpace(path: tempDir)
    log("Espace disponible: \(availableSpace/1024/1024)GB")
    if availableSpace >= requiredSpace {
        log("✅ Espace disque suffisant")
    } else {
        log("❌ Espace disque insuffisant")
    }
    
    // Test unzip
    if isUnzipInstalled() {
        log("✅ unzip est installé")
    } else {
        log("❌ unzip n'est pas installé")
    }
}

func testServerConnection() {
    print("\n=== Test de la connexion au serveur ===")
    do {
        let fileList = try getFileList(from: serverURL)
        log("✅ Connexion au serveur réussie")
        log("Fichiers trouvés: \(fileList.files.count)")
        
        // Afficher les détails de chaque fichier
        for file in fileList.files {
            let date = Date(timeIntervalSince1970: file.modified)
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            
            log("""
                Fichier: \(file.name)
                - Taille: \(formatFileSize(file.size))
                - Modifié le: \(formatter.string(from: date))
                """)
        }
    } catch {
        log("❌ Erreur de connexion au serveur: \(error)")
    }
}

func testFileDownload() {
    print("\n=== Test du téléchargement des fichiers ===")
    
    // Récupérer la liste des fichiers
    do {
        let fileList = try getFileList(from: serverURL)
        log("Fichiers trouvés sur le serveur: \(fileList.files.count)")
        
        if fileList.files.isEmpty {
            log("❌ Aucun fichier trouvé sur le serveur")
            return
        }
        
        // Calculer la taille totale à télécharger
        let totalSize = fileList.files.reduce(0) { $0 + $1.size }
        log("Taille totale à télécharger: \(formatFileSize(totalSize))")
        
        // Télécharger chaque fichier
        for (index, file) in fileList.files.enumerated() {
            log("""
                Téléchargement du fichier \(index + 1)/\(fileList.files.count):
                - Nom: \(file.name)
                - Taille: \(formatFileSize(file.size))
                """)
            
            do {
                try downloadFile(file.name, from: serverURL, to: tempDir)
                
                // Vérifier si le fichier existe
                let filePath = "\(tempDir)/\(file.name)"
                if FileManager.default.fileExists(atPath: filePath) {
                    log("✅ Fichier téléchargé avec succès: \(file.name)")
                    
                    // Si c'est un fichier zip, le décompresser
                    if file.name.hasSuffix(".zip") {
                        log("Décompression du fichier zip: \(file.name)")
                        try unzipFile(filePath, in: tempDir)
                        log("✅ Fichier décompressé avec succès")
                        
                        // Supprimer le fichier zip après décompression
                        try? FileManager.default.removeItem(atPath: filePath)
                        log("Fichier zip supprimé: \(file.name)")
                    }
                } else {
                    log("❌ Fichier non trouvé après téléchargement: \(filePath)")
                }
            } catch {
                log("❌ Erreur lors du traitement de \(file.name): \(error)")
            }
        }
        
        log("✅ Téléchargement de tous les fichiers terminé")
        
        // Afficher le contenu du dossier temporaire
        if let downloadedFiles = try? FileManager.default.contentsOfDirectory(atPath: tempDir) {
            log("\nContenu du dossier temporaire après téléchargement:")
            for file in downloadedFiles {
                let filePath = "\(tempDir)/\(file)"
                if let attributes = try? FileManager.default.attributesOfItem(atPath: filePath) {
                    let size = attributes[.size] as? Int64 ?? 0
                    let date = attributes[.modificationDate] as? Date ?? Date()
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .medium
                    
                    log("""
                        - \(file)
                          Taille: \(formatFileSize(size))
                          Modifié le: \(formatter.string(from: date))
                        """)
                } else {
                    log("- \(file)")
                }
            }
        }
        
    } catch {
        log("❌ Erreur lors de la récupération de la liste des fichiers: \(error)")
    }
}

func createTestZip() {
    print("\n=== Création du fichier zip de test ===")
    let testDir = "\(tempDir)/test_dir"
    let testFile = "\(testDir)/test.txt"
    let testZip = "\(tempDir)/test.zip"
    
    // Créer un dossier de test
    try? FileManager.default.createDirectory(atPath: testDir, withIntermediateDirectories: true)
    
    // Créer un fichier de test
    let testContent = "Ceci est un fichier de test"
    try? testContent.write(toFile: testFile, atomically: true, encoding: .utf8)
    
    // Créer le zip
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
    process.arguments = ["-r", testZip, testDir]
    
    do {
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus == 0 {
            log("✅ Fichier zip de test créé avec succès")
        } else {
            log("❌ Erreur lors de la création du fichier zip de test")
        }
    } catch {
        log("❌ Erreur lors de la création du fichier zip de test: \(error)")
    }
    
    // Nettoyer le dossier de test
    try? FileManager.default.removeItem(atPath: testDir)
}

func testUnzip() {
    print("\n=== Test de la décompression ===")
    
    // Vérifier s'il y a des fichiers zip dans le dossier temporaire
    if let files = try? FileManager.default.contentsOfDirectory(atPath: tempDir) {
        let zipFiles = files.filter { $0.hasSuffix(".zip") }
        
        if zipFiles.isEmpty {
            log("ℹ️ Aucun fichier zip trouvé dans \(tempDir), test de décompression ignoré")
            return
        }
        
        log("Fichiers zip trouvés: \(zipFiles.count)")
        for zipFile in zipFiles {
            do {
                let fullPath = "\(tempDir)/\(zipFile)"
                log("Tentative de décompression de: \(zipFile)")
                
                try unzipFile(fullPath, in: tempDir)
                log("✅ Décompression réussie pour: \(zipFile)")
                
                // Vérifier le contenu décompressé
                if let extractedFiles = try? FileManager.default.contentsOfDirectory(atPath: tempDir) {
                    log("Contenu décompressé:")
                    for file in extractedFiles {
                        log("- \(file)")
                    }
                }
            } catch {
                log("❌ Erreur lors de la décompression de \(zipFile): \(error)")
            }
        }
    } else {
        log("❌ Impossible d'accéder au dossier temporaire")
    }
}

// Extensions et fonctions utilitaires
extension String {
    func appendLineToURL(fileURL: URL) throws {
        try (self + "\n").appendToURL(fileURL: fileURL)
    }
    
    func appendToURL(fileURL: URL) throws {
        let data = self.data(using: .utf8)!
        try data.append(fileURL: fileURL)
    }
}

extension Data {
    func append(fileURL: URL) throws {
        if let fileHandle = FileHandle(forWritingAtPath: fileURL.path) {
            defer {
                fileHandle.closeFile()
            }
            fileHandle.seekToEndOfFile()
            fileHandle.write(self)
        }
        else {
            try write(to: fileURL, options: .atomic)
        }
    }
}

func getAvailableDiskSpace(path: String) -> Int64 {
    let fileSystemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: path)
    return fileSystemAttributes?[.systemFreeSize] as? Int64 ?? 0
}

func isUnzipInstalled() -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    process.arguments = ["unzip"]
    
    let pipe = Pipe()
    process.standardOutput = pipe
    
    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    } catch {
        return false
    }
}

func getFileList(from serverURL: String) throws -> FileList {
    let url = URL(string: "\(serverURL)/files")!
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(FileList.self, from: data)
}

func downloadFile(_ filename: String, from serverURL: String, to tempDir: String) throws {
    let url = URL(string: "\(serverURL)/files/\(filename)")!
    let destination = URL(fileURLWithPath: "\(tempDir)/\(filename)")
    
    // Créer le dossier parent si nécessaire
    try? FileManager.default.createDirectory(atPath: destination.deletingLastPathComponent().path,
                                          withIntermediateDirectories: true)
    
    // Télécharger le fichier
    let data = try Data(contentsOf: url)
    try data.write(to: destination)
}

func unzipFile(_ filename: String, in tempDir: String) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
    process.arguments = ["-q", filename, "-d", tempDir]
    
    log("Commande unzip: unzip -q \(filename) -d \(tempDir)")
    
    try process.run()
    process.waitUntilExit()
    
    if process.terminationStatus != 0 {
        throw NSError(domain: "UnzipError", code: Int(process.terminationStatus), userInfo: nil)
    }
}

// Fonctions utilitaires
func formatFileSize(_ size: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: size)
}

// Exécuter les tests
print("=== Début des tests ===")
testPrerequisites()
testServerConnection()
testFileDownload()
testUnzip()
print("\n=== Fin des tests ===") 