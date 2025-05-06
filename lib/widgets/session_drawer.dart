import 'package:flutter/material.dart';
import '../models/graph_session.dart';
import 'edit_title_dialog.dart';

class SessionDrawer extends StatelessWidget {
  final List<GraphSession> sessions;
  final GraphSession? currentSession;
  final Function(GraphSession) onSessionSelect;
  final VoidCallback onNewSession;
  final Function(GraphSession) onDeleteSession;
  final Function(GraphSession, String) onSessionTitleEdit;

  const SessionDrawer({
    super.key,
    required this.sessions,
    this.currentSession,
    required this.onSessionSelect,
    required this.onNewSession,
    required this.onDeleteSession,
    required this.onSessionTitleEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Center(
              child: Text(
                'チャット履歴',
                style: TextStyle(
                  color: Theme.of(context).primaryTextTheme.titleLarge?.color,
                  fontSize: 24,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                final isSelected = currentSession?.id == session.id;
                
                return ListTile(
                  title: Text(
                    session.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '作成: ${_formatDateTime(session.createdAt)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      Text(
                        '更新: ${_formatDateTime(session.updatedAt)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  selected: isSelected,
                  leading: const Icon(Icons.chat_bubble_outline),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEditTitleDialog(context, session),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _confirmDelete(context, session),
                      ),
                    ],
                  ),
                  onTap: () => onSessionSelect(session),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: onNewSession,
              icon: const Icon(Icons.add),
              label: const Text('新規チャット'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showEditTitleDialog(BuildContext context, GraphSession session) async {
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => EditTitleDialog(currentTitle: session.title),
    );

    if (newTitle != null && newTitle.isNotEmpty) {
      onSessionTitleEdit(session, newTitle);
    }
  }

  Future<void> _confirmDelete(BuildContext context, GraphSession session) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('チャットを削除'),
        content: const Text('このチャットを削除してもよろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (result == true) {
      onDeleteSession(session);
    }
  }
}