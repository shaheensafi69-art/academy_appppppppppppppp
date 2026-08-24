import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/gemini_ai_service.dart';

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
  final GeminiAiService _aiService = GeminiAiService();
  bool isLoadingHistory = true;
  bool isTyping = false;
  List<Message> messages = [];
  final TextEditingController _textController = TextEditingController();
  String studentName = "";
  List<String> studentCourses = [];
  bool showEmojiPanel = false;

  final ScrollController _scrollController = ScrollController();

  final List<String> suggestedPrompts = [
    "سوال درباره دوره‌های ثبت‌نام‌شده من",
    "چه دوره‌های جدیدی در آکادمی ارائه می‌شود؟",
    "چگونه در کلاس‌های زنده شرکت کنم؟",
    "راهنمایی درباره پروژه‌ها و برنامه‌های آموزشی"
  ];

  final List<String> emojis = ["🔥", "🚀", "💻", "📈", "📊", "🎯", "💰", "💎", "💡", "🧠", "👍", "🙌", "🎉", "👑"];

  // پالت رنگی لایت (سفید پاکیزه و صورتی غلیظ خالص)
  static const Color primaryPink = Color(0xFFC2185B);
  static const Color lightPinkBg = Color(0xFFFCE4EC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF3F4F6);

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

      // دریافت اطلاعات متنی دانشجو
      final studentCtx = await _aiService.fetchStudentContext(userId);
      studentName = studentCtx.studentName;
      studentCourses = studentCtx.enrolledCourses;

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
      if (user == null) {
        throw Exception("لطفاً ابتدا وارد حساب کاربری شوید.");
      }
      final userId = user.id;

      final List<Map<String, String>> conversationHistory = messages
          .where((m) => !m.id.startsWith("temp-"))
          .map((m) => {"role": m.role, "content": m.content})
          .toList();

      final realAIResponse = await _aiService.generateResponse(
        studentId: userId,
        userPrompt: text,
        conversationHistory: conversationHistory,
      );

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
            content: "⚠️ خطایی در پاسخ هوش مصنوعی رخ داد: $e",
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
        backgroundColor: surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: cardBorder, width: 1.5)),
        title: const Text("Clear History", style: TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w900)),
        content: const Text("Are you sure you want to clear your AI chat history?", style: TextStyle(color: textGrey, fontSize: 11)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: textGrey, fontWeight: FontWeight.bold))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Clear", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
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
      backgroundColor: surfaceWhite,
      body: Column(
        children: [
          // ================= هدر اختصاصی صفحه هوش مصنوعی =================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: surfaceWhite,
              border: Border(bottom: BorderSide(color: cardBorder, width: 1.5)),
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
                        color: lightPinkBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primaryPink.withOpacity(0.3), width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.smart_toy_rounded, color: primaryPink, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Safi AI Assistant", style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                        Row(
                          children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: primaryPink, shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            const Text("Quantum Core Live", style: TextStyle(color: primaryPink, fontSize: 8, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _handleClearChat,
                  child: const Text("Clear History", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),

          // ================= لیست پیام‌ها =================
          Expanded(
            child: isLoadingHistory
                ? const Center(child: CircularProgressIndicator(color: primaryPink, strokeWidth: 2.5))
                : messages.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: lightPinkBg, shape: BoxShape.circle),
                                child: const Icon(Icons.bolt_rounded, size: 36, color: primaryPink),
                              ),
                              const SizedBox(height: 12),
                              Text("How can I assist you, ${studentName.isNotEmpty ? studentName : "Trader"}?", style: const TextStyle(color: textDark, fontSize: 16, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
                              const SizedBox(height: 6),
                              const Text("Ask anything about financial markets, smart contracts, or full-stack systems.", style: TextStyle(color: textGrey, fontSize: 11), textAlign: TextAlign.center),
                              const SizedBox(height: 20),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 2.3,
                                ),
                                itemCount: suggestedPrompts.length,
                                itemBuilder: (context, index) {
                                  final prompt = suggestedPrompts[index];
                                  return GestureDetector(
                                    onTap: () => _handleSendMessage(promptText: prompt),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: surfaceWhite,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: cardBorder, width: 1.5),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: primaryPink),
                                          const SizedBox(width: 6),
                                          Expanded(child: Text(prompt, style: const TextStyle(color: textDark, fontSize: 10, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis)),
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
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length + (isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == messages.length && isTyping) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: surfaceWhite,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: cardBorder, width: 1.5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: primaryPink, shape: BoxShape.circle)),
                                    const SizedBox(width: 4),
                                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: primaryPink, shape: BoxShape.circle)),
                                    const SizedBox(width: 4),
                                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: primaryPink, shape: BoxShape.circle)),
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
                              padding: const EdgeInsets.all(14),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                              decoration: BoxDecoration(
                                color: isMe ? lightPinkBg : surfaceWhite,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: isMe ? primaryPink.withOpacity(0.2) : cardBorder, width: 1.5),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(msg.content, style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 4),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Text(_formatTime(msg.createdAt), style: const TextStyle(color: textGrey, fontSize: 8, fontWeight: FontWeight.bold)),
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
              padding: const EdgeInsets.all(12),
              color: cardBorder,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: emojis.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _textController.text += emoji;
                        showEmojiPanel = false;
                      });
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                  );
                }).toList(),
              ),
            ),

          // ================= باکس ارسال پیام =================
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfaceWhite,
              border: Border(top: BorderSide(color: cardBorder, width: 1.5)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(showEmojiPanel ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined, color: textGrey, size: 20),
                  onPressed: () => setState(() => showEmojiPanel = !showEmojiPanel),
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: "Ask anything from Safi AI...",
                      hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                      filled: true,
                      fillColor: cardBorder.withOpacity(0.5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryPink, width: 1.5)),
                    ),
                    onSubmitted: (_) => _handleSendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 50,
                  width: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryPink,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: isTyping ? null : () => _handleSendMessage(),
                    child: isTyping
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}