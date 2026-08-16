import 'package:flutter/material.dart';

import '../data/hackathon_repo.dart';
import '../models/indian_state.dart';
import 'hackathon_list_screen.dart';

/// Screen 1: pick an Indian state to see its hackathons.
class StateListScreen extends StatefulWidget {
  const StateListScreen({super.key});

  @override
  State<StateListScreen> createState() => _StateListScreenState();
}

class _StateListScreenState extends State<StateListScreen> {
  final _repo = HackathonRepo();
  late Future<List<IndianState>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.fetchStates();
  }

  void _openState(IndianState state) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HackathonListScreen(state: state),
      ),
    );
  }

  void _openOnline() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HackathonListScreen(
          mode: HackathonListMode.online,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your state')),
      body: FutureBuilder<List<IndianState>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(
              message: 'Could not load states.\n${snapshot.error}',
              onRetry: () => setState(() => _future = _repo.fetchStates()),
            );
          }
          final states = snapshot.data ?? [];
          return ListView.separated(
            itemCount: states.length + 1,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  leading: const Icon(Icons.language, color: Colors.teal),
                  title: const Text(
                    'Online hackathons',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Anywhere in India'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openOnline,
                );
              }
              final s = states[index - 1];
              return ListTile(
                leading: const Icon(Icons.location_city),
                title: Text(s.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openState(s),
              );
            },
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
