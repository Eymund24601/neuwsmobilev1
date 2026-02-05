import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_routes.dart';
import '../theme/app_theme.dart';

class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final topics = const [
      'Sweden',
      'Germany',
      'Finance',
      'Tech',
      'Culture',
      'Politics',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Explore')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: topics.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final topic = topics[index];
          return Container(
            decoration: BoxDecoration(
              color: palette.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.border),
            ),
            child: ListTile(
              title: Text(topic),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                context.pushNamed(
                  AppRouteName.topicFeed,
                  pathParameters: {'topicOrCountryCode': topic},
                );
              },
            ),
          );
        },
      ),
    );
  }
}
