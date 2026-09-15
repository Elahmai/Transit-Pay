import 'package:flutter/material.dart';
import '../../services/ai_service.dart';
import '../../utils/theme.dart';

class _ChatMessage {
  final String text;
  final bool fromUser;
  const _ChatMessage(this.text, this.fromUser);
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final AiService _ai = FirebaseAiService();
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _sending = false;

  static const _quickPrompts = [
    "What's my wallet balance?",
    'Do I have enough for this trip?',
    'Show my recent trips',
    'How much did I spend this week?',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(const _ChatMessage(
      "Hi! I'm Transit AI, your Transit Pay assistant. I can check your "
      "wallet balance, explain a fare estimate, pull up recent trips, or "
      "look up a route's stages — always from your real Transit Pay data. "
      "How can I help?",
      false,
    ));
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final message = (text ?? _inputCtrl.text).trim();
    if (message.isEmpty || _sending) return;
    setState(() {
      _messages.add(_ChatMessage(message, true));
      _sending = true;
      _inputCtrl.clear();
    });
    _scrollToEnd();

    final reply = await _ai.sendMessage(message);
    if (!mounted) return;
    setState(() {
      _messages.add(_ChatMessage(reply, false));
      _sending = false;
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          Text('🤖', style: TextStyle(fontSize: 18)),
          SizedBox(width: 8),
          Text('Transit AI'),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_sending ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i >= _messages.length) return const _TypingBubble();
              return _Bubble(message: _messages[i]);
            },
          ),
        ),

        if (_messages.length <= 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickPrompts
                  .map((p) => GestureDetector(
                        onTap: () => _send(p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary
                                .withValues(alpha: 0.3)),
                          ),
                          child: Text(p,
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ))
                  .toList(),
            ),
          ),

        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Ask Transit AI…',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sending ? null : () => _send(),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color:
                        _sending ? AppColors.gray300 : AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_upward,
                      color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  final _ChatMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.fromUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser
              ? null
              : Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? Colors.white : AppColors.dark,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const SizedBox(
          width: 24,
          height: 12,
          child: Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.gray500),
            ),
          ),
        ),
      ),
    );
  }
}
