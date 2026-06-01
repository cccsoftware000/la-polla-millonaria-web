#!/usr/bin/env python3
"""
Descarga batch de logos respetando rate limits de API-Football (10 req/min).

Uso:
  python batch_download_logos.py          # Descarga todo
  python batch_download_logos.py --list   # Solo listar sin descargar
  python batch_download_logos.py --resume # Reanudar descarga previa

Categorias:
  - colombianos: equipos de la Liga BetPlay
  - conmebol: equipos Sudamericanos (Libertadores/Sudamericana)
  - mundial: selecciones nacionales para el Mundial 2026
"""

import json
import os
import sys
import time
import requests
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent.parent
ASSETS_DIR = REPO_DIR / "assets" / "logos"
ENV_FILE = REPO_DIR / ".env"
CACHE_FILE = REPO_DIR / "assets" / "logos" / ".api_cache.json"

API_URL = "https://v3.football.api-sports.io/teams"
REQUESTS_PER_MINUTE = 10
DELAY = 62.0 / REQUESTS_PER_MINUTE  # ~6.2s entre requests


CATEGORIES = {
    "colombianos": [
        "America de Cali", "Atletico Bucaramanga", "Atletico Nacional",
        "Boyaca Chico", "Deportes Tolima", "Deportivo Cali",
        "Deportivo Pasto", "Deportivo Pereira", "Envigado",
        "Fortaleza CEIF", "Independiente Medellin", "Jaguares de Cordoba",
        "Junior FC", "La Equidad", "Llaneros", "Millonarios",
        "Once Caldas", "Patriotas Boyaca", "Real Cartagena",
        "Santa Fe", "Tigres FC", "Union Magdalena",
    ],
    "conmebol": [
        "Boca Juniors", "River Plate", "Racing Club", "Independiente",
        "San Lorenzo", "Flamengo", "Corinthians", "Sao Paulo",
        "Santos", "Gremio", "Internacional", "Cruzeiro",
        "Olimpia", "Cerro Porteno", "Nacional", "Penarol",
        "Barcelona SC", "LDU Quito", "Independiente del Valle",
        "Colo Colo", "Universidad de Chile", "U Catolica",
        "Universitario", "Sporting Cristal", "Alianza Lima",
        "The Strongest", "Bolivar", "Always Ready",
        "Defensa y Justicia", "Velez Sarsfield",
        "Palestino", "Coquimbo Unido",
        "Aucas", "Delfin", "Macara", "Emelec",
    ],
    "mundial_2026": [
        "Argentina", "Brazil", "England", "Spain", "Portugal",
        "Italy", "Mexico", "Japan", "South Korea", "Uruguay",
        "Chile", "Ecuador", "Peru", "Paraguay", "Venezuela",
        "Switzerland", "Denmark", "Austria", "Poland", "Ukraine",
        "Senegal", "Nigeria", "Cameroon", "Ghana", "Morocco",
        "Egypt", "Tunisia", "South Africa", "Mali",
        "Australia", "Saudi Arabia", "Iran", "Qatar",
        "Canada", "Jamaica", "Honduras", "Panama",
    ],
}


def get_api_key():
    if not ENV_FILE.exists():
        print(f"[ERROR] No se encuentra .env en {ENV_FILE}")
        sys.exit(1)
    for line in ENV_FILE.read_text(encoding="utf-8").strip().splitlines():
        if "=" in line and line.startswith("API_FOOTBALL_KEY"):
            return line.split("=", 1)[1].strip()
    print("[ERROR] API_FOOTBALL_KEY no encontrada")
    sys.exit(1)


def load_cache():
    if CACHE_FILE.exists():
        return json.loads(CACHE_FILE.read_text(encoding="utf-8"))
    return {}


def save_cache(cache):
    CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
    CACHE_FILE.write_text(json.dumps(cache, indent=2), encoding="utf-8")


def search_team(name, api_key, cache):
    if name in cache:
        return cache[name]

    headers = {"x-apisports-key": api_key}
    params = {"search": name}

    for attempt in range(3):
        try:
            r = requests.get(API_URL, headers=headers, params=params, timeout=10)
            if r.status_code == 429:
                remaining = int(r.headers.get("X-RateLimit-Remaining", 0))
                print(f"  [!] Rate limit ({remaining} remaining). Esperando 65s...")
                time.sleep(65)
                continue
            r.raise_for_status()
            data = r.json()
            break
        except Exception as e:
            print(f"  [!] Error en intento {attempt+1}: {e}")
            time.sleep(10)
            continue
    else:
        print(f"  [ERROR] No se pudo consultar: {name}")
        cache[name] = None
        return None

    results = data.get("response", [])

    # Preferir seleccion nacional sobre clubes
    for entry in results:
        team = entry["team"]
        if team["name"].lower() == name.lower() and team.get("national"):
            cache[name] = team
            return team

    # Coincidencia exacta
    for entry in results:
        team = entry["team"]
        if team["name"].lower() == name.lower():
            cache[name] = team
            return team

    # Primera seleccion nacional
    for entry in results:
        team = entry["team"]
        if team.get("national"):
            cache[name] = team
            return team

    # Primera coincidencia
    if results:
        t = results[0]["team"]
        api_name = t["name"]
        if api_name.lower() != name.lower():
            print(f"  [!] No exacto: '{name}' -> '{api_name}'")
        cache[name] = t
        return t

    cache[name] = None
    return None


def download_logo(team, name, dry_run=False):
    logo_url = team.get("logo")
    if not logo_url:
        print(f"  [!] {name}: sin URL de logo")
        return False

    fname = name.lower().replace(" ", "_").replace("-", "_").replace(".", "") + ".png"
    dest = ASSETS_DIR / fname

    if dry_run:
        print(f"  [DRY] {name} -> {fname}")
        return True

    if dest.exists():
        print(f"  [OK] {fname} ya existe ({dest.stat().st_size // 1024} KB)")
        return True

    try:
        r = requests.get(logo_url, timeout=15)
        r.raise_for_status()
        dest.write_bytes(r.content)
        print(f"  [OK] {fname} ({len(r.content) // 1024} KB)")
        return True
    except Exception as e:
        print(f"  [ERROR] {name}: {e}")
        return False


def main():
    dry_run = "--list" in sys.argv or "--dry-run" in sys.argv

    api_key = get_api_key()
    cache = load_cache()
    ASSETS_DIR.mkdir(parents=True, exist_ok=True)

    total_searched = 0
    total_downloaded = 0
    total_errors = 0

    # Procesar categorias en orden de prioridad
    for cat_name, teams in CATEGORIES.items():
        print(f"\n{'='*50}")
        print(f"[CAT] {cat_name.upper()} ({len(teams)} equipos)")
        print(f"{'='*50}")

        for name in teams:
            total_searched += 1
            remaining_old = len([k for k, v in cache.items() if v is None])
            print(f"\n[{total_searched}] {name}...", end="")

            team = search_team(name, api_key, cache)
            save_cache(cache)

            if not team:
                print(" [NO ENCONTRADO]")
                total_errors += 1
                continue

            api_name = team["name"]
            is_nat = team.get("national", False)
            print(f" -> {api_name}" + (" (seleccion)" if is_nat else ""), end="")

            if download_logo(team, name, dry_run):
                total_downloaded += 1

            # Esperar para respetar rate limit
            time.sleep(DELAY)

    # Resumen
    total_cached = len([k for k, v in cache.items() if v is not None])
    total_not_found = len([k for k, v in cache.items() if v is None])

    print(f"\n{'='*50}")
    print(f"RESUMEN FINAL")
    print(f"{'='*50}")
    print(f"  Busquedas:  {total_searched}")
    print(f"  En API:     {total_cached}")
    print(f"  No encontrados: {total_not_found}")
    if not dry_run:
        print(f"  Descargados: {total_downloaded}")
    print(f"  Cache:      {CACHE_FILE}")
    print()


if __name__ == "__main__":
    main()
