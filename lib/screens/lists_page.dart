import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:funkinkaraoke_singer/models/song.dart';
import 'package:funkinkaraoke_singer/services/theme.dart';

class ListsPage extends StatelessWidget {
  const ListsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: gradientAppBar(context, 'Popular Songs'),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('songs').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: BrandColors.purple),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No lists available.'));
          }

          // Collect unique list names
          final allLists = <String>{};
          for (final doc in snapshot.data!.docs) {
            final lists = List<String>.from(doc.data()['lists'] ?? []);
            allLists.addAll(lists);
          }

          if (allLists.isEmpty) {
            return const Center(child: Text('No lists found.'));
          }

          final listNames = allLists.toList()..sort();

          return ListView.separated(
            key: const PageStorageKey('lists_root'),
            itemCount: listNames.length,
            separatorBuilder: (_, _) =>
            const Divider(height: 1, color: BrandColors.surface2),
            itemBuilder: (context, index) {
              final name = listNames[index];
              return ListTile(
                key: ValueKey('list_$name'),
                title: Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: BrandColors.deepNavy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing:
                const Icon(Icons.chevron_right, color: BrandColors.purple),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ListSongsPage(listName: name),
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

class ListSongsPage extends StatelessWidget {
  final String listName;
  const ListSongsPage({super.key, required this.listName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: gradientAppBar(context, listName),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('songs')
            .where('lists', arrayContains: listName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: BrandColors.purple),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No songs in $listName.'));
          }

          final songs = snapshot.data!.docs
              .map((d) => Song.fromDoc(d.id, d.data()))
              .toList();

          return ListView.separated(
            key: PageStorageKey('listSongs_$listName'),
            itemCount: songs.length,
            separatorBuilder: (_, _) =>
            const Divider(height: 1, color: BrandColors.surface2),
            itemBuilder: (context, index) {
              final song = songs[index];

              return ListTile(
                key: ValueKey(song.id),
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
                trailing: _FavButton(songId: song.id, fallbackSong: song),
                onTap: () =>
                    Navigator.pushNamed(context, '/request', arguments: song),
              );
            },
          );
        },
      ),
    );
  }
}

class _FavButton extends StatelessWidget {
  final String songId;
  final Song fallbackSong;
  const _FavButton({required this.songId, required this.fallbackSong});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    // If not signed in yet, show disabled outline heart
    if (uid == null) {
      return const Icon(Icons.favorite_border, color: BrandColors.purple);
    }

    final favDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(songId);

    // Only listen to THIS favourite doc to avoid rebuilding the whole list.
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: favDoc.snapshots(),
      builder: (context, snap) {
        final isFav = snap.hasData && snap.data!.exists;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: IconButton(
            key: ValueKey(isFav),
            tooltip: isFav ? 'Remove from favourites' : 'Add to favourites',
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? BrandColors.warmPurple : BrandColors.purple,
            ),
            onPressed: () async {
              // ✅ capture context-bound stuff up front
              final messenger = ScaffoldMessenger.of(context);

              try {
                if (isFav) {
                  await favDoc.delete();
                } else {
                  final fs = FirebaseFirestore.instance;
                  final songSnap = await fs.collection('songs').doc(songId).get();
                  final data = songSnap.data() ?? {};

                  await favDoc.set({
                    'title': data['title'] ?? fallbackSong.title,
                    'artist': data['artist'] ?? fallbackSong.artist,
                    'filename': data['filename'],
                    'createdAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                }
              } catch (e) {
                // ✅ only use the captured messenger after awaits
                // If this code is inside a State, keep a safety guard:
                if (context.mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to update favourites: $e')),
                  );
                }
              }
            },
          ),
        );
      },
    );
  }
}