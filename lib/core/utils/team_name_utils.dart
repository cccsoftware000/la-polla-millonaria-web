// lib/core/utils/team_name_utils.dart

class TeamNameUtils {
  static const Map<String, String> teamShortNames = {
    // Colombia
    'Universitario': 'UNIV',
    'Universitario de Deportes': 'UNIV',
    'Millonarios': 'MIL',
    'Millonarios FC': 'MIL',
    'Nacional': 'NAC',
    'Atlético Nacional': 'NAC',
    'Independiente Medellín': 'DIM',
    'Medellín': 'DIM',
    'América de Cali': 'AME',
    'América': 'AME',
    'Junior FC': 'JUN',
    'Junior': 'JUN',
    'Deportes Tolima': 'TOL',
    'Tolima': 'TOL',
    'Independiente Santa Fe': 'SFE',
    'Santa Fe': 'SFE',
    'Envigado': 'ENV',
    'Once Caldas': 'ONC',
    'Pasto': 'PAS',
    'La Equidad': 'EQU',
    'Bucaramanga': 'BUC',
    'Jaguares': 'JAG',
    'Alianza Petrolera': 'ALI',
    'Huila': 'HUI',
    'Cortuluá': 'COR',
    'Unión Magdalena': 'MAG',
    'Quindío': 'QUI',

    // Internacionales
    'Liverpool': 'LIV',
    'Barcelona': 'BAR',
    'Real Madrid': 'RMA',
    'Paris Saint-Germain': 'PSG',
    'Paris Saint-Germain FC': 'PSG',
    'Chelsea': 'CHE',
    'Juventus': 'JUV',
    'Bayern': 'BAY',
    'Bayern Munich': 'BAY',
    'Inter': 'INT',
    'Inter Milan': 'INT',
    'Arsenal': 'ARS',
    'Arsenal FC': 'ARS',
    'Milan': 'MIL',
    'AC Milan': 'MIL',
    'Dortmund': 'DOR',
    'Borussia Dortmund': 'DOR',
    'Napoli': 'NAP',
    'Manchester City': 'MCI',
    'Man City': 'MCI',
    'City': 'MCI',
    'Atlético': 'ATM',
    'Atlético Madrid': 'ATM',

    // Sudamericanas
    'Peñarol': 'PEÑ',
    'Palmeiras': 'PAL',
    'Estudiantes LP': 'EST',
    'Estudiantes de La Plata': 'EST',
    'O\'Higgins': 'OHI',
    'Macará': 'MAC',

    // Selecciones
    'Colombia': 'COL',
    'Costa Rica': 'CRC',
  };

  static String getShortName(String fullName) {
    if (fullName.isEmpty) return '???';

    // Buscar coincidencia exacta o parcial
    for (var entry in teamShortNames.entries) {
      if (fullName.contains(entry.key)) {
        return entry.value;
      }
    }

    // Si no encuentra, devolver primeras 6 letras
    return fullName.length > 6 ? fullName.substring(0, 6).toUpperCase() : fullName.toUpperCase();
  }

  static String getDisplayName(String fullName) {
    if (fullName.isEmpty) return 'Equipo';
    return fullName;
  }
}