import 'package:flutter/material.dart';

class EditTitleDialog extends StatefulWidget {
  final String currentTitle;

  const EditTitleDialog({
    super.key,
    required this.currentTitle,
  });

  @override
  State<EditTitleDialog> createState() => _EditTitleDialogState();
}

class _EditTitleDialogState extends State<EditTitleDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('タイトルを編集'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'チャットのタイトルを入力',
        ),
        onSubmitted: (value) {
          Navigator.of(context).pop(value);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('保存'),
        ),
      ],
    );
  }
}