class RouteInfo {
  final String id;
  final String number;
  final String title;
  final String duration; // ONE_WEEK или TWO_WEEKS
  final int currentWeek; // текущая неделя (0 или 1)
  final bool canEditOutletLocations;
  final bool canCreateOrderInvoice;

  const RouteInfo({
    required this.id,
    required this.number,
    required this.title,
    required this.duration,
    required this.currentWeek,
    required this.canEditOutletLocations,
    required this.canCreateOrderInvoice,
  });

  // Удобный геттер — полное отображение
  String get displayTitle => title.isNotEmpty ? '$number - $title' : number;

  bool get isTwoWeeks => duration == 'TWO_WEEKS';
}
