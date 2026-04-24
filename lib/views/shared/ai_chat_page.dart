import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/chat_service.dart';

class AIChatPage extends ConsumerStatefulWidget {
  final String? facilityId;
  final String role;

  const AIChatPage({super.key, this.facilityId, required this.role});

  @override
  ConsumerState<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends ConsumerState<AIChatPage> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<ChatMessage> _messages = [];
  late ChatService _chatService;
  bool _isLoading = false;
  bool _isInitializing = true;

  final List<String> _quickPrompts = [
    '📊 Show inventory summary',
    '⚠️ Any low stock alerts?',
    '📈 Usage trends this week',
    '💊 Which medicine is used most?',
    '📋 Pending supply requests',
    '🔮 Predict next month demand',
  ];

  @override
  void initState() {
    super.initState();
    _chatService = ChatService();
    _initChat();
  }

  Future<void> _initChat() async {
    setState(() => _isInitializing = true);
    
    if (!_chatService.isAvailable) {
      setState(() {
        _isInitializing = false;
        _messages.add(ChatMessage(
          text: '⚠️ Gemini API key not found. Please add your API key to the .env file to enable AI Chat.',
          isUser: false,
        ));
      });
      return;
    }

    await _chatService.startChat(widget.facilityId);
    setState(() {
      _isInitializing = false;
      _messages.add(ChatMessage(
        text: 'Hello! 👋 I\'m your MediFlow AI Assistant. I have access to your facility data including inventory, usage logs, and supply requests.\n\nAsk me anything about your medical supplies!',
        isUser: false,
      ));
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    final response = await _chatService.sendMessage(text);

    setState(() {
      _messages.add(ChatMessage(text: response, isUser: false));
      _isLoading = false;
    });
    _scrollToBottom();
    _focusNode.requestFocus();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('MediFlow AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(
                  _isLoading ? 'Thinking...' : 'Online • ${_chatService.activeModelName}',
                  style: TextStyle(fontSize: 12, color: _isLoading ? Colors.orange : Colors.green[600]),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset Chat',
            onPressed: () {
              setState(() {
                _messages.clear();
              });
              _initChat();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Chat Messages
          Expanded(
            child: _isInitializing
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 48, height: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Loading facility data...', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                      ],
                    ),
                  )
                : _messages.isEmpty
                    ? _buildEmptyState(theme)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        itemCount: _messages.length + (_isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length && _isLoading) {
                            return _buildTypingIndicator(primaryColor);
                          }
                          return _buildMessageBubble(_messages[index], theme);
                        },
                      ),
          ),

          // Quick Prompts (show only when few messages)
          if (_messages.length <= 2 && !_isInitializing && _chatService.isAvailable)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickPrompts.map((prompt) => _buildQuickPromptChip(prompt, primaryColor)).toList(),
              ),
            ),

          // Input Bar
          _buildInputBar(primaryColor),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 64, color: theme.colorScheme.primary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('Start a conversation', style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Ask about inventory, usage trends, or supply chain insights', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, ThemeData theme) {
    final isUser = message.isUser;
    final primaryColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primaryColor, primaryColor.withOpacity(0.7)]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? primaryColor : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SelectableText(
                message.text,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, color: primaryColor, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primaryColor, primaryColor.withOpacity(0.7)]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(primaryColor, 0),
                const SizedBox(width: 4),
                _buildDot(primaryColor, 1),
                const SizedBox(width: 4),
                _buildDot(primaryColor, 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(Color color, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickPromptChip(String text, Color primaryColor) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _sendMessage(text),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: primaryColor.withOpacity(0.2)),
          ),
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: primaryColor, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !_isLoading && _chatService.isAvailable,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _sendMessage,
                  decoration: InputDecoration(
                    hintText: _chatService.isAvailable
                        ? 'Ask about your inventory, usage, alerts...'
                        : 'API key required',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isLoading || !_chatService.isAvailable
                      ? [Colors.grey[300]!, Colors.grey[400]!]
                      : [primaryColor, primaryColor.withOpacity(0.8)],
                ),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: _isLoading || !_chatService.isAvailable ? null : () => _sendMessage(_controller.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
