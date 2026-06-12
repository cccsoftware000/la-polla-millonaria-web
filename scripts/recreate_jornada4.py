#!/usr/bin/env python3
"""
Script para RECREAR la Jornada 4 con horas corregidas (hora Colombia)
Primero elimina la jornada 4 y sus partidos, luego los crea con las horas correctas
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import sys
import os

# Zona horaria Colombia (UTC-5)
def colombia_time(year, month, day, hour, minute=0):
    """Convertir hora Colombia a UTC para Firestore (sumamos 5 horas)"""
    # Si la hora + 5 supera 23, ajustar día
    new_hour = hour + 5
    new_day = day
    new_month = month
    new_year = year
    
    if new_hour >= 24:
        new_hour -= 24
        new_day += 1
    
    return datetime(new_year, new_month, new_day, new_hour, minute)

try:
    firebase_admin.initialize_app()
    print("✅ Usando credenciales por defecto")
except:
    SERVICE_ACCOUNT_PATH = "serviceAccountKey.json"
    if not os.path.exists(SERVICE_ACCOUNT_PATH):
        print("❌ No se encontró serviceAccountKey.json")
        sys.exit(1)
    cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
    firebase_admin.initialize_app(cred)

db = firestore.client()

JORNADA_4_ID = "jornada_4"
JORNADA_4_NAME = "Jornada 4 - Grupos K/L y Octavos - Junio 2026"

# ✅ PRIMER PARTIDO: 17 junio 12:00 PM Colombia = 17:00 UTC
FIRST_MATCH_DATE = colombia_time(2026, 6, 17, 12, 0)

POLLA_DATA = {
    "name": JORNADA_4_NAME,
    "status": "ACTIVE",
    "startDate": colombia_time(2026, 6, 17, 0, 0),
    "endDate": FIRST_MATCH_DATE,
    "prizeAmount": 100000,
    "winnerIds": [],
    "winnerCount": 0,
    "winnerPrize": 0,
    "createdAt": firestore.SERVER_TIMESTAMP,
    "closedAt": None,
    "closedReason": None,
}

# Partidos con horas CORREGIDAS (hora Colombia)
MATCHES_DATA = [
    # Miércoles 17/6 - Grupo K y L
    {
        "id": "match_j4_1",
        "local": "Portugal",
        "visitor": "RD Congo",
        "localLogo": "assets/logos/portugal.png",
        "visitorLogo": "assets/logos/rd_congo.png",
        "localEmoji": "🇵🇹",
        "visitorEmoji": "🇨🇩",
        "dateTime": colombia_time(2026, 6, 17, 12, 0),
        "tournament": "🌍 Copa del Mundo",
        "group": "Grupo K",
        "dateStr": "mié, 17 de jun",
        "time": "12:00",
    },
    {
        "id": "match_j4_2",
        "local": "Inglaterra",
        "visitor": "Croacia",
        "localLogo": "assets/logos/inglaterra.png",
        "visitorLogo": "assets/logos/croacia.png",
        "localEmoji": "🏴󠁧󠁢󠁥󠁮󠁧󠁿",
        "visitorEmoji": "🇭🇷",
        "dateTime": colombia_time(2026, 6, 17, 15, 0),
        "tournament": "🌍 Copa del Mundo",
        "group": "Grupo L",
        "dateStr": "mié, 17 de jun",
        "time": "15:00",
    },
    {
        "id": "match_j4_3",
        "local": "Ghana",
        "visitor": "Panamá",
        "localLogo": "assets/logos/ghana.png",
        "visitorLogo": "assets/logos/panama.png",
        "localEmoji": "🇬🇭",
        "visitorEmoji": "🇵🇦",
        "dateTime": colombia_time(2026, 6, 17, 18, 0),
        "tournament": "🌍 Copa del Mundo",
        "group": "Grupo L",
        "dateStr": "mié, 17 de jun",
        "time": "18:00",
    },
    {
        "id": "match_j4_4",
        "local": "Uzbekistán",
        "visitor": "Colombia",
        "localLogo": "assets/logos/uzbekistan.png",
        "visitorLogo": "assets/logos/colombia.png",
        "localEmoji": "🇺🇿",
        "visitorEmoji": "🇨🇴",
        "dateTime": colombia_time(2026, 6, 17, 21, 0),
        "tournament": "🌍 Copa del Mundo",
        "group": "Grupo K",
        "dateStr": "mié, 17 de jun",
        "time": "21:00",
    },
    # Jueves 18/6 - Grupo A y B
    {
        "id": "match_j4_5",
        "local": "Chequia",
        "visitor": "Sudáfrica",
        "localLogo": "assets/logos/chequia.png",
        "visitorLogo": "assets/logos/sudafrica.png",
        "localEmoji": "🇨🇿",
        "visitorEmoji": "🇿🇦",
        "dateTime": colombia_time(2026, 6, 18, 11, 0),
        "tournament": "🌍 Copa del Mundo",
        "group": "Grupo A",
        "dateStr": "jue, 18 de jun",
        "time": "11:00",
    },
    {
        "id": "match_j4_6",
        "local": "Suiza",
        "visitor": "Bosnia y Herzegovina",
        "localLogo": "assets/logos/suiza.png",
        "visitorLogo": "assets/logos/bosnia.png",
        "localEmoji": "🇨🇭",
        "visitorEmoji": "🇧🇦",
        "dateTime": colombia_time(2026, 6, 18, 14, 0),
        "tournament": "🌍 Copa del Mundo",
        "group": "Grupo B",
        "dateStr": "jue, 18 de jun",
        "time": "14:00",
    },
    {
        "id": "match_j4_7",
        "local": "Canadá",
        "visitor": "Catar",
        "localLogo": "assets/logos/canada.png",
        "visitorLogo": "assets/logos/catar.png",
        "localEmoji": "🇨🇦",
        "visitorEmoji": "🇶🇦",
        "dateTime": colombia_time(2026, 6, 18, 17, 0),
        "tournament": "🌍 Copa del Mundo",
        "group": "Grupo B",
        "dateStr": "jue, 18 de jun",
        "time": "17:00",
    },
    {
        "id": "match_j4_8",
        "local": "México",
        "visitor": "Corea del Sur",
        "localLogo": "assets/logos/mexico.png",
        "visitorLogo": "assets/logos/corea_sur.png",
        "localEmoji": "🇲🇽",
        "visitorEmoji": "🇰🇷",
        "dateTime": colombia_time(2026, 6, 18, 20, 0),
        "tournament": "🌍 Copa del Mundo",
        "group": "Grupo A",
        "dateStr": "jue, 18 de jun",
        "time": "20:00",
    },
]

def delete_jornada_and_matches():
    """Eliminar Jornada 4 y todos sus partidos"""
    print("\n🗑️ Eliminando Jornada 4 y sus partidos...")
    
    # Eliminar partidos
    matches = db.collection('matches').where('pollaId', '==', JORNADA_4_ID).get()
    deleted_matches = 0
    for match in matches:
        match.reference.delete()
        deleted_matches += 1
        print(f"  🗑️ Eliminado: matches/{match.id}")
    
    # Eliminar jornada
    polla_ref = db.collection('pollas').document(JORNADA_4_ID)
    if polla_ref.get().exists:
        polla_ref.delete()
        print(f"  🗑️ Eliminada: pollas/{JORNADA_4_ID}")
    
    print(f"✅ Eliminados {deleted_matches} partidos y la jornada")

def create_jornada():
    """Crear la nueva jornada"""
    print("\n📦 Creando Jornada 4...")
    
    doc_ref = db.collection('pollas').document(JORNADA_4_ID)
    doc_ref.set(POLLA_DATA)
    print(f"✅ Creada: pollas/{JORNADA_4_ID}")
    print(f"   Nombre: {JORNADA_4_NAME}")
    print(f"   endDate (UTC): {FIRST_MATCH_DATE}")

def create_matches():
    """Crear los partidos de la jornada"""
    print("\n📦 Creando partidos...")
    
    for match_data in MATCHES_DATA:
        match_id = match_data.pop("id")
        match = {
            "pollaId": JORNADA_4_ID,
            "status": "UPCOMING",
            **match_data,
        }
        
        doc_ref = db.collection('matches').document(match_id)
        doc_ref.set(match)
        print(f"  ✅ Creado: matches/{match_id}")
        print(f"     {match['local']} vs {match['visitor']} - {match['dateStr']} {match['time']}")

def show_verification():
    """Mostrar verificación de fechas"""
    print("\n📊 VERIFICACIÓN DE FECHAS EN FIRESTORE:")
    
    matches = db.collection('matches').where('pollaId', '==', JORNADA_4_ID).get()
    for match in matches:
        data = match.to_dict()
        dt = data.get('dateTime')
        print(f"   {data.get('local')} vs {data.get('visitor')}: {dt}")

if __name__ == "__main__":
    print("=" * 50)
    print("🔥 RECREANDO JORNADA 4 (FECHAS CORREGIDAS) 🔥")
    print("=" * 50)
    
    confirm = input("\n¿Eliminar Jornada 4 actual y recrearla con fechas corregidas? (s/n): ")
    if confirm.lower() != 's':
        print("❌ Operación cancelada")
        sys.exit(0)
    
    delete_jornada_and_matches()
    create_jornada()
    create_matches()
    show_verification()
    
    print("\n" + "=" * 50)
    print("✅ ¡Jornada 4 recreada correctamente!")
    print("=" * 50)
    print("\n📌 Las fechas ahora deberían verse correctas en la app")