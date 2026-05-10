import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class VaultEntry {
  final String name;
  final String relativePath;
  final String absolutePath;
  final bool isFolder;
  final int sizeBytes;
  final DateTime modifiedAt;

  const VaultEntry({
    required this.name,
    required this.relativePath,
    required this.absolutePath,
    required this.isFolder,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  String get extension => isFolder ? '' : p.extension(name).toLowerCase();
}

class DocumentVaultService {
  Future<Directory> childRoot(String childHash) async {
    final safeHash = _safeSegment(childHash);
    final documentsDir = await getApplicationDocumentsDirectory();
    final root = Directory(
      p.join(documentsDir.path, 'guardian_document_vault', safeHash),
    );
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  Future<Directory> folderFor({
    required String childHash,
    required String relativeFolder,
  }) async {
    final root = await childRoot(childHash);
    final folder = Directory(_resolveInsideRoot(root, relativeFolder));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder;
  }

  Future<List<VaultEntry>> listEntries({
    required String childHash,
    required String relativeFolder,
  }) async {
    final folder = await folderFor(
      childHash: childHash,
      relativeFolder: relativeFolder,
    );
    final entries = <VaultEntry>[];

    await for (final entity in folder.list(followLinks: false)) {
      final stat = await entity.stat();
      final isFolder = stat.type == FileSystemEntityType.directory;
      final name = p.basename(entity.path);
      entries.add(
        VaultEntry(
          name: name,
          relativePath: _joinRelative(relativeFolder, name),
          absolutePath: entity.path,
          isFolder: isFolder,
          sizeBytes: isFolder ? 0 : stat.size,
          modifiedAt: stat.modified,
        ),
      );
    }

    entries.sort((a, b) {
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  Future<void> createFolder({
    required String childHash,
    required String relativeFolder,
    required String folderName,
  }) async {
    final sanitizedName = _cleanName(folderName);
    if (sanitizedName.isEmpty) {
      throw const FileSystemException('Folder name cannot be empty');
    }

    final root = await childRoot(childHash);
    final folderPath = _resolveInsideRoot(
      root,
      _joinRelative(relativeFolder, sanitizedName),
    );
    final folder = Directory(folderPath);
    if (await folder.exists()) {
      throw FileSystemException('Folder already exists', folder.path);
    }
    await folder.create(recursive: true);
  }

  Future<VaultEntry?> pickAndStoreFile({
    required String childHash,
    required String relativeFolder,
  }) async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    final picked = result?.files.single;
    final sourcePath = picked?.path;
    if (picked == null || sourcePath == null || sourcePath.trim().isEmpty) {
      return null;
    }

    final source = File(sourcePath);
    if (!await source.exists()) return null;

    final targetFolder = await folderFor(
      childHash: childHash,
      relativeFolder: relativeFolder,
    );
    final targetName = await _availableName(
      targetFolder,
      _cleanName(picked.name),
    );
    final target = File(p.join(targetFolder.path, targetName));
    await source.copy(target.path);

    final stat = await target.stat();
    return VaultEntry(
      name: targetName,
      relativePath: _joinRelative(relativeFolder, targetName),
      absolutePath: target.path,
      isFolder: false,
      sizeBytes: stat.size,
      modifiedAt: stat.modified,
    );
  }

  Future<void> renameEntry({
    required String childHash,
    required VaultEntry entry,
    required String newName,
  }) async {
    final sanitizedName = _cleanName(newName);
    if (sanitizedName.isEmpty) {
      throw const FileSystemException('Name cannot be empty');
    }

    final root = await childRoot(childHash);
    final currentPath = _resolveInsideRoot(root, entry.relativePath);
    final parentFolder = p.dirname(entry.relativePath);
    final targetPath = _resolveInsideRoot(
      root,
      _joinRelative(parentFolder == '.' ? '' : parentFolder, sanitizedName),
    );

    if (currentPath == targetPath) return;
    if (await FileSystemEntity.type(targetPath) !=
        FileSystemEntityType.notFound) {
      throw FileSystemException(
        'A file or folder with that name already exists',
        targetPath,
      );
    }

    if (entry.isFolder) {
      await Directory(currentPath).rename(targetPath);
    } else {
      await File(currentPath).rename(targetPath);
    }
  }

  String parentFolder(String relativeFolder) {
    final normalized = p.normalize(relativeFolder);
    if (normalized == '.' || normalized.isEmpty) return '';
    final parent = p.dirname(normalized);
    return parent == '.' ? '' : parent;
  }

  String _resolveInsideRoot(Directory root, String relativePath) {
    final normalizedRelative = p.normalize(relativePath.trim());
    final safeRelative = normalizedRelative == '.' ? '' : normalizedRelative;
    final resolved = p.normalize(p.join(root.path, safeRelative));
    final rootPath = p.normalize(root.path);
    if (resolved != rootPath && !p.isWithin(rootPath, resolved)) {
      throw const FileSystemException('Invalid vault path');
    }
    return resolved;
  }

  String _joinRelative(String folder, String name) {
    final normalizedFolder = p.normalize(folder.trim());
    if (normalizedFolder.isEmpty || normalizedFolder == '.') return name;
    return p.normalize(p.join(normalizedFolder, name));
  }

  String _safeSegment(String value) {
    final safe = value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return safe.isEmpty ? 'unknown_child' : safe;
  }

  String _cleanName(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<String> _availableName(Directory folder, String requestedName) async {
    final clean = requestedName.isEmpty ? 'Document' : requestedName;
    final extension = p.extension(clean);
    final stem = extension.isEmpty ? clean : p.basenameWithoutExtension(clean);
    var candidate = clean;
    var counter = 1;

    while (await FileSystemEntity.type(p.join(folder.path, candidate)) !=
        FileSystemEntityType.notFound) {
      candidate = extension.isEmpty
          ? '$stem ($counter)'
          : '$stem ($counter)$extension';
      counter++;
    }

    return candidate;
  }
}
