# Application Flask pour gérer les fichiers sur Azure Blob Storage et les métadonnées en PostgreSQL
# CRUD : Créer, Lire, Lister, Supprimer des fichiers et métadonnées

import os
from flask import Flask, request, jsonify, send_file
from azure.storage.blob import BlobServiceClient
import psycopg2
import io

app = Flask(__name__)

# Configuration via variables d'environnement
STORAGE_ACCOUNT_NAME = os.environ.get("STORAGE_ACCOUNT_NAME")
STORAGE_ACCOUNT_KEY = os.environ.get("STORAGE_ACCOUNT_KEY")
CONTAINER_NAME = os.environ.get("CONTAINER_NAME")
DATABASE_URL = os.environ.get("DATABASE_URL")

# Connexion au Blob Storage
connexion_str = (
    f"DefaultEndpointsProtocol=https;"
    f"AccountName={STORAGE_ACCOUNT_NAME};"
    f"AccountKey={STORAGE_ACCOUNT_KEY};"
    f"EndpointSuffix=core.windows.net"
)
blob_service = BlobServiceClient.from_connection_string(connexion_str)
conteneur = blob_service.get_container_client(CONTAINER_NAME)


def get_db():
    return psycopg2.connect(DATABASE_URL)


def init_db():
    conn = get_db()
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS metadonnees (
            id SERIAL PRIMARY KEY,
            cle VARCHAR(255) UNIQUE NOT NULL,
            valeur TEXT NOT NULL
        )
    """)
    conn.commit()
    cur.close()
    conn.close()


init_db()


@app.route("/")
def accueil():
    return jsonify({
        "message": "API Flask - Gestion de fichiers et métadonnées",
        "routes": {
            "GET /fichiers": "Lister tous les fichiers",
            "POST /fichiers": "Envoyer un fichier (form-data, champ 'fichier')",
            "GET /fichiers/<nom>": "Télécharger un fichier",
            "DELETE /fichiers/<nom>": "Supprimer un fichier",
            "GET /db": "Lister toutes les métadonnées",
            "POST /db": "Créer une métadonnée (JSON: clé, valeur)",
            "PUT /db/<clé>": "Modifier une métadonnée",
            "DELETE /db/<clé>": "Supprimer une métadonnée",
        }
    })


@app.route("/fichiers", methods=["GET"])
def lister_fichiers():
    blobs = conteneur.list_blobs()
    fichiers = [
        {"nom": blob.name, "taille": blob.size, "derniere_modification": str(blob.last_modified)}
        for blob in blobs
    ]
    return jsonify({"fichiers": fichiers, "total": len(fichiers)})


@app.route("/fichiers", methods=["POST"])
def envoyer_fichier():
    if "fichier" not in request.files:
        return jsonify({"erreur": "Aucun fichier fourni. Utilisez le champ 'fichier'."}), 400
    fichier = request.files["fichier"]
    if fichier.filename == "":
        return jsonify({"erreur": "Nom de fichier vide"}), 400
    blob_client = conteneur.get_blob_client(fichier.filename)
    blob_client.upload_blob(fichier.read(), overwrite=True)
    return jsonify({"message": f"Fichier '{fichier.filename}' envoyé avec succès", "nom": fichier.filename}), 201


@app.route("/fichiers/<nom>", methods=["GET"])
def telecharger_fichier(nom):
    try:
        blob_client = conteneur.get_blob_client(nom)
        donnees = blob_client.download_blob().readall()
        return send_file(io.BytesIO(donnees), download_name=nom, as_attachment=True)
    except Exception:
        return jsonify({"erreur": f"Fichier '{nom}' introuvable"}), 404


@app.route("/fichiers/<nom>", methods=["DELETE"])
def supprimer_fichier(nom):
    try:
        blob_client = conteneur.get_blob_client(nom)
        blob_client.delete_blob()
        return jsonify({"message": f"Fichier '{nom}' supprimé avec succès"})
    except Exception:
        return jsonify({"erreur": f"Fichier '{nom}' introuvable"}), 404


@app.route("/db", methods=["GET"])
def lister_metadonnees():
    conn = get_db()
    cur = conn.cursor()
    cur.execute("SELECT id, cle, valeur FROM metadonnees ORDER BY id")
    rows = [{"id": r[0], "cle": r[1], "valeur": r[2]} for r in cur.fetchall()]
    cur.close()
    conn.close()
    return jsonify({"metadonnees": rows, "total": len(rows)})


@app.route("/db", methods=["POST"])
def creer_metadonnee():
    data = request.get_json()
    if not data or "cle" not in data or "valeur" not in data:
        return jsonify({"erreur": "JSON requis avec 'cle' et 'valeur'"}), 400
    conn = get_db()
    cur = conn.cursor()
    try:
        cur.execute("INSERT INTO metadonnees (cle, valeur) VALUES (%s, %s) RETURNING id", (data["cle"], data["valeur"]))
        new_id = cur.fetchone()[0]
        conn.commit()
    except psycopg2.errors.UniqueViolation:
        conn.rollback()
        cur.close()
        conn.close()
        return jsonify({"erreur": f"La clé '{data['cle']}' existe déjà"}), 409
    cur.close()
    conn.close()
    return jsonify({"message": "Métadonnée créée", "id": new_id, "cle": data["cle"], "valeur": data["valeur"]}), 201


@app.route("/db/<cle>", methods=["PUT"])
def modifier_metadonnee(cle):
    data = request.get_json()
    if not data or "valeur" not in data:
        return jsonify({"erreur": "JSON requis avec 'valeur'"}), 400
    conn = get_db()
    cur = conn.cursor()
    cur.execute("UPDATE metadonnees SET valeur = %s WHERE cle = %s", (data["valeur"], cle))
    if cur.rowcount == 0:
        cur.close()
        conn.close()
        return jsonify({"erreur": f"Clé '{cle}' introuvable"}), 404
    conn.commit()
    cur.close()
    conn.close()
    return jsonify({"message": f"Métadonnée '{cle}' modifiée", "cle": cle, "valeur": data["valeur"]})


@app.route("/db/<cle>", methods=["DELETE"])
def supprimer_metadonnee(cle):
    conn = get_db()
    cur = conn.cursor()
    cur.execute("DELETE FROM metadonnees WHERE cle = %s", (cle,))
    if cur.rowcount == 0:
        cur.close()
        conn.close()
        return jsonify({"erreur": f"Clé '{cle}' introuvable"}), 404
    conn.commit()
    cur.close()
    conn.close()
    return jsonify({"message": f"Métadonnée '{cle}' supprimée"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
