import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/hackathon_repo.dart';
import '../models/hackathon.dart';
import '../widgets/hackathon_card.dart';
import 'hackathon_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  String _selectedFilter = 'ALL INDIA';
  List<Hackathon> _all = [];
  List<Hackathon> _filtered = [];
  List<String> _suggestions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final hackathons = await HackathonRepo().fetchAllHackathons();
      setState(() {
        _all = hackathons;
        _loading = false;
      });
      _applyFilter();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool _showSuggestions() =>
      _searchFocus.hasFocus && _searchCtrl.text.trim().isNotEmpty;

  void _applyFilter() {
    final q = _query.toLowerCase();
    List<Hackathon> result = _all.where((h) {
      if (q.isNotEmpty) {
        final haystack =
            '${h.title} ${h.description} ${h.city} ${h.state.name} ${h.organizer?.name ?? ''}'
                .toLowerCase();
        if (!haystack.contains(q)) return false;
      }
      switch (_selectedFilter) {
        case 'ALL INDIA':
          return true;
        case 'ONLINE':
          return h.mode == 'online';
        case 'UPCOMING':
          return !h.isEnded;
        default:
          return h.state.name.toUpperCase() == _selectedFilter;
      }
    }).toList();

    setState(() => _filtered = result);
  }

  void _refreshSuggestions() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    final out = <String>[];
    final seen = <String>{};

    void add(String s) {
      if (seen.add(s)) out.add(s);
    }

    final states = <String>{};
    for (final h in _all) {
      if (h.state.name.isNotEmpty) states.add(h.state.name);
    }
    final stateList = states.toList()..sort();

    // States that start with the typed text come first (Google-style).
    for (final s in stateList) {
      if (s.toLowerCase().startsWith(q)) add(s);
    }
    for (final s in stateList) {
      if (s.toLowerCase().contains(q) && !s.toLowerCase().startsWith(q)) add(s);
    }
    if ('Online hackathons'.toLowerCase().contains(q)) add('Online hackathons');

    // Hackathon titles + cities that match.
    for (final h in _all) {
      if (out.length >= 8) break;
      if (h.title.toLowerCase().contains(q)) add(h.title);
      if (out.length < 8 && h.city.isNotEmpty && h.city.toLowerCase().contains(q)) {
        add(h.city);
      }
    }
    setState(() => _suggestions = out.take(8).toList());
  }

  bool _isStateSuggestion(String s) =>
      _all.any((h) => h.state.name == s);

  void _selectSuggestion(String s) {
    if (s == 'Online hackathons') {
      setState(() {
        _selectedFilter = 'ONLINE';
        _query = '';
        _searchCtrl.clear();
        _suggestions = [];
      });
    } else if (_isStateSuggestion(s)) {
      setState(() {
        _selectedFilter = s.toUpperCase();
        _query = '';
        _searchCtrl.clear();
        _suggestions = [];
      });
    } else {
      setState(() {
        _query = s;
        _searchCtrl.text = s;
        _searchCtrl.selection = TextSelection.collapsed(offset: s.length);
        _suggestions = [];
      });
    }
    _searchFocus.unfocus();
    _applyFilter();
  }

  List<String> _buildFilters(List<Hackathon> all) {
    final states = <String>{};
    for (final h in all) {
      if (h.state.name.isNotEmpty) states.add(h.state.name.toUpperCase());
    }
    final sorted = states.toList()..sort();
    return ['ALL INDIA', ...sorted, 'ONLINE', 'UPCOMING'];
  }

  @override
  Widget build(BuildContext context) {
    final filters = _buildFilters(_all);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                _buildFilterRow(filters),
                Expanded(child: _buildBody()),
              ],
            ),
            if (_showSuggestions())
              Positioned(
                top: 58,
                left: 14,
                right: 14,
                child: _suggestionPanel(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/logo.svg',
            height: 34,
            placeholderBuilder: (_) => const SizedBox(
              width: 34,
              height: 34,
              child: Icon(Icons.psychology, color: Color(0xFF10B981), size: 26),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'HACKATHON\nINDIA',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: (v) {
                _query = v;
                _refreshSuggestions();
                _applyFilter();
              },
              onSubmitted: (v) {
                final q = v.trim();
                if (q.isNotEmpty && _isStateSuggestion(_fullStateName(q))) {
                  _selectSuggestion(_fullStateName(q));
                }
              },
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search events, tech stacks, or cities...',
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _postButton(),
        ],
      ),
    );
  }

  String _fullStateName(String typed) {
    for (final h in _all) {
      if (h.state.name.toLowerCase() == typed.toLowerCase()) return h.state.name;
    }
    return typed;
  }

  Widget _suggestionPanel() {
    return Material(
      color: const Color(0xFF1E293B),
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Text(
                'SUGGESTIONS',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (context, i) {
                  final s = _suggestions[i];
                  final isState = _isStateSuggestion(s);
                  final isOnline = s == 'Online hackathons';
                  final icon = isState
                      ? Icons.map_outlined
                      : isOnline
                          ? Icons.language
                          : Icons.search;
                  return InkWell(
                    onTap: () => _selectSuggestion(s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Icon(icon, size: 16, color: const Color(0xFF10B981)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _postButton() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF10B981), width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Coming soon! You will be able to post hackathons here.')),
            );
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              'Post a\nHackathon',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF10B981),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow(List<String> filters) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = filters[i];
          final selected = f == _selectedFilter;
          return ChoiceChip(
            label: Text(f),
            selected: selected,
            onSelected: (_) {
              setState(() {
                _selectedFilter = f;
                _searchCtrl.clear();
                _query = '';
              });
              _applyFilter();
            },
            selectedColor: f == 'ALL INDIA' || f == 'ONLINE' || f == 'UPCOMING'
                ? const Color(0xFF10B981)
                : const Color(0xFF7C3AED),
            backgroundColor: const Color(0xFF1E293B),
            side: selected
                ? null
                : const BorderSide(color: Color(0xFF334155)),
            labelStyle: TextStyle(
              color: selected ? Colors.white : const Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_filtered.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, color: Color(0xFF64748B), size: 48),
            SizedBox(height: 12),
            Text('No hackathons found', style: TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF10B981),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossCount = constraints.maxWidth > 900
              ? 4
              : constraints.maxWidth > 600
                  ? 3
                  : 2;
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossCount,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.68,
            ),
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final h = _filtered[i];
              return HackathonCard(
                hackathon: h,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HackathonDetailScreen(hackathon: h),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
