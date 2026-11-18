import 'package:material_ui/material_ui.dart';

import '../../domain/model.dart';

/// List row for a single Track.
class TrackCard extends StatelessWidget {
  const TrackCard({super.key, required this.item, this.onTap});

  final Track item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.audiotrack),
        title: Text(item.displayName),
        subtitle: Text(item.subtitle),
        trailing: Text(item.meta),
        onTap: onTap,
      ),
    );
  }
}