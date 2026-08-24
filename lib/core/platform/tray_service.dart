import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';

class TrayMenuItem {
  final String? key;
  final String label;
  final bool isSeparator;
  final bool disabled;

  const TrayMenuItem({
    this.key,
    required this.label,
    this.isSeparator = false,
    this.disabled = false,
  });

  const TrayMenuItem.separator()
      : key = null,
        label = '',
        isSeparator = true,
        disabled = false;
}

abstract class TrayService {
  Future<void> initialize();
  Future<void> setTitle(String title);
  Future<void> setToolTip(String toolTip);
  Future<void> setContextMenu(List<TrayMenuItem> items);
  void setMenuItemClickListener(void Function(String key) listener);
  void setTrayClickListener(void Function() listener);
  Future<void> destroy();
}

class DesktopTrayService with TrayListener implements TrayService {
  void Function(String key)? _menuItemClickListener;
  void Function()? _trayClickListener;
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb ||
        (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux)) {
      return;
    }

    try {
      trayManager.addListener(this);
      await trayManager.setIcon(
        Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png',
      );
      _isInitialized = true;
    } catch (e) {
      debugPrint('DesktopTrayService initialize error: $e');
    }
  }

  @override
  Future<void> setTitle(String title) async {
    if (!_isInitialized) return;
    try {
      if (Platform.isMacOS) {
        await trayManager.setTitle(title);
      }
    } catch (e) {
      debugPrint('DesktopTrayService setTitle error: $e');
    }
  }

  @override
  Future<void> setToolTip(String toolTip) async {
    if (!_isInitialized) return;
    try {
      await trayManager.setToolTip(toolTip);
    } catch (e) {
      debugPrint('DesktopTrayService setToolTip error: $e');
    }
  }

  @override
  Future<void> setContextMenu(List<TrayMenuItem> items) async {
    if (!_isInitialized) return;
    try {
      final nativeMenu = Menu(
        items: items.map((item) {
          if (item.isSeparator) {
            return MenuItem.separator();
          }
          return MenuItem(
            key: item.key,
            label: item.label,
            disabled: item.disabled,
          );
        }).toList(),
      );
      await trayManager.setContextMenu(nativeMenu);
    } catch (e) {
      debugPrint('DesktopTrayService setContextMenu error: $e');
    }
  }

  @override
  void setMenuItemClickListener(void Function(String key) listener) {
    _menuItemClickListener = listener;
  }

  @override
  void setTrayClickListener(void Function() listener) {
    _trayClickListener = listener;
  }

  @override
  void onTrayIconMouseDown() {
    _trayClickListener?.call();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key != null) {
      _menuItemClickListener?.call(menuItem.key!);
    }
  }

  @override
  Future<void> destroy() async {
    if (!_isInitialized) return;
    try {
      trayManager.removeListener(this);
      await trayManager.destroy();
      _isInitialized = false;
    } catch (e) {
      debugPrint('DesktopTrayService destroy error: $e');
    }
  }
}

class NoOpTrayService implements TrayService {
  String currentTitle = '';
  String currentToolTip = '';
  List<TrayMenuItem> currentMenu = const [];
  void Function(String key)? menuItemClickListener;
  void Function()? trayClickListener;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> setTitle(String title) async {
    currentTitle = title;
  }

  @override
  Future<void> setToolTip(String toolTip) async {
    currentToolTip = toolTip;
  }

  @override
  Future<void> setContextMenu(List<TrayMenuItem> items) async {
    currentMenu = List.unmodifiable(items);
  }

  @override
  void setMenuItemClickListener(void Function(String key) listener) {
    menuItemClickListener = listener;
  }

  @override
  void setTrayClickListener(void Function() listener) {
    trayClickListener = listener;
  }

  @override
  Future<void> destroy() async {}
}
