import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:funkinkaraoke_singer/models/song.dart';
import 'package:funkinkaraoke_singer/services/theme.dart';
import 'package:funkinkaraoke_singer/services/listmaker.dart'; // <-- NEW
import 'package:funkinkaraoke_singer/services/favsync.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  String _sortMode = 'recent';
  String? _uid; // nullable until auth ready
  bool _authReady = false;

  @override
  void initState() {
    super.initState();
    _ensureAuth();
  }

  Future<void> _ensureAuth() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        user = (await FirebaseAuth.instance.signInAnonymously()).user;
      } catch (_) {}
    }
    if (!mounted) return;

    setState(() {
      _uid = user?.uid;
      _authReady = user != null;
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _favoritesStream() {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('favorites');
    return _sortMode == 'alphabetical'
        ? ref.orderBy('title').snapshots()
        : ref.orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> _removeFavorite(String songId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('favorites')
        .doc(songId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    if (!_authReady) {
      return Scaffold(
        appBar: gradientAppBar(context, 'Favourites'),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: BrandColors.purple),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _ensureAuth,
                child: const Text('Retry sign-in'),
              ),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: gradientAppBar(
          context,
          'Favourites',
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'All Songs'),
              Tab(text: 'Lists'),
              Tab(text: 'Sync'),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) => setState(() => _sortMode = value),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'alphabetical', child: Text('Alphabetical')),
                PopupMenuItem(value: 'recent', child: Text('Recent')),
              ],
              icon: const Icon(Icons.sort),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // 1) All Songs
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _favoritesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: BrandColors.purple),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No favourites yet.',
                      style: TextStyle(
                        color: BrandColors.deepNavy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: BrandColors.surface2),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final song = Song.fromDoc(docs[index].id, data);

                    return ListTile(
                      title: Text(
                        song.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: BrandColors.deepNavy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        song.artist,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: BrandColors.onLight.withValues(alpha: 0.8),
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'remove') {
                            await _removeFavorite(docs[index].id);
                          } else if (value == 'list') {
                            // Show "Add to List" dialog
                            await ListMaker.showAddSongToListDialog(
                              context: context,
                              uid: _uid!,
                              songId: docs[index].id,
                              songData: {
                                'title': song.title,
                                'artist': song.artist,
                                'filename': (data['filename']),
                              },
                            );
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'remove', child: Text('Remove')),
                          PopupMenuItem(value: 'list', child: Text('Add to List')),
                        ],
                      ),
                      onTap: () =>
                          Navigator.pushNamed(context, '/request', arguments: song),
                    );
                  },
                );
              },
            ),

            // 2) Lists tab
            _ListsTab(uid: _uid!),

            // 3) Sync tab (placeholder)
            FavSyncTab(uid: _uid!),
          ],
        ),
      ),
    );
  }
}

/// Lists tab body with a small "+" button to create new lists.
class _ListsTab extends StatelessWidget {
  final String uid;
  const _ListsTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    final listsQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('lists')
        .orderBy('createdAt', descending: true);

    return Column(
      children: [
        // Header + create button
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'YOUR LISTS',
                  style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                    color: BrandColors.deepNavy, // visible on white background
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Create New List',
                icon: const Icon(Icons.add),
                onPressed: () => ListMaker.showCreateDialog(context: context, uid: uid),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Lists
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: listsQuery.snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? const [];
              if (docs.isEmpty) {
                return const Center(child: Text('No lists yet. Tap + to create one.'));
              }

              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final d = docs[i];
                  final name = (d.data()['name'] ?? 'Untitled').toString();

                  return ListTile(
                    title: Text(name),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'delete') {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete list?'),
                              content: const Text(
                                "Are you sure you want to delete this list?\n\n"
                                    "Note: this does not remove songs from your favourites.",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton.tonal(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          ) ??
                              false;

                          if (!ok) return;

                          // Delete list and its songs
                          final base = d.reference;
                          final songsSnap = await base.collection('songs').get();
                          final batch = FirebaseFirestore.instance.batch();
                          for (final s in songsSnap.docs) {
                            batch.delete(s.reference);
                          }
                          batch.delete(base);
                          await batch.commit();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ListDetailPage(
                            uid: uid,
                            listId: d.id,
                            listName: name,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class ListDetailPage extends StatelessWidget {
  final String uid;
  final String listId;
  final String listName;

  const ListDetailPage({
    super.key,
    required this.uid,
    required this.listId,
    required this.listName,
  });

  @override
  Widget build(BuildContext context) {
    final songsCol = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('lists')
        .doc(listId)
        .collection('songs')
        .orderBy('addedAt', descending: true);

    return Scaffold(
        appBar: gradientAppBar(context, listName),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: songsCol.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: BrandColors.purple));
          }
          final docs = snap.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'This list is empty.',
                style: TextStyle(
                  color: BrandColors.deepNavy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, _) => const Divider(height: 1, color: BrandColors.surface2),
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data();

              // Reconstruct a Song-like object for submission
              final song = Song.fromDoc(
                d.id,
                {
                  'title': data['title'] ?? '',
                  'artist': data['artist'] ?? '',
                  'filename': data['filename'],
                },
              );

              return ListTile(
                title: Text(
                  song.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: BrandColors.deepNavy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  song.artist,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: BrandColors.onLight.withValues(alpha: 0.8),
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'remove') {
                      // Remove from this list (no confirm)
                      await d.reference.delete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'remove', child: Text('Remove')),
                  ],
                ),
                // Submit just like elsewhere: tap row to go to RequestPage
                onTap: () => Navigator.pushNamed(context, '/request', arguments: song),
              );
            },
          );
        },
      ),
    );
  }
}