"""
Módulo compartido de inicialización de Firebase para scripts Python.
Todos los scripts deben importar `db` desde aquí.

Uso:
    from firebase_init import db
"""

import firebase_admin
from firebase_admin import credentials, firestore
from pathlib import Path

SCRIPTS_DIR = Path(__file__).parent
SERVICE_ACCOUNT_PATH = SCRIPTS_DIR / "serviceAccountKey.json"

if not firebase_admin._apps:
    cred = credentials.Certificate(str(SERVICE_ACCOUNT_PATH))
    firebase_admin.initialize_app(cred)

db = firestore.client()
