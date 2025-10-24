import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:funkinkaraoke_singer/models/song.dart';
import 'package:funkinkaraoke_singer/services/theme.dart'; // for gradientAppBar(context, ...)
import 'package:shared_preferences/shared_preferences.dart';
import 'package:funkinkaraoke_singer/services/venue_scope.dart';

class RequestPage extends StatefulWidget {
  final Song song;
  const RequestPage({super.key, required this.song});

  @override
  State<RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends State<RequestPage> {
  final TextEditingController _nameController = TextEditingController();
  int _keyChange = 0;

  late ConfettiController _confettiController;

  Future<void> _loadSavedName() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString('lastSingerName');
    if (!mounted) return;
    if (last != null && last.trim().isNotEmpty) {
      _nameController.text = last;
    }
  }

  Future<void> _saveName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastSingerName', name.trim());
  }

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(milliseconds: 1000),
    );
    _loadSavedName(); // ← auto-fill last used singer name
  }

  @override
  void dispose() {
    _nameController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  String _formatKey(int v) => v > 0 ? '+$v' : v.toString();

  Widget _detailRow(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 16),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
// ADD inside _RequestPageState (below fields/methods is fine)
  Future<bool> _requestsAreOpen(String venueCode) async {
    try {
      final snap = await FirebaseFirestore.instance
          .doc('venues/$venueCode/state/config')
          .get();
      return (snap.data()?['requestsOpen'] == true);
    } catch (_) {
      // If we can't read it, be safe & treat as closed
      return false;
    }
  }

  Future<void> _submit() async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Please enter your name')));
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Not signed in. Please restart the app.')));
      return;
    }

    // Show blocking spinner (use local context then avoid it afterward)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    Future<void> showError(String msg) async {
      if (nav.canPop()) nav.pop(); // close spinner
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }

    try {
      // 🔑 Fetch the active venue code (set by the host app)
      // 🔑 Use the venue selected locally by the singer on the HomeScreen
      final venueCode = VenueScope.of(context).code;
      if (venueCode == null || venueCode.isEmpty) {
        await showError('Please select a venue on the home screen first.');
        return;
      }

      // AFTER you compute `venueCode` and validate it's non-empty, INSERT this:
      final isOpen = await _requestsAreOpen(venueCode);
      if (!isOpen) {
        if (nav.canPop()) nav.pop(); // close spinner if showing

        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dCtx) => AlertDialog(
            title: const Text('Requests not open yet'),
            content: const Text(
              'Song requests aren’t open for this venue right now. '
                  'Please check back later.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      final payload = {
        'venueCode': venueCode, // 👈 REQUIRED so host sees the request
        'songId': widget.song.id,
        'songTitle': widget.song.title,
        'songArtist': widget.song.artist,
        'singerUid': uid,
        'singerName': name,
        'keyChange': _keyChange,
        'status': 'queued',
        'played': false, // optional but keeps things consistent
        'createdAt': FieldValue.serverTimestamp(),
        'source': 'patron-app',
      };

      await FirebaseFirestore.instance
          .collection('requests')
          .add(payload)
          .timeout(const Duration(seconds: 20));

// Persist the name for next time
      await _saveName(name);

// Close spinner
      if (nav.canPop()) nav.pop();

      // Celebrate
      _confettiController.play();
      if (!mounted) return;

      await showDialog<void>(
        context: nav.context, // safe: we cached nav before any await
        barrierDismissible: false,
        builder: (dialogCtx) => Stack(
          alignment: Alignment.center,
          children: [
            AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              titlePadding: EdgeInsets.zero,
              contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              title: Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  gradient: dialogCtx.brandGradients.dialogBar,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Submitted',
                  style: Theme.of(dialogCtx).appBarTheme.titleTextStyle,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Song', '${widget.song.title} — ${widget.song.artist}'),
                  const SizedBox(height: 8),
                  _detailRow('Sung by', name),
                  const SizedBox(height: 8),
                  _detailRow('Key Change', _formatKey(_keyChange)),
                ],
              ),
              actionsAlignment: MainAxisAlignment.end,
              actions: [
                TextButton(
                  onPressed: () {
                    nav.pop(); // close success dialog
                    if (nav.canPop()) nav.pop(); // back to search
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
            ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.0,
              numberOfParticles: 70,
              minBlastForce: 10,
              maxBlastForce: 42,
              particleDrag: 0.01,
              gravity: 0.55,
              shouldLoop: false,
              minimumSize: const Size(8, 8),
              maximumSize: const Size(14, 14),
              colors: const [Color(0xFF5E2B97), Color(0xFFFF6F61), Color(0xFFFF8AB3)],
            ),
          ],
        ),
      );

      // Reset local inputs
      setState(() => _keyChange = 0);
    }

    on TimeoutException {
      await showError('Submitting timed out. Check internet connection.');
    } on FirebaseException catch (e) {
      await showError('Firebase error: ${e.code} — ${e.message}');
    } catch (e) {
      await showError('Unexpected error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: gradientAppBar(context, 'Confirm Submission'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Song header
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.song.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.song.artist,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Singer name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'First Name - Last initial',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // Key change selector
            Row(
              children: [
                const Text('Key change:'),
                const SizedBox(width: 20),
                DropdownButton<int>(
                  value: _keyChange,
                  items: List.generate(7, (i) {
                    final v = i - 3; // -3..+3
                    return DropdownMenuItem(
                      value: v,
                      child: Text(v > 0 ? '+$v' : v.toString()),
                    );
                  }),
                  onChanged: (val) => setState(() => _keyChange = val!),
                ),
              ],
            ),
            const Spacer(),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                child: const Text('Submit Request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}