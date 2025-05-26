on run
    -- Définir les chemins
    set scriptPath to "/var/tmp/installMacOsV6.sh"
    set logPath to "/var/tmp/install_launcher.log"
    set progressLogPath to "/var/tmp/install_progress.log"
    
    -- Créer le fichier de log
    try
        do shell script "echo '$(date): Démarrage du script de lancement' > " & logPath
    on error errMsg
        display dialog "Erreur lors de la création du fichier log: " & errMsg buttons {"OK"} default button "OK" with icon stop
        return
    end try
    
    -- Vérifier si le script existe
    try
        do shell script "test -f " & scriptPath
    on error
        do shell script "echo '$(date): ERREUR - Script non trouvé' >> " & logPath
        display dialog "Le script d'installation n'a pas été trouvé à l'emplacement: " & scriptPath buttons {"OK"} default button "OK" with icon stop
        return
    end try
    
    -- Rendre le script exécutable
    try
        do shell script "chmod +x " & scriptPath
    on error errMsg
        do shell script "echo '$(date): ERREUR - Impossible de rendre le script exécutable: " & errMsg & "' >> " & logPath
        display dialog "Erreur lors de la configuration des permissions: " & errMsg buttons {"OK"} default button "OK" with icon stop
        return
    end try
    
    -- Créer le script de surveillance directement dans un fichier
    try
        do shell script "cat > /var/tmp/monitor_progress.sh << 'EOF'
#!/bin/bash
while true; do
    if [ -f /var/tmp/macos_auto_install.log ]; then
        if grep -q \"Démarrage de l'installation\" /var/tmp/macos_auto_install.log; then
            echo \"10:Recherche de l'installateur...\" > /var/tmp/install_progress.log
        fi
        if grep -q \"Installateur trouvé\" /var/tmp/macos_auto_install.log; then
            echo \"30:Installateur trouvé, préparation de l'installation...\" > /var/tmp/install_progress.log
        fi
        if grep -q \"Démarrage de l'installation de macOS\" /var/tmp/macos_auto_install.log; then
            echo \"50:Installation en cours...\" > /var/tmp/install_progress.log
        fi
        if grep -q \"L'ordinateur redémarrera automatiquement\" /var/tmp/macos_auto_install.log; then
            echo \"90:Installation terminée, redémarrage imminent...\" > /var/tmp/install_progress.log
        fi
    fi
    sleep 2
done
EOF"
        do shell script "chmod +x /var/tmp/monitor_progress.sh"
        do shell script "nohup /var/tmp/monitor_progress.sh > /dev/null 2>&1 &"
    on error errMsg
        do shell script "echo '$(date): ERREUR - Impossible de configurer la surveillance: " & errMsg & "' >> " & logPath
        display dialog "Erreur lors de la configuration de la surveillance: " & errMsg buttons {"OK"} default button "OK" with icon stop
        return
    end try
    
    -- Lancer l'installation en arrière-plan
    try
        do shell script "nohup sudo " & scriptPath & " > /var/tmp/install_output.log 2>&1 &"
    on error errMsg
        do shell script "echo '$(date): ERREUR - Impossible de lancer l'installation: " & errMsg & "' >> " & logPath
        display dialog "Erreur lors du lancement de l'installation: " & errMsg buttons {"OK"} default button "OK" with icon stop
        return
    end try
    
    -- Afficher la fenêtre de progression
    set progress description to "Installation de macOS"
    set progress total steps to 100
    set progress completed steps to 0
    
    -- Boucle de mise à jour de la progression
    repeat while true
        try
            set progressInfo to do shell script "cat " & progressLogPath
            set progressValue to first word of progressInfo
            set progressDescription to text 3 thru -1 of progressInfo
            set progress completed steps to progressValue
            set progress description to progressDescription
            
            -- Vérifier si l'installation est terminée
            if progressValue is "90" then
                exit repeat
            end if
        on error errMsg
            -- En cas d'erreur de lecture, continuer après un court délai
            delay 1
        end try
        delay 1
    end repeat
    
    -- Nettoyage
    try
        do shell script "rm -f /var/tmp/monitor_progress.sh /var/tmp/install_progress.log"
    on error errMsg
        do shell script "echo '$(date): ERREUR - Impossible de nettoyer les fichiers temporaires: " & errMsg & "' >> " & logPath
    end try
    
    -- Message final
    display dialog "L'installation est terminée. L'ordinateur va redémarrer dans quelques instants." buttons {"OK"} default button "OK" with icon note
end run