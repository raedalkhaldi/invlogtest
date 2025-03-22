import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/checkin_model.dart';
import '../models/comment_model.dart';
import '../providers/checkin_provider.dart';
import '../providers/auth_view_model.dart';

class CheckInCard extends StatefulWidget {
  final CheckInModel checkIn;
  final VoidCallback? onLike;
  final Function(String)? onUserTap;

  const CheckInCard({
    super.key,
    required this.checkIn,
    this.onLike,
    this.onUserTap,
  });

  @override
  State<CheckInCard> createState() => _CheckInCardState();
}

class _CheckInCardState extends State<CheckInCard> {
  bool _showComments = false;
  final _commentController = TextEditingController();
  bool _isPostingComment = false;

  @override
  void initState() {
    super.initState();
    print('CheckInCard.initState - Loading comments for check-in: ${widget.checkIn.id}'); // Debug log
    // Load comments immediately when the card is created
    context.read<CheckInProvider>().loadComments(widget.checkIn.id);
  }

  @override
  void didUpdateWidget(CheckInCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload comments if the check-in ID changes
    if (oldWidget.checkIn.id != widget.checkIn.id) {
      print('CheckInCard.didUpdateWidget - Reloading comments for check-in: ${widget.checkIn.id}'); // Debug log
      context.read<CheckInProvider>().loadComments(widget.checkIn.id);
    }
  }

  void _toggleComments() {
    setState(() {
      _showComments = !_showComments;
      if (_showComments) {
        print('CheckInCard._toggleComments - Loading comments for check-in: ${widget.checkIn.id}'); // Debug log
        context.read<CheckInProvider>().loadComments(widget.checkIn.id);
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(timestamp);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() {
      _isPostingComment = true;
    });

    try {
      final currentUser = context.read<AuthViewModel>().currentUser;
      if (currentUser == null) {
        throw Exception('User must be logged in to comment');
      }

      print('CheckInCard._addComment - Adding comment for check-in: ${widget.checkIn.id}'); // Debug log
      print('Current user: ${currentUser.id}'); // Debug log

      await context.read<CheckInProvider>().addComment(
        widget.checkIn.id,
        currentUser.id,
        _commentController.text.trim(),
      );
      _commentController.clear();
    } catch (e) {
      print('Error in CheckInCard._addComment: $e'); // Debug log
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting comment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPostingComment = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    widget.checkIn.username.isNotEmpty ? widget.checkIn.username[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onUserTap?.call(widget.checkIn.userId),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.checkIn.displayName ?? widget.checkIn.username,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  _formatTimestamp(widget.checkIn.timestamp),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    TextSpan(
                      text: '@${widget.checkIn.username}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => widget.onUserTap?.call(widget.checkIn.userId),
                    ),
                    const TextSpan(text: ' checked in at '),
                    TextSpan(
                      text: widget.checkIn.restaurantName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (widget.checkIn.caption != null && widget.checkIn.caption!.isNotEmpty)
              Text(widget.checkIn.caption!),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    widget.checkIn.likedBy.contains(context.read<AuthViewModel>().currentUser?.id)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: widget.checkIn.likedBy.contains(context.read<AuthViewModel>().currentUser?.id)
                        ? Colors.red
                        : null,
                  ),
                  onPressed: widget.onLike,
                ),
                Text('${widget.checkIn.likes}'),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.comment_outlined),
                  onPressed: _toggleComments,
                ),
                Text('${widget.checkIn.commentCount}'),
              ],
            ),
            if (_showComments) ...[
              const Divider(),
              Consumer<CheckInProvider>(
                builder: (context, provider, child) {
                  final comments = provider.getCommentsForCheckIn(widget.checkIn.id);
                  print('CheckInCard.build - Found ${comments.length} comments for check-in: ${widget.checkIn.id}'); // Debug log

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (comments.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text('No comments yet'),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: comments.length,
                          itemBuilder: (context, index) {
                            final comment = comments[index];
                            print('Rendering comment: $comment'); // Debug log
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Theme.of(context).primaryColor,
                                    child: Text(
                                      comment.username.isNotEmpty ? comment.username[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        RichText(
                                          text: TextSpan(
                                            style: DefaultTextStyle.of(context).style,
                                            children: [
                                              TextSpan(
                                                text: comment.displayName ?? comment.username,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              TextSpan(
                                                text: ' ${comment.text}',
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          DateFormat('MMM d, h:mm a').format(comment.createdAt),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              decoration: const InputDecoration(
                                hintText: 'Add a comment...',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              maxLines: 1,
                              onSubmitted: (_) => _addComment(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_isPostingComment)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.send),
                              onPressed: _addComment,
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
} 