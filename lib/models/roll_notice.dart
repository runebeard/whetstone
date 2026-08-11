enum RollNoticeTone { normal, criticalSuccess, criticalFailure, damage }

class RollNotice {
  final int id;
  final String title;
  final String calculation;
  final int total;
  final String? detail;
  final RollNoticeTone tone;
  final bool visible;

  const RollNotice({
    required this.id,
    required this.title,
    required this.calculation,
    required this.total,
    required this.tone,
    this.detail,
    this.visible = true,
  });

  RollNotice copyWith({bool? visible}) {
    return RollNotice(
      id: id,
      title: title,
      calculation: calculation,
      total: total,
      detail: detail,
      tone: tone,
      visible: visible ?? this.visible,
    );
  }
}
