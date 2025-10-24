// lib/services/favsync.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:funkinkaraoke_singer/services/theme.dart';

/// How long a transfer code should live before Firestore TTL deletes it.
const int _kTtlDays = 30;

/// Drop-in Sync tab for the Favourites page.
/// - Top: "Generate code" -> saves a snapshot of this user's favourites + lists to /sync/{code}
/// - Bottom: Paste a code to import that snapshot into the CURRENT user (merge, no duplicates).
class FavSyncTab extends StatefulWidget {
  final String uid;
  const FavSyncTab({super.key, required this.uid});

  @override
  State<FavSyncTab> createState() => _FavSyncTabState();
}

class _FavSyncTabState extends State<FavSyncTab> {
  final _codeCtrl = TextEditingController();
  bool _working = false;
  String? _lastGenerated;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  // ---------- EXPORT (Generate code) ----------
  Future<void> _generateCodeAndUpload() async {
    if (_working) return;
    setState(() => _working = true);

    final messenger = ScaffoldMessenger.of(context);

    try {
      // 1) Collect favourites
      final favSnap = await FirebaseFirestore.instance
          .collection('users').doc(widget.uid)
          .collection('favorites').get();

      final favs = <String, Map<String, dynamic>>{};
      for (final d in favSnap.docs) {
        favs[d.id] = {
          'title': d.data()['title'],
          'artist': d.data()['artist'],
          'filename': d.data()['filename'],
        };
      }

      // 2) Collect lists + their songs
      final listsRoot = FirebaseFirestore.instance
          .collection('users').doc(widget.uid).collection('lists');

      final listsSnap = await listsRoot.get();
      final lists = <String, Map<String, dynamic>>{};
      for (final ld in listsSnap.docs) {
        final name = (ld.data()['name'] ?? 'Untitled').toString();
        final songsSnap = await ld.reference.collection('songs').get();
        final songs = <String, Map<String, dynamic>>{};
        for (final sd in songsSnap.docs) {
          songs[sd.id] = {
            'title': sd.data()['title'],
            'artist': sd.data()['artist'],
            'filename': sd.data()['filename'],
          };
        }
        lists[ld.id] = {'name': name, 'songs': songs};
      }

      // 3) Generate short code and write snapshot to /sync/{code}
      final code = await _newUniqueCode();
      final expiresAt = Timestamp.fromDate(
        DateTime.now().add(Duration(days: _kTtlDays)),
      );

      final payload = {
        'schema': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': expiresAt,            // <- TTL target field
        'ttlDays': _kTtlDays,              // (optional) for visibility/debug
        'sourceUid': widget.uid,
        'favorites': favs,
        'lists': lists,
      };

      await FirebaseFirestore.instance.collection('sync').doc(code).set(payload);

      if (!mounted) return;
      setState(() => _lastGenerated = code);
      messenger.showSnackBar(
        SnackBar(content: Text('Transfer code created: $code')),
      );
    } on FirebaseException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Sync failed: ${e.message ?? e.code}')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Sync failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  // Make a short 6-char code [A-Z0-9], ensure not in use.
  Future<String> _newUniqueCode() async {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // skip easily-confused chars
    final rnd = Random.secure();

    Future<String> one() async {
      final s = List.generate(6, (_) => alphabet[rnd.nextInt(alphabet.length)]).join();
      final exists = await FirebaseFirestore.instance.collection('sync').doc(s).get();
      if (exists.exists) return await one(); // extremely unlikely loop
      return s;
    }

    return one();
  }

  // ---------- IMPORT (Paste code) ----------
  Future<void> _importFromCode() async {
    if (_working) return;
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a code to import')),
      );
      return;
    }

    setState(() => _working = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final doc = await FirebaseFirestore.instance.collection('sync').doc(code).get();
      if (!doc.exists) {
        messenger.showSnackBar(const SnackBar(content: Text('Code not found')));
        if (mounted) setState(() => _working = false);
        return;
      }

      final data  = doc.data()!;
      final favs  = Map<String, dynamic>.from(data['favorites'] ?? {});
      final lists = Map<String, dynamic>.from(data['lists'] ?? {});

      // Batch writer (chunked)
      WriteBatch batch = FirebaseFirestore.instance.batch();
      int ops = 0;

      Future<void> commitIfNeeded() async {
        if (ops >= 450) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          ops = 0;
        }
      }

      // ----- favourites -----
      final favRoot = FirebaseFirestore.instance
          .collection('users').doc(widget.uid).collection('favorites');

      for (final entry in favs.entries) {
        final songId = entry.key;
        final m = Map<String, dynamic>.from(entry.value as Map);

        batch.set(
          favRoot.doc(songId),
          {
            'title': m['title'],
            'artist': m['artist'],
            'filename': m['filename'],
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        ops++;
        await commitIfNeeded();
      }

      // ----- lists -----
      final listsRoot = FirebaseFirestore.instance
          .collection('users').doc(widget.uid).collection('lists');

      for (final entry in lists.entries) {
        final lMap = Map<String, dynamic>.from(entry.value as Map);
        final name = (lMap['name'] ?? 'Untitled').toString();
        final newListRef = listsRoot.doc();

        batch.set(newListRef, {
          'name': name,
          'createdAt': FieldValue.serverTimestamp(),
        });
        ops++;
        await commitIfNeeded();

        final songs = Map<String, dynamic>.from(lMap['songs'] ?? {});
        for (final sEntry in songs.entries) {
          final songId = sEntry.key;
          final sm = Map<String, dynamic>.from(sEntry.value as Map);

          batch.set(
            newListRef.collection('songs').doc(songId),
            {
              'title': sm['title'],
              'artist': sm['artist'],
              'filename': sm['filename'],
              'addedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
          ops++;
          await commitIfNeeded();
        }
      }

      await batch.commit();

      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Import complete')));
    } on FirebaseException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: ${e.message ?? e.code}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ===== Export card =====
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Backup (Generate Code)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: BrandColors.deepNavy,
                    )),
                const SizedBox(height: 8),
                const Text(
                  'Create a short code that contains a snapshot of your favourites and lists.',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _working ? null : _generateCodeAndUpload,
                    child: _working
                        ? const SizedBox(
                        height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Create Transfer Code'),
                  ),
                ),
                if (_lastGenerated != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: SelectableText(
                      _lastGenerated!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        letterSpacing: 2,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('Copy this code and keep it safe.'),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ===== Import card =====
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Restore (Paste Code)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: BrandColors.deepNavy,
                    )),
                const SizedBox(height: 8),
                const Text(
                  'Paste a transfer code to copy favourites and lists into this phone.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Enter code',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: _working ? null : _importFromCode,
                    child: _working
                        ? const SizedBox(
                        height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Import'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: child,
    );
  }
}