import 'package:flutter/material.dart';

PreferredSizeWidget gradientAppBar(String title) {
  return AppBar(
    title: Text(title),
    centerTitle: true,
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    flexibleSpace: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF5E2B97), // purple edge
            Color(0xFFFF8AB3), // pink transition
            Color(0xFFFF6F61), // orange start
            Color(0xFFFF6F61), // orange stay (flat band)
            Color(0xFFFF8AB3), // pink transition
            Color(0xFF5E2B97), // purple edge
          ],
          stops: [0.00, 0.18, 0.32, 0.68, 0.82, 1.00],
        ),
      ),
    ),
  );
}
