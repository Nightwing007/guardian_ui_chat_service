import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/services/parent/document_vault_platform_service.dart';
import 'package:myapp/services/parent/document_vault_service.dart';
import 'package:myapp/theme/app_colors.dart';

class DocumentVaultScreen extends StatefulWidget {
  final String childHash;
  final String childName;

  const DocumentVaultScreen({
    super.key,
    required this.childHash,
    required this.childName,
  });

  @override
  State<DocumentVaultScreen> createState() => _DocumentVaultScreenState();
}

class _DocumentVaultScreenState extends State<DocumentVaultScreen> {
  final _vault = DocumentVaultService();
  final _platform = DocumentVaultPlatformService();
  var _relativeFolder = '';
  var _entries = <VaultEntry>[];
  var _isLoading = true;
  var _isWorking = false;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    try {
      final entries = await _vault.listEntries(
        childHash: widget.childHash,
        relativeFolder: _relativeFolder,
      );
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Unable to load documents');
    }
  }

  Future<void> _createFolder() async {
    final name = await _promptForName(title: 'Create folder', action: 'Create');
    if (name == null) return;

    await _runAction(() async {
      await _vault.createFolder(
        childHash: widget.childHash,
        relativeFolder: _relativeFolder,
        folderName: name,
      );
      await _loadEntries();
    }, successMessage: 'Folder created');
  }

  Future<void> _uploadFile() async {
    await _runAction(() async {
      final stored = await _vault.pickAndStoreFile(
        childHash: widget.childHash,
        relativeFolder: _relativeFolder,
      );
      if (stored != null) {
        await _loadEntries();
        _showMessage('File uploaded');
      }
    });
  }

  Future<void> _renameEntry(VaultEntry entry) async {
    final name = await _promptForName(
      title: entry.isFolder ? 'Rename folder' : 'Rename file',
      action: 'Rename',
      initialValue: entry.name,
    );
    if (name == null) return;

    await _runAction(() async {
      await _vault.renameEntry(
        childHash: widget.childHash,
        entry: entry,
        newName: name,
      );
      await _loadEntries();
    }, successMessage: 'Renamed');
  }

  Future<void> _shareEntry(VaultEntry entry) async {
    if (entry.isFolder) {
      _showMessage('Only files can be shared');
      return;
    }

    await _runAction(() async {
      await _platform.shareFile(entry.absolutePath, entry.name);
    });
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (_isWorking) return;
    setState(() => _isWorking = true);
    try {
      await action();
      if (successMessage != null) _showMessage(successMessage);
    } catch (e) {
      _showMessage(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<String?> _promptForName({
    required String title,
    required String action,
    String initialValue = '',
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _NamePromptDialog(
        title: title,
        action: action,
        initialValue: initialValue,
      ),
    );
    if (result == null || result.trim().isEmpty) return null;
    return result.trim();
  }

  void _openEntry(VaultEntry entry) {
    if (entry.isFolder) {
      setState(() => _relativeFolder = entry.relativePath);
      _loadEntries();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VaultFileViewerScreen(
          entry: entry,
          onRename: () {
            Navigator.pop(context);
            _renameEntry(entry);
          },
          onShare: () => _shareEntry(entry),
        ),
      ),
    ).then((_) => _loadEntries());
  }

  Future<bool> _handleBack() async {
    if (_relativeFolder.isEmpty) return true;
    setState(() => _relativeFolder = _vault.parentFolder(_relativeFolder));
    await _loadEntries();
    return false;
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('already exists')) {
      return 'A file or folder with that name already exists';
    }
    if (error is PlatformException && error.code == 'SHARE_FAILED') {
      return error.message ?? 'Unable to share this file';
    }
    if (error is PlatformException && error.code == 'PDF_RENDER_FAILED') {
      return error.message ?? 'Unable to preview this PDF';
    }
    if (message.contains('empty')) return 'Name cannot be empty';
    return 'Something went wrong';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _relativeFolder.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildBody()),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () async {
                  final shouldPop = await _handleBack();
                  if (shouldPop && mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              ),
              Expanded(
                child: Text(
                  'Documents',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.childName,
            style: GoogleFonts.poppins(
              color: AppColors.textGrey,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _relativeFolder.isEmpty ? 'Vault home' : _relativeFolder,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryPurple),
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.cardBlueBackground,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.folder_open,
                  color: AppColors.accentBlue,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No documents yet',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create a folder or upload a file for this child.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: AppColors.textGrey,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      itemCount: _entries.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return _VaultEntryTile(
          entry: entry,
          onTap: () => _openEntry(entry),
          onRename: () => _renameEntry(entry),
          onShare: () => _shareEntry(entry),
        );
      },
    );
  }

  Widget _buildActions() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isWorking ? null : _createFolder,
                icon: const Icon(Icons.create_new_folder),
                label: const Text('Folder'),
                style: _secondaryButtonStyle(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isWorking ? null : _uploadFile,
                icon: _isWorking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.upload_file),
                label: const Text('Upload'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ButtonStyle _secondaryButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(52),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700),
    );
  }
}

class _VaultEntryTile extends StatelessWidget {
  final VaultEntry entry;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onShare;

  const _VaultEntryTile({
    required this.entry,
    required this.onTap,
    required this.onRename,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBlueBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                entry.isFolder ? Icons.folder : _fileIcon(entry.extension),
                color: AppColors.accentBlue,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.isFolder ? 'Folder' : _formatSize(entry.sizeBytes),
                    style: GoogleFonts.poppins(
                      color: AppColors.textGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<_VaultAction>(
              tooltip: 'More',
              color: const Color(0xFF1E1E20),
              icon: Icon(Icons.more_vert, color: AppColors.textGrey),
              onSelected: (action) {
                switch (action) {
                  case _VaultAction.rename:
                    onRename();
                    break;
                  case _VaultAction.share:
                    onShare();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _VaultAction.rename,
                  child: _ActionMenuItem(icon: Icons.edit, label: 'Rename'),
                ),
                if (!entry.isFolder)
                  PopupMenuItem(
                    value: _VaultAction.share,
                    child: _ActionMenuItem(icon: Icons.share, label: 'Share'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class VaultFileViewerScreen extends StatelessWidget {
  final VaultEntry entry;
  final VoidCallback onRename;
  final VoidCallback onShare;

  const VaultFileViewerScreen({
    super.key,
    required this.entry,
    required this.onRename,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  PopupMenuButton<_VaultAction>(
                    tooltip: 'More',
                    color: const Color(0xFF1E1E20),
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (action) {
                      switch (action) {
                        case _VaultAction.rename:
                          onRename();
                          break;
                        case _VaultAction.share:
                          onShare();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _VaultAction.rename,
                        child: _ActionMenuItem(
                          icon: Icons.edit,
                          label: 'Rename',
                        ),
                      ),
                      PopupMenuItem(
                        value: _VaultAction.share,
                        child: _ActionMenuItem(
                          icon: Icons.share,
                          label: 'Share',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: _FilePreview(entry: entry)),
          ],
        ),
      ),
    );
  }
}

class _FilePreview extends StatelessWidget {
  final VaultEntry entry;

  const _FilePreview({required this.entry});

  @override
  Widget build(BuildContext context) {
    if (_isImage(entry.extension)) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4,
        child: Center(
          child: Image.file(
            File(entry.absolutePath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                _PreviewMessage(entry: entry),
          ),
        ),
      );
    }

    if (_isText(entry.extension)) {
      return FutureBuilder<String>(
        future: File(entry.absolutePath).readAsString(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryPurple),
            );
          }
          if (!snapshot.hasData) return _PreviewMessage(entry: entry);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: SelectableText(
              snapshot.data!,
              style: GoogleFonts.robotoMono(
                color: Colors.white,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          );
        },
      );
    }

    if (entry.extension == '.pdf') {
      return _PdfPreview(entry: entry);
    }

    return _PreviewMessage(entry: entry);
  }
}

class _PdfPreview extends StatefulWidget {
  final VaultEntry entry;

  const _PdfPreview({required this.entry});

  @override
  State<_PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<_PdfPreview> {
  final _platform = DocumentVaultPlatformService();
  late final Future<List<String>> _pagesFuture;

  @override
  void initState() {
    super.initState();
    _pagesFuture = _platform.renderPdfPages(widget.entry.absolutePath);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _pagesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryPurple),
          );
        }

        final pages = snapshot.data ?? [];
        if (pages.isEmpty) {
          return _PreviewMessage(
            entry: widget.entry,
            message: 'PDF preview is unavailable on this device.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          itemCount: pages.length,
          separatorBuilder: (context, index) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.file(
                    File(pages[index]),
                    fit: BoxFit.fitWidth,
                    errorBuilder: (context, error, stackTrace) =>
                        _PreviewMessage(entry: widget.entry),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PreviewMessage extends StatelessWidget {
  final VaultEntry entry;
  final String? message;

  const _PreviewMessage({required this.entry, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: AppColors.cardBlueBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _fileIcon(entry.extension),
                color: AppColors.accentBlue,
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              entry.name,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_formatSize(entry.sizeBytes)} • ${entry.extension.isEmpty ? 'File' : entry.extension.substring(1).toUpperCase()}',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: AppColors.textGrey,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message ??
                  'This file is saved in the vault. Preview is available for images, PDFs, and text files.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: AppColors.textGrey,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _fileIcon(String extension) {
  if (_isImage(extension)) return Icons.image;
  if (_isText(extension)) return Icons.article;
  if (extension == '.pdf') return Icons.picture_as_pdf;
  return Icons.insert_drive_file;
}

bool _isImage(String extension) {
  return {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'}.contains(extension);
}

bool _isText(String extension) {
  return {
    '.txt',
    '.md',
    '.json',
    '.csv',
    '.log',
    '.xml',
    '.yaml',
    '.yml',
  }.contains(extension);
}

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(1)} GB';
}

enum _VaultAction { rename, share }

class _ActionMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ActionMenuItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 19),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _NamePromptDialog extends StatefulWidget {
  final String title;
  final String action;
  final String initialValue;

  const _NamePromptDialog({
    required this.title,
    required this.action,
    required this.initialValue,
  });

  @override
  State<_NamePromptDialog> createState() => _NamePromptDialogState();
}

class _NamePromptDialogState extends State<_NamePromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.title,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: GoogleFonts.poppins(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Name',
          hintStyle: GoogleFonts.poppins(color: AppColors.textGrey),
          filled: true,
          fillColor: AppColors.cardBlueBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(color: AppColors.textGrey),
          ),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            widget.action,
            style: GoogleFonts.poppins(color: AppColors.accentBlue),
          ),
        ),
      ],
    );
  }
}
