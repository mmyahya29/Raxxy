import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

// 1. Define the Conversation Stages
enum ChatStage {
  diagnosing,     // Step 1: User reports symptom, Bot lists causes
  confirmedIssue, // Step 2: User confirms which part is broken
  solution        // Step 3: Bot gives fixes/advice
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
  // TODO: Replace with your actual Hugging Face Access Token
  final String _apiKey = "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";
  final String _apiUrl = "https://router.huggingface.co/hf-inference/models/google/flan-t5-base";

  @override
  void initState() {
    super.initState();
    _addMessage(_bot, "Hello! I'm your automotive troubleshooting assistant. What problem are you experiencing with your vehicle?");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Mechanic"),
        backgroundColor: const Color(0xff6366f1),
      ),
      body: Chat(
        messages: _messages,
        onSendPressed: _handleUserMessage,
        user: _user,
        theme: DefaultChatTheme(
          primaryColor: const Color(0xff6366f1),
          secondaryColor: const Color(0xfff3f4f6),
          inputBackgroundColor: Colors.blueGrey,
        ),
      ),
    );
  }

  // --- Core Message Handling ---

  void _handleUserMessage(types.PartialText message) async {
    // 1. Show User Message
    _addMessage(_user, message.text);

    // 2. Generate Logic-Based Prompt
    final prompt = _generatePrompt(message.text);

    // 3. Call Hugging Face API
    try {
      final botReply = await _callHuggingFaceApi(prompt);

      // 4. Update Conversation State for next time
      _advanceConversationState(message.text);

      // 5. Show Bot Response
      _addMessage(_bot, botReply);

    } catch (e) {
      _addMessage(_bot, "I'm having trouble connecting to the server. Please check your internet or API key.");
      debugPrint(e.toString());
    }
  }

  // --- The "Brain": Prompt Engineering ---

  String _generatePrompt(String userInput) {
    switch (_currentStage) {

      case ChatStage.diagnosing:
      // Stage 1: Diagnosis Prompt
        return """
You are an expert automotive troubleshooting assistant.
User reports the following issue: "$userInput"
Explain possible causes in simple terms and list defective parts.
Ask the user to confirm which issue they found.
""";

      case ChatStage.confirmedIssue:
      // Stage 2: Solution Prompt
      // We assume the user's input IS the confirmation (e.g., "It's the spark plugs")
        return """
You are an automotive troubleshooting assistant.
The user identified this issue: "$userInput"
Explain easy fixes, safety precautions, and when to visit a mechanic.
""";

      case ChatStage.solution:
      // Stage 3: General Advice / Wrap up
        return """
User question: "$userInput"
Provide a helpful, short automotive maintenance tip or answer related to the question.
""";
    }
  }

  // --- State Management ---

  void _advanceConversationState(String userInput) {
    setState(() {
      if (_currentStage == ChatStage.diagnosing) {
        // After we diagnose, we move to waiting for confirmation
        _currentStage = ChatStage.confirmedIssue;
      } else if (_currentStage == ChatStage.confirmedIssue) {
        // After they confirm the issue, we move to solution mode
        _identifiedIssue = userInput; // Save what they said was wrong
        _currentStage = ChatStage.solution;
      }
      // If in solution mode, we stay there or could reset based on logic
    });
  }

  // --- API Connection ---

  Future<String> _callHuggingFaceApi(String prompt) async {
    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        "Authorization": "Bearer $_apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "inputs": prompt,
        "parameters": {
          "max_new_tokens": 250, // Use max_new_tokens for the newer router
          "temperature": 0.7,
        },
        "options": {
          "wait_for_model": true // Ensures the API wakes up the model if it's "asleep"
        }
      }),
    );

    // Debugging: If it fails, print the status so we know why
    if (response.statusCode != 200) {
      print("Failed with status: ${response.statusCode}");
      print("Response body: ${response.body}");
    }

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      if (data.isNotEmpty && data[0]['generated_text'] != null) {
        return data[0]['generated_text'].trim();
      }
    }

    throw Exception("Failed to load response: ${response.statusCode}");
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