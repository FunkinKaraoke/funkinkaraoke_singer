import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:funkinkaraoke_singer/models/song.dart';
import 'package:funkinkaraoke_singer/services/theme.dart';

class SongSearchPage extends StatefulWidget {
  const SongSearchPage({super.key});

  @override
  State<SongSearchPage> createState() => _SongSearchPageState();
}

class _SongSearchPageState extends State<SongSearchPage> {
  final TextEditingController _controller = TextEditingController();

  String _query = '';
  List<Song> _results = [];
  bool _loading = false;
  String? _error;

  late String _uid;
  bool _authReady = false;

  final Set<String> _favIds = <String>{};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _favSub;

  @override
  void initState() {
    super.initState();
    _ensureAuthAndSubscribe();
  }

  Future<void> _ensureAuthAndSubscribe() async {
    // Ensure we have a user (handles iOS keychain hiccups gracefully)
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        user = (await FirebaseAuth.instance.signInAnonymously()).user;
      } catch (_) {
        // ignore; we'll just not crash and can show a spinner instead
      }
    }
    if (!mounted) return;

    if (user == null) {
      setState(() => _authReady = false);
      return;
    }

    _uid = user.uid;
    setState(() => _authReady = true);

    // Live-sync favorites -> _favIds
    _favSub?.cancel();
    _favSub = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('favorites')
        .snapshots()
        .listen((snap) {
      final next = <String>{ for (final d in snap.docs) d.id };
      if (!mounted) return;
      setState(() {
        _favIds
          ..clear()
          ..addAll(next);
      });
    });
  }

  @override
  void dispose() {
    _favSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final col = FirebaseFirestore.instance.collection('songs');

      // Split user input into tokens
      final tokens = q
          .split(RegExp(r'\s+'))
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      if (tokens.isEmpty) {
        setState(() {
          _results = [];
          _loading = false;
        });
        return;
      }

      // Query by the first token
      final snap = await col
          .where('searchTokens', arrayContains: tokens.first)
          .limit(250)
          .get();

      // Filter locally: song must contain ALL tokens
      final byId = <String, Song>{};
      for (final d in snap.docs) {
        final data = d.data();
        final song = Song.fromDoc(d.id, data);
        final songTokens = List<String>.from(data['searchTokens'] ?? []);
        final matchesAll = tokens.every((t) => songTokens.contains(t));
        if (matchesAll) {
          byId[d.id] = song;
        }
      }

      setState(() {
        _results = byId.values.toList(growable: false);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Search failed: $e';
      });
    }
  }

  Future<void> _toggleFavorite(Song song) async {
    final messenger = ScaffoldMessenger.of(context); // capture before awaits

    final favRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('favorites')
        .doc(song.id);

    final isFav = _favIds.contains(song.id);
    try {
      if (isFav) {
        await favRef.delete();
      } else {
        // Pull canonical fields (incl. filename) from the songs doc
        final doc = await FirebaseFirestore.instance
            .collection('songs')
            .doc(song.id)
            .get();
        final data = doc.data() ?? {};

        await favRef.set({
          'title': data['title'] ?? song.title,
          'artist': data['artist'] ?? song.artist,
          'filename': data['filename'],
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      // use captured messenger, not context
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update favourites: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_authReady) {
      return Scaffold(
        appBar: gradientAppBar(context, 'Submit A Song'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: gradientAppBar(context, 'Submit A Song'),
      body: Column(
        children: [
          // Search bar + button row
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (value) {
                      setState(() => _query = value);
                      _performSearch();
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by Artist or Song',
                      hintStyle: const TextStyle(
                        color: BrandColors.deepNavy,
                        fontWeight: FontWeight.w600,
                      ),
                      prefixIcon:
                      const Icon(Icons.search, color: BrandColors.deepNavy),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide:
                        BorderSide(color: BrandColors.purple, width: 2),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                        icon: const Icon(Icons.clear,
                            color: BrandColors.deepNavy),
                        onPressed: () {
                          _controller.clear();
                          setState(() {
                            _query = '';
                            _results = [];
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    setState(() => _query = _controller.text);
                    _performSearch();
                  },
                  child: const Text('Search'),
                ),
              ],
            ),
          ),

          // Results section
          Expanded(
            child: Builder(
              builder: (context) {
                if (_loading) {
                  return const Center(
                    child:
                    CircularProgressIndicator(color: BrandColors.purple),
                  );
                }
                if (_error != null) {
                  return Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }
                if (_results.isEmpty) {
                  return const Center(
                    child: Text(
                      'No results yet. Try searching!',
                      style: TextStyle(
                        color: BrandColors.deepNavy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    color: BrandColors.surface2,
                  ),
                  itemBuilder: (context, index) {
                    final song = _results[index];
                    final isFav = _favIds.contains(song.id);

                    return ListTile(
                      title: Text(
                        song.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                          color: BrandColors.deepNavy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        song.artist,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                          color:
                          BrandColors.onLight.withValues(alpha: 0.8),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: isFav ? 'Remove from favourites' : 'Add to favourites',
                            icon: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              color: isFav
                                  ? BrandColors.warmPurple
                                  : BrandColors.deepNavy.withValues(alpha: 0.7),
                            ),
                            onPressed: () => _toggleFavorite(song),
                          ),
                          const Icon(Icons.chevron_right,
                              color: BrandColors.purple),
                        ],
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, '/request',
                            arguments: song);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}