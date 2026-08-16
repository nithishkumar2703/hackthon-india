import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/hackathon.dart';

class HackathonCard extends StatelessWidget {
  final Hackathon hackathon;
  final VoidCallback? onTap;

  const HackathonCard({super.key, required this.hackathon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF334155), width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heroSection(),
            _infoSection(),
          ],
        ),
      ),
    );
  }

  Widget _heroSection() {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        if (hackathon.thumbnailUrl.isNotEmpty)
          Image.network(
            hackathon.thumbnailUrl,
            height: 110,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholderImage(),
          )
        else
          _placeholderImage(),
        Container(
          height: 110,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xFF1E293B)],
              stops: [0.3, 1.0],
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: _statusBadge(),
        ),
        Positioned(
          bottom: 8,
          left: 10,
          right: 10,
          child: Text(
            hackathon.title.toUpperCase(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholderImage() {
    final colors = [
      [const Color(0xFF1a1a4e), const Color(0xFF0d0d2b)],
      [const Color(0xFF1a3a2e), const Color(0xFF0d1f17)],
      [const Color(0xFF2e1a3a), const Color(0xFF1a0d22)],
      [const Color(0xFF3a2a1a), const Color(0xFF221a0d)],
    ];
    final pair = colors[hackathon.id % colors.length];
    return Container(
      height: 110,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: pair),
      ),
      child: const Center(
        child: Icon(Icons.code, color: Colors.white24, size: 40),
      ),
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
      text = 'LIVE';
    } else {
      bgColor = const Color(0xFFF59E0B);
      text = 'UPCOMING';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _infoSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hackathon.organizer != null) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: const Color(0xFF334155),
                  child: Text(
                    hackathon.organizer!.name.isNotEmpty
                        ? hackathon.organizer!.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hackathon.organizer!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          if (_locationText().isNotEmpty)
            _metaRow(Icons.location_on_outlined, _locationText()),
          const SizedBox(height: 3),
          _metaRow(Icons.calendar_today_outlined, _dateRange()),
          if (hackathon.prizePool.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.emoji_events_outlined, size: 12, color: Color(0xFFF59E0B)),
                const SizedBox(width: 4),
                Text(
                  'Prize pool',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                ),
                const Spacer(),
                Text(
                  hackathon.prizePool,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
          if (hackathon.deadline != null) ...[
            const SizedBox(height: 4),
            _countdownRow(),
          ],
        ],
      ),
    );
  }

  Widget _metaRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 11, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
          ),
        ),
      ],
    );
  }

  Widget _countdownRow() {
    final now = DateTime.now();
    final diff = hackathon.deadline!.difference(now);
    String label;
    if (diff.isNegative) {
      label = 'Registration closed';
    } else if (diff.inDays > 0) {
      label = 'Registration ends in ${diff.inDays} days';
    } else if (diff.inHours > 0) {
      label = 'Ends in ${diff.inHours} hours';
    } else {
      label = 'Ends soon';
    }
    return Row(
      children: [
        const Icon(Icons.schedule_outlined, size: 11, color: Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: diff.isNegative ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _locationText() {
    if (hackathon.mode == 'online') return 'Online';
    final parts = [
      if (hackathon.city.isNotEmpty) hackathon.city,
      if (hackathon.state.name.isNotEmpty) hackathon.state.name,
    ];
    return parts.join(', ');
  }

  String _dateRange() {
    final fmt = (DateTime? d) {
      if (d == null) return 'TBA';
      return DateFormat('MMM d, yyyy').format(d);
    };
    final start = fmt(hackathon.startDate);
    final end = fmt(hackathon.endDate);
    return '$start - $end';
  }
}
