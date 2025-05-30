#!/usr/bin/env python3
"""
Serveur SMTP de test pour capturer les emails d'AlertManager
Ce serveur écoute sur le port 587 et affiche les emails reçus
"""

import socket
import threading
import email
from datetime import datetime
import re

class TestSMTPServer:
    def __init__(self, host='localhost', port=587):
        self.host = host
        self.port = port
        self.socket = None
        self.running = False

    def start(self):
        print(f"Démarrage du serveur SMTP de test sur {self.host}:{self.port}")
        print("Ce serveur va capturer et afficher tous les emails envoyés par AlertManager")
        print("=" * 60)

        self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

        try:
            self.socket.bind((self.host, self.port))
            self.socket.listen(5)
            self.running = True

            print("✅ Serveur SMTP prêt à recevoir les emails d'AlertManager")
            print("📧 Les emails seront affichés ici et sauvegardés dans des fichiers")
            print()

            while self.running:
                try:
                    client_socket, address = self.socket.accept()
                    print(f"🔗 Nouvelle connexion de {address}")

                    # Traiter la connexion dans un thread séparé
                    thread = threading.Thread(target=self.handle_client, args=(client_socket, address))
                    thread.daemon = True
                    thread.start()

                except socket.error:
                    if self.running:
                        print("Erreur de socket")
                    break

        except Exception as e:
            print(f"❌ Erreur: {e}")
            print("Assurez-vous que le port 587 n'est pas déjà utilisé")
        finally:
            if self.socket:
                self.socket.close()

    def handle_client(self, client_socket, address):
        try:
            # Envoyer le message de bienvenue SMTP
            client_socket.send(b"220 localhost SMTP Test Server Ready\r\n")

            mail_from = ""
            rcpt_to = []
            data_mode = False
            email_data = ""

            while True:
                data = client_socket.recv(1024).decode('utf-8', errors='ignore')
                if not data:
                    break

                lines = data.strip().split('\r\n')

                for line in lines:
                    if not line:
                        continue

                    print(f"📨 Reçu: {line}")

                    if data_mode:
                        if line == ".":
                            # Fin des données
                            self.process_email(mail_from, rcpt_to, email_data, address)
                            client_socket.send(b"250 OK Message accepted\r\n")
                            data_mode = False
                            email_data = ""
                        else:
                            email_data += line + "\n"
                    else:
                        # Commandes SMTP
                        if line.upper().startswith("HELO") or line.upper().startswith("EHLO"):
                            client_socket.send(b"250 Hello\r\n")
                        elif line.upper().startswith("MAIL FROM:"):
                            mail_from = line[10:].strip().strip('<>')
                            client_socket.send(b"250 OK\r\n")
                        elif line.upper().startswith("RCPT TO:"):
                            rcpt_to.append(line[8:].strip().strip('<>'))
                            client_socket.send(b"250 OK\r\n")
                        elif line.upper() == "DATA":
                            client_socket.send(b"354 Start mail input; end with <CRLF>.<CRLF>\r\n")
                            data_mode = True
                        elif line.upper() == "QUIT":
                            client_socket.send(b"221 Bye\r\n")
                            break
                        else:
                            client_socket.send(b"250 OK\r\n")

        except Exception as e:
            print(f"Erreur lors du traitement du client {address}: {e}")
        finally:
            client_socket.close()
            print(f"🔌 Connexion fermée avec {address}")

    def process_email(self, mail_from, rcpt_to, email_data, peer):
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        print(f"\n🔔 NOUVEL EMAIL REÇU - {timestamp}")
        print("=" * 50)
        print(f"De: {mail_from}")
        print(f"Pour: {', '.join(rcpt_to)}")
        print(f"Peer: {peer}")
        print("-" * 30)

        try:
            # Parser l'email
            msg = email.message_from_string(email_data)

            # Afficher les headers principaux
            print(f"Sujet: {msg.get('Subject', 'Pas de sujet')}")
            print(f"Date: {msg.get('Date', 'Pas de date')}")
            print(f"Content-Type: {msg.get('Content-Type', 'text/plain')}")

            print("\n--- CONTENU DE L'EMAIL ---")

            # Afficher le contenu
            if msg.is_multipart():
                for part in msg.walk():
                    if part.get_content_type() == "text/plain":
                        content = part.get_payload(decode=True)
                        if content:
                            print(content.decode('utf-8', errors='ignore'))
                    elif part.get_content_type() == "text/html":
                        print("--- CONTENU HTML ---")
                        content = part.get_payload(decode=True)
                        if content:
                            print(content.decode('utf-8', errors='ignore'))
            else:
                payload = msg.get_payload()
                if isinstance(payload, bytes):
                    print(payload.decode('utf-8', errors='ignore'))
                else:
                    print(payload)

        except Exception as e:
            print(f"Erreur lors du parsing de l'email: {e}")
            print("--- DONNÉES BRUTES ---")
            print(email_data)

        print("=" * 50)
        print("Email traité avec succès ✅")

        # Sauvegarder l'email dans un fichier
        filename = f"email_{timestamp.replace(':', '-').replace(' ', '_')}.txt"
        try:
            with open(filename, 'w', encoding='utf-8') as f:
                f.write(f"Timestamp: {timestamp}\n")
                f.write(f"From: {mail_from}\n")
                f.write(f"To: {', '.join(rcpt_to)}\n")
                f.write(f"Peer: {peer}\n")
                f.write("-" * 30 + "\n")
                f.write(email_data)
            print(f"Email sauvegardé dans: {filename}")
        except Exception as e:
            print(f"Erreur lors de la sauvegarde: {e}")

    def stop(self):
        self.running = False
        if self.socket:
            self.socket.close()

if __name__ == "__main__":
    print("🚀 Serveur SMTP de test pour AlertManager")
    print("Appuyez sur Ctrl+C pour arrêter")
    print()

    server = TestSMTPServer()

    try:
        server.start()
    except KeyboardInterrupt:
        print("\n🛑 Arrêt du serveur SMTP")
        server.stop()
    except Exception as e:
        print(f"❌ Erreur: {e}")
        server.stop()
