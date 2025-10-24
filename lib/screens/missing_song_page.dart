import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:funkinkaraoke_singer/services/theme.dart';
import 'package:funkinkaraoke_singer/services/venue_scope.dart';

class MissingSongPage extends StatefulWidget {
  const MissingSongPage({super.key});

  @override
  State<MissingSongPage> createState() => _MissingSongPageState();
}

class _MissingSongPageState extends State<MissingSongPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _songController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _songController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (!_formKey.currentState!.validate()) return;

    final venueCode = VenueScope.of(context).code;
    if (venueCode == null || venueCode.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please select a venue first.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await FirebaseFirestore.instance.collection('missing_songs').add({
        'text': _songController.text.trim(),            // <— free-form field host reads first
        'query': _songController.text.trim(),           // <— optional: backward compatible
        'singerName': _nameController.text.trim(),      // <— host expects singerName
        'venueCode': venueCode,
        'createdAt': FieldValue.serverTimestamp(),
        'source': 'patron-app',
      }).timeout(const Duration(seconds: 20));

      if (nav.canPop()) nav.pop(); // close spinner

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Thanks!'),
          content: const Text(
            "We've received your song request and will try to add it soon.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      _songController.clear();
      _nameController.clear();
    } on TimeoutException {
      if (nav.canPop()) nav.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Submitting timed out. Please try again.')),
      );
    } on FirebaseException catch (e) {
      if (nav.canPop()) nav.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Firebase error: ${e.code} — ${e.message}')),
      );
    } catch (e) {
      if (nav.canPop()) nav.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: gradientAppBar(context, 'Missing Song Request'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'Are we missing a song you want to sing?\nRequest it below and we will do our best to add it.',
                style: TextStyle(
                  color: BrandColors.deepNavy,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),

              // Song free-text
            TextFormField(
              controller: _songController,
              decoration: const InputDecoration(
                labelText: 'Tell us what we are missing (artist, song)',
                hintText: "e.g. 'I’m Still Standing by Elton John'",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please type your request';
                }
                return null;
              },
            ),
              const SizedBox(height: 16),

              // Name (optional)
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Requested by',
                  hintText: 'Let us know who you are',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.warmPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Submit Request'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}