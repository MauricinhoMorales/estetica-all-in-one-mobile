class ShoppingSession {
  final int id;
  final String? place;
  final String date;
  final String status;

  const ShoppingSession({
    required this.id,
    this.place,
    required this.date,
    required this.status,
  });

  factory ShoppingSession.fromMap(Map<String, dynamic> map) {
    return ShoppingSession(
      id: map['id'] as int,
      place: map['place'] as String?,
      date: map['date'] as String,
      status: map['status'] as String? ?? 'active',
    );
  }

  bool get isActive => status == 'active';
}
