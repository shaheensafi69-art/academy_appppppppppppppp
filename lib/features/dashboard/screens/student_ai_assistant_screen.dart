import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http; // برای فراخوانی API چت

class Message {
  final String id;
  final String role; // "user" | "ai"
  final String content;
  final String createdAt;

  Message({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });
}

class StudentAiAssistantScreen extends StatefulWidget {
  const StudentAiAssistantScreen({super.key});

  @override
  State<StudentAiAssistantScreen> createState() => _StudentAiAssistantScreenState();
}

class _StudentAiAssistantScreenState extends State<StudentAiAssistantScreen> {
  final supabase = Supabase.instance.client;
  bool isLoadingHistory = true;
  bool isTyping = false;
  List<Message> messages = [];
  final TextEditingController _textController = TextEditingController();
  String studentName = "";
  bool showEmojiPanel = false;

  final ScrollController _scrollController = ScrollController();

  final List<String> suggestedPrompts = [
    "Explain Stripe Treasury BaaS integration.",
    "Review my latest Trading Journal entry.",
    "How do I set up Dropshipping on Shopify?",
    "Debug my Next.js & Supabase connection."
  ];

  final List<String> emojis = ["🔥", "🚀", "💻", "📈", "📊", "🎯", "💰", "💎", "💡", "🧠", "👍", "🙌", "🎉", "👑"];
  
  Null get ascending => null;

  @override
  void initState() {
    super.initState();
    _fetchChatHistory();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _fetchChatHistory() async {
    setState(() => isLoadingHistory = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userId = user.id;

      // دریافت نام دانشجو
      final profile = await supabase
          .from("profiles")
          .select("first_name")
          .eq("id", userId)
          .maybeSingle();

      if (profile != null) {
        studentName = profile['first_name'] ?? '';
      }

      // دریافت تاریخچه چت از جدول ai_chat_history
      final history = await supabase
          .from("ai_chat_history")
          .select("*")
          .eq("student_id", userId)
          .order("created_at", ascending: true);

      List<Message> formattedMessages = [];
      for (var chat in (history as List)) {
        formattedMessages.add(Message(
          id: "user-${chat['id']}",
          role: "user",
          content: chat['user_prompt'] ?? '',
          createdAt: chat['created_at'] ?? DateTime.now().toIso8601String(),
        ));
        if (chat['ai_response'] != null) {
          formattedMessages.add(Message(
            id: "ai-${chat['id']}",
            role: "ai",
            content: chat['ai_response'],
            createdAt: chat['created_at'] ?? DateTime.now().toIso8601String(),
          ));
        }
      }
    
      if (mounted) {
        setState(() {
          messages = formattedMessages;
          isLoadingHistory = false;
        });
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    } catch (e) {
      debugPrint("Error fetching chat history: $e");
      if (mounted) setState(() => isLoadingHistory = false);
    }
  }

  Future<void> _handleSendMessage({String? promptText}) async {
    final text = promptText ?? _textController.text.trim();
    if (text.isEmpty || isTyping) return;

    _textController.clear();
    setState(() {
      showEmojiPanel = false;
      messages.add(Message(
        id: "temp-${DateTime.now().millisecondsSinceEpoch}",
        role: "user",
        content: text,
        createdAt: DateTime.now().toIso8601String(),
      ));
      isTyping = true;
    });
    Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userId = user.id;

      // توجه: در فلاتر اگر اندپوینت وب Next.js دارید، آدرس کامل API را اینجا قرار دهید یا از سرویس هوش مصنوعی مستقیم استفاده کنید.
      // مثال اتصال به API سرور Next.js شما:
      final response = await http.post(
        Uri.parse("https://your-domain.com/api/chat"), // آدرس وب‌سایت یا سرور Next.js
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"prompt": text, "userId": userId}),
      );

      final resData = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(resData['message'] ?? "Server error");
      }

      final realAIResponse = resData['message'] ?? "No response received.";

      // ذخیره در دیتابیس Supabase
      final savedChat = await supabase
          .from("ai_chat_history")
          .insert({
            'student_id': userId,
            'user_prompt': text,
            'ai_response': realAIResponse,
          })
          .select()
          .single();

      if (mounted) {
        setState(() {
          messages.removeWhere((m) => m.id.startsWith("temp-"));
          messages.add(Message(
            id: "user-${savedChat['id']}",
            role: "user",
            content: savedChat['user_prompt'],
            createdAt: savedChat['created_at'],
          ));
          messages.add(Message(
            id: "ai-${savedChat['id']}",
            role: "ai",
            content: savedChat['ai_response'],
            createdAt: savedChat['created_at'],
          ));
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("Error sending message: $e");
      if (mounted) {
        setState(() {
          messages.removeWhere((m) => m.id.startsWith("temp-"));
          messages.add(Message(
            id: "error-${DateTime.now().millisecondsSinceEpoch}",
            role: "ai",
            content: "⚠️ Failed to get AI response. Please check connection.",
            createdAt: DateTime.now().toIso8601String(),
          ));
        });
      }
    } finally {
      if (mounted) setState(() => isTyping = false);
    }
  }

  Future<void> _handleClearChat() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0a0a0f),
        title: const Text("Clear History", style: TextStyle(color: Colors.white, fontSize: 14)),
        content: const Text("Are you sure you want to clear your AI chat history?", style: TextStyle(color: Colors.grey, fontSize: 11)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Clear", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase.from("ai_chat_history").delete().eq("student_id", user.id);
      setState(() => messages.clear());
    } catch (e) {
      debugPrint("Error clearing chat: $e");
    }
  }

  String _formatTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      body: Column(
        children: [
          // ================= هدر اختصاصی صفحه هوش مصنوعی =================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF050508).withOpacity(0.8),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.purpleAccent]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Text("🤖", style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Safi AI Assistant", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                        Row(
                          children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.purpleAccent, shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            const Text("Quantum Core Live", style: TextStyle(color: Colors.purpleAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _handleClearChat,
                  child: const Text("Clear History", style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // ================= لیست پیام‌ها =================
          Expanded(
            child: isLoadingHistory
                ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
                : messages.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("⚡", style: TextStyle(fontSize: 40)),
                              const SizedBox(height: 10),
                              Text("How can I assist you, ${studentName.isNotEmpty ? studentName : "Trader"}?", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
                              const SizedBox(height: 6),
                              const Text("Ask anything about financial markets, smart contracts, or full-stack systems.", style: TextStyle(color: Colors.grey, fontSize: 10), textAlign: TextAlign.center),
                              const SizedBox(height: 20),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 2.2,
                                ),
                                itemCount: suggestedPrompts.length,
                                itemBuilder: (context, index) {
                                  final prompt = suggestedPrompts[index];
                                  return GestureDetector(
                                    onTap: () => _handleSendMessage(promptText: prompt),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.03),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Text("👉", style: TextStyle(fontSize: 10)),
                                          const SizedBox(width: 6),
                                          Expanded(child: Text(prompt, style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis)),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length + (isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == messages.length && isTyping) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.purple, shape: BoxShape.circle)),
                                    const SizedBox(width: 4),
                                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.purple, shape: BoxShape.circle)),
                                    const SizedBox(width: 4),
                                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.purple, shape: BoxShape.circle)),
                                  ],
                                ),
                              ),
                            );
                          }

                          final msg = messages[index];
                          bool isMe = msg.role == "user";

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.all(12),
                              constraints: const BoxConstraints(maxWidth: 280),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.indigo.withOpacity(0.3) : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isMe ? Colors.indigo.withOpacity(0.4) : Colors.white10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(msg.content, style: const TextStyle(color: Colors.white, fontSize: 11)),
                                  const SizedBox(height: 4),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Text(_formatTime(msg.createdAt), style: TextStyle(color: Colors.grey.shade500, fontSize: 7)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // ================= پنل ایموجی =================
          if (showEmojiPanel)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black.withOpacity(0.8),
              child: Wrap(
                spacing: 8,
                children: emojis.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _textController.text += emoji;
                        showEmojiPanel = false;
                      });
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  );
                }).toList(),
              ),
            ),

          // ================= باکس ارسال پیام =================
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF050508),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Text(showEmojiPanel ? "⌨️" : "😀", style: const TextStyle(fontSize: 16)),
                  onPressed: () => setState(() => showEmojiPanel = !showEmojiPanel),
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                    decoration: InputDecoration(
                      hintText: "Ask anything from Safi AI...",
                      hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.04),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _handleSendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.indigoAccent, size: 18),
                  onPressed: isTyping ? null : () => _handleSendMessage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}