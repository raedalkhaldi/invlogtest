import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/checkin_provider.dart';
import '../../models/checkin_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load check-ins when the screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user != null) {
        context.read<CheckInProvider>().loadUserCheckIns(authProvider.user!.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthProvider>().signOut();
            },
          ),
        ],
      ),
      body: Consumer<CheckInProvider>(
        builder: (context, checkInProvider, child) {
          if (checkInProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (checkInProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    checkInProvider.error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      final authProvider = context.read<AuthProvider>();
                      if (authProvider.user != null) {
                        checkInProvider.loadUserCheckIns(authProvider.user!.uid);
                      }
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (checkInProvider.checkIns.isEmpty) {
            return const Center(
              child: Text('No check-ins yet. Be the first to check in!'),
            );
          }

          return ListView.builder(
            itemCount: checkInProvider.checkIns.length,
            itemBuilder: (context, index) {
              final checkIn = checkInProvider.checkIns[index];
              return _CheckInCard(checkIn: checkIn);
            },
          );
        },
      ),
    );
  }
}

class _CheckInCard extends StatefulWidget {
  final CheckInModel checkIn;

  const _CheckInCard({required this.checkIn});

  @override
  State<_CheckInCard> createState() => _CheckInCardState();
}

class _CheckInCardState extends State<_CheckInCard> {
  final _commentController = TextEditingController();
  bool _isCommenting = false;

  @override
  void initState() {
    super.initState();
    // Load comments when the card is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CheckInProvider>().loadComments(widget.checkIn.id);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final authProvider = context.read<AuthProvider>();
    if (authProvider.user != null) {
      await context.read<CheckInProvider>().addComment(
        widget.checkIn.id,
        authProvider.user!.uid,
        _commentController.text.trim(),
      );
      _commentController.clear();
      setState(() {
        _isCommenting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                Text(
                  widget.checkIn.restaurantName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (widget.checkIn.caption != null)
                  Text(widget.checkIn.caption!),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        widget.checkIn.likes.contains(context.read<AuthProvider>().user?.uid)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: Colors.red,
                      ),
                      onPressed: () {
                        if (context.read<AuthProvider>().user != null) {
                          context.read<CheckInProvider>().likeCheckIn(
                            widget.checkIn.id,
                            context.read<AuthProvider>().user!.uid,
                          );
                        }
                      },
                    ),
                    Text('${widget.checkIn.likeCount} likes'),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.comment_outlined),
                      onPressed: () {
                        setState(() {
                          _isCommenting = !_isCommenting;
                        });
                      },
                    ),
                    Text('${widget.checkIn.commentCount} comments'),
                    const Spacer(),
                    Text(
                      '${widget.checkIn.createdAt.day}/${widget.checkIn.createdAt.month}/${widget.checkIn.createdAt.year}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                if (_isCommenting) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: const InputDecoration(
                            hintText: 'Add a comment...',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: null,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _addComment,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Consumer<CheckInProvider>(
                  builder: (context, checkInProvider, child) {
                    final comments = checkInProvider.getCommentsForCheckIn(widget.checkIn.id);
                    if (comments.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        const SizedBox(height: 8),
                        ...comments.map((comment) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CircleAvatar(
                                radius: 16,
                                child: Icon(Icons.person, size: 16),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      comment.text,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    Text(
                                      '${comment.createdAt.hour}:${comment.createdAt.minute}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (comment.userId == context.read<AuthProvider>().user?.uid)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 16),
                                  onPressed: () {
                                    checkInProvider.deleteComment(
                                      comment.id,
                                      widget.checkIn.id,
                                    );
                                  },
                                ),
                            ],
                          ),
                        )).toList(),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 