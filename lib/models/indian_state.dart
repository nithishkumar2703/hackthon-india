/// A single Indian state/UT. Named [IndianState] to avoid clashing
/// with Flutter's built-in `State` class.
class IndianState {
  final int id;
  final String name;

  IndianState({required this.id, required this.name});

  factory IndianState.fromJson(Map<String, dynamic> json) {
    return IndianState(id: json['id'] as int, name: json['name'] as String);
  }
}
