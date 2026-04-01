import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/chore.dart';
import '../../models/family_member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chore_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/message_provider.dart';
import '../../widgets/chore_picker.dart';
import '../../widgets/mention_suggestions.dart';
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
  Chore? _attachedChore;
  List<FamilyMember> _mentionSuggestions = [];
  List<String> _mentionedUserIds = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 50) {
      ref.read(messageProvider.notifier).loadMore();
    }
    _isAtBottom = _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100;
  }

  void _onTextChanged() {
    final text = _textController.text;
    final cursorPos = _textController.selection.baseOffset;
    if (cursorPos < 0) return;

    // Detect @mention trigger
    final textUpToCursor = text.substring(0, cursorPos);
    final lastAt = textUpToCursor.lastIndexOf('@');

    if (lastAt >= 0) {
      final afterAt = textUpToCursor.substring(lastAt + 1);
      // Only show suggestions if no space after @ (still typing the mention)
      if (!afterAt.contains(' ') && afterAt.length <= 20) {
        final query = afterAt.toLowerCase();
        final family = ref.read(familyProvider);
        final currentUser = ref.read(authProvider).user;
        final suggestions = family.members.where((m) {
          if (m.userId == currentUser?.id) return false;
          final name = (m.user?.displayName ?? '').toLowerCase();
          final username = (m.user?.username ?? '').toLowerCase();
          return name.contains(query) || username.contains(query);
        }).toList();
        setState(() => _mentionSuggestions = suggestions);
        return;
      }
    }
    setState(() => _mentionSuggestions = []);
  }

  void _onMentionSelected(FamilyMember member) {
    final text = _textController.text;
    final cursorPos = _textController.selection.baseOffset;
    final textUpToCursor = text.substring(0, cursorPos);
    final lastAt = textUpToCursor.lastIndexOf('@');

    if (lastAt >= 0) {
      final username = member.user?.username ?? member.userId;
      final before = text.substring(0, lastAt);
      final after = cursorPos < text.length ? text.substring(cursorPos) : '';
      final newText = '$before@$username $after';
      _textController.text = newText;
      _textController.selection = TextSelection.collapsed(offset: lastAt + username.length + 2);

      if (!_mentionedUserIds.contains(member.userId)) {
        _mentionedUserIds.add(member.userId);
      }
    }
    setState(() => _mentionSuggestions = []);
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

  void _showChorePicker() {
    final chores = ref.read(choreProvider).chores;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChorePicker(
        chores: chores,
        onSelected: (chore) {
          setState(() => _attachedChore = chore);
        },
      ),
    );
  }

  void _send() {
    final text = _textController.text.trim();
    if (text.isEmpty && _attachedChore == null) return;

    final finalText = text.isEmpty && _attachedChore != null
        ? 'Shared a chore: ${_attachedChore!.title}'
        : text;

    ref.read(messageProvider.notifier).sendMessage(
      finalText,
      choreId: _attachedChore?.id,
      mentionUserIds: _mentionedUserIds.isNotEmpty ? _mentionedUserIds : null,
    );

    _textController.clear();
    setState(() {
      _attachedChore = null;
      _mentionedUserIds = [];
      _mentionSuggestions = [];
    });
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProvider);
    final messages = ref.watch(messageProvider);
    final currentUser = ref.watch(authProvider).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Build member name lookup for mention highlighting
    final memberNames = <String, String>{};
    for (final m in family.members) {
      memberNames[m.userId] = m.user?.displayName ?? 'Unknown';
    }

    ref.listen(messageProvider, (prev, next) {
      if (_isAtBottom && (prev?.messages.length ?? 0) < next.messages.length) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    });

    final typingNames = messages.typingUserIds
        .map((id) => memberNames[id] ?? 'Someone')
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
          // Messages
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
                          final showName = index == 0 || messages.messages[index - 1].userId != msg.userId;

                          return MessageBubble(
                            message: msg,
                            isMe: isMe,
                            showName: showName,
                            memberNames: memberNames,
                            onChoreTap: msg.hasChoreAttachment
                                ? () => context.push('/chores/${msg.choreId}')
                                : null,
                          );
                        },
                      ),
          ),

          // Typing indicator
          TypingIndicator(userNames: typingNames),

          // Mention suggestions popup
          MentionSuggestions(
            suggestions: _mentionSuggestions,
            onSelected: _onMentionSelected,
          ),

          // Attached chore preview
          if (_attachedChore != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.task_rounded, size: 18, color: Color(0xFF6C63FF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _attachedChore!.title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6C63FF)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _attachedChore = null),
                    child: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                  ),
                ],
              ),
            ),

          // Input bar
          Container(
            padding: EdgeInsets.only(
              left: 8,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2A) : Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2)),
              ],
            ),
            child: Row(
              children: [
                // Chore attach button
                IconButton(
                  onPressed: _showChorePicker,
                  icon: Icon(
                    Icons.attach_file_rounded,
                    color: _attachedChore != null ? const Color(0xFF6C63FF) : Colors.grey,
                  ),
                  tooltip: 'Attach chore',
                ),
                // Text input
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Type a message... Use @ to mention',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
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
                const SizedBox(width: 4),
                // Send button
                Container(
                  decoration: const BoxDecoration(color: Color(0xFF6C63FF), shape: BoxShape.circle),
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
