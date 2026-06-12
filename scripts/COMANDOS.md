# GUÍA DE EJECUCIÓN DE SCRIPTS

## 📋 Requisitos

- **Python 3.8+** con `pip install firebase-admin`
- **Node.js 18+** con `cd functions && npm install`
- **serviceAccountKey.json** en `scripts/` (descargado de Firebase Console)

---

## 🏆 CREAR JORNADA (NUEVA)

Crea una jornada con 8 partidos en Firestore.

```bash
# Crear jornada (con confirmación)
python create_jornada.py -j jornada_2

# Modo append: solo agrega partidos faltantes
python create_jornada.py -j jornada_2 --append

# Simular sin escribir
python create_jornada.py -j jornada_2 --dry-run

# Listar jornadas disponibles
python create_jornada.py --list
```

> **Editar datos:** Abre `create_jornada.py` y modifica el preset correspondiente en `JORNADAS`. Los placeholders `TBD` deben reemplazarse con datos reales.

---

## ⚽ ACTUALIZAR RESULTADOS

Sube los marcadores reales de los partidos que ya terminaron.

```bash
# Usar un preset (varios partidos a la vez)
node update_results.js
node update_results.js --preset jornada_1_v1
node update_results.js --preset jornada_2_dia1

# Partido individual
node update_results.js --match match_j2_1 --home 2 --away 1
node update_results.js -m match_j2_6 -h 1 -a 0

# Con prefijo para otras jornadas (si los IDs usan prefijo distinto)
MATCH_PREFIX=match_j2 node update_results.js

# Listar todos los presets disponibles
node update_results.js --list
```

> Los presets se definen en `PRESETS` dentro del script. Agrega tantos como necesites para actualizaciones parciales.

---

## 📊 EJECUTAR ESCRUTINIO

Procesa los resultados y determina ganadores.

```bash
cd ../functions && node run_scrutiny.js
```

> Procesa automaticamente todas las pollas con `status` en `CLOSED/FINISHED` y `processedAt == null`.
> Calcula aciertos exactos, determina ganadores (min 4 aciertos y solo los de maximo puntaje), reparte el pozo por jornada y hace rollover si no hay ganadores.

---

## 💳 CONFIRMAR PAGOS

Marca apuestas como pagadas después de recibir el dinero.

> Importante: cuando inicia el primer partido la polla pasa a `CLOSED` y las apuestas pendientes se marcan como `CANCELLED` (abandonadas). No se deben confirmar pagos despues del cierre.

```bash
# Por ID de apuesta
python confirm_payment.py --bet-id ABC123

# Por teléfono del usuario
python confirm_payment.py --phone 3001234567

# Listar apuestas pendientes
python confirm_payment.py --list
python confirm_payment.py --phone 3001234567 --list
```

---

## 🎫 GENERAR VALES DE PAGO

Crea códigos de vale para que los usuarios paguen sin transferencia.

```bash
# Generar 10 vales de $5,000 COP con 30 días de validez
python generate_vouchers.py --amount 5000 --count 10 --days 30
```

---

## 🔄 SCRIPTS LEGADOS (ya no uses)

| Script | Reemplazado por |
|--------|----------------|
| `populate_firestore.py` | `create_jornada.py` |
| `generate_matches_polla.py` | `create_jornada.py` |
| `ingresaResultado.js` | `update_results.js --preset jornada_1_v1` |

---

## 🚀 DESPLIEGUE

### Web (GitHub Pages)
```powershell
.\deploy_web.ps1
```

### APK Android
```bash
flutter build apk --release
# El APK se genera en: build\app\outputs\flutter-apk\app-release.apk
```

### Cloud Functions
```bash
cd functions
firebase deploy --only functions
```
