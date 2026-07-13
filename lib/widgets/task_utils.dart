import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../models.dart';

const List<Color> colorPalette = [
  Color(0xFF3F8CFF), // Sapphire Blue
  Color(0xFFFF7B54), // Sunset Orange
  Color(0xFF10B981), // Emerald Green
  Color(0xFF8B5CF6), // Amethyst Purple
  Color(0xFFEC4899), // Soft Rose
  Color(0xFFF59E0B), // Amber Yellow
  Color(0xFF06B6D4), // Mint Teal
  Color(0xFFF97316), // Warm Peach
  Color(0xFF84CC16), // Lime Green
  Color(0xFF6366F1), // Indigo
  Color(0xFF14B8A6), // Muted Teal
  Color(0xFFD946EF), // Fuchsia
];

Color getDeterministicColor(String value) {
  if (value.isEmpty || value == 'None') return Colors.grey[700]!;
  int hash = 0;
  for (int i = 0; i < value.length; i++) {
    hash = value.codeUnitAt(i) + ((hash << 5) - hash);
  }
  int index = hash.abs() % colorPalette.length;
  return colorPalette[index];
}

Color getUrgencyColor(String urgency) {
  switch (urgency.toLowerCase()) {
    case 'today':
      return const Color(0xFFEF4444); // Premium Red
    case 'urgent':
      return const Color(0xFFF43F5E); // Premium Rose/Crimson
    case 'not urgent':
      return const Color(0xFF10B981); // Premium Emerald Green
    case 'long term':
      return const Color(0xFF64748B); // Premium Slate/Steel
    default:
      return getDeterministicColor(urgency);
  }
}

InputDecoration buildFormInputDecoration(
  String label, {
  IconData? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
    suffixIcon: suffixIcon != null
        ? Icon(suffixIcon, color: Colors.grey)
        : null,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Colors.white24, width: 1),
      borderRadius: BorderRadius.all(Radius.circular(4)),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Colors.blueAccent, width: 2),
      borderRadius: BorderRadius.all(Radius.circular(4)),
    ),
    border: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(4)),
    ),
  );
}

Widget buildSubTaskReminderPill({
  required IconData icon,
  required bool isActive,
  required Color activeColor,
  VoidCallback? onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? activeColor : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: activeColor, width: 1),
      ),
      child: Icon(
        icon,
        size: 12,
        color: isActive ? Colors.black : activeColor,
      ),
    ),
  );
}

Widget buildSubTaskUrgencyPill(SubTask sub, StateSetter setOverlayState) {
  final color = getUrgencyColor(sub.urgency);
  return GestureDetector(
    onTap: () async {
      const options = ['Today', 'Urgent', 'Not Urgent', 'Long Term'];
      int idx = options.indexOf(sub.urgency);
      if (idx == -1) idx = 0;
      int next = (idx + 1) % options.length;
      sub.urgency = options[next];
      await DBHelper.updateSubTask(sub);
      setOverlayState(() {});
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_outline, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            sub.urgency,
            style: TextStyle(
              fontSize: 11,
              height: 1.1,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}
