import 'package:flutter/material.dart';

/// Total number of maps available in Cannon Fodder 1.
const _cf1Maps = 72;

/// Total number of maps available in Cannon Fodder 2.
const _cf2Maps = 72;

/// A dropdown selector for switching between maps.
class LevelSelector extends StatelessWidget {
  const LevelSelector({
    required this.currentMap,
    required this.onChanged,
    super.key,
  });

  final String currentMap;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButton<String>(
        value: currentMap,
        isExpanded: true,
        dropdownColor: Colors.black87,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        underline: const SizedBox.shrink(),
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
        items: [
          const DropdownMenuItem(
            enabled: false,
            child: Text(
              'Cannon Fodder 1',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          for (var i = 1; i <= _cf1Maps; i++)
            DropdownMenuItem(
              value: 'cf1/maps/mapm$i.tmx',
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text('Map $i'),
              ),
            ),
          const DropdownMenuItem(
            enabled: false,
            child: Text(
              'Cannon Fodder 2',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          for (var i = 1; i <= _cf2Maps; i++)
            DropdownMenuItem(
              value: 'cf2/maps/mapm$i.tmx',
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text('Map $i'),
              ),
            ),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}
