import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/checkin_model.dart';
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

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
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
    final currentUser = context.read<AuthViewModel>().currentUser;
    final isOwnPost = currentUser?.id == widget.checkIn.userId;

    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              child: Text(
                widget.checkIn.username.isNotEmpty ?
                widget.checkIn.username[0].toUpperCase() : '?',
              ),
            ),
            title: Row(
              children: [
                Text(
                  widget.checkIn.displayName ?? widget.checkIn.username,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(' checked in at '),
                Text(
                  widget.checkIn.restaurantName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            subtitle: Text('@${widget.checkIn.username}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTimestamp(widget.checkIn.createdAt),
                  style: const TextStyle(color: Colors.grey),
                ),
                if (isOwnPost) ...[
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) async {
                      if (value == 'delete') {
                        final shouldDelete = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Check-in'),
                            content: const Text('Are you sure you want to delete this check-in?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (shouldDelete == true) {
                          try {
                            await context.read<CheckInProvider>().deleteCheckIn(widget.checkIn.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Check-in deleted successfully')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error deleting check-in: $e')),
                              );
                            }
                          }
                        }
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (widget.checkIn.photoUrl != null)
            Image.network(
              widget.checkIn.photoUrl!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.checkIn.caption != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(widget.checkIn.caption!),
                  ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onLike,
                      child: Icon(
                        widget.checkIn.likes.contains(
                          context.read<AuthViewModel>().currentUser?.id
                        )
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: widget.checkIn.likes.contains(
                          context.read<AuthViewModel>().currentUser?.id
                        )
                            ? Colors.red
                            : null,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('${widget.checkIn.likeCount}'),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: _toggleComments,
                      child: const Icon(Icons.comment_outlined),
                    ),
                    const SizedBox(width: 4),
                    Text('${widget.checkIn.commentCount}'),
                  ],
                ),
                if (_showComments) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  Consumer<CheckInProvider>(
                    builder: (context, provider, child) {
                      final comments = provider.getCommentsForCheckIn(widget.checkIn.id);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...comments.map((comment) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  child: Text(
                                    comment.username[0].toUpperCase(),
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
                                              text: comment.username,
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            TextSpan(text: ' ${comment.text}'),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        _formatTimestamp(comment.createdAt),
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
                          )),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _commentController,
                                  decoration: const InputDecoration(
                                    hintText: 'Add a comment...',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  onSubmitted: (_) => _addComment(),
                                ),
                              ),
                              const SizedBox(width: 8),
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
        ],
      ),
    );
  }
} 