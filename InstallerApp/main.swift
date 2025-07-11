import Foundation
import AppKit

// Structures pour les informations des fichiers
struct FileInfo: Codable {
    let name: String
    let size: Int64
    let modified: TimeInterval
}

struct FileList: Codable {
    let files: [FileInfo]
}

// Fonctions utilitaires
func formatFileSize(_ size: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: size)
}

class InstallerApp: NSApplication {
    var statusWindow: NSWindow!
    var progressBar: NSProgressIndicator!
    var statusLabel: NSTextField!
    var fileInfoLabel: NSTextField!
    
    override func run() {
        setupUI()
        startInstallation()
        super.run()
    }
    
    func setupUI() {
        // Créer la fenêtre
        statusWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        statusWindow.center()
        statusWindow.title = "Installation en cours"
        
        // Créer la barre de progression
        progressBar = NSProgressIndicator(frame: NSRect(x: 20, y: 120, width: 360, height: 20))
        progressBar.style = .bar
        progressBar.minValue = 0
        progressBar.maxValue = 100
        progressBar.isIndeterminate = false
        statusWindow.contentView?.addSubview(progressBar)
        
        // Créer le label de statut
        statusLabel = NSTextField(frame: NSRect(x: 20, y: 80, width: 360, height: 20))
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = .clear
        statusLabel.stringValue = "Vérification des prérequis..."
        statusWindow.contentView?.addSubview(statusLabel)
        
        // Créer le label d'information sur le fichier
        fileInfoLabel = NSTextField(frame: NSRect(x: 20, y: 40, width: 360, height: 20))
        fileInfoLabel.isEditable = false
        fileInfoLabel.isBordered = false
        fileInfoLabel.backgroundColor = .clear
        fileInfoLabel.stringValue = ""
        statusWindow.contentView?.addSubview(fileInfoLabel)
        
        statusWindow.makeKeyAndOrderFront(nil)
    }
    
    func startInstallation() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.runInstallation()
        }
    }
    
    func updateStatus(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.stringValue = message
        }
    }
    
    func updateFileInfo(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.fileInfoLabel.stringValue = message
        }
    }
    
    func updateProgress(_ value: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.progressBar.doubleValue = value
        }
    }
    
    func runInstallation() {
        print("DEBUG: Démarrage de l'installation")
        let serverURL = "http://172.17.19.26:5001"
        let tempDir = "/var/tmp"
        let logFile = "/var/tmp/macos_installer_client.log"
        
        // Fonction de logging
        func log(_ level: String, _ message: String) {
            let logMessage = "[\(Date())] [\(level)] \(message)"
            print("DEBUG: \(logMessage)")
            try? logMessage.appendLineToURL(fileURL: URL(fileURLWithPath: logFile))
            updateStatus(message)
        }
        
        // Vérification des prérequis
        print("DEBUG: Vérification des prérequis")
        updateStatus("Vérification des prérequis...")
        updateProgress(0)
        
        // 1. Vérifier l'accès en écriture au dossier temporaire
        if !FileManager.default.isWritableFile(atPath: tempDir) {
            print("DEBUG: Erreur - Dossier non accessible en écriture: \(tempDir)")
            log("ERROR", "Le dossier \(tempDir) n'est pas accessible en écriture")
            NSApp.terminate(nil)
            return
        }
        updateProgress(10)
        
        // 2. Vérifier l'espace disque
        let requiredSpace = 20 * 1024 * 1024 // 20 GB en KB
        let availableSpace = getAvailableDiskSpace(path: tempDir)
        print("DEBUG: Espace disponible: \(availableSpace/1024/1024)GB, Requis: 20GB")
        
        if availableSpace < requiredSpace {
            print("DEBUG: Erreur - Espace insuffisant")
            log("ERROR", "Espace insuffisant: \(availableSpace/1024/1024)GB disponible, 20GB requis")
            NSApp.terminate(nil)
            return
        }
        updateProgress(20)
        
        // 3. Vérifier si unzip est installé
        print("DEBUG: Vérification de l'installation de unzip")
        if !isUnzipInstalled() {
            print("DEBUG: Erreur - unzip non installé")
            log("ERROR", "unzip n'est pas installé")
            NSApp.terminate(nil)
            return
        }
        updateProgress(30)
        
        // Créer le dossier temporaire si nécessaire
        print("DEBUG: Création du dossier temporaire: \(tempDir)")
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        
        // Télécharger la liste des fichiers
        print("DEBUG: Récupération de la liste des fichiers depuis: \(serverURL)")
        updateStatus("Récupération de la liste des fichiers...")
        updateProgress(40)
        
        do {
            let fileList = try getFileList(from: serverURL)
            print("DEBUG: Nombre de fichiers trouvés: \(fileList.files.count)")
            
            if fileList.files.isEmpty {
                print("DEBUG: Avertissement - Aucun fichier trouvé")
                log("WARNING", "Aucun fichier trouvé sur le serveur")
                NSApp.terminate(nil)
                return
            }
            
            // Calculer la taille totale à télécharger
            let totalSize = fileList.files.reduce(0) { $0 + $1.size }
            log("INFO", "Taille totale à télécharger: \(formatFileSize(totalSize))")
            
            // Télécharger chaque fichier
            for (index, file) in fileList.files.enumerated() {
                let progress = 40.0 + (Double(index) / Double(fileList.files.count) * 60.0)
                updateProgress(progress)
                
                let fileInfo = """
                    Fichier: \(file.name)
                    Taille: \(formatFileSize(file.size))
                    """
                updateFileInfo(fileInfo)
                updateStatus("Téléchargement de \(file.name)...")
                
                do {
                    try downloadFile(file.name, from: serverURL, to: tempDir)
                    
                    // Si c'est un fichier zip, le décompresser
                    if file.name.hasSuffix(".zip") {
                        updateStatus("Décompression de \(file.name)...")
                        try unzipFile("\(tempDir)/\(file.name)", in: tempDir)
                        
                        // Supprimer le fichier zip après décompression
                        try? FileManager.default.removeItem(atPath: "\(tempDir)/\(file.name)")
                        log("INFO", "Fichier zip supprimé: \(file.name)")
                    }
                } catch {
                    print("DEBUG: Erreur lors du traitement de \(file.name): \(error)")
                    log("ERROR", "Erreur lors du traitement de \(file.name): \(error.localizedDescription)")
                    NSApp.terminate(nil)
                    return
                }
            }
            
            updateProgress(100)
            print("DEBUG: Installation terminée avec succès")
            log("INFO", "Installation terminée avec succès")
            updateStatus("Installation terminée avec succès")
            updateFileInfo("")
            
            // Fermer l'application après 3 secondes
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                print("DEBUG: Fermeture de l'application")
                NSApp.terminate(nil)
            }
            
        } catch {
            print("DEBUG: Erreur lors de la récupération de la liste des fichiers: \(error)")
            log("ERROR", "Erreur lors de la récupération de la liste des fichiers: \(error.localizedDescription)")
            NSApp.terminate(nil)
            return
        }
    }
}

// Extensions utilitaires
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

// Fonctions utilitaires
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
    
    try process.run()
    process.waitUntilExit()
    
    if process.terminationStatus != 0 {
        throw NSError(domain: "UnzipError", code: Int(process.terminationStatus), userInfo: nil)
    }
}

// Point d'entrée de l'application
let app = InstallerApp.shared
app.run() 