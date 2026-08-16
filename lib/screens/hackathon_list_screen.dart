import 'package:flutter/material.dart';

import '../data/hackathon_repo.dart';
import '../models/hackathon.dart';
import '../models/indian_state.dart';
import 'hackathon_detail_screen.dart';

/// What the list screen should show.
enum HackathonListMode { state, online }

/// Screen 2: scrollable list of hackathons for the chosen state (or online).
class HackathonListScreen extends StatefulWidget {
  final IndianState? state;
  final HackathonListMode? mode;

  const HackathonListScreen({super.key, this.state, this.mode});

  @override
  State<HackathonListScreen> createState() => _HackathonListScreenState();
}

class _HackathonListScreenState extends State<HackathonListScreen> {
  final _repo = HackathonRepo();
  late Future<List<Hackathon>> _future;

  bool get _isOnline => widget.mode == HackathonListMode.online;

  String get _title => _isOnline ? 'Online hackathons' : 'Hackathons in ${widget.state!.name}';

  Future<List<Hackathon>> _load() {
    return _isOnline
        ? _repo.fetchOnlineHackathons()
        : _repo.fetchHackathonsByState(widget.state!.id);
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: FutureBuilder<List<Hackathon>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 48),
                    const SizedBox(height: 12),
                    Text('Could not load hackathons.\n${snapshot.error}',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          setState(() => _future = _load()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final hackathons = snapshot.data ?? [];
          if (hackathons.isEmpty) {
            return const Center(
              child: Text('No upcoming hackathons in this state yet.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: hackathons.length,
            itemBuilder: (context, index) =>
                HackathonCard(hackathon: hackathons[index]),
          );
        },
      ),
    );
  }
}

/// A single hackathon card with thumbnail and key info.
class HackathonCard extends StatelessWidget {
  final Hackathon hackathon;

  const HackathonCard({super.key, required this.hackathon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HackathonDetailScreen(hackathon: hackathon),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _Thumbnail(url: hackathon.thumbnailUrl),
                if (hackathon.isEnded)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'ENDED',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hackathon.title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.place, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _locationLabel(hackathon),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.event,
                          size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(_dateRange(hackathon), style: theme.textTheme.bodySmall),
                      const Spacer(),
                      if (hackathon.prizePool.isNotEmpty)
                        Text(hackathon.prizePool,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _locationLabel(Hackathon h) {
    final parts = [
      if (h.city.isNotEmpty) h.city,
      if (h.state.name.isNotEmpty) h.state.name,
    ];
    final place = parts.join(', ');
    return place.isNotEmpty ? '$place · ${_modeLabel(h.mode)}' : _modeLabel(h.mode);
  }

  String _modeLabel(String mode) {
    switch (mode) {
      case 'online':
        return 'Online';
      case 'offline':
        return 'Offline';
      default:
        return 'Hybrid';
    }
  }

  String _dateRange(Hackathon h) {
    final fmt = (DateTime? d) =>
        d == null ? 'TBA' : '${d.day}/${d.month}/${d.year}';
    return '${fmt(h.startDate)} - ${fmt(h.endDate)}';
  }
}

class _Thumbnail extends StatelessWidget {
  final String url;

  const _Thumbnail({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        height: 150,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: const Icon(Icons.code, size: 48),
      );
    }
    return Image.network(
      url,
      height: 150,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          height: 150,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(),
        );
      },
      errorBuilder: (context, error, stack) => Container(
        height: 150,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported, size: 48),
      ),
    );
  }
}
