#!/usr/bin/env python3
"""
Script para poblar Firestore con datos iniciales de La Polla Millonaria
Fechas: Mayo 2026

Modos de ejecución:
  python populate_firestore.py          # Modo normal: borra y crea nuevos datos
  python populate_firestore.py --append # Modo append: solo agrega, no borra existentes
  python populate_firestore.py --dry-run # Simular ejecución sin cambios
Uso: python populate_firestore.py [--append] [--dry-run]
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import argparse
import sys

# ==================== CONFIGURACIÓN ====================

SERVICE_ACCOUNT_PATH = "serviceAccountKey.json"

# Inicializar Firebase
cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
firebase_admin.initialize_app(cred)
db = firestore.client()

# ==================== FECHAS (MAYO 2026) ====================

POLLA_NAME = "Jornada 1 - Mayo 2026"
POLLA_ID = "jornada_1"

# Fecha del primer partido (para calcular cierre de la polla)
FIRST_MATCH_DATE = datetime(2026, 5, 26, 17, 0, 0)  # 26 de mayo 17:00

# Datos de la polla
POLLA_DATA = {
    "id": POLLA_ID,
    "name": POLLA_NAME,
    "status": "ACTIVE",
    "startDate": datetime(2026, 5, 1, 0, 0, 0),
    "endDate": FIRST_MATCH_DATE,  # Cierra cuando empieza el primer partido
    "prizeAmount": 100000,
    "winnerIds": [],
    "winnerCount": 0,
    "winnerPrize": 0,
    "createdAt": firestore.SERVER_TIMESTAMP,
}

# Configuración global
SETTINGS = {
    "betPrice": 5000,
    "accumulatedPercentage": 60,
    "currentAccumulated": 100000,
    "lastAccumulatedIncrease": 0,
    "lastAccumulatedUpdate": firestore.SERVER_TIMESTAMP,
}

# Partidos
MATCHES_DATA = [
    # Copa Libertadores
    {
        "id": "match_1",
        "local": "Universitario de Deportes",
        "visitor": "Deportes Tolima",
        "localLogo": "assets/logos/universitario.png",
        "visitorLogo": "assets/logos/tolima.png",
        "dateTime": datetime(2026, 5, 26, 19, 30, 0),
        "tournament": "🌎 CONMEBOL Libertadores",
        "group": "Grupo B",
        "dateStr": "mar, 26 de may",
        "time": "19:30"
    },
    {
        "id": "match_2",
        "local": "Estudiantes de La Plata",
        "visitor": "Independiente Medellín",
        "localLogo": "assets/logos/estudiantes.png",
        "visitorLogo": "assets/logos/medellin.png",
        "dateTime": datetime(2026, 5, 26, 19, 30, 0),
        "tournament": "🌎 CONMEBOL Libertadores",
        "group": "Grupo A",
        "dateStr": "mar, 26 de may",
        "time": "19:30"
    },
    {
        "id": "match_3",
        "local": "Peñarol",
        "visitor": "Independiente Santa Fe",
        "localLogo": "assets/logos/penarol.png",
        "visitorLogo": "assets/logos/santafe.png",
        "dateTime": datetime(2026, 5, 27, 19, 30, 0),
        "tournament": "🌎 CONMEBOL Libertadores",
        "group": "Grupo C",
        "dateStr": "mié, 27 de may",
        "time": "19:30"
    },
    {
        "id": "match_4",
        "local": "Palmeiras",
        "visitor": "Junior FC",
        "localLogo": "assets/logos/palmeiras.png",
        "visitorLogo": "assets/logos/junior.png",
        "dateTime": datetime(2026, 5, 28, 17, 0, 0),
        "tournament": "🌎 CONMEBOL Libertadores",
        "group": "Grupo D",
        "dateStr": "jue, 28 de may",
        "time": "17:00"
    },
    # Copa Sudamericana
    {
        "id": "match_5",
        "local": "Millonarios FC",
        "visitor": "O'Higgins",
        "localLogo": "assets/logos/millonarios.png",
        "visitorLogo": "assets/logos/ohiggins.png",
        "dateTime": datetime(2026, 5, 26, 17, 0, 0),
        "tournament": "🏆 CONMEBOL Sudamericana",
        "group": "Grupo C",
        "dateStr": "mar, 26 de may",
        "time": "17:00"
    },
    {
        "id": "match_6",
        "local": "América de Cali",
        "visitor": "Macará",
        "localLogo": "assets/logos/america.png",
        "visitorLogo": "assets/logos/macara.png",
        "dateTime": datetime(2026, 5, 28, 19, 30, 0),
        "tournament": "🏆 CONMEBOL Sudamericana",
        "group": "Grupo B",
        "dateStr": "jue, 28 de may",
        "time": "19:30"
    },
    # Champions League Final
    {
        "id": "match_7",
        "local": "Paris Saint-Germain FC",
        "visitor": "Arsenal FC",
        "localLogo": "assets/logos/psg.png",
        "visitorLogo": "assets/logos/arsenal.png",
        "dateTime": datetime(2026, 5, 30, 11, 0, 0),
        "tournament": "🏆 UEFA Champions League",
        "group": "Final",
        "dateStr": "sáb, 30 de may",
        "time": "11:00"
    },
    # Amistoso Selección
    {
        "id": "match_8",
        "local": "Colombia",
        "visitor": "Costa Rica",
        "localLogo": "assets/logos/colombia.png",
        "visitorLogo": "assets/logos/costa_rica.png",
        "dateTime": datetime(2026, 6, 1, 18, 0, 0),
        "tournament": "🏅 Amistoso Internacional",
        "group": "Despedida",
        "dateStr": "lun, 1 de jun",
        "time": "18:00"
    }
]

# ==================== FUNCIONES ====================

def doc_exists(collection, doc_id):
    """Verificar si un documento existe"""
    doc = db.collection(collection).document(doc_id).get()
    return doc.exists

def create_or_skip(collection, doc_id, data, dry_run=False, append_mode=False):
    """Crear documento si no existe o si append_mode es False"""
    exists = doc_exists(collection, doc_id)

    if append_mode and exists:
        print(f"  ⏭️ Saltado: {collection}/{doc_id} (ya existe)")
        return False

    if dry_run:
        print(f"  🔍 [DRY RUN] Crearía: {collection}/{doc_id}")
        return True

    db.collection(collection).document(doc_id).set(data)
    print(f"  ✅ Creado: {collection}/{doc_id}")
    return True

def clear_collection(collection_name, dry_run=False):
    """Eliminar todos los documentos de una colección"""
    docs = db.collection(collection_name).stream()
    count = 0

    for doc in docs:
        if dry_run:
            print(f"  🔍 [DRY RUN] Eliminaría: {collection_name}/{doc.id}")
        else:
            db.collection(collection_name).document(doc.id).delete()
            print(f"  🗑️ Eliminado: {collection_name}/{doc.id}")
        count += 1

    if not dry_run:
        print(f"✅ Colección '{collection_name}' limpiada ({count} documentos)\n")
    else:
        print(f"🔍 [DRY RUN] Limpiaría colección '{collection_name}' ({count} documentos)\n")

    return count

def create_settings(dry_run=False, append_mode=False):
    """Crear configuración global"""
    print("📦 Creando configuración global...")
    create_or_skip("settings", "global", SETTINGS, dry_run, append_mode)
    print()

def create_polla(dry_run=False, append_mode=False):
    """Crear polla/jornada"""
    print("📦 Creando polla...")
    polla_id = POLLA_DATA.pop("id")

    create_or_skip("pollas", polla_id, POLLA_DATA, dry_run, append_mode)
    print(f"     Nombre: {POLLA_DATA['name']}")
    print(f"     Inicio: {POLLA_DATA['startDate'].strftime('%d/%m/%Y %H:%M')}")
    print(f"     Cierre: {POLLA_DATA['endDate'].strftime('%d/%m/%Y %H:%M')} (primer partido)")
    print()

def create_matches(dry_run=False, append_mode=False):
    """Crear partidos"""
    print("📦 Creando partidos...")

    for match_data in MATCHES_DATA:
        match_id = match_data.pop("id")
        match = {
            "pollaId": POLLA_ID,
            "local": match_data["local"],
            "visitor": match_data["visitor"],
            "localLogo": match_data["localLogo"],
            "visitorLogo": match_data["visitorLogo"],
            "dateTime": match_data["dateTime"],
            "status": "UPCOMING",
            "tournament": match_data["tournament"],
            "group": match_data["group"],
            "dateStr": match_data["dateStr"],
            "time": match_data["time"],
        }

        created = create_or_skip("matches", match_id, match, dry_run, append_mode)
        if created:
            print(f"     {match['local']} vs {match['visitor']} - {match['dateStr']} {match['time']}")
    print()

def show_summary():
    """Mostrar resumen de lo que se creará"""
    print("=" * 50)
    print("📊 RESUMEN DE DATOS A CREAR")
    print("=" * 50)
    print(f"🏆 Polla: 1 ({POLLA_NAME})")
    print(f"⚽ Partidos: {len(MATCHES_DATA)}")
    print(f"⚙️ Configuración global: 1")
    print("=" * 50)
    print("\n🎯 POLLA:")
    print(f"   Nombre: {POLLA_NAME}")
    print(f"   Estado: ACTIVE")
    print(f"   Premio: ${POLLA_DATA['prizeAmount']:,}")
    print(f"   Inicio: {POLLA_DATA['startDate'].strftime('%d/%m/%Y %H:%M')}")
    print(f"   Cierre: {POLLA_DATA['endDate'].strftime('%d/%m/%Y %H:%M')}")
    print("\n⚽ PRIMER PARTIDO:")
    print(f"   {MATCHES_DATA[0]['local']} vs {MATCHES_DATA[0]['visitor']}")
    print(f"   Fecha: {MATCHES_DATA[0]['dateTime'].strftime('%d/%m/%Y %H:%M')}")

def main():
    parser = argparse.ArgumentParser(description='Poblar Firestore con datos de La Polla Millonaria')
    parser.add_argument('--append', '-a', action='store_true',
                        help='Modo append: no borra datos existentes, solo agrega los que faltan')
    parser.add_argument('--dry-run', '-d', action='store_true',
                        help='Simular ejecución sin hacer cambios reales')
    parser.add_argument('--force', '-f', action='store_true',
                        help='Forzar limpieza incluso en modo append')

    args = parser.parse_args()

    print("=" * 50)
    print("🔥 LA POLLA MILLONARIA - FIRESTORE SETUP 🔥")
    print("=" * 50)
    print()

    if args.dry_run:
        print("🔍 MODO DRY RUN - Solo simulación, no se harán cambios 🔍")
        print()

    if args.append:
        print("📌 MODO APPEND - Solo se agregarán datos faltantes")
        print("   (No se borrarán documentos existentes)")
    else:
        print("⚠️ MODO NORMAL - Se borrarán y recrearán los datos")

    print()
    show_summary()
    print()

    # Confirmar acción
    if not args.dry_run:
        confirm = input("¿Continuar? (s/n): ")
        if confirm.lower() != 's':
            print("❌ Operación cancelada")
            return
        print()

    try:
        if not args.append or args.force:
            # Limpiar colecciones existentes (solo si no es append o si es force)
            print("🧹 Limpiando datos existentes...")
            if not args.append:
                clear_collection("pollas", args.dry_run)
                clear_collection("matches", args.dry_run)
            elif args.force:
                print("⚠️ Force mode: limpiando colecciones...")
                clear_collection("pollas", args.dry_run)
                clear_collection("matches", args.dry_run)
            else:
                print("⏭️ Saltando limpieza (modo append)\n")

        # Crear nuevos datos
        create_settings(args.dry_run, args.append)
        create_polla(args.dry_run, args.append)
        create_matches(args.dry_run, args.append)

        if args.dry_run:
            print("\n🔍 DRY RUN COMPLETADO - No se hicieron cambios reales 🔍")
        else:
            print("\n✅ ¡Firestore poblado exitosamente!")
            print(f"⏰ La polla estará ACTIVA hasta que empiece el primer partido")
            print("🚀 Ya puedes correr la app y hacer tus apuestas!")

    except Exception as e:
        print(f"\n❌ Error: {e}")
        print("\n📌 Asegúrate de:")
        print("   1. Tener el archivo serviceAccountKey.json en la carpeta scripts/")
        print("   2. Haber descargado las credenciales desde Firebase Console")
        print("   3. Tener instalado firebase-admin: pip install firebase-admin")

if __name__ == "__main__":
    main()