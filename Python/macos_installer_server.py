#!/usr/bin/env python3
import os
import sys
import logging
import shutil
from flask import Flask, request, jsonify, send_file
import time
from pathlib import Path

# Configuration
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
FILES_FOLDER = os.path.join(BASE_DIR, 'files')  # Dossier contenant les fichiers à servir
LOG_FILE = os.path.join(BASE_DIR, 'macos_installer.log')
SERVER_PORT = 5001

# Configuration du logging
logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

app = Flask(__name__)

def log(level, message):
    """Fonction de logging améliorée"""
    timestamp = time.strftime('%Y-%m-%d %H:%M:%S')
    log_message = f"[{timestamp}] [{level}] {message}"
    print(log_message)  # Affiche aussi dans la console
    logging.log(getattr(logging, level), message)

def check_prerequisites():
    """Vérifie les prérequis"""
    try:
        # Vérifier que le dossier files existe
        if not os.path.exists(FILES_FOLDER):
            log("ERROR", f"Le dossier {FILES_FOLDER} n'existe pas")
            return False
            
        # Vérifier les permissions du dossier
        if not os.access(FILES_FOLDER, os.R_OK):
            log("ERROR", f"Le dossier {FILES_FOLDER} n'est pas accessible en lecture")
            return False
            
        return True
    except Exception as e:
        log("ERROR", f"Erreur lors de la vérification des prérequis: {str(e)}")
        return False

@app.route('/files', methods=['GET'])
def list_files():
    """Liste les fichiers disponibles"""
    try:
        files = []
        for file in os.listdir(FILES_FOLDER):
            file_path = os.path.join(FILES_FOLDER, file)
            if os.path.isfile(file_path):
                files.append({
                    'name': file,
                    'size': os.path.getsize(file_path),
                    'modified': os.path.getmtime(file_path)
                })
        return jsonify({'files': files}), 200
    except Exception as e:
        log("ERROR", f"Erreur lors de la liste des fichiers: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/files/<filename>', methods=['GET'])
def get_file(filename):
    """Sert un fichier spécifique"""
    try:
        file_path = os.path.join(FILES_FOLDER, filename)
        if not os.path.exists(file_path):
            log("ERROR", f"Fichier non trouvé: {filename}")
            return jsonify({'error': 'Fichier non trouvé'}), 404
            
        log("INFO", f"Envoi du fichier: {filename}")
        return send_file(file_path, as_attachment=True)
    except Exception as e:
        log("ERROR", f"Erreur lors de l'envoi du fichier: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/status', methods=['GET'])
def get_status():
    """Retourne le statut du serveur"""
    try:
        with open(LOG_FILE, 'r') as f:
            logs = f.readlines()[-50:]  # Dernières 50 lignes
        return jsonify({'status': 'running', 'logs': logs}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    try:
        # Vérifier les prérequis
        if not check_prerequisites():
            log("ERROR", "Les prérequis ne sont pas satisfaits")
            sys.exit(1)
        
        log("INFO", f"Démarrage du serveur sur le port {SERVER_PORT}")
        log("INFO", f"Dossier des fichiers: {FILES_FOLDER}")
        
        # Démarrer le serveur Flask
        app.run(host='0.0.0.0', port=SERVER_PORT)
    except Exception as e:
        log("ERROR", f"Erreur lors du démarrage du serveur: {str(e)}")
        sys.exit(1) 