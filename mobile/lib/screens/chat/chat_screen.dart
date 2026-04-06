import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../models/chore.dart';
import '../../models/family_member.dart';
import '../../models/message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chore_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/message_provider.dart';
import '../../widgets/chore_picker.dart';
import '../../widgets/date_separator.dart';
import '../../widgets/mention_suggestions.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/reply_preview.dart';
import '../../widgets/typing_indicator.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isAtBottom = true;
  bool _showScrollToBottom = false;
  bool _isSearching = false;
  Chore? _attachedChore;
  Message? _replyingTo;
  List<FamilyMember> _mentionSuggestions = [];
  List<String> _mentionedUserIds = [];
  final _imagePicker = ImagePicker();
  bool _isUploading = false;
  Timer? _mentionDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _textController.addListener(_onTextChanged);

    // Listen for new messages — auto scroll and mark read
    ref.listenManual(messageProvider, (prev, next) {
      if (_isAtBottom && (prev?.messages.length ?? 0) < next.messages.length) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
      if (_isAtBottom) {
        Future.delayed(const Duration(milliseconds: 500), _markVisibleAsRead);
      }
    });
  }

  @override
  void dispose() {
    _mentionDebounce?.cancel();
    _textController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // With reverse: true, scrolling UP (toward older) increases pixels
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50) {
      ref.read(messageProvider.notifier).loadMore();
    }
    // With reverse: true, "at bottom" (newest) means pixels near 0
    final atBottom = _scrollController.position.pixels <= 100;
    if (_isAtBottom != atBottom || _showScrollToBottom == atBottom) {
      setState(() {
        _isAtBottom = atBottom;
        _showScrollToBottom = !atBottom;
      });
    }
  }

  void _onTextChanged() {
    _mentionDebounce?.cancel();
    _mentionDebounce = Timer(const Duration(milliseconds: 150), _processMentions);
  }

  void _processMentions() {
    final text = _textController.text;
    final cursorPos = _textController.selection.baseOffset;
    if (cursorPos < 0) return;

    final textUpToCursor = text.substring(0, cursorPos);
    final lastAt = textUpToCursor.lastIndexOf('@');

    if (lastAt >= 0) {
      final afterAt = textUpToCursor.substring(lastAt + 1);
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
        0, // With reverse: true, 0 is the newest message (bottom)
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

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(source: source, imageQuality: 70, maxWidth: 1200);
    if (picked == null) return;

    setState(() => _isUploading = true);
    final imageUrl = await ref.read(messageProvider.notifier).uploadImage(File(picked.path));
    setState(() => _isUploading = false);

    if (imageUrl != null) {
      ref.read(messageProvider.notifier).sendMessage(
        'Sent a photo',
        imageUrl: imageUrl,
        replyToId: _replyingTo?.id,
        choreId: _attachedChore?.id,
        mentionUserIds: _mentionedUserIds.isNotEmpty ? _mentionedUserIds : null,
      );
      _clearInputState();
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Send Photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _ImageSourceOption(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ImageSourceOption(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onReply(Message message) {
    setState(() => _replyingTo = message);
    // Focus the text field
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _clearInputState() {
    _textController.clear();
    setState(() {
      _attachedChore = null;
      _replyingTo = null;
      _mentionedUserIds = [];
      _mentionSuggestions = [];
    });
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
      replyToId: _replyingTo?.id,
    );

    _clearInputState();
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _markVisibleAsRead() {
    final messages = ref.read(messageProvider).messages;
    final user = ref.read(authProvider).user;
    if (user == null || messages.isEmpty) return;

    // Mark last 20 visible messages as read
    final toMark = messages
        .reversed
        .take(20)
        .where((m) => m.userId != user.id)
        .map((m) => m.id)
        .toList();

    if (toMark.isNotEmpty) {
      ref.read(messageProvider.notifier).markMessagesRead(toMark);
    }
  }

  /// Check if we need a date separator between two messages
  bool _needsDateSeparator(int index, List<Message> messages) {
    if (index == 0) return true;
    try {
      final current = DateTime.parse(messages[index].createdAt);
      final previous = DateTime.parse(messages[index - 1].createdAt);
      return current.year != previous.year ||
          current.month != previous.month ||
          current.day != previous.day;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProvider);
    final messages = ref.watch(messageProvider);
    final currentUser = ref.watch(authProvider).user;

    if (family.currentFamily == null && family.hasLoadError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade600),
              const SizedBox(height: 16),
              const Text('Connection Problem', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Could not load chat. Check your connection.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => ref.read(familyProvider.notifier).loadFamilies(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final memberNames = <String, String>{};
    for (final m in family.members) {
      memberNames[m.userId] = m.user?.displayName ?? 'Unknown';
    }

    final typingNames = messages.typingUserIds
        .map((id) => memberNames[id] ?? 'Someone')
        .toList();

    return Scaffold(
      appBar: _isSearching
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  setState(() => _isSearching = false);
                  _searchController.clear();
                  ref.read(messageProvider.notifier).clearSearch();
                },
              ),
              title: TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search messages...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  border: InputBorder.none,
                  filled: false,
                ),
                onSubmitted: (query) {
                  ref.read(messageProvider.notifier).searchMessages(query);
                },
              ),
              actions: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(messageProvider.notifier).clearSearch();
                    },
                  ),
              ],
            )
          : AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(family.currentFamily?.name ?? 'Chat', style: const TextStyle(fontSize: 18)),
                  Text('${family.members.length} members',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w400)),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search_rounded, size: 22),
                  onPressed: () => setState(() => _isSearching = true),
                ),
              ],
            ),
      body: Stack(
        children: [
          Column(
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
                                Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.grey.shade700),
                                const SizedBox(height: 16),
                                Text(
                                  messages.isSearching ? 'No messages found' : 'No messages yet',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                                ),
                                if (!messages.isSearching) ...[
                                  const SizedBox(height: 4),
                                  Text('Say hi to your family!', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                ],
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.only(top: 12, bottom: 8),
                            itemCount: messages.messages.length,
                            itemBuilder: (context, index) {
                              // reverse: true flips the list, so index 0 = newest
                              final reversedIndex = messages.messages.length - 1 - index;
                              final msg = messages.messages[reversedIndex];
                              final isMe = msg.userId == currentUser?.id;
                              final showName = reversedIndex == 0 || messages.messages[reversedIndex - 1].userId != msg.userId;
                              final showDateSeparator = _needsDateSeparator(reversedIndex, messages.messages);

                              return Column(
                                children: [
                                  if (showDateSeparator)
                                    DateSeparator(dateStr: msg.createdAt),
                                  MessageBubble(
                                    message: msg,
                                    isMe: isMe,
                                    showName: showName || showDateSeparator,
                                    memberNames: memberNames,
                                    currentUserId: currentUser?.id ?? '',
                                    onChoreTap: msg.hasChoreAttachment
                                        ? () => context.push('/chores/${msg.choreId}')
                                        : null,
                                    onReply: _onReply,
                                    onReaction: (emoji) {
                                      ref.read(messageProvider.notifier).toggleReaction(msg.id, emoji);
                                    },
                                    onDelete: isMe ? () {
                                      ref.read(messageProvider.notifier).deleteMessage(msg.id);
                                    } : null,
                                  ),
                                ],
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

              // Reply preview
              if (_replyingTo != null)
                ReplyPreviewBar(
                  replyingTo: _replyingTo!,
                  onCancel: () => setState(() => _replyingTo = null),
                ),

              // Attached chore preview
              if (_attachedChore != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.task_rounded, size: 18, color: AppTheme.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _attachedChore!.title,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.accent),
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

              // Upload progress
              if (_isUploading)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('Uploading photo...', style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2)),
                  ],
                ),
                child: Row(
                  children: [
                    // Attach menu
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.add_circle_outline_rounded,
                        color: _attachedChore != null ? AppTheme.accent : Colors.grey,
                      ),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (value) {
                        if (value == 'chore') _showChorePicker();
                        if (value == 'photo') _showImageSourcePicker();
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 'photo', child: Row(children: [
                          Icon(Icons.photo_rounded, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                          const SizedBox(width: 10),
                          Text('Photo', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                        ])),
                        PopupMenuItem(value: 'chore', child: Row(children: [
                          Icon(Icons.task_rounded, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                          const SizedBox(width: 10),
                          Text('Chore', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                        ])),
                      ],
                    ),
                    // Text input
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: InputDecoration(
                          hintText: 'Type a message... Use @ to mention',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                      decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
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

          // Scroll to bottom FAB
          if (_showScrollToBottom)
            Positioned(
              right: 16,
              bottom: 100,
              child: GestureDetector(
                onTap: _scrollToBottom,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.keyboard_arrow_down_rounded, color: Theme.of(context).colorScheme.onSurface, size: 24),
                      if (messages.unreadCount > 0)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppTheme.accent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              messages.unreadCount > 9 ? '9+' : '${messages.unreadCount}',
                              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImageSourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImageSourceOption({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppTheme.accent),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }
}
