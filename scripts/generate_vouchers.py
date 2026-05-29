#!/usr/bin/env python3
"""
Script para generar vales de pago
Uso: python generate_vouchers.py --amount 5000 --count 10 --days 30
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta
import random
import string
import argparse

SERVICE_ACCOUNT_PATH = "serviceAccountKey.json"

cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
firebase_admin.initialize_app(cred)
db = firestore.client()

def generate_voucher_code():
    """Genera código único con formato XXXX-XXXX-XXXX"""
    chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ0123456789'

    part1 = ''.join(random.choice(chars) for _ in range(4))
    part2 = ''.join(random.choice(chars) for _ in range(4))
    part3 = ''.join(random.choice(chars) for _ in range(4))

    return f"{part1}-{part2}-{part3}"

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--amount', '-a', type=int, required=True, help='Monto del vale')
    parser.add_argument('--count', '-c', type=int, required=True, help='Cantidad de vales')
    parser.add_argument('--days', '-d', type=int, default=30, help='Días de validez')

    args = parser.parse_args()

    expires_at = datetime.now() + timedelta(days=args.days)
    batch = db.batch()

    print("=" * 60)
    print("🎫 GENERADOR DE VALES - LA POLLA MILLONARIA 🎫")
    print("=" * 60)
    print(f"💰 Monto: ${args.amount:,} COP")
    print(f"📦 Cantidad: {args.count}")
    print(f"📅 Fecha expiración: {expires_at.strftime('%d/%m/%Y %H:%M')}")
    print()
    print("📋 CÓDIGOS GENERADOS:")
    print("-" * 40)

    codes = []
    for i in range(args.count):
        code = generate_voucher_code()
        codes.append(code)
        voucher_ref = db.collection('vouchers').document()
        batch.set(voucher_ref, {
            'code': code,
            'amount': args.amount,
            'used': False,
            'createdAt': firestore.SERVER_TIMESTAMP,
            'expiresAt': expires_at,
        })
        print(f"  {i+1:2d}. {code}")

    batch.commit()

    print()
    print("=" * 60)
    print(f"✅ {args.count} vales generados exitosamente!")
    print("=" * 60)
    print()
    print("📝 Para probar, copia uno de los códigos y pégalo en la app")
    print(f"   Ejemplo: {codes[0] if codes else 'XXXX-XXXX-XXXX'}")
    print()
    print("📍 Los vales están en la colección 'vouchers' de Firestore")

if __name__ == "__main__":
    main()