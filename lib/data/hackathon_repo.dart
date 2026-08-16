import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/hackathon.dart';
import '../models/indian_state.dart';

/// All database calls go through here.
class HackathonRepo {
  final SupabaseClient _client = Supabase.instance.client;

  /// Fetch all Indian states, alphabetically.
  Future<List<IndianState>> fetchStates() async {
    final rows = await _client.from('states').select('id, name').order('name');
    return rows.map((r) => IndianState.fromJson(r)).toList();
  }

  /// Fetch all hackathons for one state (ended ones included, so the UI
  /// can mark them in red). Upcoming ones come first.
  Future<List<Hackathon>> fetchHackathonsByState(int stateId) async {
    final rows = await _client
        .from('hackathons')
        .select('*, states(name), organizers(*)')
        .eq('state_id', stateId)
        .eq('is_active', true)
        .order('start_date');

    return rows.map((r) => Hackathon.fromJson(r)).toList();
  }

  /// Fetch online hackathons (for the "Online" list in the state screen).
  Future<List<Hackathon>> fetchOnlineHackathons() async {
    final rows = await _client
        .from('hackathons')
        .select('*, states(name), organizers(*)')
        .eq('mode', 'online')
        .eq('is_active', true)
        .order('start_date');

    return rows.map((r) => Hackathon.fromJson(r)).toList();
  }

  /// Fetch one hackathon's full details (used by the detail screen).
  Future<Hackathon> fetchHackathonById(int id) async {
    final rows = await _client
        .from('hackathons')
        .select('*, states(name), organizers(*)')
        .eq('id', id);

    if (rows.isEmpty) throw Exception('Hackathon not found');
    return Hackathon.fromJson(rows.first);
  }

  /// Fetch all active hackathons (for the explore screen grid).
  Future<List<Hackathon>> fetchAllHackathons() async {
    final rows = await _client
        .from('hackathons')
        .select('*, states(name), organizers(*)')
        .eq('is_active', true)
        .order('start_date', ascending: true);

    return rows.map((r) => Hackathon.fromJson(r)).toList();
  }
}
