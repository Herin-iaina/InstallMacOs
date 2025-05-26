-- Fonction de logging
on log(level, message, logFilePath)
    set timestamp to do shell script "date '+%Y-%m-%d %H:%M:%S'"
    set logMessage to "[" & timestamp & "] [" & level & "] " & message
    do shell script "echo " & quoted form of logMessage & " | tee -a " & quoted form of logFilePath
end log

on run
    set scriptDir to "/var/tmp"
    set clientScript to "macos_installer_client.sh"
    set logFile to "/var/tmp/downloader.log"
    
    try
        -- Vérifier si le client est déjà en cours d'exécution
        do shell script "pgrep -f " & quoted form of clientScript
        display dialog "Le téléchargement est déjà en cours" buttons {"OK"} default button "OK" with icon note
        return
    on error
        -- Lancer le client en arrière-plan avec nohup et redirection des logs
        do shell script "cd " & quoted form of scriptDir & " && nohup ./" & quoted form of clientScript & " > " & quoted form of logFile & " 2>&1 &"
        
        -- Vérifier que le processus a bien démarré
        delay 1
        try
            do shell script "pgrep -f " & quoted form of clientScript
            display notification "Le téléchargement a démarré en arrière-plan" with title "Téléchargement macOS"
        on error
            display dialog "Erreur lors du démarrage du téléchargement. Vérifiez le fichier de log: " & logFile buttons {"OK"} default button "OK" with icon stop
        end try
    end try
end run 