import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
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
  final bool isFullScreen;

  const StudentAiAssistantScreen({super.key, this.isFullScreen = false});

  @override
  State<StudentAiAssistantScreen> createState() =>
      _StudentAiAssistantScreenState();
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

  // Voice/Audio States
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  final SpeechToText _speechToText = SpeechToText();
  String _speechLocale = "fa_IR"; // Default to Persian/Farsi input
  String _selectedVoice = "Kore";
  bool _isMuted = false;
  bool _isVoiceMode = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  String _voiceUserInputSim = "";
  String _voiceAiOutputSim = "";

  final List<String> suggestedPrompts = [
    "Ask about my enrolled courses",
    "What new courses are offered in the academy?",
    "How can I join live classes?",
    "Help with my assignment structure",
  ];

  final List<String> emojis = [
    "🔥",
    "🚀",
    "💻",
    "📈",
    "📊",
    "🎯",
    "💰",
    "💎",
    "💡",
    "🧠",
    "👍",
    "🙌",
    "🎉",
    "👑",
  ];

  // Prebuilt Voice options from Gemini guidelines
  final List<String> voiceOptions = [
    "Kore",
    "Zephyr",
    "Puck",
    "Leda",
    "Charon",
    "Fenrir",
    "Aoede",
    "Callirrhoe",
  ];

  // Bubblegum Theme Colors
  static const Color primaryPink = Color(0xFFF494AC);
  static const Color lightPinkBg = Color(0xFFFAF4F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFF1E3E7);
  static const Color darkSpaceBg = Color(0xFF0F0C1B);

  @override
  void initState() {
    super.initState();
    _fetchChatHistory();
    _initSpeech();

    // Listen to player state to dynamically show speaking visualizer
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isSpeaking = (state == PlayerState.playing);
        });
      }
    });

    _flutterTts.setStartHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = true;
        });
      }
    });

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    });

    _flutterTts.setCancelHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    });

    _flutterTts.setErrorHandler((_) {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    });
  }

  void _initSpeech() async {
    try {
      await _speechToText.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isListening) {
              setState(() {
                _isListening = false;
              });
            }
          }
        },
        onError: (errorVal) {
          debugPrint('Speech error: $errorVal');
          if (mounted) {
            setState(() {
              _isListening = false;
            });
          }
        },
      );
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint("SpeechToText init exception: $e");
    }
  }

  void _startListening() async {
    await _audioPlayer.stop();
    await _flutterTts.stop();

    if (!_speechToText.isAvailable) {
      bool initialized = false;
      try {
        initialized = await _speechToText.initialize(
          onStatus: (status) {
            debugPrint('Speech status: $status');
            if (status == 'done' || status == 'notListening') {
              if (mounted && _isListening) {
                setState(() {
                  _isListening = false;
                });
              }
            }
          },
          onError: (errorVal) {
            debugPrint('Speech error: $errorVal');
            if (mounted) {
              setState(() {
                _isListening = false;
              });
            }
          },
        );
      } catch (e) {
        debugPrint("SpeechToText init exception inside _startListening: $e");
      }

      if (!initialized) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Microphone access or speech recognition is not available. Please check your settings."),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _isListening = true;
        _voiceUserInputSim = "";
        _voiceAiOutputSim = "Listening...";
      });
    }

    try {
      await _speechToText.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _voiceUserInputSim = result.recognizedWords;
              if (result.finalResult) {
                _isListening = false;
                if (_voiceUserInputSim.trim().isNotEmpty) {
                  _handleSendMessage(promptText: _voiceUserInputSim.trim());
                }
              }
            });
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        localeId: _speechLocale,
      );
    } catch (e) {
      debugPrint("Error starting speech recognition: $e");
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
    }
  }

  void _stopListening() async {
    try {
      await _speechToText.stop();
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
    } catch (e) {
      debugPrint("Error stopping speech recognition: $e");
    }
  }

  void _handleMicTap() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    _flutterTts.stop();
    _speechToText.stop();
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
    if (!mounted) return;
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
        formattedMessages.add(
          Message(
            id: "user-${chat['id']}",
            role: "user",
            content: chat['user_prompt'] ?? '',
            createdAt: chat['created_at'] ?? DateTime.now().toIso8601String(),
          ),
        );
        if (chat['ai_response'] != null) {
          formattedMessages.add(
            Message(
              id: "ai-${chat['id']}",
              role: "ai",
              content: chat['ai_response'],
              createdAt: chat['created_at'] ?? DateTime.now().toIso8601String(),
            ),
          );
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

  /// Detects whether the input text is predominantly English
  bool _isEnglish(String text) {
    int engChars = 0;
    int nonEngChars = 0;
    for (int i = 0; i < text.length; i++) {
      final codeUnit = text.codeUnitAt(i);
      if ((codeUnit >= 65 && codeUnit <= 90) || (codeUnit >= 97 && codeUnit <= 122)) {
        engChars++;
      } else if (codeUnit > 128) {
        nonEngChars++;
      }
    }
    return engChars > nonEngChars;
  }

  /// Synthesize multilingual speech natively using the device's default TTS engine
  Future<void> _speakNativeTts(String text, {bool forceEnglish = false}) async {
    try {
      if (mounted) setState(() => _isSpeaking = true);
      String langCode = "fa-IR"; // Default to Persian
      if (forceEnglish) {
        langCode = "en-US";
      } else if (text.contains(RegExp(r'[\u0600-\u06FF]'))) {
        langCode = "fa-IR";
      } else {
        langCode = "en-US";
      }

      await _flutterTts.setLanguage(langCode);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint("Native TTS Error: $e");
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  /// Synthesize speech and play (Gemini TTS for English, Native TTS for Persian/others)
  Future<void> _speakText(String text) async {
    if (_isMuted) return;
    try {
      // Stop all active voice engines
      await _audioPlayer.stop();
      await _flutterTts.stop();

      if (mounted) setState(() => _isSpeaking = true);

      final isEng = _isEnglish(text);
      if (isEng) {
        // Use premium Gemini TTS for English
        final audioBase64 = await _aiService.generateSpeech(text, voice: _selectedVoice);
        if (audioBase64 != null) {
          final bytes = base64Decode(audioBase64);

          // Prepend WAV header if it doesn't already have one (checking RIFF signature)
          List<int> finalBytes;
          if (bytes.length > 4 &&
              bytes[0] == 0x52 &&
              bytes[1] == 0x49 &&
              bytes[2] == 0x46 &&
              bytes[3] == 0x46) {
            finalBytes = bytes;
          } else {
            finalBytes = _addWavHeader(bytes, 24000);
          }

          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/gemini_tts.wav');
          await file.writeAsBytes(finalBytes);

          await _audioPlayer.play(DeviceFileSource(file.path));
        } else {
          // Fallback to Native TTS if Gemini TTS fails
          await _speakNativeTts(text, forceEnglish: true);
        }
      } else {
        // Use Native Speech Synthesis for Persian/Dari or other languages
        await _speakNativeTts(text);
      }
    } catch (e) {
      debugPrint("TTS Audio Playback Error: $e");
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  /// Appends a standard 44-byte WAV header for 24kHz 16-bit mono raw PCM audio
  List<int> _addWavHeader(List<int> pcmBytes, int sampleRate) {
    final int totalDataLen = pcmBytes.length;
    final int totalAudioLen = totalDataLen + 36;
    final int byteRate = sampleRate * 2;

    final header = List<int>.filled(44, 0);
    header[0] = 0x52; // R
    header[1] = 0x49; // I
    header[2] = 0x46; // F
    header[3] = 0x46; // F
    header[4] = (totalAudioLen & 0xff);
    header[5] = ((totalAudioLen >> 8) & 0xff);
    header[6] = ((totalAudioLen >> 16) & 0xff);
    header[7] = ((totalAudioLen >> 24) & 0xff);
    header[8] = 0x57; // W
    header[9] = 0x41; // A
    header[10] = 0x56; // V
    header[11] = 0x45; // E
    header[12] = 0x66; // f
    header[13] = 0x6d; // m
    header[14] = 0x74; // t
    header[15] = 0x20; // ' '
    header[16] = 16;
    header[17] = 0;
    header[18] = 0;
    header[19] = 0;
    header[20] = 1; // PCM
    header[21] = 0;
    header[22] = 1; // Mono
    header[23] = 0;
    header[24] = (sampleRate & 0xff);
    header[25] = ((sampleRate >> 8) & 0xff);
    header[26] = ((sampleRate >> 16) & 0xff);
    header[27] = ((sampleRate >> 24) & 0xff);
    header[28] = (byteRate & 0xff);
    header[29] = ((byteRate >> 8) & 0xff);
    header[30] = ((byteRate >> 16) & 0xff);
    header[31] = ((byteRate >> 24) & 0xff);
    header[32] = 2; // Block align
    header[33] = 0;
    header[34] = 16; // 16-bit
    header[35] = 0;
    header[36] = 0x64; // d
    header[37] = 0x61; // a
    header[38] = 0x74; // t
    header[39] = 0x61; // a
    header[40] = (totalDataLen & 0xff);
    header[41] = ((totalDataLen >> 8) & 0xff);
    header[42] = ((totalDataLen >> 16) & 0xff);
    header[43] = ((totalDataLen >> 24) & 0xff);

    return [...header, ...pcmBytes];
  }

  Future<void> _handleSendMessage({String? promptText}) async {
    final text = promptText ?? _textController.text.trim();
    if (text.isEmpty || isTyping) return;

    _textController.clear();
    setState(() {
      showEmojiPanel = false;
      messages.add(
        Message(
          id: "temp-${DateTime.now().millisecondsSinceEpoch}",
          role: "user",
          content: text,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      isTyping = true;
      if (_isVoiceMode) {
        _voiceUserInputSim = text;
        _voiceAiOutputSim = "...";
      }
    });
    Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception("Please sign in first.");
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

      // Perform Supabase insert in the background (asynchronously) without awaiting it
      supabase.from("ai_chat_history").insert({
        'student_id': userId,
        'user_prompt': text,
        'ai_response': realAIResponse,
      }).then((value) {
        debugPrint("Background Supabase save success.");
      }).catchError((err) {
        debugPrint("Background Supabase save failed: $err");
      });

      if (mounted) {
        setState(() {
          messages.removeWhere((m) => m.id.startsWith("temp-"));
          messages.add(
            Message(
              id: "user-msg-${DateTime.now().millisecondsSinceEpoch}",
              role: "user",
              content: text,
              createdAt: DateTime.now().toIso8601String(),
            ),
          );
          messages.add(
            Message(
              id: "ai-response-${DateTime.now().millisecondsSinceEpoch}",
              role: "ai",
              content: realAIResponse,
              createdAt: DateTime.now().toIso8601String(),
            ),
          );
          if (_isVoiceMode) {
            _voiceUserInputSim = text;
            _voiceAiOutputSim = realAIResponse;
          }
        });
        _scrollToBottom();

        // Speak the response instantly!
        if (_isVoiceMode) {
          _speakText(realAIResponse);
        }
      }
    } catch (e) {
      debugPrint("Error sending message: $e");
      if (mounted) {
        setState(() {
          messages.removeWhere((m) => m.id.startsWith("temp-"));
          messages.add(
            Message(
              id: "error-${DateTime.now().millisecondsSinceEpoch}",
              role: "ai",
              content: "⚠️ Safe System Alert: Offline/Unable to connect",
              createdAt: DateTime.now().toIso8601String(),
            ),
          );
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: cardBorder, width: 1.5),
        ),
        title: const Text(
          "Clear History",
          style: TextStyle(
            color: textDark,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: const Text(
          "Are you sure you want to clear your AI chat history?",
          style: TextStyle(color: textGrey, fontSize: 11),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancel",
              style: TextStyle(color: textGrey, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Clear",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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
    // ================= هدر اختصاصی صفحه هوش مصنوعی =================
    Widget header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isVoiceMode ? darkSpaceBg : surfaceWhite,
        border: Border(
          bottom: BorderSide(
            color: _isVoiceMode ? Colors.white10 : cardBorder,
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (widget.isFullScreen) ...[
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: _isVoiceMode ? Colors.white : textDark,
                    size: 18,
                  ),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
              ],
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _isVoiceMode ? primaryPink.withOpacity(0.2) : lightPinkBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: primaryPink.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.smart_toy_rounded,
                  color: primaryPink,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Safi AI Assistant",
                    style: TextStyle(
                      color: _isVoiceMode ? Colors.white : textDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: primaryPink,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        "Quantum Voice Live",
                        style: TextStyle(
                          color: primaryPink,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              // Switch Toggle between Chat Mode and Voice Mode
              IconButton(
                icon: Icon(
                  _isVoiceMode
                      ? Icons.chat_bubble_outline_rounded
                      : Icons.headset_mic_rounded,
                  color: _isVoiceMode ? primaryPink : textGrey,
                ),
                onPressed: () {
                  setState(() {
                    _isVoiceMode = !_isVoiceMode;
                    if (!_isVoiceMode) {
                      _audioPlayer.stop();
                    }
                  });
                },
                tooltip: _isVoiceMode ? "Switch to Chat Mode" : "Switch to Voice Mode",
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20),
                onPressed: _handleClearChat,
                tooltip: "Clear History",
              ),
            ],
          ),
        ],
      ),
    );

    // ================= چیدمان نمای صوتی (Voice Mode UI) =================
    Widget voiceContent = Expanded(
      child: Container(
        color: darkSpaceBg,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            // Top Status Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Voice Selector Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedVoice,
                      dropdownColor: darkSpaceBg,
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: primaryPink, size: 20),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      onChanged: (String? newVal) {
                        if (newVal != null) {
                          setState(() {
                            _selectedVoice = newVal;
                          });
                        }
                      },
                      items: voiceOptions.map<DropdownMenuItem<String>>((String voice) {
                        return DropdownMenuItem<String>(
                          value: voice,
                          child: Text(voice),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                // Speech Input Language Selection
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _speechLocale,
                      dropdownColor: darkSpaceBg,
                      icon: const Icon(Icons.language_rounded, color: primaryPink, size: 16),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      onChanged: (String? newVal) {
                        if (newVal != null) {
                          setState(() {
                            _speechLocale = newVal;
                          });
                        }
                      },
                      items: const [
                        DropdownMenuItem<String>(
                          value: "fa_IR",
                          child: Text("فارسی (FA)"),
                        ),
                        DropdownMenuItem<String>(
                          value: "en_US",
                          child: Text("English (EN)"),
                        ),
                      ],
                    ),
                  ),
                ),
                // Mute / Unmute Button
                IconButton(
                  icon: Icon(
                    _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: _isMuted ? Colors.white38 : primaryPink,
                  ),
                  onPressed: () {
                    setState(() {
                      _isMuted = !_isMuted;
                      if (_isMuted) {
                        _audioPlayer.stop();
                        _flutterTts.stop();
                      }
                    });
                  },
                ),
              ],
            ),
            const Spacer(),

            // Large pulsing visualizer orb in the center
            GlowingVoiceOrb(
              isListening: _isListening,
              isSpeaking: _isSpeaking,
              onTap: () {
                if (_isSpeaking) {
                  _audioPlayer.stop();
                  _flutterTts.stop();
                  setState(() => _isSpeaking = false);
                } else {
                  _handleMicTap();
                }
              },
            ),

            const SizedBox(height: 24),
            // Sound Wave Indicator
            AnimatedSoundWave(isActive: _isListening || _isSpeaking),

            const SizedBox(height: 16),
            // Current audio state label
            Text(
              _isListening
                  ? "Listening..."
                  : _isSpeaking
                      ? "Speaking..."
                      : isTyping
                          ? "Thinking..."
                          : "Tap orb to speak",
              style: TextStyle(
                color: _isListening
                    ? Colors.cyanAccent
                    : _isSpeaking
                        ? const Color(0xFFE040FB)
                        : Colors.white70,
                fontSize: 14,
                fontWeight: SystemMouseCursors.click == MouseCursor.defer ? FontWeight.bold : FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),

            // Voice command helper prompt selector / input simulator
            if (_isListening) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "You can speak now, or tap a quick prompt below:",
                      style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 38,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: suggestedPrompts.length,
                        itemBuilder: (context, index) {
                          final prompt = suggestedPrompts[index];
                          return GestureDetector(
                            onTap: () {
                              setState(() => _isListening = false);
                              _handleSendMessage(promptText: prompt);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: primaryPink.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: primaryPink.withOpacity(0.3)),
                              ),
                              child: Center(
                                child: Text(
                                  prompt,
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Standard text input inside voice mode for fully flexible dictation fallback
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: InputDecoration(
                              hintText: "Or type your voice message here...",
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (val) {
                              setState(() => _isListening = false);
                              _handleSendMessage();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, color: primaryPink),
                          onPressed: () {
                            setState(() => _isListening = false);
                            _handleSendMessage();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // Real-time transcript monitor
            if (_voiceUserInputSim.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "You: $_voiceUserInputSim",
                      textDirection: _voiceUserInputSim.contains(RegExp(r'[\u0600-\u06FF]'))
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      style: const TextStyle(color: primaryPink, fontSize: 10, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "AI: $_voiceAiOutputSim",
                      textDirection: _voiceAiOutputSim.contains(RegExp(r'[\u0600-\u06FF]'))
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    // ================= چیدمان نمای متنی (Chat Mode UI) =================
    Widget chatContent = Expanded(
      child: isLoadingHistory
          ? const Center(
              child: CircularProgressIndicator(
                color: primaryPink,
                strokeWidth: 2.5,
              ),
            )
          : messages.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: lightPinkBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.bolt_rounded,
                            size: 36,
                            color: primaryPink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "How can I assist you, ${studentName.isNotEmpty ? studentName : "Trader"}?",
                          style: const TextStyle(
                            color: textDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Ask anything about financial markets, smart contracts, or full-stack systems.",
                          style: TextStyle(color: textGrey, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 2.3,
                          ),
                          itemCount: suggestedPrompts.length,
                          itemBuilder: (context, index) {
                            final prompt = suggestedPrompts[index];
                            return GestureDetector(
                              onTap: () =>
                                  _handleSendMessage(promptText: prompt),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: surfaceWhite,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: cardBorder,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 10,
                                      color: primaryPink,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        prompt,
                                        style: const TextStyle(
                                          color: textDark,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
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
                          child: const BouncingThinkingIndicator(),
                        ),
                      );
                    }

                    final msg = messages[index];
                    bool isMe = msg.role == "user";

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(14),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.78,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? lightPinkBg : surfaceWhite,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isMe
                                ? primaryPink.withOpacity(0.2)
                                : cardBorder,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    msg.content,
                                    textDirection: msg.content.contains(RegExp(r'[\u0600-\u06FF]'))
                                        ? TextDirection.rtl
                                        : TextDirection.ltr,
                                    style: const TextStyle(
                                      color: textDark,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                // Speak icon next to AI message
                                if (!isMe) ...[
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => _speakText(msg.content),
                                    child: const Icon(
                                      Icons.volume_up_rounded,
                                      color: primaryPink,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                _formatTime(msg.createdAt),
                                style: const TextStyle(
                                  color: textGrey,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );

    // ================= باکس ارسال پیام متنی (Chat Mode Input) =================
    Widget chatInput = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceWhite,
        border: Border(top: BorderSide(color: cardBorder, width: 1.5)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              showEmojiPanel
                  ? Icons.keyboard_rounded
                  : Icons.emoji_emotions_outlined,
              color: textGrey,
              size: 20,
            ),
            onPressed: () =>
                setState(() => showEmojiPanel = !showEmojiPanel),
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(
                color: textDark,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: "Ask anything from Safi AI...",
                hintStyle: const TextStyle(color: textGrey, fontSize: 11),
                filled: true,
                fillColor: cardBorder.withOpacity(0.5),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: primaryPink,
                    width: 1.5,
                  ),
                ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: isTyping ? null : () => _handleSendMessage(),
              child: isTyping
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
            ),
          ),
        ],
      ),
    );

    // ================= چیدمان اصلی صفحه براساس حالت فعال =================
    Widget mainBody = Column(
      children: [
        header,
        if (_isVoiceMode) voiceContent else chatContent,
        if (!_isVoiceMode) ...[
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
          chatInput,
        ],
      ],
    );

    return Scaffold(
      backgroundColor: _isVoiceMode ? darkSpaceBg : surfaceWhite,
      body: widget.isFullScreen ? SafeArea(child: mainBody) : mainBody,
    );
  }
}

/// A glowing pulsing orb designed specifically for the Bubblegum Theme Voice Mode.
class GlowingVoiceOrb extends StatefulWidget {
  final bool isListening;
  final bool isSpeaking;
  final VoidCallback onTap;

  const GlowingVoiceOrb({
    super.key,
    required this.isListening,
    required this.isSpeaking,
    required this.onTap,
  });

  @override
  State<GlowingVoiceOrb> createState() => _GlowingVoiceOrbState();
}

class _GlowingVoiceOrbState extends State<GlowingVoiceOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color orbColor = const Color(0xFFF494AC); // Bubblegum Pink
    if (widget.isListening) {
      orbColor = Colors.cyanAccent;
    } else if (widget.isSpeaking) {
      orbColor = const Color(0xFFE040FB);
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: orbColor.withOpacity(0.12),
            border: Border.all(color: orbColor.withOpacity(0.4), width: 2),
            boxShadow: [
              BoxShadow(
                color: orbColor.withOpacity(0.3),
                blurRadius: 35,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    orbColor,
                    orbColor.withOpacity(0.6),
                  ],
                ),
              ),
              child: Icon(
                widget.isListening
                    ? Icons.mic_rounded
                    : widget.isSpeaking
                        ? Icons.volume_up_rounded
                        : Icons.headset_mic_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated sound waves for speaking and listening mode feedback.
class AnimatedSoundWave extends StatefulWidget {
  final bool isActive;
  const AnimatedSoundWave({super.key, required this.isActive});

  @override
  State<AnimatedSoundWave> createState() => _AnimatedSoundWaveState();
}

class _AnimatedSoundWaveState extends State<AnimatedSoundWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedSoundWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double value = 1.0;
            if (widget.isActive) {
              final phase = (index * 0.15);
              value = (0.3 +
                  0.7 *
                      (0.5 +
                          0.5 *
                              (math.sin(_controller.value * 2 * math.pi +
                                  phase * 10))));
            } else {
              value = 0.2;
            }
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 4,
              height: 35 * value,
              decoration: BoxDecoration(
                color: const Color(0xFFF494AC),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          },
        );
      }),
    );
  }
}

class BouncingThinkingIndicator extends StatefulWidget {
  const BouncingThinkingIndicator({super.key});

  @override
  State<BouncingThinkingIndicator> createState() =>
      _BouncingThinkingIndicatorState();
}

class _BouncingThinkingIndicatorState extends State<BouncingThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.2;
            double progress = (_controller.value - delay) % 1.0;
            if (progress < 0) progress += 1.0;

            double bounce = 0.0;
            if (progress < 0.5) {
              bounce = -8.0 * (progress * 2) * (1.0 - progress * 2);
            }

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              transform: Matrix4.translationValues(0.0, bounce, 0.0),
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFFF494AC),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}
