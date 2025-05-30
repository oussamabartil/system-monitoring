#!/usr/bin/env python3
"""
Test simple du serveur SMTP
"""

import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

def test_smtp_server():
    print("🧪 Test du serveur SMTP local...")
    
    try:
        # Créer un message de test
        msg = MIMEMultipart()
        msg['From'] = 'alertmanager@monitoring.local'
        msg['To'] = 'oussamabartil.04@gmail.com'
        msg['Subject'] = '[TEST] Alerte CPU Test'
        
        body = "Ceci est un test d'alerte CPU depuis AlertManager"
        msg.attach(MIMEText(body, 'plain'))
        
        # Se connecter au serveur SMTP local
        print("Connexion au serveur SMTP localhost:587...")
        server = smtplib.SMTP('localhost', 587)
        
        # Envoyer l'email
        print("Envoi de l'email de test...")
        text = msg.as_string()
        server.sendmail('alertmanager@monitoring.local', 'oussamabartil.04@gmail.com', text)
        server.quit()
        
        print("✅ Email de test envoyé avec succès!")
        
    except Exception as e:
        print(f"❌ Erreur lors du test SMTP: {e}")

if __name__ == "__main__":
    test_smtp_server()
