#!/usr/bin/env python3
"""
Descarga logos de equipos usando API-Football (v3).

Uso:
  python download_logos.py "Germany"              Descarga un equipo
  python download_logos.py "France" "USA" "Spain" Descarga varios
  python download_logos.py --all                   Descarga todos los equipos del Mundial 2026
  python download_logos.py --list "Colombia"       Solo lista sin descargar

Requiere: pip install requests
Usa la API key del .env del proyecto raiz.
"""

import os
import sys
import time
import requests
from pathlib import Path
from collections import OrderedDict

REPO_DIR = Path(__file__).resolve().parent.parent
ASSETS_DIR = REPO_DIR / "assets" / "logos"
ENV_FILE = REPO_DIR / ".env"

API_URL = "https://v3.football.api-sports.io/teams"

ALL_TEAMS = OrderedDict({
    "Grupo A": [
        ("M\u00e9xico", "Mexico", "mexico.png"),
        ("Sud\u00e1frica", "South Africa", "sudafrica.png"),
        ("Corea del Sur", "South Korea", "corea_sur.png"),
        ("Chequia", "Czech Republic", "chequia.png"),
    ],
    "Grupo B": [
        ("Canad\u00e1", "Canada", "canada.png"),
        ("Bosnia y Herzegovina", "Bosnia", "bosnia.png"),
        ("Catar", "Qatar", "catar.png"),
        ("Suiza", "Switzerland", "suiza.png"),
    ],
    "Grupo C": [
        ("Brasil", "Brazil", "brasil.png"),
        ("Marruecos", "Morocco", "marruecos.png"),
        ("Hait\u00ed", "Haiti", "haiti.png"),
        ("Escocia", "Scotland", "escocia.png"),
    ],
    "Grupo D": [
        ("Estados Unidos", "United States", "eeuu.png"),
        ("Paraguay", "Paraguay", "paraguay.png"),
        ("Australia", "Australia", "australia.png"),
        ("Turqu\u00eda", "Turkey", "turquia.png"),
    ],
    "Grupo E": [
        ("Alemania", "Germany", "alemania.png"),
        ("Curazao", "Curacao", "curazao.png"),
        ("Costa de Marfil", "Ivory Coast", "costa_marfil.png"),
        ("Ecuador", "Ecuador", "ecuador.png"),
    ],
    "Grupo F": [
        ("Pa\u00edses Bajos", "Netherlands", "paises_bajos.png"),
        ("Jap\u00f3n", "Japan", "japon.png"),
        ("Suecia", "Sweden", "suecia.png"),
        ("T\u00fanez", "Tunisia", "tunez.png"),
    ],
    "Grupo G": [
        ("B\u00e9lgica", "Belgium", "belgica.png"),
        ("Egipto", "Egypt", "egipto.png"),
        ("Ir\u00e1n", "Iran", "iran.png"),
        ("Nueva Zelanda", "New Zealand", "nueva_zelanda.png"),
    ],
    "Grupo H": [
        ("Espa\u00f1a", "Spain", "espana.png"),
        ("Cabo Verde", "Cape Verde", "cabo_verde.png"),
        ("Arabia Saudita", "Saudi Arabia", "arabia_saudita.png"),
        ("Uruguay", "Uruguay", "uruguay.png"),
    ],
    "Grupo I": [
        ("Francia", "France", "francia.png"),
        ("Senegal", "Senegal", "senegal.png"),
        ("Irak", "Iraq", "irak.png"),
        ("Noruega", "Norway", "noruega.png"),
    ],
    "Grupo J": [
        ("Argentina", "Argentina", "argentina.png"),
        ("Argelia", "Algeria", "argelia.png"),
        ("Austria", "Austria", "austria.png"),
        ("Jordania", "Jordan", "jordania.png"),
    ],
    "Grupo K": [
        ("Portugal", "Portugal", "portugal.png"),
        ("RD Congo", "DR Congo", "rd_congo.png"),
        ("Uzbekist\u00e1n", "Uzbekistan", "uzbekistan.png"),
        ("Colombia", "Colombia", "colombia.png"),
    ],
    "Grupo L": [
        ("Inglaterra", "England", "inglaterra.png"),
        ("Croacia", "Croatia", "croacia.png"),
        ("Ghana", "Ghana", "ghana.png"),
        ("Panam\u00e1", "Panama", "panama.png"),
    ],
})


def get_api_key():
    if not ENV_FILE.exists():
        print(f"[ERROR] No se encuentra .env en {ENV_FILE}")
        sys.exit(1)

    for line in ENV_FILE.read_text(encoding="utf-8").strip().splitlines():
        if "=" in line and line.startswith("API_FOOTBALL_KEY"):
            return line.split("=", 1)[1].strip()
    print("[ERROR] API_FOOTBALL_KEY no encontrada en .env")
    sys.exit(1)


def search_team(name, api_key):
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

    for entry in results:
        team = entry["team"]
        if team["name"].lower() == name.lower() and team.get("national"):
            return team

    for entry in results:
        team = entry["team"]
        if team["name"].lower() == name.lower():
            return team

    for entry in results:
        team = entry["team"]
        if team.get("national"):
            return team

    if results:
        return results[0]["team"]

    return None


def download_logo(team, filename=None, dry_run=False, overwrite="prompt"):
    name = team["name"]
    logo_url = team.get("logo")
    if not logo_url:
        print(f"  [!] {name}: sin URL de logo")
        return False

    if filename is None:
        filename = name.lower().replace(" ", "_").replace("-", "_") + ".png"

    if "/" in filename:
        filename = filename.rsplit("/", 1)[1]

    dest = ASSETS_DIR / filename

    if dry_run:
        print(f"  [DRY] {name} -> {dest.name} ({logo_url})")
        return True

    if dest.exists():
        if overwrite == "skip":
            print(f"  [SKIP] {filename} ya existe")
            return True
        elif overwrite == "replace":
            pass
        else:
            confirm = input(f"  [!] {filename} ya existe. Sobrescribir? (s/n): ")
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


def download_all(dry_run=False):
    api_key = get_api_key()
    ASSETS_DIR.mkdir(parents=True, exist_ok=True)

    total = sum(len(teams) for teams in ALL_TEAMS.values())
    ok = 0
    fail = 0
    delay = 2.0

    for group_name, teams in ALL_TEAMS.items():
        print(f"\n{'='*45}")
        print(f"  {group_name}")
        print(f"{'='*45}")
        for spanish_name, api_name, filename in teams:
            print(f"\n> {spanish_name} ...")
            if dry_run:
                print(f"  [DRY] {spanish_name} -> {filename} (API: {api_name})")
                ok += 1
                continue

            team = search_team(api_name, api_key)
            if not team:
                print(f"  [ERROR] No se encontr\u00f3: {spanish_name}")
                fail += 1
                time.sleep(delay)
                continue

            api_team_name = team["name"]
            if api_team_name.lower() != api_name.lower():
                print(f"  [INFO] API devolvi\u00f3: {api_team_name}")

            result = download_logo(team, filename=filename, overwrite="skip")
            if result:
                ok += 1
            else:
                fail += 1
            time.sleep(delay)

    print(f"\n{'='*45}")
    print(f"  Descarga completa: {ok} ok, {fail} fallos, {total} total")
    print(f"{'='*45}")


def main():
    dry_run = "--list" in sys.argv or "--dry-run" in sys.argv

    if "--all" in sys.argv:
        download_all(dry_run=dry_run)
        return

    args = [a for a in sys.argv[1:] if not a.startswith("--")]

    if not args:
        print("Uso: python download_logos.py [--list] [--all] Equipo1 Equipo2 ...")
        print("  --all     : descargar todos los equipos del Mundial 2026")
        print("  --list    : solo listar sin descargar")
        print("  --dry-run : simular")
        print()
        print("Ejemplos:")
        print('  python download_logos.py "Germany" "France"')
        print('  python download_logos.py --all')
        return

    api_key = get_api_key()
    ASSETS_DIR.mkdir(parents=True, exist_ok=True)

    for name in args:
        print(f"\n> Buscando: {name}...")
        team = search_team(name, api_key)

        if not team:
            print(f"  [ERROR] No se encontr\u00f3 equipo: {name}")
            continue

        api_name = team["name"]
        is_national = team.get("national", False)

        if api_name.lower() != name.lower():
            print(f"  [INFO] API devolvi\u00f3: {api_name} (buscaste: {name})")

        if is_national:
            print(f"  [INFO] Selecci\u00f3n nacional encontrada")

        download_logo(team, dry_run=dry_run)

    print("\nListo!")


if __name__ == "__main__":
    main()
