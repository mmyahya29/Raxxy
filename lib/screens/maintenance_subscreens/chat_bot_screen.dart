import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:http/http.dart' as http;
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
    _addMessage(_bot, "Hello! I'm your AI Mechanic. What's wrong with your vehicle today?");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Mechanic"),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Chat(
        messages: _messages,
        onSendPressed: _handleUserMessage,
        user: _user,
        theme: DefaultChatTheme(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          primaryColor: Color(0xFF8A3AE1),
          secondaryColor: Color(0xFFD1D1D1),
          inputBackgroundColor: Color(0xFF68308A),
          sendButtonIcon: Icon(Icons.send, color: Theme.of(context).textTheme.bodySmall?.color,)
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
You are an expert mechanic. The user says: "$userInput".
1. List 3-4 likely causes.
2. Mention the specific parts that might be broken.
3. Ask the user to check one thing or confirm which symptom fits best.
Keep it concise and helpful.
""";

      case ChatStage.confirmedIssue:
        return """
The user has confirmed or provided more info: "$userInput".
Provide a step-by-step fix, safety warnings, and tell them if this is a "DIY" job or requires a professional.
""";

      case ChatStage.solution:
        return "The user asks: $userInput. Provide a quick tip or follow-up answer regarding vehicle maintenance.";
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
  }
}