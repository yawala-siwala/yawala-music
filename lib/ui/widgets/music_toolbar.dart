import 'package:flutter/material.dart';

import '../../state/app_state.dart';

/// Search / filter bar shown above the tracks list.
class MusicToolbar extends StatelessWidget {
  const MusicToolbar({super.key, required this.state});

  final MusicState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
                hintText: 'Filter tracks and artists',
              ),
              onChanged: state.setFilter,
            ),
          ),
          ListenableBuilder(
            listenable: state,
            builder: (context, _) => Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Chip(label: Text('${state.items.length} tracks')),
            ),
          ),
        ],
      ),
    );
  }
}