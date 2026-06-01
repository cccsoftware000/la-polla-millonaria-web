#!/usr/bin/env python3
"""
Descarga logos de equipos usando API-Football (v3).
Busca por nombre de equipo y guarda el PNG en assets/logos/.

Uso:
  python download_logos.py "Germany"              Descarga un equipo
  python download_logos.py "France" "USA" "Spain" Descarga varios
  python download_logos.py --list "Colombia"       Solo lista sin descargar

Requiere: pip install requests
Usa la API key del .env del proyecto raiz.
"""

import os
import sys
import requests
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent.parent
ASSETS_DIR = REPO_DIR / "assets" / "logos"
ENV_FILE = REPO_DIR / ".env"

API_URL = "https://v3.football.api-sports.io/teams"


def get_api_key():
    """Leer API key del .env raiz"""
    if not ENV_FILE.exists():
        print(f"[ERROR] No se encuentra .env en {ENV_FILE}")
        sys.exit(1)

    for line in ENV_FILE.read_text(encoding="utf-8").strip().splitlines():
        if "=" in line and line.startswith("API_FOOTBALL_KEY"):
            return line.split("=", 1)[1].strip()
    print("[ERROR] API_FOOTBALL_KEY no encontrada en .env")
    sys.exit(1)


def search_team(name, api_key):
    """Buscar equipo por nombre en API-Football"""
    headers = {"x-apisports-key": api_key}
    params = {"search": name}

    try:
        r = requests.get(API_URL, headers=headers, params=params, timeout=10)
        r.raise_for_status()
        data = r.json()
    except Exception as e:
        print(f"  [!] Error HTTP: {e}")
        return None

    if data.get("errors"):
        print(f"  [!] API Error: {data['errors']}")
        return None

    results = data.get("response", [])

    # Preferir seleccion nacional sobre clubes
    for entry in results:
        team = entry["team"]
        if team["name"].lower() == name.lower() and team.get("national"):
            return team

    # Si no hay nacional exacta, devolver la primera coincidencia exacta
    for entry in results:
        team = entry["team"]
        if team["name"].lower() == name.lower():
            return team

    # Si no hay exacta, devolver la primera nacional
    for entry in results:
        team = entry["team"]
        if team.get("national"):
            return team

    # Devolver la primera
    if results:
        return results[0]["team"]

    return None


def download_logo(team, dry_run=False):
    """Descargar logo y guardarlo como PNG"""
    name = team["name"]
    logo_url = team.get("logo")
    if not logo_url:
        print(f"  [!] {name}: sin URL de logo")
        return False

    filename = name.lower().replace(" ", "_").replace("-", "_") + ".png"
    dest = ASSETS_DIR / filename

    if dry_run:
        print(f"  [DRY] {name} -> {dest.name} ({logo_url})")
        return True

    # Si ya existe, preguntar
    if dest.exists():
        confirm = input(f"  [!] {dest.name} ya existe. Sobrescribir? (s/n): ")
        if confirm.lower() != "s":
            print(f"  [SKIP] {name}")
            return True

    try:
        r = requests.get(logo_url, timeout=15)
        r.raise_for_status()
        dest.write_bytes(r.content)
        size = len(r.content)
        print(f"  [OK] {dest.name} ({size / 1024:.1f} KB)")
        return True
    except Exception as e:
        print(f"  [ERROR] {name}: {e}")
        return False


def main():
    dry_run = False
    args = [a for a in sys.argv[1:] if not a.startswith("--")]

    if "--list" in sys.argv or "--dry-run" in sys.argv:
        dry_run = True

    if not args:
        print("Uso: python download_logos.py [--list] Equipo1 Equipo2 ...")
        print("  --list  : solo listar sin descargar")
        print("  --dry-run: simular")
        print()
        print("Ejemplos:")
        print('  python download_logos.py "Germany" "France"')
        print('  python download_logos.py --list "USA" "Spain"')
        return

    api_key = get_api_key()
    ASSETS_DIR.mkdir(parents=True, exist_ok=True)

    for name in args:
        print(f"\n> Buscando: {name}...")
        team = search_team(name, api_key)

        if not team:
            print(f"  [ERROR] No se encontro equipo: {name}")
            continue

        api_name = team["name"]
        is_national = team.get("national", False)

        if api_name.lower() != name.lower():
            print(f"  [INFO] API devolvio: {api_name} (buscaste: {name})")

        if is_national:
            print(f"  [INFO] Seleccion nacional encontrada")

        download_logo(team, dry_run=dry_run)

    print("\nListo!")


if __name__ == "__main__":
    main()
