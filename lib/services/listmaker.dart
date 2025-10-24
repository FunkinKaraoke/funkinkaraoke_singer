// lib/services/listmaker.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:funkinkaraoke_singer/services/theme.dart'; // BrandGradients/BrandColors

class ListMaker {
  /// Create a new list under /users/{uid}/lists.
  /// If [songId] and [songData] are provided, the song will be added to the new list right after creation.
  static Future<void> showCreateDialog({
    required BuildContext context,
    required String uid,
    String? songId,
    Map<String, dynamic>? songData, // title/artist/filename...
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateListDialog(
        uid: uid,
        songId: songId,
        songData: songData,
      ),
    );
  }

  /// Pick a list and add a song into that list's /songs subcollection
  static Future<void> showAddSongToListDialog({
    required BuildContext context,
    required String uid,
    required String songId,
    required Map<String, dynamic> songData, // title/artist/filename...
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _AddToListDialog(
        uid: uid,
        songId: songId,
        songData: songData,
      ),
    );
  }
}

/// ---------- Create List Dialog ----------
class _CreateListDialog extends StatefulWidget {
  final String uid;
  final String? songId;
  final Map<String, dynamic>? songData;

  const _CreateListDialog({
    required this.uid,
    this.songId,
    this.songData,
  });

  @override
  State<_CreateListDialog> createState() => _CreateListDialogState();
}

class _CreateListDialogState extends State<_CreateListDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);

    try {
      final listsCol = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('lists');

      // 1) Create list
      final newListRef = await listsCol.add({
        'name': _nameCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2) If a song was provided, add it to this new list
      if (widget.songId != null && widget.songData != null) {
        final itemRef = newListRef.collection('songs').doc(widget.songId);
        await itemRef.set({
          'title': widget.songData!['title'],
          'artist': widget.songData!['artist'],
          'filename': widget.songData!['filename'],
          'addedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      nav.pop(); // close dialog
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            (widget.songId != null && widget.songData != null)
                ? 'List created & song added'
                : 'List created',
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Create failed: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Create failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradients = Theme.of(context).extension<BrandGradients>()!;
    final titleStyle = Theme.of(context).appBarTheme.titleTextStyle;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      title: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          gradient: gradients.dialogBar,
        ),
        alignment: Alignment.center,
        child: Text('CREATE NEW LIST', style: titleStyle),
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Enter list name',
            hintText: 'e.g. Party Bangers',
            border: OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: BrandColors.purple, width: 2),
            ),
          ),
          validator: (v) {
            final t = v?.trim() ?? '';
            if (t.isEmpty) return 'Please enter a name';
            if (t.length > 60) return 'Keep it under 60 characters';
            return null;
          },
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: BrandColors.warmPurple,
            foregroundColor: Colors.white,
          ),
          child: _saving
              ? const SizedBox(
              height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create'),
        ),
      ],
    );
  }
}

/// ---------- Add to List Dialog ----------
class _AddToListDialog extends StatelessWidget {
  final String uid;
  final String songId;
  final Map<String, dynamic> songData;
  const _AddToListDialog({
    required this.uid,
    required this.songId,
    required this.songData,
  });

  Future<void> _addToList(BuildContext context, String listId) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final itemRef = FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('lists').doc(listId)
          .collection('songs').doc(songId);

      await itemRef.set({
        'title': songData['title'],
        'artist': songData['artist'],
        'filename': songData['filename'],
        'addedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      nav.pop(); // close dialog
      messenger.showSnackBar(const SnackBar(content: Text('Added to list')));
    } on FirebaseException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Add failed: ${e.message ?? e.code}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Add failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradients = Theme.of(context).extension<BrandGradients>()!;
    final titleStyle = Theme.of(context).appBarTheme.titleTextStyle;

    final listsQuery = FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('lists')
        .orderBy('createdAt', descending: true);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      title: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          gradient: gradients.dialogBar,
        ),
        alignment: Alignment.center,
        child: Text('ADD TO LIST', style: titleStyle),
      ),
      content: SizedBox(
        width: 420,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: listsQuery.snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: LinearProgressIndicator(color: BrandColors.purple),
              );
            }
            final docs = snap.data?.docs ?? const [];
            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Create lists to add songs.', style: TextStyle(fontWeight: FontWeight.w600)),
              );
            }

            return SizedBox(
              height: 260,
              child: ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, _) => const Divider(height: 1, color: BrandColors.surface2),
                itemBuilder: (context, i) {
                  final d = docs[i];
                  final name = (d.data()['name'] ?? 'Untitled').toString();
                  return ListTile(
                    title: Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: BrandColors.deepNavy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    trailing: const Icon(Icons.add, color: BrandColors.purple),
                    onTap: () => _addToList(context, d.id),
                  );
                },
              ),
            );
          },
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () {
            // Open Create dialog *with song context* so it also adds the song.
            Navigator.of(context).pop();
            ListMaker.showCreateDialog(
              context: context,
              uid: uid,
              songId: songId,
              songData: songData,
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: BrandColors.warmPurple,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.add),
          label: const Text('New List'),
        ),
      ],
    );
  }
}