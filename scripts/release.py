#!/usr/bin/env python3
"""
Script de release automatizado para La Polla Millonaria.
Incrementa versión, compila APK + Web, y crea tag en git.

Uso:
  python scripts/release.py                  # Incrementa patch (1.0.3 → 1.0.4)
  python scripts/release.py --minor          # Incrementa minor (1.0.3 → 1.1.0)
  python scripts/release.py --major          # Incrementa major (1.0.3 → 2.0.0)
  python scripts/release.py --version 1.2.0  # Versión específica
  python scripts/release.py --dry-run        # Simular sin ejecutar

Requisitos:
  - Flutter SDK en PATH
  - gh CLI instalado y autenticado (para GitHub release)
  - android/key.properties configurado (para APK firmada)
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent.parent
SCRIPTS_DIR = Path(__file__).parent
PUBSPEC_FILE = REPO_DIR / "pubspec.yaml"


def run(cmd, cwd=None, dry_run=False):
    """Ejecutar comando o simularlo"""
    cwd = cwd or REPO_DIR
    if dry_run:
        print(f"  [DRY] $ {cmd}")
        return ""
    print(f"  $ {cmd}")
    result = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"  [ERROR] {result.stderr.strip()}")
        sys.exit(1)
    return result.stdout.strip()


def get_current_version():
    """Leer versión actual de pubspec.yaml"""
    content = PUBSPEC_FILE.read_text(encoding="utf-8")
    match = re.search(r"^version:\s*(\S+)", content, re.MULTILINE)
    if not match:
        print("[ERROR] No se encontro version en pubspec.yaml")
        sys.exit(1)
    return match.group(1)


def bump_version(current, part):
    """Incrementar versión (major, minor, patch)"""
    parts = current.split("+")[0].split(".")
    major, minor, patch = int(parts[0]), int(parts[1]), int(parts[2])

    if part == "major":
        major += 1
        minor = 0
        patch = 0
    elif part == "minor":
        minor += 1
        patch = 0
    else:  # patch
        patch += 1

    return f"{major}.{minor}.{patch}"


def update_pubspec_version(new_version, dry_run=False):
    """Actualizar versión en pubspec.yaml"""
    content = PUBSPEC_FILE.read_text(encoding="utf-8")
    updated = re.sub(
        r"^version:\s*\S+",
        f"version: {new_version}",
        content,
        count=1,
        flags=re.MULTILINE,
    )

    if dry_run:
        print(f"  [DRY] Actualizaria pubspec.yaml: version -> {new_version}")
        return

    PUBSPEC_FILE.write_text(updated, encoding="utf-8")
    print(f"  [OK] pubspec.yaml actualizado: version {new_version}")


def build_apk(dry_run=False):
    """Compilar APK release"""
    print("\n  [APK] Compilando APK release...")
    run("flutter clean", dry_run=dry_run)
    run("flutter pub get", dry_run=dry_run)
    run("flutter build apk --release", dry_run=dry_run)

    apk_path = REPO_DIR / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
    if not dry_run:
        if apk_path.exists():
            size_mb = apk_path.stat().st_size / (1024 * 1024)
            print(f"  [OK] APK generada: {apk_path} ({size_mb:.1f} MB)")
        else:
            print(f"  [!] No se encontro la APK en {apk_path}")


def build_web(dry_run=False):
    """Compilar web release"""
    print("\n  [WEB] Compilando Web release...")

    if not dry_run:
        run("flutter clean")
        run("flutter pub get")

    run("flutter build web --release", dry_run=dry_run)

    web_path = REPO_DIR / "build" / "web"
    if not dry_run:
        if web_path.exists():
            print(f"  [OK] Web build generada en: {web_path}")
        else:
            print(f"  [!] No se encontro el build web en {web_path}")


def git_commit_tag(version, dry_run=False):
    """Commit del cambio de versión y tag"""
    print("\n  [GIT] Creando commit y tag git...")

    # Verificar si hay cambios
    status = run("git status --porcelain", dry_run=dry_run)

    if dry_run:
        print(f"  [DRY] Haria commit con: 'release: v{version}'")
        print(f"  [DRY] Crearia tag: v{version}")
        return

    if status:
        run(f'git add -A')
        run(f'git commit -m "release: v{version}"')
        run(f'git tag -a v{version} -m "Version {version}"')
        print(f"  [OK] Commit y tag v{version} creados")
        print(f"  [!] Revisa y haz push manual:")
        print(f"     git push origin main --tags")
    else:
        print("  [!] No hay cambios para commitear")


def create_github_release(version, dry_run=False):
    """Crear release en GitHub"""
    apk_path = REPO_DIR / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"

    if not apk_path.exists():
        print("  [!] APK no encontrada. Omite GitHub release.")
        return

    print("\n  [GIT] Creando GitHub Release...")

    if dry_run:
        print(f"  [DRY] Crearia release: v{version}")
        return

    try:
        run(f'gh release create v{version} '
            f'--title "Version {version}" '
            f'--notes "Release v{version}" '
            f'"{apk_path}"')
        print(f"  [OK] Release v{version} creado en GitHub")
    except Exception as e:
        print(f"  [!] No se pudo crear release: {e}")
        print("  Asegurate de tener gh CLI instalado y autenticado")


def main():
    parser = argparse.ArgumentParser(description="Automatizar release de La Polla Millonaria")
    parser.add_argument("--major", action="store_true", help="Incrementar versión major")
    parser.add_argument("--minor", action="store_true", help="Incrementar versión minor")
    parser.add_argument("--version", type=str, help="Versión específica (ej: 1.2.0)")
    parser.add_argument("--dry-run", action="store_true", help="Simular sin ejecutar")
    parser.add_argument("--skip-web", action="store_true", help="Saltar build web")
    parser.add_argument("--skip-github", action="store_true", help="Saltar GitHub release")

    args = parser.parse_args()

    dry_run = args.dry_run

    print("=" * 55)
    print("  >> LA POLLA MILLONARIA - RELEASE AUTOMATIZADO")
    print("=" * 55)

    # 1. Determinar nueva versión
    current = get_current_version()
    print(f"\n[i] Version actual: {current}")

    if args.version:
        new_version = args.version
    elif args.major:
        new_version = bump_version(current, "major")
    elif args.minor:
        new_version = bump_version(current, "minor")
    else:
        new_version = bump_version(current, "patch")

    print(f"[i] Nueva version: {new_version}")

    if not dry_run:
        confirm = input(f"\nCrear release v{new_version}? (s/n): ")
        if confirm.lower() != "s":
            print("[x] Cancelado")
            return

    # 2. Actualizar pubspec.yaml
    print("\n" + "-" * 55)
    print("[UPDATE] ACTUALIZANDO VERSION")
    print("-" * 55)
    update_pubspec_version(new_version, dry_run)

    # 3. Compilar APK
    print("\n" + "-" * 55)
    print("[APK] COMPILANDO APK")
    print("-" * 55)
    build_apk(dry_run)

    # 4. Compilar Web (opcional)
    if not args.skip_web:
        print("\n" + "-" * 55)
        print("[WEB] COMPILANDO WEB")
        print("-" * 55)
        build_web(dry_run)

    # 5. Commit y tag
    print("\n" + "-" * 55)
    print("[GIT] COMMIT & TAG")
    print("-" * 55)
    git_commit_tag(new_version, dry_run)

    # 6. GitHub Release
    if not args.skip_github:
        print("\n" + "-" * 55)
        print("[GIT] GITHUB RELEASE")
        print("-" * 55)
        create_github_release(new_version, dry_run)

    print("\n" + "=" * 55)
    if dry_run:
        print("  [DRY] DRY RUN COMPLETADO -- No se hicieron cambios")
    else:
        print(f"  [OK] Release v{new_version} completado")
        print("\n  [NEXT] Proximos pasos:")
        print(f"     git push origin main --tags")
        if not args.skip_web:
            print("     .\\deploy_web.ps1")
    print("=" * 55)


if __name__ == "__main__":
    main()
