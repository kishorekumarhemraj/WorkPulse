import 'package:flutter/material.dart';

class IconUtils {
  static const Map<String, IconData> availableIcons = {
    'folder': Icons.folder_outlined,
    'code': Icons.code,
    'architecture': Icons.account_tree_outlined,
    'chat': Icons.chat_bubble_outline,
    'brain': Icons.psychology_outlined,
    'gear': Icons.settings_outlined,
    'star': Icons.star_border,
    'check': Icons.check_circle_outline,
    'clock': Icons.access_time,
    'book': Icons.menu_book_outlined,
    'briefcase': Icons.business_center_outlined,
    'terminal': Icons.terminal,
    'bug': Icons.bug_report_outlined,
    'design': Icons.palette_outlined,
    'search': Icons.search,
    'rocket': Icons.rocket_launch_outlined,
  };

  static IconData getIcon(String? iconName, {IconData defaultIcon = Icons.folder_outlined}) {
    if (iconName == null) return defaultIcon;
    return availableIcons[iconName.toLowerCase()] ?? defaultIcon;
  }
}
