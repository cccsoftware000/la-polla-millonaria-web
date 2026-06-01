#!/usr/bin/env python3
"""
Script unificado para crear jornadas en Firestore.
Siempre crea 8 partidos por jornada.

Uso:
  python create_jornada.py -j 2                  # Crea Jornada 2
  python create_jornada.py -j 2 --append         # Solo agrega lo que falta
  python create_jornada.py -j 3 --dry-run        # Simula sin escribir
  python create_jornada.py --list                # Lista jornadas disponibles
"""

from firebase_admin import firestore
from datetime import datetime
import argparse
import sys
from copy import deepcopy

from firebase_init import db

# =====================================================================
# PRESETS DE JORNADAS
# =====================================================================
# Para agregar una nueva jornada, añade una entrada a JORNADAS.
# Cada jornada debe tener EXACTAMENTE 8 partidos en "matches".
# El "id_prefix" se usa para generar IDs como: match_j2_1, match_j2_2, etc.
#
# Formato de cada match:
#   "local", "visitor"            → nombres de equipos
#   "localLogo", "visitorLogo"    → ruta del logo en assets/logos/
#   "localEmoji", "visitorEmoji"  → emoji para la UI
#   "dateTime"                    → datetime(año, mes, día, hora, min)
#   "tournament"                  → nombre del torneo
#   "group"                       → grupo/fecha
#   "dateStr"                     → texto corto de fecha (ej: "mar, 2 de jun")
#   "time"                        → hora texto (ej: "19:30")
# =====================================================================

JORNADAS = {
    "jornada_1": {
        "name": "Jornada 1 - Mayo 2026",
        "id_prefix": "match",
        "start_date": datetime(2026, 5, 1, 0, 0, 0),
        "first_match_date": datetime(2026, 5, 26, 17, 0, 0),
        "prize_amount": 100000,
        "matches": [
            {
                "local": "Universitario de Deportes",
                "visitor": "Deportes Tolima",
                "localLogo": "assets/logos/universitario.png",
                "visitorLogo": "assets/logos/tolima.png",
                "localEmoji": "⚽",
                "visitorEmoji": "⚽",
                "dateTime": datetime(2026, 5, 26, 19, 30, 0),
                "tournament": "🌎 CONMEBOL Libertadores",
                "group": "Grupo B",
                "dateStr": "mar, 26 de may",
                "time": "19:30",
            },
            {
                "local": "Estudiantes de La Plata",
                "visitor": "Independiente Medellín",
                "localLogo": "assets/logos/estudiantes.png",
                "visitorLogo": "assets/logos/medellin.png",
                "localEmoji": "⚽",
                "visitorEmoji": "🔴",
                "dateTime": datetime(2026, 5, 26, 19, 30, 0),
                "tournament": "🌎 CONMEBOL Libertadores",
                "group": "Grupo A",
                "dateStr": "mar, 26 de may",
                "time": "19:30",
            },
            {
                "local": "Peñarol",
                "visitor": "Independiente Santa Fe",
                "localLogo": "assets/logos/penarol.png",
                "visitorLogo": "assets/logos/santafe.png",
                "localEmoji": "⚽",
                "visitorEmoji": "⚽",
                "dateTime": datetime(2026, 5, 27, 19, 30, 0),
                "tournament": "🌎 CONMEBOL Libertadores",
                "group": "Grupo C",
                "dateStr": "mié, 27 de may",
                "time": "19:30",
            },
            {
                "local": "Palmeiras",
                "visitor": "Junior FC",
                "localLogo": "assets/logos/palmeiras.png",
                "visitorLogo": "assets/logos/junior.png",
                "localEmoji": "⚽",
                "visitorEmoji": "🦈",
                "dateTime": datetime(2026, 5, 28, 17, 0, 0),
                "tournament": "🌎 CONMEBOL Libertadores",
                "group": "Grupo D",
                "dateStr": "jue, 28 de may",
                "time": "17:00",
            },
            {
                "local": "Millonarios FC",
                "visitor": "O'Higgins",
                "localLogo": "assets/logos/millonarios.png",
                "visitorLogo": "assets/logos/ohiggins.png",
                "localEmoji": "⚽",
                "visitorEmoji": "⚽",
                "dateTime": datetime(2026, 5, 26, 17, 0, 0),
                "tournament": "🏆 CONMEBOL Sudamericana",
                "group": "Grupo C",
                "dateStr": "mar, 26 de may",
                "time": "17:00",
            },
            {
                "local": "América de Cali",
                "visitor": "Macará",
                "localLogo": "assets/logos/america.png",
                "visitorLogo": "assets/logos/macara.png",
                "localEmoji": "⚽",
                "visitorEmoji": "⚽",
                "dateTime": datetime(2026, 5, 28, 19, 30, 0),
                "tournament": "🏆 CONMEBOL Sudamericana",
                "group": "Grupo B",
                "dateStr": "jue, 28 de may",
                "time": "19:30",
            },
            {
                "local": "Paris Saint-Germain FC",
                "visitor": "Arsenal FC",
                "localLogo": "assets/logos/psg.png",
                "visitorLogo": "assets/logos/arsenal.png",
                "localEmoji": "⚽",
                "visitorEmoji": "⚽",
                "dateTime": datetime(2026, 5, 30, 11, 0, 0),
                "tournament": "🏆 UEFA Champions League",
                "group": "Final",
                "dateStr": "sáb, 30 de may",
                "time": "11:00",
            },
            {
                "local": "Colombia",
                "visitor": "Costa Rica",
                "localLogo": "assets/logos/colombia.png",
                "visitorLogo": "assets/logos/costa_rica.png",
                "localEmoji": "⚽",
                "visitorEmoji": "⚽",
                "dateTime": datetime(2026, 6, 1, 18, 0, 0),
                "tournament": "🏅 Amistoso Internacional",
                "group": "Despedida",
                "dateStr": "lun, 1 de jun",
                "time": "18:00",
            },
        ],
    },
    "jornada_2": {
        "name": "Jornada 2 - Junio 2026",
        "id_prefix": "match_j2",
        "start_date": datetime(2026, 6, 2, 0, 0, 0),
        "first_match_date": datetime(2026, 6, 2, 18, 0, 0),
        "prize_amount": 100000,
        "matches": [
            {
                "local": "Junior FC",
                "visitor": "Atlético Nacional",
                "localLogo": "assets/logos/junior.png",
                "visitorLogo": "assets/logos/nacional.png",
                "localEmoji": "⚽",
                "visitorEmoji": "⚽",
                "dateTime": datetime(2026, 6, 2, 19, 30, 0),
                "tournament": "Liga BetPlay",
                "group": "Fecha 1",
                "dateStr": "mar, 2 de jun",
                "time": "19:30",
            },
            {
                "local": "Independiente Medellín",
                "visitor": "Cúcuta Deportivo",
                "localLogo": "assets/logos/medellin.png",
                "visitorLogo": "assets/logos/cucuta.png",
                "localEmoji": "⚽",
                "visitorEmoji": "⚽",
                "dateTime": datetime(2026, 6, 2, 18, 0, 0),
                "tournament": "Copa BetPlay",
                "group": "Octavos",
                "dateStr": "mar, 2 de jun",
                "time": "18:00",
            },
            {
                "local": "Croacia",
                "visitor": "Bélgica",
                "localLogo": "assets/logos/croacia.png",
                "visitorLogo": "assets/logos/belgica.png",
                "localEmoji": "⚽",
                "visitorEmoji": "⚽",
                "dateTime": datetime(2026, 6, 2, 11, 0, 0),
                "tournament": "Amistoso Internacional",
                "group": "Fecha FIFA",
                "dateStr": "mar, 2 de jun",
                "time": "11:00",
            },
            {
                "local": "Suecia",
                "visitor": "Grecia",
                "localLogo": "assets/logos/suecia.png",
                "visitorLogo": "assets/logos/grecia.png",
                "localEmoji": "⚽",
                "visitorEmoji": "⚽",
                "dateTime": datetime(2026, 6, 4, 12, 0, 0),
                "tournament": "Amistoso Internacional",
                "group": "Fecha FIFA",
                "dateStr": "jue, 4 de jun",
                "time": "12:00",
            },
            {
                "local": "Atlético Nacional",
                "visitor": "Junior FC",
                "localLogo": "assets/logos/nacional.png",
                "visitorLogo": "assets/logos/junior.png",
                "localEmoji": "⚽",
                "visitorEmoji": "⚽",
                "dateTime": datetime(2026, 6, 8, 20, 0, 0),
                "tournament": "Liga BetPlay",
                "group": "Fecha 2",
                "dateStr": "lun, 8 de jun",
                "time": "20:00",
            },
            # =========================================================
            # PARTIDO 6 - Paises Bajos vs Argelia
            # =========================================================
            {
                "local": "Países Bajos",
                "visitor": "Argelia",
                "localLogo": "assets/logos/netherlands.png",
                "visitorLogo": "assets/logos/algeria.png",
                "localEmoji": "⚽",
                "visitorEmoji": "⚽",
                "dateTime": datetime(2026, 6, 3, 13, 0, 0),
                "tournament": "Amistoso Internacional",
                "group": "Pre-Mundial 2026",
                "dateStr": "mie, 3 de jun",
                "time": "13:00",
            },
            # =========================================================
            # PARTIDO 7 - Francia vs Costa de Marfil
            # =========================================================
            {
                "local": "Francia",
                "visitor": "Costa de Marfil",
                "localLogo": "assets/logos/france.png",
                "visitorLogo": "assets/logos/ivory_coast.png",
                "localEmoji": "⚽",
                "visitorEmoji": "⚽",
                "dateTime": datetime(2026, 6, 4, 15, 0, 0),
                "tournament": "Amistoso Internacional",
                "group": "Pre-Mundial 2026",
                "dateStr": "jue, 4 de jun",
                "time": "15:00",
            },
            # =========================================================
            # PARTIDO 8 - Estados Unidos vs Alemania
            # =========================================================
            {
                "local": "Estados Unidos",
                "visitor": "Alemania",
                "localLogo": "assets/logos/usa.png",
                "visitorLogo": "assets/logos/germany.png",
                "localEmoji": "⚽",
                "visitorEmoji": "⚽",
                "dateTime": datetime(2026, 6, 6, 18, 30, 0),
                "tournament": "Amistoso Internacional",
                "group": "Pre-Mundial 2026",
                "dateStr": "sab, 6 de jun",
                "time": "18:30",
            },
        ],
    },
    # =====================================================================
    # Para agregar Jornada 3, copia este bloque y completa los datos:
    # =====================================================================
    # "jornada_3": {
    #     "name": "Jornada 3 - Julio 2026",
    #     "id_prefix": "match_j3",
    #     "start_date": datetime(2026, 7, 1, 0, 0, 0),
    #     "first_match_date": datetime(2026, 7, 5, 18, 0, 0),
    #     "prize_amount": 100000,
    #     "matches": [
    #         ... 8 partidos exactamente ...
    #     ],
    # },
}


def show_available_jornadas():
    """Mostrar jornadas disponibles"""
    print("=" * 50)
    print("[i] JORNADAS DISPONIBLES")
    print("=" * 50)
    for j_id, j_data in JORNADAS.items():
        match_count = len(j_data["matches"])
        tbd = sum(1 for m in j_data["matches"] if m["local"].startswith("TBD"))
        estado = f"[!] {tbd} TBD" if tbd else "[OK] Completa"
        print(f"  {j_id}: {j_data['name']} ({match_count} partidos) {estado}")
    print()


def create_polla(jornada_id, jornada_data, dry_run=False, append_mode=False):
    """Crear la polla/jornada en Firestore"""
    polla_doc = {
        "name": jornada_data["name"],
        "status": "ACTIVE",
        "startDate": jornada_data["start_date"],
        "endDate": jornada_data["first_match_date"],
        "prizeAmount": jornada_data["prize_amount"],
        "winnerIds": [],
        "winnerCount": 0,
        "winnerPrize": 0,
        "createdAt": firestore.SERVER_TIMESTAMP,
        "closedAt": None,
        "closedReason": None,
    }

    if dry_run:
        print(f"  [DRY] Crearia: pollas/{jornada_id}")
        return True

    doc_ref = db.collection("pollas").document(jornada_id)

    if not append_mode:
        if doc_ref.get().exists:
            confirm = input(f"[!] {jornada_id} ya existe. Sobrescribir? (s/n): ")
            if confirm.lower() != "s":
                print("[x] Operacion cancelada")
                return False

    doc_ref.set(polla_doc)
    print(f"  [OK] Creada: pollas/{jornada_id} - {jornada_data['name']}")
    return True


def create_matches(jornada_id, jornada_data, dry_run=False, append_mode=False):
    """Crear los 8 partidos de la jornada"""
    prefix = jornada_data["id_prefix"]
    created = 0

    print(f"\n  [+] Creando {len(jornada_data['matches'])} partidos...")

    for i, match_data in enumerate(jornada_data["matches"], 1):
        match_id = f"{prefix}_{i}"

        if not dry_run:
            doc_ref = db.collection("matches").document(match_id)

            if append_mode and doc_ref.get().exists:
                print(f"  [SKIP] matches/{match_id} (ya existe)")
                continue

        match = {
            "pollaId": jornada_id,
            "status": "UPCOMING",
            "local": match_data["local"],
            "visitor": match_data["visitor"],
            "localLogo": match_data["localLogo"],
            "visitorLogo": match_data["visitorLogo"],
            "localEmoji": match_data.get("localEmoji", "⚽"),
            "visitorEmoji": match_data.get("visitorEmoji", "⚽"),
            "dateTime": match_data["dateTime"],
            "tournament": match_data["tournament"],
            "group": match_data.get("group", ""),
            "dateStr": match_data["dateStr"],
            "time": match_data["time"],
        }

        if dry_run:
            print(f"  [DRY] Crearia: matches/{match_id}")
        else:
            doc_ref.set(match)
            print(f"  [OK] Creado: matches/{match_id} - {match['local']} vs {match['visitor']}")
        created += 1

    print(f"\n  [i] {created} partidos creados ({len(jornada_data['matches']) - created} ya existian)")
    return True


def show_summary(jornada_id, jornada_data):
    """Mostrar resumen de lo que se creará"""
    tbd = sum(1 for m in jornada_data["matches"] if m["local"].startswith("TBD"))

    print("=" * 50)
    print(f"[+] CREAR JORNADA: {jornada_id}")
    print("=" * 50)
    print(f"  Nombre:    {jornada_data['name']}")
    print(f"  Partidos:  {len(jornada_data['matches'])}")
    if tbd:
        print(f"  [!] {tbd} partidos tienen datos TBD (rellenalos antes de ejecutar)")
    print()
    for i, m in enumerate(jornada_data["matches"], 1):
        tbd_mark = " [!] TBD" if m["local"].startswith("TBD") else ""
        print(f"  {i}. {m['local']} vs {m['visitor']}{tbd_mark}")
        print(f"     {m['dateStr']} {m['time']} - {m['tournament']}")
    print("=" * 50)


def main():
    parser = argparse.ArgumentParser(description="Crear jornadas en Firestore")
    parser.add_argument("-j", "--jornada", type=str, help="ID de la jornada (ej: jornada_2, jornada_3)")
    parser.add_argument("-a", "--append", action="store_true", help="Solo agregar partidos faltantes")
    parser.add_argument("-d", "--dry-run", action="store_true", help="Simular sin escribir")
    parser.add_argument("-y", "--yes", action="store_true", help="Auto-aceptar confirmacion")
    parser.add_argument("-l", "--list", action="store_true", help="Listar jornadas disponibles")

    args = parser.parse_args()

    if args.list:
        show_available_jornadas()
        return

    jornada_id = args.jornada
    if not jornada_id:
        print("[ERROR] Debes especificar una jornada con -j")
        print("   Usa --list para ver las disponibles")
        return

    jornada_data = JORNADAS.get(jornada_id)
    if not jornada_data:
        print(f"[ERROR] Jornada '{jornada_id}' no encontrada")
        print(f"   Disponibles: {', '.join(JORNADAS.keys())}")
        return

    tbd = sum(1 for m in jornada_data["matches"] if m["local"].startswith("TBD"))
    if tbd:
        print(f"[!] {jornada_id} tiene {tbd} partidos sin configurar (TBD)")
        print("   Edita 'create_jornada.py' y completa los datos antes de ejecutar.\n")

    show_summary(jornada_id, jornada_data)
    print()

    if args.dry_run:
        print("[i] MODO DRY RUN - Solo simulacion\n")

    if not args.dry_run and tbd > 0:
        if args.yes:
            print(f"  [!] Continuando con {tbd} TBD (--yes)")
        else:
            confirm = input(f"Crear de todas formas con {tbd} TBD? (s/n): ")
            if confirm.lower() != "s":
                print("[x] Cancelado")
                return

    if not args.dry_run:
        if args.yes:
            print("  [!) Modo --yes, creando directamente...")
        else:
            confirm = input("Continuar? (s/n): ")
            if confirm.lower() != "s":
                print("[x] Cancelado")
                return

    try:
        create_polla(jornada_id, jornada_data, args.dry_run, args.append)
        create_matches(jornada_id, jornada_data, args.dry_run, args.append)

        if not args.dry_run:
            print(f"\n[OK] {jornada_data['name']} creada exitosamente!")
            if tbd == 0:
                print("   Los usuarios ya pueden hacer sus apuestas.")
            else:
                print("   [!] Recuerda completar los partidos TBD antes de abrir la jornada.")

    except Exception as e:
        print(f"\n[ERROR] {e}")


if __name__ == "__main__":
    main()
