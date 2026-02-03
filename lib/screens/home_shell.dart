import 'package:flutter/material.dart';

import 'home_page.dart';
import 'messages_page.dart';
import 'learn_page.dart';
import 'games_page.dart';
import 'you_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final List<Widget> _pages = const [
    HomePage(),
    MessagesPage(),
    LearnPage(),
    GamesPage(),
    YouPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (value) => setState(() => _index = value),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.school_outlined), label: 'Learn'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Games'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'You'),
        ],
      ),
    );
  }
}
