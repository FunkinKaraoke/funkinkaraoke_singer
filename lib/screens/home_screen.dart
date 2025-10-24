import 'package:flutter/material.dart';
import 'package:funkinkaraoke_singer/services/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:funkinkaraoke_singer/services/venue_scope.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _localSelectedVenue; // mirrors session for dropdown UI

  @override
  void initState() {
    super.initState();
    // Read the current venue ONCE after the first frame (no subscription).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initial = VenueScope.of(context).code;
      if (mounted) setState(() => _localSelectedVenue = initial);
    });
  }

  void _selectVenue(String? code) {
    if (_localSelectedVenue == code) return;

    // Update local immediately so the dropdown changes without relayout jitter.
    setState(() => _localSelectedVenue = code);

    // Nudge the global session AFTER this frame to avoid a bigger rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      VenueScope.of(context).set(code);
    });
  }

  void _guardedNav(VoidCallback go) {
    // Use the local value to avoid depending on VenueScope during build.
    if (_localSelectedVenue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select venue to continue')),
      );
      return;
    }
    go();
  }

  @override
  Widget build(BuildContext context) {
    final gradients = Theme.of(context).extension<BrandGradients>()!;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: gradients.primarySweep),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Expanded(
                  flex: 6,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.contain,
                      height: size.height * 0.48,
                    ),
                  ),
                ),

                // KARAOKE headline
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: Text(
                    'KARAOKE',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.bebasNeue(
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          blurRadius: 8,
                          color: Colors.black26,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),

                // Venue selector — REQUIRED before navigation (live from Firestore)
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('venues')
                      .orderBy('name')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      // Keep a stable height so layout doesn't jump.
                      return const SizedBox(
                        height: 64,
                        child: Center(
                          child: LinearProgressIndicator(color: BrandColors.purple),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Failed to load venues',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      );
                    }
                    final docs = snapshot.data?.docs ?? const [];
                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No venues available yet.',
                          style: TextStyle(
                            color: BrandColors.deepNavy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }

                    final items = <DropdownMenuItem<String>>[];
                    for (final d in docs) {
                      final data = d.data();
                      final active = (data['active'] as bool?) ?? true;
                      if (!active) continue;
                      final code = (data['code'] ?? '').toString();
                      final name = (data['name'] ?? code).toString();
                      if (code.isEmpty) continue;
                      items.add(DropdownMenuItem<String>(value: code, child: Text(name)));
                    }

// Keep a stable, fixed height so nothing shifts during setState or menu open/close.
                    return SizedBox(
                      height: 64,
                      child: Center(
                        child: DropdownButtonFormField<String>(
                          // Use `value:` and guard against values not present in items.
                          initialValue: items.any((i) => i.value == _localSelectedVenue)
                              ? _localSelectedVenue
                              : null,
                          isExpanded: true,
                          decoration: InputDecoration(
                            hintText: 'Please Select a Venue',
                            hintStyle: const TextStyle(
                              color: BrandColors.deepNavy,
                              fontWeight: FontWeight.w700,
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.90),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            enabledBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.black87, width: 1.2),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: BrandColors.purple, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          items: items,
                          onChanged: (v) {
                            if (v == null || v == _localSelectedVenue) return;
                            _selectVenue(v);
                          },
                          dropdownColor: Colors.white,
                          iconEnabledColor: BrandColors.deepNavy,
                          iconDisabledColor: BrandColors.deepNavy,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: BrandColors.onLight,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // 2x2 grid (Song Search, Favourites, My Requests, Popular Songs)
                Expanded(
                  flex: 5,
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 2.3,
                    children: [
                      _NavButton(
                        label: 'Song Search',
                        onTap: () => _guardedNav(
                              () => Navigator.pushNamed(context, '/search'),
                        ),
                      ),
                      _NavButton(
                        label: 'Favourites',
                        onTap: () => _guardedNav(
                              () => Navigator.pushNamed(context, '/favourites'),
                        ),
                      ),
                      _NavButton(
                        label: 'My Requests',
                        onTap: () => _guardedNav(
                              () => Navigator.pushNamed(context, '/my-requests'),
                        ),
                      ),
                      _NavButton(
                        label: 'CHOOSE FROM LIST',
                        onTap: () => _guardedNav(
                              () => Navigator.pushNamed(context, '/lists'),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom text link (also guarded)
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: () => _guardedNav(
                          () => Navigator.pushNamed(context, '/missing'),
                    ),
                    child: const Text(
                      'Request to Add a Song',
                      style: TextStyle(
                        color: BrandColors.purple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NavButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: BrandColors.warmPurple,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              offset: const Offset(2, 4),
              blurRadius: 6,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}