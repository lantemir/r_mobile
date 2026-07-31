class RouteDay {
  final String id;
  final String routeId;
  final int day; // 0=Понедельник, 1=Вторник... 6=Воскресенье
  final String dayDisplay; // "Monday", "Tuesday"... (на английском из Django)
  final List<String> outletIds; // ID торговых точек этого дня

  const RouteDay({
    required this.id,
    required this.routeId,
    required this.day,
    required this.dayDisplay,
    required this.outletIds,
  });

  // Русское название дня недели
  String get dayDisplayRu {
    switch (day) {
      case 0:
        return 'Понедельник';
      case 1:
        return 'Вторник';
      case 2:
        return 'Среда';
      case 3:
        return 'Четверг';
      case 4:
        return 'Пятница';
      case 5:
        return 'Суббота';
      case 6:
        return 'Воскресенье';
      default:
        return dayDisplay;
    }
  }

  // Количество точек в этом дне
  int get outletsCount => outletIds.length;
}
