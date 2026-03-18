import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

class MessageInputBar extends StatefulWidget {
  final Function(String) onSendText;
  final Function(File)? onSendFile;
  final bool readOnly;
  final String? readOnlyMessage;

  const MessageInputBar({
    super.key,
    required this.onSendText,
    this.onSendFile,
    this.readOnly = false,
    this.readOnlyMessage,
  });

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _hasText = _controller.text.isNotEmpty));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSendText(text);
    _controller.clear();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result == null || result.files.isEmpty) return;
    final file = File(result.files.single.path!);
    widget.onSendFile?.call(file);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null) return;
    widget.onSendFile?.call(File(image.path));
  }

  void _showAttachMenu() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.image_outlined, color: Theme.of(context).colorScheme.primary),
              title: const Text('Photo from gallery'),
              onTap: () { Navigator.pop(context); _pickImage(); },
            ),
            ListTile(
              leading: Icon(Icons.attach_file_outlined, color: Theme.of(context).colorScheme.primary),
              title: const Text('Any file'),
              onTap: () { Navigator.pop(context); _pickFile(); },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borderColor = cs.outline.withValues(alpha: 0.6);

    if (widget.readOnly) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(widget.readOnlyMessage ?? 'Read only',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _showAttachMenu,
              color: cs.onSurfaceVariant,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  isDense: true,
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _hasText
                  ? IconButton(
                      key: const ValueKey('send'),
                      onPressed: _send,
                      icon: const Icon(Icons.send_rounded),
                      color: cs.primary,
                    )
                  : const SizedBox(width: 48, key: ValueKey('empty')),
            ),
          ],
        ),
      ),
    );
  }
}
