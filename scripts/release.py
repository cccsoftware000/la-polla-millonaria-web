#!/usr/bin/env python3
"""
Script de release automatizado para La Polla Millonaria.
Incrementa version, compila APK, crea tag en git, sube release a GitHub.

Uso:
  python scripts/release.py                        # Incrementa patch (1.0.3 -> 1.0.4)
  python scripts/release.py --minor                # Incrementa minor (1.0.3 -> 1.1.0)
  python scripts/release.py --major                # Incrementa major (1.0.3 -> 2.0.0)
  python scripts/release.py --version 1.2.0        # Version especifica
  python scripts/release.py --notes "notas aqui"   # Notas directas (saltar prompt)
  python scripts/release.py --dry-run              # Simular sin ejecutar

Requisitos:
  - Flutter SDK en PATH
  - gh CLI instalado y autenticado
  - android/key.properties configurado (para APK firmada)
"""

import argparse
import re
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent.parent
PUBSPEC_FILE = REPO_DIR / "pubspec.yaml"


def run(cmd, cwd=None, dry_run=False):
    cwd = cwd or REPO_DIR
    if dry_run:
        print(f"  [DRY] $ {cmd}")
        return ""
    print(f"  $ {cmd}")
    result = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        err = result.stderr.strip()
        if err:
            print(f"  [ERROR] {err}")
        out = result.stdout.strip()
        if out:
            print(f"  [OUT] {out}")
        sys.exit(1)
    return result.stdout.strip()


def get_current_version():
    content = PUBSPEC_FILE.read_text(encoding="utf-8")
    match = re.search(r"^version:\s*(\S+)", content, re.MULTILINE)
    if not match:
        print("[ERROR] No se encontro version en pubspec.yaml")
        sys.exit(1)
    return match.group(1)


def bump_version(current, part):
    parts = current.split("+")[0].split(".")
    major, minor, patch = int(parts[0]), int(parts[1]), int(parts[2])
    if part == "major":
        major += 1
        minor = 0
        patch = 0
    elif part == "minor":
        minor += 1
        patch = 0
    else:
        patch += 1
    return f"{major}.{minor}.{patch}"


def update_pubspec_version(new_version, dry_run=False):
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
    return apk_path


def prompt_notes(new_version):
    print("\n  [NOTAS] Escribe las notas del release (linea vacia + Enter para finalizar):")
    print(f"  (Se insertara automaticamente '## v{new_version}' al inicio)")
    lines = []
    while True:
        try:
            line = input("    > ")
            if line == "":
                break
            lines.append(line)
        except EOFError:
            break
    if not lines:
        return f"## v{new_version}\n\n- Sin notas"
    body = f"## v{new_version}\n"
    for l in lines:
        body += "\n" + l
    return body


def git_commit_and_push(version, dry_run=False, auto_yes=False):
    print("\n  [GIT] Creando commit y tag git...")
    status = run("git status --porcelain", dry_run=dry_run)
    if dry_run:
        print(f"  [DRY] Haria commit: 'release: v{version}'")
        print(f"  [DRY] Crearia tag: v{version}")
        print(f"  [DRY] Haria push origin main --tags")
        return
    if not status:
        print("  [!] No hay cambios para commitear")
        return
    run("git add -A")
    # Verificar que no se hayan colado node_modules, .dart_tool, etc.
    staged = run("git diff --cached --name-only")
    suspicious = [f for f in staged.split("\n") if "node_modules" in f or ".dart_tool" in f or f.endswith(".lock")]
    if suspicious:
        print("  [⚠] Archivos sospechosos detectados en el commit:")
        for f in suspicious[:10]:
            print(f"     - {f}")
        print("  [i] Revisa .gitignore antes de continuar")
        if not auto_yes:
            try:
                confirm = input("  Continuar de todas formas? (s/N): ")
                if confirm.lower() != "s":
                    print("[x] Commit cancelado")
                    sys.exit(1)
            except EOFError:
                print("  [⚠] No se pudo confirmar. Usa --yes para auto-aceptar.")
                sys.exit(1)
    run(f'git commit -m "release: v{version}"')
    run(f'git tag -a v{version} -m "Version {version}"')
    print(f"  [OK] Commit y tag v{version} creados")
    print("  [GIT] Subiendo commit y tag al remoto...")
    run("git push origin main --tags")
    print("  [OK] Push completado")


def create_github_release(version, notes, apk_path, title=None, dry_run=False):
    if not dry_run and not apk_path.exists():
        print("  [!] APK no encontrada. Omite GitHub release.")
        return
    print("\n  [GITHUB] Creando GitHub Release...")
    if dry_run:
        print(f"  [DRY] Crearia release: v{version} con notas:")
        print(notes)
        return
    # Escribir notas a archivo temporal para evitar problemas de shell con caracteres especiales
    with tempfile.NamedTemporaryFile(mode="w", suffix=".md", delete=False, encoding="utf-8") as f:
        f.write(notes)
        notes_path = f.name
    try:
        rel_title = title if title else f"Version {version}"
        run(f'gh release create v{version} --title "{rel_title}" --notes-file "{notes_path}" "{apk_path}"')
        print(f"  [OK] Release v{version} creado en GitHub")
    except Exception as e:
        print(f"  [!] No se pudo crear release: {e}")
        print("  Asegurate de tener gh CLI instalado y autenticado")
    finally:
        Path(notes_path).unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description="Automatizar release de La Polla Millonaria")
    parser.add_argument("--major", action="store_true", help="Incrementar version major")
    parser.add_argument("--minor", action="store_true", help="Incrementar version minor")
    parser.add_argument("--version", type=str, help="Version especifica (ej: 1.2.0)")
    parser.add_argument("--notes", type=str, help="Notas del release (si no se pasa, pide interactivo)")
    parser.add_argument("--title", type=str, help="Titulo personalizado del release (ej: \"Version 1.0.7 - Mundial 2026\")")
    parser.add_argument("--yes", "-y", action="store_true", help="Auto-confirmar (saltar prompt)")
    parser.add_argument("--dry-run", action="store_true", help="Simular sin ejecutar")
    parser.add_argument("--skip-web", action="store_true", help="Saltar build web")

    args = parser.parse_args()
    dry_run = args.dry_run

    print("=" * 55)
    print("  >> LA POLLA MILLONARIA - RELEASE AUTOMATIZADO")
    print("=" * 55)

    # 1. Determinar nueva version
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

    # 2. Pedir confirmacion
    if not dry_run and not args.yes:
        try:
            confirm = input(f"\nCrear release v{new_version}? (s/n): ")
            if confirm.lower() != "s":
                print("[x] Cancelado")
                return
        except EOFError:
            print("[x] Entrada no disponible. Usa --notes --yes para saltar confirmacion.")
            return

    # 3. Notas del release
    if args.notes:
        notes = f"## v{new_version}\n\n{args.notes}"
    else:
        notes = prompt_notes(new_version)

    print(f"\n  [OK] Notas capturadas ({len(notes)} chars)")

    # 4. Actualizar pubspec.yaml
    print("\n" + "-" * 55)
    print("[UPDATE] ACTUALIZANDO VERSION")
    print("-" * 55)
    update_pubspec_version(new_version, dry_run)

    # 5. Compilar APK
    print("\n" + "-" * 55)
    print("[APK] COMPILANDO APK")
    print("-" * 55)
    apk_path = build_apk(dry_run)

    # 6. Compilar Web (opcional)
    if not args.skip_web:
        print("\n" + "-" * 55)
        print("[WEB] COMPILANDO WEB")
        print("-" * 55)
        build_web(dry_run)

    # 7. Commit, tag y push
    print("\n" + "-" * 55)
    print("[GIT] COMMIT, TAG & PUSH")
    print("-" * 55)
    git_commit_and_push(new_version, dry_run, auto_yes=args.yes)

    # 8. GitHub Release
    print("\n" + "-" * 55)
    print("[GITHUB] CREANDO RELEASE")
    print("-" * 55)
    create_github_release(new_version, notes, apk_path, title=args.title, dry_run=dry_run)

    print("\n" + "=" * 55)
    if dry_run:
        print("  [DRY] DRY RUN COMPLETADO -- No se hicieron cambios")
    else:
        print(f"  [OK] Release v{new_version} completado y subido a GitHub")
    print("=" * 55)


def build_web(dry_run=False):
    print("\n  [WEB] Compilando Web release...")
    if not dry_run:
        run("flutter clean")
        run("flutter pub get")
    run("flutter build web --release", dry_run=dry_run)
    web_path = REPO_DIR / "build" / "web"
    if not dry_run and web_path.exists():
        print(f"  [OK] Web build generada en: {web_path}")


if __name__ == "__main__":
    main()
