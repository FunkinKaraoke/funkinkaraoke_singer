import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:funkinkaraoke_singer/services/theme.dart';

class MyRequestsPage extends StatefulWidget {
  const MyRequestsPage({super.key});

  @override
  State<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<MyRequestsPage> {
  String? _uid;
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
      _authReady = true;
    });
  }

  Future<void> _withdrawRequest(BuildContext context, String requestId) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw Request'),
        content: const Text('Are you sure you want to withdraw this request?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('requests').doc(requestId).delete();
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Failed to withdraw request: $e')));
      }
    }
  }

  Future<void> _withdrawAllRequests(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw All Requests'),
        content: const Text('Are you sure you want to withdraw ALL your requests?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Withdraw All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final query = await FirebaseFirestore.instance
          .collection('requests')
          .where('singerUid', isEqualTo: _uid)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      messenger.showSnackBar(const SnackBar(content: Text('All requests withdrawn')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to withdraw all: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_authReady) {
      return Scaffold(
        appBar: gradientAppBar(context, 'My Requests'),
        body: const Center(child: CircularProgressIndicator(color: BrandColors.purple)),
      );
    }
    if (_uid == null) {
      return Scaffold(
        appBar: gradientAppBar(context, 'My Requests'),
        body: const Center(child: Text('Not signed in')),
      );
    }

    return Scaffold(
      appBar: gradientAppBar(context, 'My Requests'),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('requests')
            .where('singerUid', isEqualTo: _uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: BrandColors.purple));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'You have no submitted requests.',
                style: TextStyle(color: BrandColors.deepNavy, fontWeight: FontWeight.w600),
              ),
            );
          }

          final docs = [...snapshot.data!.docs]..sort((a, b) {
            final ta = a.data()['createdAt'];
            final tb = b.data()['createdAt'];
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return (tb as Timestamp).compareTo(ta as Timestamp);
          });

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, _) => const Divider(height: 1, color: BrandColors.surface2),
            itemBuilder: (context, index) {
              final d = docs[index];
              final data = d.data();
              final artist = (data['songArtist'] ?? 'Unknown Artist').toString();
              final title = (data['songTitle'] ?? 'Unknown Title').toString();
              final singer = (data['singerName'] ?? 'Unknown').toString();
              final key = (data['keyChange'] ?? 0).toString();

              return ListTile(
                title: Text(
                  '$artist - $title',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: BrandColors.deepNavy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Requested by: $singer   Key: $key',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: BrandColors.onLight.withValues(alpha: 0.8),
                  ),
                ),
                trailing: TextButton(
                  onPressed: () => _withdrawRequest(context, d.id),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Withdraw'),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _withdrawAllRequests(context),
              child: const Text('Withdraw All Requests'),
            ),
          ),
        ),
      ),
    );
  }
}