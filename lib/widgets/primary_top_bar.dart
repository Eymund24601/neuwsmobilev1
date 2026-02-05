import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrimaryTopBar extends StatelessWidget {
  const PrimaryTopBar({
    super.key,
    required this.title,
    this.trailing = const [],
  });

  final String title;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
            icon: const Icon(Icons.more_vert),
            tooltip: 'More',
          ),
          const SizedBox(width: 4),
          Text(
            title,
            style: GoogleFonts.libreBaskerville(
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          ...trailing,
        ],
      ),
    );
  }
}
