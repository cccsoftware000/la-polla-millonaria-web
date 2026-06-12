#!/usr/bin/env python3
"""
Script para LIMPIAR partidos duplicados y luego ACTUALIZAR jornadas 3 y 4
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import sys
import os

# ==================== CREDENCIALES ====================
SERVICE_ACCOUNT_PATH = "serviceAccountKey.json"

if not os.path.exists(SERVICE_ACCOUNT_PATH):
    print(f"❌ No se encontró el archivo {SERVICE_ACCOUNT_PATH}")
    sys.exit(1)

cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
firebase_admin.initialize_app(cred)
print("✅ Firebase inicializado")

db = firestore.client()

# ==================== FUNCIÓN PARA HORAS ====================
def colombia_time(year, month, day, hour, minute=0):
    new_hour = hour + 5
    new_day = day
    if new_hour >= 24:
        new_hour -= 24
        new_day += 1
    return datetime(year, month, new_day, new_hour, minute)

# ==================== 1. LISTAR TODOS LOS PARTIDOS ====================
print("\n📊 VERIFICANDO PARTIDOS EXISTENTES")
print("=" * 50)

# Ver partidos de jornada_3
matches_j3 = db.collection('matches').where('pollaId', '==', 'jornada_3').get()
print(f"\nPartidos en jornada_3: {len(matches_j3)}")
for m in matches_j3:
    data = m.to_dict()
    print(f"  - {m.id}: {data.get('local')} vs {data.get('visitor')}")

# Ver partidos de jornada_4
matches_j4 = db.collection('matches').where('pollaId', '==', 'jornada_4').get()
print(f"\nPartidos en jornada_4: {len(matches_j4)}")
for m in matches_j4:
    data = m.to_dict()
    print(f"  - {m.id}: {data.get('local')} vs {data.get('visitor')}")

# ==================== 2. ELIMINAR PARTIDOS DUPLICADOS ====================
print("\n" + "=" * 50)
print("🗑️ ELIMINANDO PARTIDOS DUPLICADOS")
print("=" * 50)

# IDs correctos que deben permanecer (8 por jornada)
correct_j3_ids = [f"match_j3_{i}" for i in range(1, 9)]
correct_j4_ids = [f"match_j4_{i}" for i in range(1, 9)]

# Eliminar partidos de jornada_3 con IDs incorrectos
for match in matches_j3:
    if match.id not in correct_j3_ids:
        match.reference.delete()
        print(f"  🗑️ Eliminado: {match.id}")

# Eliminar partidos de jornada_4 con IDs incorrectos
for match in matches_j4:
    if match.id not in correct_j4_ids:
        match.reference.delete()
        print(f"  🗑️ Eliminado: {match.id}")

# ==================== 3. ACTUALIZAR/CREAR PARTIDOS CORRECTOS ====================
print("\n" + "=" * 50)
print("📝 ACTUALIZANDO JORNADA 3")
print("=" * 50)

matches_j3_data = [
    {"id": "match_j3_1", "local": "España", "visitor": "Cabo Verde", "emoji_local": "🇪🇸", "emoji_visitor": "🇨🇻", "group": "Grupo H", "dt": colombia_time(2026, 6, 15, 11, 0)},
    {"id": "match_j3_2", "local": "Bélgica", "visitor": "Egipto", "emoji_local": "🇧🇪", "emoji_visitor": "🇪🇬", "group": "Grupo G", "dt": colombia_time(2026, 6, 15, 14, 0)},
    {"id": "match_j3_3", "local": "Arabia Saudita", "visitor": "Uruguay", "emoji_local": "🇸🇦", "emoji_visitor": "🇺🇾", "group": "Grupo H", "dt": colombia_time(2026, 6, 15, 17, 0)},
    {"id": "match_j3_4", "local": "Irán", "visitor": "Nueva Zelanda", "emoji_local": "🇮🇷", "emoji_visitor": "🇳🇿", "group": "Grupo G", "dt": colombia_time(2026, 6, 15, 20, 0)},
    {"id": "match_j3_5", "local": "Francia", "visitor": "Senegal", "emoji_local": "🇫🇷", "emoji_visitor": "🇸🇳", "group": "Grupo I", "dt": colombia_time(2026, 6, 16, 14, 0)},
    {"id": "match_j3_6", "local": "Irak", "visitor": "Noruega", "emoji_local": "🇮🇶", "emoji_visitor": "🇳🇴", "group": "Grupo I", "dt": colombia_time(2026, 6, 16, 17, 0)},
    {"id": "match_j3_7", "local": "Argentina", "visitor": "Argelia", "emoji_local": "🇦🇷", "emoji_visitor": "🇩🇿", "group": "Grupo J", "dt": colombia_time(2026, 6, 16, 20, 0)},
    {"id": "match_j3_8", "local": "Austria", "visitor": "Jordania", "emoji_local": "🇦🇹", "emoji_visitor": "🇯🇴", "group": "Grupo J", "dt": colombia_time(2026, 6, 16, 23, 0)},
]

for match in matches_j3_data:
    doc_ref = db.collection('matches').document(match["id"])
    data = {
        "pollaId": "jornada_3",
        "status": "UPCOMING",
        "local": match["local"],
        "visitor": match["visitor"],
        "localEmoji": match["emoji_local"],
        "visitorEmoji": match["emoji_visitor"],
        "tournament": "🌍 Copa del Mundo",
        "group": match["group"],
        "dateTime": match["dt"],
        "dateStr": match["dt"].strftime("%a, %d de %b"),
        "time": match["dt"].strftime("%H:%M"),
    }
    doc_ref.set(data)
    print(f"  ✅ Creado/Actualizado: {match['id']} - {match['local']} vs {match['visitor']}")

# ==================== 4. JORNADA 4 ====================
print("\n" + "=" * 50)
print("📝 ACTUALIZANDO JORNADA 4")
print("=" * 50)

matches_j4_data = [
    {"id": "match_j4_1", "local": "Portugal", "visitor": "RD Congo", "emoji_local": "🇵🇹", "emoji_visitor": "🇨🇩", "group": "Grupo K", "dt": colombia_time(2026, 6, 17, 12, 0)},
    {"id": "match_j4_2", "local": "Inglaterra", "visitor": "Croacia", "emoji_local": "🏴󠁧󠁢󠁥󠁮󠁧󠁿", "emoji_visitor": "🇭🇷", "group": "Grupo L", "dt": colombia_time(2026, 6, 17, 15, 0)},
    {"id": "match_j4_3", "local": "Ghana", "visitor": "Panamá", "emoji_local": "🇬🇭", "emoji_visitor": "🇵🇦", "group": "Grupo L", "dt": colombia_time(2026, 6, 17, 18, 0)},
    {"id": "match_j4_4", "local": "Uzbekistán", "visitor": "Colombia", "emoji_local": "🇺🇿", "emoji_visitor": "🇨🇴", "group": "Grupo K", "dt": colombia_time(2026, 6, 17, 21, 0)},
    {"id": "match_j4_5", "local": "Chequia", "visitor": "Sudáfrica", "emoji_local": "🇨🇿", "emoji_visitor": "🇿🇦", "group": "Grupo A", "dt": colombia_time(2026, 6, 18, 11, 0)},
    {"id": "match_j4_6", "local": "Suiza", "visitor": "Bosnia y Herzegovina", "emoji_local": "🇨🇭", "emoji_visitor": "🇧🇦", "group": "Grupo B", "dt": colombia_time(2026, 6, 18, 14, 0)},
    {"id": "match_j4_7", "local": "Canadá", "visitor": "Catar", "emoji_local": "🇨🇦", "emoji_visitor": "🇶🇦", "group": "Grupo B", "dt": colombia_time(2026, 6, 18, 17, 0)},
    {"id": "match_j4_8", "local": "México", "visitor": "Corea del Sur", "emoji_local": "🇲🇽", "emoji_visitor": "🇰🇷", "group": "Grupo A", "dt": colombia_time(2026, 6, 18, 20, 0)},
]

for match in matches_j4_data:
    doc_ref = db.collection('matches').document(match["id"])
    data = {
        "pollaId": "jornada_4",
        "status": "UPCOMING",
        "local": match["local"],
        "visitor": match["visitor"],
        "localEmoji": match["emoji_local"],
        "visitorEmoji": match["emoji_visitor"],
        "tournament": "🌍 Copa del Mundo",
        "group": match["group"],
        "dateTime": match["dt"],
        "dateStr": match["dt"].strftime("%a, %d de %b"),
        "time": match["dt"].strftime("%H:%M"),
    }
    doc_ref.set(data)
    print(f"  ✅ Creado/Actualizado: {match['id']} - {match['local']} vs {match['visitor']}")

# ==================== 5. ACTUALIZAR FECHAS DE JORNADAS ====================
print("\n" + "=" * 50)
print("📝 ACTUALIZANDO FECHAS DE JORNADAS")
print("=" * 50)

# Jornada 3
first_match_j3 = colombia_time(2026, 6, 15, 11, 0)
db.collection('pollas').document('jornada_3').update({
    "endDate": first_match_j3,
    "startDate": colombia_time(2026, 6, 15, 0, 0),
})
print(f"  ✅ jornada_3: endDate = {first_match_j3}")

# Jornada 4
first_match_j4 = colombia_time(2026, 6, 17, 12, 0)
db.collection('pollas').document('jornada_4').update({
    "endDate": first_match_j4,
    "startDate": colombia_time(2026, 6, 17, 0, 0),
})
print(f"  ✅ jornada_4: endDate = {first_match_j4}")

# ==================== 6. VERIFICAR RESULTADO FINAL ====================
print("\n" + "=" * 50)
print("📊 VERIFICACIÓN FINAL")
print("=" * 50)

matches_j3_final = db.collection('matches').where('pollaId', '==', 'jornada_3').get()
matches_j4_final = db.collection('matches').where('pollaId', '==', 'jornada_4').get()

print(f"\nJornada 3: {len(matches_j3_final)} partidos (deben ser 8)")
print(f"Jornada 4: {len(matches_j4_final)} partidos (deben ser 8)")

print("\n✅ ¡Script completado!")