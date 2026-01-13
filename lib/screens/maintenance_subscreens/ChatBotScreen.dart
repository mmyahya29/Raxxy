import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:uuid/uuid.dart';

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final _user = const types.User(id: "user");
  final _bot = const types.User(id: "bot");
  final List<types.Message> _messages = [];
  final uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    // Add welcome message
    final welcomeMessage = types.TextMessage(
      id: uuid.v4(),
      author: _bot,
      text: "Hello!  I'm your vehicle maintenance assistant. Ask me anything about vehicle maintenance, oil changes, tire care, and more! ",
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    _messages.insert(0, welcomeMessage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Assistant"),
        backgroundColor: const Color(0xff6366f1),
      ),
      body: Chat(
        messages: _messages,
        onSendPressed:  _handleUserMessage,
        user: _user,
        theme: DefaultChatTheme(
          primaryColor: const Color(0xff6366f1),
          secondaryColor: const Color(0xfff3f4f6),
        ),
      ),
    );
  }

  // When user sends a message
  void _handleUserMessage(types.PartialText message) async {
    final userMessage = types.TextMessage(
      id: uuid.v4(),
      author: _user,
      text: message.text,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    setState(() {
      _messages.insert(0, userMessage);
    });

    // Process message and generate bot reply
    final botReply = await _processMessage(message.text);

    final botMessage = types.TextMessage(
      id: uuid.v4(),
      author: _bot,
      text: botReply,
      createdAt: DateTime. now().millisecondsSinceEpoch,
    );

    setState(() {
      _messages.insert(0, botMessage);
    });
  }

  // Hardcoded processing function for vehicle maintenance
  Future<String> _processMessage(String input) async {
    await Future.delayed(const Duration(seconds: 1)); // simulate thinking

    final lowerInput = input.toLowerCase();

    // Oil change related
    if (lowerInput.contains('oil') &&
        (lowerInput.contains('change') || lowerInput.contains('when') || lowerInput.contains('how often'))) {
      return "🛢️ Oil changes are typically recommended every 5,000 to 7,500 kilometers for conventional oil, or every 10,000 to 15,000 kilometers for synthetic oil. However, always check your vehicle's owner manual for specific recommendations.";
    }

    // Tire related
    if (lowerInput. contains('tire') || lowerInput.contains('tyre')) {
      if (lowerInput.contains('pressure')) {
        return "🚗 Proper tire pressure is crucial!  Check your tire pressure monthly.  The recommended PSI is usually found on a sticker inside the driver's door or in your owner's manual.  Under-inflated tires can reduce fuel efficiency by up to 3%.";
      }
      if (lowerInput.contains('rotate') || lowerInput.contains('rotation')) {
        return "🔄 Tire rotation should be done every 8,000 to 10,000 kilometers to ensure even wear. This extends tire life and improves vehicle handling. ";
      }
      if (lowerInput.contains('replace') || lowerInput.contains('change')) {
        return "⚠️ Replace tires when tread depth reaches 2/32 of an inch (1.6mm). Use the penny test:  insert a penny with Lincoln's head down - if you can see the top of his head, it's time for new tires! ";
      }
      return "🛞 Tires are critical for safety!  Regular pressure checks, rotations every 8,000-10,000 km, and replacements when tread is worn are essential. ";
    }

    // Brake related
    if (lowerInput.contains('brake')) {
      if (lowerInput.contains('pad')) {
        return "🛑 Brake pads typically last 40,000 to 100,000 kilometers depending on driving habits. Warning signs include squealing sounds, reduced responsiveness, or vibration when braking. Have them inspected regularly! ";
      }
      if (lowerInput.contains('fluid')) {
        return "💧 Brake fluid should be changed every 2 years or 40,000 kilometers.  Old brake fluid absorbs moisture, which can reduce braking performance and cause corrosion in the brake system.";
      }
      return "🛑 Brakes are your most important safety feature! Have them inspected every 20,000 km or if you notice any unusual sounds, vibrations, or reduced stopping power.";
    }

    // Battery related
    if (lowerInput.contains('battery')) {
      return "🔋 Car batteries typically last 3-5 years. Signs of a failing battery include slow engine crank, dimming lights, or warning lights on the dashboard. Have it tested annually after 3 years of use.";
    }

    // Air filter
    if (lowerInput.contains('air filter')) {
      return "🌬️ Engine air filters should be replaced every 15,000 to 30,000 kilometers, or annually.  A clean air filter improves fuel efficiency and engine performance. Check it more frequently if you drive in dusty conditions.";
    }

    // Coolant/Antifreeze
    if (lowerInput.contains('coolant') || lowerInput.contains('antifreeze')) {
      return "❄️ Coolant (antifreeze) should be flushed and replaced every 40,000 to 100,000 kilometers, depending on the type. It prevents your engine from overheating in summer and freezing in winter.";
    }

    // Transmission
    if (lowerInput.contains('transmission')) {
      return "⚙️ Transmission fluid should be changed every 50,000 to 100,000 kilometers. Signs of transmission problems include difficulty shifting, slipping gears, or unusual noises. Regular maintenance prevents costly repairs!";
    }

    // General maintenance schedule
    if (lowerInput. contains('maintenance') &&
        (lowerInput.contains('schedule') || lowerInput.contains('when') || lowerInput.contains('checklist'))) {
      return """📋 Basic Maintenance Schedule:
      
• Every 5,000 km: Oil & filter change
• Every 10,000 km: Tire rotation
• Every 15,000 km: Air filter check
• Every 20,000 km: Brake inspection
• Every 40,000 km: Spark plugs, brake fluid
• Every 50,000 km: Transmission fluid
• Annually: Battery test, coolant check

Always refer to your owner's manual for specific recommendations! """;
    }

    // Cost related
    if (lowerInput. contains('cost') || lowerInput.contains('price') || lowerInput.contains('expensive')) {
      return "💰 Maintenance costs vary by vehicle and location. Regular maintenance is much cheaper than major repairs!  An oil change might cost 50-100, but neglecting it could lead to engine damage costing thousands.";
    }

    // Warning lights
    if (lowerInput. contains('warning light') || lowerInput.contains('dashboard light')) {
      return "⚠️ Warning lights shouldn't be ignored! Common ones include:\n\n🔴 Check Engine - Get diagnosed ASAP\n🛢️ Oil Pressure - Stop immediately\n🌡️ Temperature - Pull over safely\n🔋 Battery - Have charging system checked\n\nConsult your manual for specific meanings! ";
    }

    // Winter/Summer care
    if (lowerInput. contains('winter') || lowerInput.contains('cold')) {
      return "❄️ Winter vehicle care tips:\n\n• Use winter-grade oil\n• Check battery (cold reduces capacity)\n• Ensure coolant is rated for cold temps\n• Consider winter tires\n• Keep fuel tank at least half full\n• Check wiper blades and fluid";
    }

    if (lowerInput.contains('summer') || lowerInput.contains('hot')) {
      return "☀️ Summer vehicle care tips:\n\n• Check coolant levels regularly\n• Ensure AC is working properly\n• Check tire pressure (heat increases it)\n• Protect paint with wax\n• Check battery (heat accelerates failure)\n• Replace worn wiper blades before rainy season";
    }

    // Fuel efficiency
    if (lowerInput.contains('fuel') && (lowerInput.contains('efficiency') || lowerInput.contains('mileage') || lowerInput.contains('save'))) {
      return "⛽ Improve fuel efficiency:\n\n• Keep tires properly inflated (+3% efficiency)\n• Regular oil changes\n• Replace air filters\n• Remove excess weight\n• Avoid aggressive driving\n• Use cruise control on highways\n• Regular tune-ups";
    }

    // Greetings
    if (lowerInput.contains('hello') || lowerInput.contains('hi') || lowerInput.contains('hey')) {
      return "Hello! 👋 How can I help you with your vehicle maintenance today?";
    }

    if (lowerInput.contains('thank')) {
      return "You're welcome! 😊 Feel free to ask if you have more questions about vehicle maintenance! ";
    }

    // Default response
    return "I can help you with:\n\n• Oil changes\n• Tire care and rotation\n• Brake maintenance\n• Battery care\n• Air filters\n• Coolant and fluids\n• Maintenance schedules\n• Warning lights\n• Seasonal care tips\n\nWhat would you like to know? ";
  }
}