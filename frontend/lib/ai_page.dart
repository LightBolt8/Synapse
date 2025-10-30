import 'package:flutter/material.dart';
import 'app_bottom_nav.dart';
import 'instructor_bottom_nav.dart';
import 'services/api_service.dart';
import 'app_theme.dart';

class AIPage extends StatefulWidget {
  const AIPage({super.key, this.isInstructor = false});
  final bool isInstructor;

  @override
  State<AIPage> createState() => _AIPageState();
}

class _AIPageState extends State<AIPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _conversationId;

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text.trim();
    _messageController.clear();

    // Add user message to chat
    setState(() {
      _messages.add(ChatMessage(
        text: userMessage,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      // Call your AI API
      final response = await ApiService.chatWithAI(userMessage, conversationId: _conversationId);
      
      // Update conversation ID if this is first message
      _conversationId ??= response['conversation_id'];

      // Add AI response to chat
      setState(() {
        _messages.add(ChatMessage(
          text: response['response'],
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    } catch (e) {
      // Handle errors
      setState(() {
        _messages.add(ChatMessage(
          text: 'Sorry, I encountered an error: ${e.toString()}',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
      });
    }

    setState(() {
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Study Buddy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New conversation',
            onPressed: () {
              setState(() {
                _messages.clear();
                _conversationId = null;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Welcome message when chat is empty
          if (_messages.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.psychology_outlined,
                        size: 80,
                        color: AppTheme.iosBlue,
                      ),
                      const SizedBox(height: AppTheme.spacing24),
                      Text(
                        'AI Study Buddy',
                        style: AppTheme.title1.copyWith(
                          color: AppTheme.primaryLabel,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing8),
                      Text(
                        'Ask me anything about your studies!\nI\'ll help you learn through guiding questions.',
                        textAlign: TextAlign.center,
                        style: AppTheme.callout.copyWith(
                          color: AppTheme.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            // Chat messages
            Expanded(
              child: Container(
                color: AppTheme.systemBackground,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing16,
                    vertical: AppTheme.spacing8,
                  ),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return ChatBubble(message: _messages[index]);
                  },
                ),
              ),
            ),
          
          // Loading indicator
          if (_isLoading)
            Container(
              color: AppTheme.systemBackground,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing16,
                vertical: AppTheme.spacing8,
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.systemGray,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Text(
                    'AI is thinking...',
                    style: AppTheme.footnote.copyWith(
                      color: AppTheme.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
          
          // Message input
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing12,
              vertical: AppTheme.spacing8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.systemGray6,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge * 2),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Ask me about your studies...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: AppTheme.spacing16,
                            vertical: AppTheme.spacing12,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _isLoading ? AppTheme.systemGray3 : AppTheme.iosBlue,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                      onPressed: _isLoading ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.isInstructor
          ? const InstructorBottomNav(currentIndex: 1)
          : const AppBottomNav(currentIndex: 1),
    );
  }
}

// Chat message model
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });
}

// Chat bubble widget - iMessage style with animation
class ChatBubble extends StatefulWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(widget.message.isUser ? 0.1 : -0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // iMessage-style colors
    final Color bubbleColor = widget.message.isUser
      ? AppTheme.iosBlue
      : widget.message.isError
        ? const Color(0xFFFFE5E5)
        : const Color(0xFFE9E9EB);

    final Color textColor = widget.message.isUser
      ? Colors.white
      : widget.message.isError
        ? AppTheme.errorRed
        : AppTheme.primaryLabel;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing4),
          child: Row(
            mainAxisAlignment: widget.message.isUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing16,
                    vertical: AppTheme.spacing12,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge * 1.5),
                  ),
                  child: Text(
                    widget.message.text,
                    style: AppTheme.body.copyWith(
                      color: textColor,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}