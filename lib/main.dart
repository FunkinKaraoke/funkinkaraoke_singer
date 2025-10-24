import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:funkinkaraoke_singer/models/song.dart';

// Theme
import 'package:funkinkaraoke_singer/services/theme.dart';
import 'package:funkinkaraoke_singer/services/venue_scope.dart';

// Screens
import 'package:funkinkaraoke_singer/screens/song_search_page.dart';
import 'package:funkinkaraoke_singer/screens/request_page.dart';
import 'package:funkinkaraoke_singer/screens/home_screen.dart';
import 'package:funkinkaraoke_singer/screens/lists_page.dart';
import 'package:funkinkaraoke_singer/screens/favourites_page.dart';
import 'package:funkinkaraoke_singer/screens/missing_song_page.dart' show MissingSongPage;
import 'package:funkinkaraoke_singer/screens/my_requests.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Platform-specific auth behavior
  try {
    if (kIsWeb) {
      // Web supports explicit persistence control
      await FirebaseAuth.instance.setPersistence(Persistence.NONE);
    } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      // Desktop: simulate fresh session each run for testing
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }
  } catch (e) {
    // Non-fatal; continue with sign-in attempt
    debugPrint('Auth platform setup warning: $e');
  }

  // Anonymous sign-in (persists on mobile; fresh per run on desktop due to signOut above)
  try {
    await FirebaseAuth.instance.signInAnonymously();
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('Signed in with UID: ${user?.uid}');
  } on FirebaseAuthException catch (e) {
    debugPrint('Anon sign-in failed: ${e.code} — ${e.message}');
  } catch (e) {
    debugPrint('Anon sign-in unexpected error: $e');
  }

  runApp(const FunkinApp());
}

class FunkinApp extends StatefulWidget {
  const FunkinApp({super.key});

  @override
  State<FunkinApp> createState() => _FunkinAppState();
}

class _FunkinAppState extends State<FunkinApp> {
  final VenueSession _venueSession = VenueSession();

  @override
  Widget build(BuildContext context) {
    return VenueScope(
      notifier: _venueSession,
      child: MaterialApp(
        title: 'Funkin Karaoke',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.light,
        home: const HomeScreen(),
        routes: {
          '/search': (_) => const SongSearchPage(),
          '/lists': (_) => const ListsPage(),
          '/favourites': (_) => const FavoritesPage(),
          '/missing': (_) => const MissingSongPage(),
          '/request': (context) {
            final song = ModalRoute.of(context)!.settings.arguments as Song;
            return RequestPage(song: song);
          },
          '/my-requests': (_) => const MyRequestsPage(),
        },
      ),
    );
  }
}