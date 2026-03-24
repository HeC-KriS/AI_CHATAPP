class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isUser}) : timestamp = DateTime.now();
}

class ChatThread {
  String id;
  String title;
  List<ChatMessage> messages;
  String selectedModel;

  ChatThread({
    required this.id, 
    required this.title, 
    this.selectedModel = "llama3.2:1B-Q8_0",
    List<ChatMessage>? messages,
  }) : this.messages = messages ?? [];
}