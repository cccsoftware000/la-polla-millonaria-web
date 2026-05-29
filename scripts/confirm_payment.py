#!/usr/bin/env python3
"""
Script para confirmar pagos de apuestas
El acumulado lo maneja la Cloud Function onBetPaid
Uso: python confirm_payment.py --bet-id ID_APUESTA
     python confirm_payment.py --phone 3001234567
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import argparse

SERVICE_ACCOUNT_PATH = "serviceAccountKey.json"

cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
firebase_admin.initialize_app(cred)
db = firestore.client()

def get_user_by_phone(phone):
    users_ref = db.collection('users')
    docs = users_ref.where('phone', '==', f'+57{phone}').stream()
    users = list(docs)
    if len(users) == 0:
        docs = users_ref.where('phone', '==', phone).stream()
        users = list(docs)
    if len(users) == 0:
        return None
    return users[0]

def get_pending_bets_by_user(user_id):
    bets_ref = db.collection('bets')
    docs = bets_ref.where('uid', '==', user_id) \
        .where('status', '==', 'PENDING_PAYMENT') \
        .where('deleted', '==', False) \
        .stream()
    return list(docs)

def confirm_bet(bet_id, bet_doc):
    """Confirmar pago de una apuesta"""
    bet_data = bet_doc.to_dict()

    if bet_data.get('paymentConfirmed', False):
        print(f"⚠️ La apuesta {bet_id} ya fue confirmada anteriormente")
        return False

    try:
        bet_ref = db.collection('bets').document(bet_id)
        # ✅ ACTUALIZAR ambos campos: paymentConfirmed y status
        bet_ref.update({
            'paymentConfirmed': True,
            'paymentConfirmedAt': firestore.SERVER_TIMESTAMP,
            'status': 'ACTIVE',  # 👈 IMPORTANTE: Cambiar status
        })

        print(f"\n✅ Apuesta marcada como pagada!")
        print(f"   Apuesta ID: {bet_id}")
        print(f"   Status: ACTIVE")
        print(f"   ⏳ La Cloud Function aumentará el acumulado automáticamente")
        return True

    except Exception as e:
        print(f"\n❌ Error al confirmar pago: {e}")
        return False

def list_pending_bets(phone=None, bet_id=None):
    if bet_id:
        doc = db.collection('bets').document(bet_id).get()
        if not doc.exists:
            print(f"❌ Apuesta {bet_id} no encontrada")
            return []
        data = doc.to_dict()
        print(f"\n📝 Apuesta: {bet_id}")
        print(f"   Usuario: {data.get('uid', 'N/A')}")
        print(f"   Estado: {data.get('status', 'N/A')}")
        print(f"   Confirmada: {data.get('paymentConfirmed', False)}")
        return [(bet_id, doc)]

    elif phone:
        user = get_user_by_phone(phone)
        if not user:
            print(f"❌ Usuario con teléfono {phone} no encontrado")
            return []

        user_data = user.to_dict()
        user_id = user.id
        print(f"👤 Usuario encontrado: {user_data.get('name', 'Sin nombre')}")

        bets = get_pending_bets_by_user(user_id)
        if len(bets) == 0:
            print(f"📭 No hay apuestas pendientes para este usuario")
            return []

        print(f"\n📋 Apuestas pendientes ({len(bets)}):")
        for i, doc in enumerate(bets, 1):
            data = doc.to_dict()
            predictions = data.get('predictions', [])
            created_at = data.get('createdAt')
            fecha = created_at.strftime('%Y-%m-%d %H:%M') if created_at else 'N/A'
            print(f"   {i}. ID: {doc.id}")
            print(f"      Fecha: {fecha}")
            print(f"      Partidos: {len(predictions)}")
        return [(doc.id, doc) for doc in bets]

    else:
        bets = db.collection('bets') \
            .where('status', '==', 'PENDING_PAYMENT') \
            .order_by('createdAt', direction=firestore.Query.DESCENDING) \
            .limit(10) \
            .stream()

        results = list(bets)
        if len(results) == 0:
            print("📭 No hay apuestas pendientes")
            return []

        print(f"\n📋 Últimas apuestas pendientes ({len(results)}):")
        for i, doc in enumerate(results, 1):
            data = doc.to_dict()
            created_at = data.get('createdAt')
            fecha = created_at.strftime('%Y-%m-%d %H:%M') if created_at else 'N/A'
            print(f"   {i}. ID: {doc.id}")
            print(f"      Usuario: {data.get('uid', 'N/A')}")
            print(f"      Fecha: {fecha}")
        return [(doc.id, doc) for doc in results]

def main():
    parser = argparse.ArgumentParser(description='Confirmar pagos de apuestas')
    parser.add_argument('--bet-id', '-b', type=str, help='ID de la apuesta a confirmar')
    parser.add_argument('--phone', '-p', type=str, help='Número de teléfono del usuario')
    parser.add_argument('--list', '-l', action='store_true', help='Listar apuestas pendientes')
    parser.add_argument('--all', '-a', action='store_true', help='Confirmar TODAS las apuestas pendientes')

    args = parser.parse_args()

    print("=" * 50)
    print("💳 LA POLLA MILLONARIA - CONFIRMAR PAGOS 💳")
    print("=" * 50)
    print("   ⚠️ El acumulado lo maneja la Cloud Function")
    print("=" * 50)
    print()

    if args.list:
        list_pending_bets(phone=args.phone)
        return

    if args.bet_id:
        doc = db.collection('bets').document(args.bet_id).get()
        if not doc.exists:
            print(f"❌ Apuesta {args.bet_id} no encontrada")
            return

        data = doc.to_dict()
        print(f"📝 Apuesta a confirmar:")
        print(f"   ID: {args.bet_id}")
        print(f"   Usuario: {data.get('uid', 'N/A')}")
        print(f"   Estado: {data.get('status', 'N/A')}")
        print(f"   Confirmada: {data.get('paymentConfirmed', False)}")
        print()

        confirm = input("¿Marcar como pagada? (s/n): ")
        if confirm.lower() == 's':
            confirm_bet(args.bet_id, doc)
        else:
            print("❌ Cancelado")
        return

    if args.phone:
        user = get_user_by_phone(args.phone)
        if not user:
            print(f"❌ Usuario con teléfono {args.phone} no encontrado")
            return

        user_data = user.to_dict()
        bets = get_pending_bets_by_user(user.id)
        if len(bets) == 0:
            print("📭 No hay apuestas pendientes para este usuario")
            return

        print(f"👤 Usuario: {user_data.get('name', 'Sin nombre')}")
        print(f"📞 Teléfono: {args.phone}")
        print()

        if args.all:
            print(f"📋 Se marcarán {len(bets)} apuestas como pagadas:")
            for i, doc in enumerate(bets, 1):
                print(f"   {i}. ID: {doc.id}")

            confirm = input(f"\n¿Confirmar TODAS? (s/n): ")
            if confirm.lower() == 's':
                for doc in bets:
                    confirm_bet(doc.id, doc)
            else:
                print("❌ Cancelado")
        else:
            print("📋 Apuestas pendientes:")
            for i, doc in enumerate(bets, 1):
                print(f"   {i}. ID: {doc.id}")

            try:
                selection = input(f"\nSelecciona apuesta (1-{len(bets)}) o 't' para todas: ")
                if selection.lower() == 't':
                    for doc in bets:
                        confirm_bet(doc.id, doc)
                else:
                    idx = int(selection) - 1
                    if 0 <= idx < len(bets):
                        confirm_bet(bets[idx].id, bets[idx])
                    else:
                        print("❌ Selección inválida")
            except ValueError:
                print("❌ Entrada inválida")
        return

    parser.print_help()

if __name__ == "__main__":
    main()