import 'indian_state.dart';

/// A hackathon listing, matching the `hackathons` table.
class Hackathon {
  final int id;
  final String title;
  final String tagline;
  final String description;
  final IndianState state;
  final String city;
  final String venue;
  final String mode; // online | offline | hybrid
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? deadline;
  final String thumbnailUrl;
  final String websiteUrl;
  final String prizePool;
  final int maxTeamSize;
  final Organizer? organizer;

  Hackathon({
    required this.id,
    required this.title,
    required this.tagline,
    required this.description,
    required this.state,
    required this.city,
    required this.venue,
    required this.mode,
    this.startDate,
    this.endDate,
    this.deadline,
    this.thumbnailUrl = '',
    this.websiteUrl = '',
    this.prizePool = '',
    this.maxTeamSize = 0,
    this.organizer,
  });

  /// True when the hackathon's end date has already passed.
  bool get isEnded {
    final end = endDate;
    if (end == null) return false;
    return end.isBefore(DateTime.now());
  }

  factory Hackathon.fromJson(Map<String, dynamic> json) {
    DateTime? date(dynamic v) => v == null ? null : DateTime.tryParse(v);

    IndianState state = const IndianState(id: 0, name: '');
    final stateJson = json['states'];
    if (stateJson is Map<String, dynamic>) {
      state = IndianState.fromJson(stateJson);
    }

    Organizer? org;
    final orgJson = json['organizers'];
    if (orgJson is Map<String, dynamic>) {
      org = Organizer.fromJson(orgJson);
    }

    return Hackathon(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Untitled',
      tagline: json['tagline'] as String? ?? '',
      description: json['description'] as String? ?? '',
      state: state,
      city: json['city'] as String? ?? '',
      venue: json['venue'] as String? ?? '',
      mode: json['mode'] as String? ?? 'hybrid',
      startDate: date(json['start_date']),
      endDate: date(json['end_date']),
      deadline: date(json['deadline']),
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      websiteUrl: json['website_url'] as String? ?? '',
      prizePool: json['prize_pool'] as String? ?? '',
      maxTeamSize: json['max_team_size'] as int? ?? 0,
      organizer: org,
    );
  }
}

/// Organizer contact details, matching the `organizers` table.
class Organizer {
  final int id;
  final String name;
  final String email;
  final String phone; // stored as 91XXXXXXXXXX
  final String whatsapp; // stored as 91XXXXXXXXXX
  final String website;

  Organizer({
    required this.id,
    required this.name,
    this.email = '',
    this.phone = '',
    this.whatsapp = '',
    this.website = '',
  });

  factory Organizer.fromJson(Map<String, dynamic> json) {
    return Organizer(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      whatsapp: json['whatsapp'] as String? ?? '',
      website: json['website'] as String? ?? '',
    );
  }
}
