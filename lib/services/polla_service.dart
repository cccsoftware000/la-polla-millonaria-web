import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/date_utils.dart';
import '../models/bet_model.dart';
import '../models/polla_model.dart';

class PollaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ CORREGIDO - getActivePolla
  // lib/services/polla_service.dart

  Future<PollaModel?> getActivePolla() async {
    try {
      final snapshot = await _firestore
          .collection('pollas')
          .where('status', isEqualTo: 'ACTIVE')
          .get();

      // ✅ Buscar la primera que no tenga closedAt
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['closedAt'] == null) {
          return PollaModel.fromMap(doc.id, data);
        }
      }

      // ✅ Si no hay activa (todas cerradas), devolver null
      return null;
    } catch (e) {
      print('Error getting active polla: $e');
      return null;
    }
  }

  // Stream de la polla activa (tiempo real)
  Stream<PollaModel?> streamActivePolla() {
    return _firestore
        .collection('pollas')
        .where('status', isEqualTo: 'ACTIVE')
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;

      // Preferir la que este abierta a apuestas (sin closedAt)
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['closedAt'] == null) {
          return PollaModel.fromMap(doc.id, data);
        }
      }

      // Si ninguna esta abierta, no hay polla activa para apostar
      return null;
    });
  }

  // Stream de próximas pollas
  Stream<List<PollaModel>> streamUpcomingPollas() {
    return _firestore
        .collection('pollas')
        .where('status', isEqualTo: 'UPCOMING')
        .orderBy('startDate')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return PollaModel.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  // Obtener todas las pollas (para historial)
  Future<List<PollaModel>> getAllPollas() async {
    try {
      final snapshot = await _firestore
          .collection('pollas')
          .orderBy('startDate', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return PollaModel.fromMap(doc.id, doc.data());
      }).toList();
    } catch (e) {
      print('Error getting all pollas: $e');
      return [];
    }
  }

  // Verificar si la polla sigue abierta para apuestas
  Future<bool> isPollaOpen(String pollaId) async {
    try {
      final polla = await _firestore.collection('pollas').doc(pollaId).get();
      if (!polla.exists) return false;

      final data = polla.data()!;
      final status = data['status'];

      final endDate = (data['endDate'] as Timestamp?)?.toDate();
      if (endDate == null) return status == 'ACTIVE';

      final colombiaEndDate = endDate;
      final colombiaNow = DateTime.now();

      return status == 'ACTIVE' && colombiaNow.isBefore(colombiaEndDate);
    } catch (e) {
      return false;
    }
  }

  // Obtener polla por ID
  Future<PollaModel?> getPollaById(String pollaId) async {
    try {
      final doc = await _firestore.collection('pollas').doc(pollaId).get();
      if (!doc.exists) return null;
      return PollaModel.fromMap(doc.id, doc.data()!);
    } catch (e) {
      print('Error getting polla by id: $e');
      return null;
    }
  }

  // lib/services/polla_service.dart - AGREGAR estos métodos

// Obtener jornadas disponibles (activa + últimas 2 cerradas)
  // lib/services/polla_service.dart

  Future<List<PollaModel>> getAvailableJornadas() async {
    try {
      // Traer TODAS las pollas (sin filtros complicados)
      final snapshot = await _firestore
          .collection('pollas')
          .orderBy('endDate', descending: true)
          .get();

      final List<PollaModel> todas = snapshot.docs.map((doc) {
        return PollaModel.fromMap(doc.id, doc.data());
      }).toList();

      // Separar activas y cerradas
      final List<PollaModel> activas = [];
      final List<PollaModel> cerradas = [];

      for (var polla in todas) {
        // Una polla está activa si status es ACTIVE y NO tiene closedAt
        final estaActiva = polla.status == 'ACTIVE' && polla.closedAt == null;
        if (estaActiva) {
          activas.add(polla);
        } else {
          cerradas.add(polla);
        }
      }

      // Resultado: activas primero, luego cerradas
      final result = [...activas, ...cerradas];

      print('📊 Jornadas disponibles: ${result.length} (activas: ${activas.length}, cerradas: ${cerradas.length})');
      for (var j in result) {
        print('   - ${j.name}: status=${j.status}, closedAt=${j.closedAt != null ? "SÍ" : "NO"}');
      }

      return result;
    } catch (e) {
      print('Error getting available jornadas: $e');
      return [];
    }
  }

  Future<List<PollaModel>> getUnscruitedJornadas() async {
    try {
      final snapshot = await _firestore
          .collection('pollas')
          .orderBy('startDate', descending: false)
          .get();

      final unscruited = snapshot.docs
          .map((doc) => PollaModel.fromMap(doc.id, doc.data()))
          .where((p) => p.isUnscruited)
          .toList();

      print('📊 Jornadas no escrutadas: ${unscruited.length}');
      for (var j in unscruited) {
        print('   - ${j.name}: status=${j.status}');
      }

      return unscruited;
    } catch (e) {
      print('Error getting unscruited jornadas: $e');
      return [];
    }
  }

// Obtener apuestas del usuario filtradas por pollaId
  Future<List<BetModel>> getBetsByPolla(String userId, String pollaId) async {
    try {
      final snapshot = await _firestore
          .collection('bets')
          .where('uid', isEqualTo: userId)
          .where('pollaId', isEqualTo: pollaId)
          .where('deleted', isEqualTo: false)  // ✅ Filtro importante
          .orderBy('createdAt', descending: true)
          .get();

      print('🔍 Buscando apuestas para pollaId: $pollaId');
      print('📊 Encontradas: ${snapshot.docs.length} apuestas');

      return snapshot.docs.map((doc) {
        return BetModel.fromMap(doc.id, doc.data());
      }).toList();
    } catch (e) {
      print('Error getting bets by polla: $e');
      return [];
    }
  }
}
