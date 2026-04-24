import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// 1. Define the Conversation Stages
enum ChatStage {
  diagnosing,     // Step 1: User reports symptom
  confirmedIssue, // Step 2: User confirms issue
  solution        // Step 3: Bot gives fixes
}

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  // User & Bot Identifiers
  final _user = const types.User(id: "user");
  final _bot = const types.User(id: "bot");

  // State Variables
  final List<types.Message> _messages = [];
  final uuid = const Uuid();

  // 2. Logic State Tracking
  ChatStage _currentStage = ChatStage.diagnosing;
  String? _identifiedIssue;

  // 3. API Configuration
  // IMPORTANT: Do not share this key publicly!
  final String _apiKey = dotenv.env['API_KEY'] ?? 'default_value';
  final String _apiUrl = "https://api.groq.com/openai/v1/chat/completions";
  final String _model = "llama-3.1-8b-instant";

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  // --- Chat History & State Management ---

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final lastChatTime = prefs.getInt('chat_timestamp') ?? 0;
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    // 24 hours = 86,400,000 milliseconds
    if (currentTime - lastChatTime < 86400000) {
      final savedMessages = prefs.getStringList('chat_messages');

      if (savedMessages != null && savedMessages.isNotEmpty) {
        setState(() {
          // 1. Load Messages
          _messages.clear();
          _messages.addAll(
            savedMessages.map((e) => types.Message.fromJson(jsonDecode(e) as Map<String, dynamic>)).toList(),
          );

          // 2. Load the Bot's Brain (Stage & Issue)
          final savedStageIndex = prefs.getInt('chat_stage') ?? 0;
          _currentStage = ChatStage.values[savedStageIndex];
          _identifiedIssue = prefs.getString('chat_issue');
        });
        return;
      }
    }

    // If 24 hours passed, reset everything
    _addMessage(_bot, "Hello! I'm your AI Mechanic. How can I help you today?");
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Save Messages & Time
    final messagesJson = _messages.map((m) => jsonEncode(m.toJson())).toList();
    await prefs.setStringList('chat_messages', messagesJson);
    await prefs.setInt('chat_timestamp', DateTime.now().millisecondsSinceEpoch);

    // 2. Save the Bot's Brain (Stage & Issue)
    await prefs.setInt('chat_stage', _currentStage.index);
    if (_identifiedIssue != null) {
      await prefs.setString('chat_issue', _identifiedIssue!);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the exact height of the keyboard
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      // CRITICAL FIX: Turn off automatic resizing so we can handle it manually
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text("AI Mechanic"),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Padding(
        padding: EdgeInsets.only(
          // If the keyboard is open, push up by the EXACT height of the keyboard.
          // Otherwise, apply your original 70.r padding for the nav bar.
          bottom: keyboardHeight > 0 ? keyboardHeight : 70.r,
        ),
        child: Chat(
          messages: _messages,
          onSendPressed: _handleUserMessage,
          user: _user,
          theme: DefaultChatTheme(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              primaryColor: const Color(0xFF8A3AE1),
              secondaryColor: const Color(0xFFFFFFFF),
              inputBackgroundColor: const Color(0x1F9200EA),
              sendButtonIcon: Icon(Icons.send, color: Theme.of(context).textTheme.bodySmall?.color)
          ),
        ),
      ),
    );
  }

  // --- Core Message Handling ---

  void _handleUserMessage(types.PartialText message) async {
    _addMessage(_user, message.text);

    final prompt = _generatePrompt(message.text);

    try {
      final botReply = await _callApi(prompt);

      // Update state AFTER successful API call
      _advanceConversationState(message.text);

      _addMessage(_bot, botReply);
    } catch (e) {
      _addMessage(_bot, "Sorry, I hit a snag. Please check your connection or API key.");
      debugPrint("Error details: $e");
    }
  }

  // --- The Brain: Prompt Engineering ---

  String _generatePrompt(String userInput) {
    switch (_currentStage) {
      case ChatStage.diagnosing:
        return """
You are an elite automotive diagnostic AI. The user is reporting a vehicle issue: "$userInput".

### Task:
1. **Analyze:** Identify the most probable mechanical or electrical systems involved (e.g., Ignition, Fuel Delivery, Suspension).
2. **The "Top 3" Rule:** List 3-4 likely causes. For each, explain *why* it happens (e.g., "Misfiring: Likely clogged fuel injectors, preventing the engine from getting enough gas").
3. **Component Identification:** Explicitly name the parts that need inspection (e.g., Spark plugs, O2 sensor, Serpentine belt).
4. **The Diagnostic Question:** Ask the user ONE specific follow-up question to narrow the search (e.g., "Does the sound happen only when braking, or while driving at high speeds?").

### Tone & Safety:
- Use professional yet accessible mechanic language. 
- If the symptom sounds life-threatening (e.g., brake failure, smelling fuel), start with a **BOLD WARNING** to stop driving immediately.
""";

      case ChatStage.confirmedIssue:
        return """
The user has confirmed the issue or provided deep detail: "$userInput".

### Task:
1. **Difficulty Rating:** Start by labeling this fix as [EASY-DIY], [INTERMEDIATE], or [PROFESSIONAL REQUIRED].
2. **Step-by-Step Guide:** If DIY-friendly, provide a numbered list of steps to inspect or replace the part.
3. **Tool List:** Mention specific tools needed (e.g., 10mm socket, torque wrench, multimeter).
4. **Safety Protocol:** List essential safety steps (e.g., "Let the engine cool for 30 minutes," "Disconnect the negative battery terminal").
5. **The "Mechanic Trigger":** If the repair requires specialized tools (like a hydraulic press) or involves high-voltage EV components/internal engine timing, strongly advise visiting a certified mechanic.

### Style:
Keep steps concise. Use "Mechanic Tips" (e.g., "Spray WD-40 on the bolt 10 minutes before trying to turn it").
""";

      case ChatStage.solution:
        return """
The user is asking a follow-up or general maintenance question: "$userInput".

### Task:
1. **Direct Answer:** Provide a concise, 2-3 sentence answer to the specific question.
2. **Preventative Insight:** Explain how to prevent this specific issue from recurring (e.g., "Check your oil every 1,000 miles to avoid the sludge buildup we discussed").
3. **Pro-Tip:** Offer one "Hidden Gem" of car care related to their vehicle type.

### Tone:
Supportive, encouraging, and focused on vehicle longevity.
""";
    }
  }

  // --- State Management ---

  void _advanceConversationState(String userInput) {
    setState(() {
      if (_currentStage == ChatStage.diagnosing) {
        _currentStage = ChatStage.confirmedIssue;
      } else if (_currentStage == ChatStage.confirmedIssue) {
        _identifiedIssue = userInput;
        _currentStage = ChatStage.solution;
      }
    });

    _saveData(); // Save every time the bot moves to the next step
  }

  // --- API Connection (FIXED FOR GROQ) ---

  Future<String> _callApi(String prompt) async {
    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        "Authorization": "Bearer $_apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": _model,
        "messages": [
          {
            "role": "system",
            "content": "You are a professional automotive mechanic assistant. You help users diagnose car problems and suggest fixes."
          },
          {
            "role": "user",
            "content": prompt
          }
        ],
        "temperature": 0.7,
      }),
    );

    if (response.statusCode == 200) {
      // FIXED: Groq returns a Map (Object), not a List
      final Map<String, dynamic> data = jsonDecode(response.body);

      // Navigate the Groq/OpenAI JSON structure
      if (data.containsKey('choices') && data['choices'].isNotEmpty) {
        return data['choices'][0]['message']['content'].trim();
      }
      return "I received an empty response from the engine.";
    } else {
      throw Exception("Server Error: ${response.statusCode} - ${response.body}");
    }
  }

  // Helper to update UI
  void _addMessage(types.User author, String text) {
    final message = types.TextMessage(
      id: uuid.v4(),
      author: author,
      text: text,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    setState(() {
      _messages.insert(0, message);
    });

    _saveData(); // Save every time a message is sent/received
  }
}