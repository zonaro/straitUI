class SessionItem {
  final String id;
  final String runtime;
  final String title;
  final String preview;
  final String cwd;
  final DateTime updatedAt;

  SessionItem.fromJson(Map<String, dynamic> json)
      : id = json['id']?.toString() ?? '',
        runtime = json['runtime']?.toString() ?? '',
        title = json['title']?.toString() ?? '',
        preview = json['preview']?.toString() ?? '',
        cwd = json['cwd']?.toString() ?? '',
        updatedAt = DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
}

class MessageBlock {
  final String type;
  final String text;
  final String name;

  MessageBlock.fromJson(Map<String, dynamic> json)
      : type = json['type']?.toString() ?? 'text',
        text = json['text']?.toString() ?? '',
        name = json['name']?.toString() ?? '';
}

class ConversationMessage {
  final String role;
  final DateTime? timestamp;
  final List<MessageBlock> blocks;

  ConversationMessage.fromJson(Map<String, dynamic> json)
      : role = json['role']?.toString() ?? '',
        timestamp = DateTime.tryParse(json['timestamp']?.toString() ?? ''),
        blocks = (json['blocks'] as List? ?? [])
            .map((item) => MessageBlock.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
}

class Conversation {
  final String cwd;
  final List<ConversationMessage> messages;
  final List<String> warnings;

  Conversation.fromJson(Map<String, dynamic> json)
      : cwd = json['cwd']?.toString() ?? '',
        messages = (json['messages'] as List? ?? [])
            .map((item) => ConversationMessage.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        warnings = (json['warnings'] as List? ?? []).map((item) => item.toString()).toList();

  int get droppedBlocks => messages.expand((message) => message.blocks).where((block) => block.type == 'thinking' || block.type == 'image').length;
}
