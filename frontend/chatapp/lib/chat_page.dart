import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_model.dart';
import 'api_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatPage extends StatefulWidget {
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<ChatThread> _threads = [];
  int _activeThreadIndex = 0;
  String? _deviceId;
  
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  final Map<String, String> _availableModels = {
    "Llama 3.2 (Fast)": "llama3.2:1B-Q8_0",
    "Gemma (Light)": "gemma3:1B-Q4_K_M",
    "Qwen (Smart)": "qwen2.5:3B-Q4_K_M"
  };

  @override
  void initState() {
    super.initState();
    _initializeAppData();
  }

  Future<void> _initializeAppData() async {
    setState(() => _isLoading = true);
    _deviceId = await ApiService.getDeviceId();
    
    // Sync existing threads from NeonDB
    final cloudThreads = await ApiService.getThreads(_deviceId!);
    
    setState(() {
      if (cloudThreads.isNotEmpty) {
        _threads = cloudThreads.map((t) => ChatThread(
          id: t['id'],
          title: t['name'], // Uses the Chat 1, Chat 2 names from DB
        )).toList();
      } else {
        // First time ever? Start with Chat 1
        _threads = [ChatThread(id: "chat_initial", title: "Chat 1")];
        _updateCounter(1); 
      }
    });
    
    _loadHistory();
  }

  // 🔥 Helper to keep Chat 1, 2, 3 sequential even if deleted
  Future<void> _updateCounter(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('chat_count_key', count);
  }

  void _loadHistory() async {
    if (_deviceId == null || _threads.isEmpty) return;
    setState(() => _isLoading = true);
    var currentThread = _threads[_activeThreadIndex];
    currentThread.messages.clear();

    try {
      final history = await ApiService.getHistory(currentThread.id);
      setState(() {
        currentThread.messages = history.map((m) => 
          ChatMessage(text: m['text'], isUser: m['isUser'])
        ).toList();
      });
      _scrollToBottom();
    } catch (e) {
      print("History load error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _createNewChat() async {
    final prefs = await SharedPreferences.getInstance();
    int currentCount = prefs.getInt('chat_count_key') ?? _threads.length;
    int nextCount = currentCount + 1;

    setState(() {
      String newId = "chat_${DateTime.now().millisecondsSinceEpoch}";
      _threads.add(ChatThread(
        id: newId,
        title: "Chat $nextCount",
      ));
      _activeThreadIndex = _threads.length - 1;
    });
    
    await _updateCounter(nextCount);
    Navigator.pop(context);
    _loadHistory();
  }

  void _deleteChat(int index) async {
    final threadId = _threads[index].id;
    Navigator.pop(context); 
    setState(() => _isLoading = true);

    try {
      bool success = await ApiService.deleteChat(threadId);
      if (success) {
        setState(() {
          _threads.removeAt(index);
          if (_threads.isEmpty) {
             _threads.add(ChatThread(id: "chat_${DateTime.now().millisecondsSinceEpoch}", title: "Chat 1"));
             _activeThreadIndex = 0;
          } else if (_activeThreadIndex >= _threads.length) {
            _activeThreadIndex = _threads.length - 1;
          }
        });
        _loadHistory();
      }
    } catch (e) {
      print("Delete error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty || _deviceId == null) return;
    String userText = _controller.text;
    var currentThread = _threads[_activeThreadIndex];

    setState(() {
      currentThread.messages.add(ChatMessage(text: userText, isUser: true));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final response = await ApiService.chat(
        prompt: userText,
        modelId: currentThread.selectedModel,
        threadId: currentThread.id,
        userId: _deviceId!,
        threadName: currentThread.title, // 🔥 Pass the Chat 1, Chat 2 name
      );
      setState(() {
        currentThread.messages.add(ChatMessage(text: response, isUser: false));
      });
    } catch (e) {
      setState(() {
        currentThread.messages.add(ChatMessage(text: "Error: $e", isUser: false));
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_threads.isEmpty) return Scaffold(body: Center(child: CircularProgressIndicator()));
    var currentThread = _threads[_activeThreadIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.lightBlue[700]),
        title: Text(currentThread.title, style: TextStyle(color: Colors.lightBlue[700], fontWeight: FontWeight.bold)),
        actions: [
          DropdownButton<String>(
            dropdownColor: Colors.grey[900],
            value: currentThread.selectedModel,
            underline: Container(),
            onChanged: (val) => setState(() => currentThread.selectedModel = val!),
            items: _availableModels.entries.map((e) => DropdownMenuItem(value: e.value, child: Text(e.key, style: TextStyle(color: Colors.white)))).toList(),
          ),
          SizedBox(width: 15),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.grey[900],
        child: Column(
          children: [
            DrawerHeader(child: Center(child: Text("AI Chatapp", style: TextStyle(color: Colors.lightBlue, fontSize: 24, fontWeight: FontWeight.bold)))),
            ListTile(
              leading: Icon(Icons.add, color: Colors.lightBlue),
              title: Text("New Chat", style: TextStyle(color: Colors.white)),
              onTap: _createNewChat,
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _threads.length,
                itemBuilder: (context, i) => ListTile(
                  selected: _activeThreadIndex == i,
                  selectedTileColor: Colors.lightBlue.withOpacity(0.1),
                  title: Text(_threads[i].title, style: TextStyle(color: _activeThreadIndex == i ? Colors.lightBlue : Colors.white)),
                  trailing: IconButton(icon: Icon(Icons.delete, color: Colors.red[400], size: 20), onPressed: () => _deleteChat(i)),
                  onTap: () {
                    setState(() => _activeThreadIndex = i);
                    Navigator.pop(context);
                    _loadHistory();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(10),
              itemCount: currentThread.messages.length,
              itemBuilder: (context, i) {
                final msg = currentThread.messages[i];

                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      // Limits bubble width to 80% of the screen for better readability
                      maxWidth: MediaQuery.of(context).size.width * 0.80, 
                    ),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: msg.isUser ? Colors.lightBlue[700] : Colors.grey[850],
                        borderRadius: BorderRadius.circular(15), // Slightly rounder for a modern look
                      ),
                      child: MarkdownBody(
                        data: msg.text,
                        selectable: true, // Crucial so you can copy code/text from the AI
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(
                            color: msg.isUser ? Colors.black : Colors.white,
                            fontSize: 16,
                          ),
                          code: TextStyle(
                            backgroundColor: Colors.black26,
                            fontFamily: 'monospace',
                            color: msg.isUser ? Colors.black87 : Colors.lightBlueAccent,
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading) LinearProgressIndicator(color: Colors.lightBlue),
          _buildInputSection(),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(child: TextField(controller: _controller, style: TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Type...", filled: true, fillColor: Colors.grey[900], border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)))),
          IconButton(icon: Icon(Icons.send, color: Colors.lightBlue), onPressed: _isLoading ? null : _sendMessage),
        ],
      ),
    );
  }
}