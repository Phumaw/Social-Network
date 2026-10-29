import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ReactionBottomSheet extends StatelessWidget {
  final Function(String) onReactionSelected;

  const ReactionBottomSheet({Key? key, required onReactionSelected})
      : onReactionSelected = onReactionSelected,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    final reactions = [
      {'icon': '👍', 'label': 'Like'},
      {'icon': '👎', 'label': 'Dislike'}, // ปุ่ม Dislike ตามข้อกำหนด
      {'icon': '❤️', 'label': 'Love'},
      {'icon': '😆', 'label': 'Haha'},
      {'icon': '😮', 'label': 'Wow'},
      {'icon': '😢', 'label': 'Sad'},
      {'icon': '😡', 'label': 'Angry'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: reactions.map((r) {
          return GestureDetector(
            onTap: () {
              onReactionSelected(r['label']!);
              Navigator.pop(context);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(r['icon']!, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 4),
                Text(r['label']!, style: const TextStyle(fontSize: 12)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}