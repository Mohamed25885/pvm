import 'dart:io';

import '../domain/exceptions.dart';

/// Prepares [path] to receive a new link.
///
/// * nothing there → no-op
/// * an existing link (symlink or junction) → removed (the target is untouched)
/// * a real file or directory → [LinkSlotOccupiedException]; never deleted
Future<void> clearLinkSlot(String path) async {
  final type = await FileSystemEntity.type(path, followLinks: false);
  switch (type) {
    case FileSystemEntityType.notFound:
      return;
    case FileSystemEntityType.link:
      await Link(path).delete();
      return;
    default:
      throw LinkSlotOccupiedException(path);
  }
}
