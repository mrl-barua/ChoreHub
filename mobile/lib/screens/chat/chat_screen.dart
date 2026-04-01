import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/message_provider.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/typing_indicator.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isAtBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 50) {
      // Near top — load more
      ref.read(messageProvider.notifier).loadMore();
    }
    _isAtBottom = _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100;
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _send() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    ref.read(messageProvider.notifier).sendMessage(text);
    _textController.clear();
    // Scroll to bottom after sending
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProvider);
    final messages = ref.watch(messageProvider);
    final currentUser = ref.watch(authProvider).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Auto-scroll on new messages if already at bottom
    ref.listen(messageProvider, (prev, next) {
      if (_isAtBottom && (prev?.messages.length ?? 0) < next.messages.length) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    });

    // Resolve typing user names
    final typingNames = messages.typingUserIds
        .map((id) {
          final member = family.members.where((m) => m.userId == id).firstOrNull;
          return member?.user?.displayName ?? 'Someone';
        })
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(family.currentFamily?.name ?? 'Chat', style: const TextStyle(fontSize: 18)),
            Text('${family.members.length} members',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: messages.isLoading
                ? const Center(child: CircularProgressIndicator())
                : messages.messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('No messages yet', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('Say hi to your family!', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(top: 12, bottom: 8),
                        itemCount: messages.messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages.messages[index];
                          final isMe = msg.userId == currentUser?.id;
                          // Show name if different user from previous message
                          final showName = index == 0 ||
                              messages.messages[index - 1].userId != msg.userId;

                          return MessageBubble(
                            message: msg,
                            isMe: isMe,
                            showName: showName,
                          );
                        },
                      ),
          ),

          // Typing indicator
          TypingIndicator(userNames: typingNames),

          // Input bar
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2A) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2A2A40) : const Color(0xFFF5F5FA),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 4,
                    minLines: 1,
                    onChanged: (_) => ref.read(messageProvider.notifier).onTyping(),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF6C63FF),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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
