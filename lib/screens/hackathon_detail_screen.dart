import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/hackathon.dart';
import '../services/app_actions.dart';

class HackathonDetailScreen extends StatelessWidget {
  final Hackathon hackathon;

  const HackathonDetailScreen({super.key, required this.hackathon});

  @override
  Widget build(BuildContext context) {
    final org = hackathon.organizer;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(
          hackathon.title,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white70),
            onPressed: () => AppActions.shareHackathon(
              hackathon.title,
              hackathon.websiteUrl,
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          _heroImage(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _statusBadge(),
                const SizedBox(height: 12),
                Text(
                  hackathon.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                if (hackathon.tagline.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    hackathon.tagline,
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  ),
                ],
                const SizedBox(height: 20),
                _infoCard([
                  if (_locationText().isNotEmpty)
                    _infoRow(Icons.location_on_outlined, _locationText()),
                  _infoRow(Icons.calendar_today_outlined, _dateRange()),
                  if (hackathon.mode.isNotEmpty)
                    _infoRow(Icons.laptop_outlined, _modeLabel()),
                  if (hackathon.deadline != null)
                    _infoRow(Icons.schedule_outlined,
                        'Registration deadline: ${_formatDate(hackathon.deadline!)}'),
                ]),
                if (hackathon.prizePool.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _prizeCard(),
                ],
                if (org != null) ...[
                  const SizedBox(height: 12),
                  _organizerCard(org),
                ],
                if (hackathon.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'About',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hackathon.description,
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: org == null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  border: Border(top: BorderSide(color: Color(0xFF334155))),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hackathon.websiteUrl.isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.language, size: 18),
                          label: const Text('Visit Official Website'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () =>
                              AppActions.openWebsite(hackathon.websiteUrl),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _contactBtn(
                            Icons.chat_outlined,
                            'WhatsApp',
                            org.whatsapp.isNotEmpty
                                ? () => AppActions.openWhatsApp(org.whatsapp)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _contactBtn(
                            Icons.mail_outlined,
                            'Email',
                            org.email.isNotEmpty
                                ? () => AppActions.emailOrganizer(org.email)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _contactBtn(
                            Icons.phone_outlined,
                            'Call',
                            org.phone.isNotEmpty
                                ? () => AppActions.callOrganizer(org.phone)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _heroImage() {
    if (hackathon.thumbnailUrl.isEmpty) {
      return Container(
        height: 220,
        color: const Color(0xFF1E293B),
        alignment: Alignment.center,
        child: const Icon(Icons.code, size: 64, color: Color(0xFF334155)),
      );
    }
    return Stack(
      children: [
        Image.network(
          hackathon.thumbnailUrl,
          height: 220,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              height: 220,
              color: const Color(0xFF1E293B),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(color: Color(0xFF10B981)),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            height: 220,
            color: const Color(0xFF1E293B),
            alignment: Alignment.center,
            child: const Icon(Icons.image_not_supported, size: 64, color: Color(0xFF334155)),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 80,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xFF0F172A)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusBadge() {
    Color bgColor;
    String text;
    if (hackathon.isEnded) {
      bgColor = const Color(0xFFEF4444);
      text = 'ENDED';
    } else if (hackathon.mode == 'online') {
      bgColor = const Color(0xFF3B82F6);
      text = 'ONLINE';
    } else if (hackathon.startDate != null &&
        hackathon.startDate!.isBefore(DateTime.now()) &&
        !hackathon.isEnded) {
      bgColor = const Color(0xFF10B981);
      text = 'LIVE NOW';
    } else {
      bgColor = const Color(0xFFF59E0B);
      text = 'UPCOMING';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _prizeCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: Color(0xFFF59E0B), size: 24),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Prize Pool', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
              Text(
                hackathon.prizePool,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _organizerCard(Organizer org) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF334155),
            child: Text(
              org.name.isNotEmpty ? org.name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Organized by',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                Text(
                  org.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactBtn(IconData icon, String label, VoidCallback? onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: onTap != null ? Colors.white : const Color(0xFF64748B),
        side: BorderSide(
          color: onTap != null ? const Color(0xFF334155) : const Color(0xFF1E293B),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _locationText() {
    final parts = [
      if (hackathon.city.isNotEmpty) hackathon.city,
      if (hackathon.state.name.isNotEmpty) hackathon.state.name,
    ];
    return parts.join(', ');
  }

  String _dateRange() {
    final fmt = (DateTime? d) => d == null ? 'TBA' : _formatDate(d);
    return '${fmt(hackathon.startDate)} — ${fmt(hackathon.endDate)}';
  }

  String _formatDate(DateTime d) => DateFormat('d MMM yyyy').format(d);

  String _modeLabel() {
    switch (hackathon.mode) {
      case 'online':
        return 'Online event';
      case 'offline':
        return 'Offline event';
      default:
        return 'Hybrid event';
    }
  }
}
