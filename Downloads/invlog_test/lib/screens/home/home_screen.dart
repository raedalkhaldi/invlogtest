import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:invlog_test/providers/auth_view_model.dart';
import 'package:invlog_test/screens/auth/login_screen.dart';
import 'package:invlog_test/screens/checkin/checkin_screen.dart';
import 'package:invlog_test/screens/profile/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/profile_service.dart';
import '../../widgets/user_profile_card.dart';
import '../../models/checkin.dart';
import '../../models/comment.dart';
import '../../widgets/checkin_card.dart' as widgets;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final _firestore = FirebaseFirestore.instance;
  Stream<QuerySnapshot>? _checkInsStream;
  Stream<QuerySnapshot>? _exploreStream;
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initCheckInsStream();
    _initExploreStream();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _initCheckInsStream() {
    _checkInsStream = _firestore
        .collection('checkins')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  void _initExploreStream() {
    final currentUser = context.read<AuthViewModel>().currentUser;
    if (currentUser != null) {
      _exploreStream = _firestore
          .collection('checkins')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots();
    }
  }

  Future<void> _toggleLike(String checkInId, List<dynamic> currentLikes) async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    try {
      if (currentLikes.contains(user.id)) {
        // Unlike
        await _firestore.collection('checkins').doc(checkInId).update({
          'likes': FieldValue.arrayRemove([user.id])
        });
      } else {
        // Like
        await _firestore.collection('checkins').doc(checkInId).update({
          'likes': FieldValue.arrayUnion([user.id])
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _addComment(String checkInId) async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;

    try {
      // Get the user's profile first
      final userProfile = await context.read<ProfileService>().getUserProfile(user.id);
      if (userProfile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Could not fetch user profile')),
        );
        return;
      }

      await _firestore.collection('checkins').doc(checkInId).update({
        'comments': FieldValue.arrayUnion([
          {
            'userId': user.id,
            'userName': userProfile.displayName ?? userProfile.username,
            'userUsername': userProfile.username,
            'text': comment,
            'timestamp': Timestamp.now(),
          }
        ])
      });
      _commentController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void _showCommentDialog(String checkInId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 8,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add a Comment',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  hintText: 'Write your comment...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      _addComment(checkInId);
                      Navigator.pop(context);
                    },
                    child: const Text('Post'),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  void _showComments(BuildContext context, List<dynamic> comments) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${comments.length} ${comments.length == 1 ? 'Comment' : 'Comments'}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: comments.isEmpty
                  ? const Center(
                      child: Text('No comments yet. Be the first to comment!'),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(
                                    radius: 16,
                                    child: Icon(Icons.person, size: 20),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () {
                                      // Close the comments modal first
                                      Navigator.pop(context);
                                      // Then show the user profile
                                      if (comment['userId'] != null) {
                                        _showUserProfile(comment['userId']);
                                      }
                                    },
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          comment['userName'] ?? 'Anonymous',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (comment['userUsername'] != null)
                                          Text(
                                            '@${comment['userUsername']}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    comment['timestamp'] != null
                                        ? _formatTimestamp(comment['timestamp'] as Timestamp)
                                        : 'Just now',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 40, top: 4),
                                child: Text(comment['text']),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthViewModel>().currentUser;
    
    if (currentUser == null) {
      return const LoginScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0 ? 'Timeline' :
          _selectedIndex == 1 ? 'Explore' :
          _selectedIndex == 2 ? 'Check In' :
          'Profile',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildTimelineTab(),
          _buildExploreTab(),
          const CheckInScreen(),
          ProfileScreen(userId: currentUser.id),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Timeline',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_location),
            label: 'Check In',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _checkInsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data?.docs ?? [];
        
        if (posts.isEmpty) {
          return const Center(child: Text('No posts yet'));
        }

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index].data() as Map<String, dynamic>;
            return _buildPostCard(post, posts[index].id);
          },
        );
      },
    );
  }

  Widget _buildExploreTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _exploreStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data?.docs ?? [];
        
        if (posts.isEmpty) {
          return const Center(child: Text('No posts to explore'));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index].data() as Map<String, dynamic>;
            return _buildExploreCard(post, posts[index].id);
          },
        );
      },
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, String postId) {
    final currentUser = context.read<AuthViewModel>().currentUser;
    final likes = List<String>.from(post['likes'] ?? []);
    final comments = (post['comments'] as List<dynamic>? ?? [])
        .map((comment) => Comment.fromMap(comment as Map<String, dynamic>))
        .toList();
    
    // Debug print to check post data
    print('Post data for $postId:');
    print('Username: ${post['username']}');
    print('DisplayName: ${post['displayName']}');
    print('UserId: ${post['userId']}');
    
    // Convert the post data to a CheckIn model
    final checkIn = CheckIn(
      id: postId,
      userId: post['userId'] ?? '',
      username: post['username'] ?? '',  // Make sure username is not null
      displayName: post['displayName'] ?? post['username'] ?? 'Anonymous',  // Fallback chain: displayName -> username -> 'Anonymous'
      content: post['content'] ?? '',
      imageUrl: post['imageUrl'],
      timestamp: post['timestamp'] is Timestamp ? post['timestamp'].toDate() : DateTime.now(),
      likedBy: likes,
      isLiked: currentUser != null && likes.contains(currentUser.id),
      comments: comments,
      placeName: post['placeName'] ?? '',
      caption: post['caption'] ?? '',
    );

    // Debug print to check CheckIn model
    print('CheckIn model data:');
    print('Username: ${checkIn.username}');
    print('DisplayName: ${checkIn.displayName}');

    return GestureDetector(
      onTap: () async {
        // If username is empty, try to fetch user profile
        if (checkIn.username.isEmpty) {
          final userProfile = await context.read<ProfileService>().getUserProfile(checkIn.userId);
          if (userProfile != null && mounted) {
            // Update the post with the user's information
            await _firestore.collection('checkins').doc(postId).update({
              'username': userProfile.username,
              'displayName': userProfile.displayName,
            });
          }
        }
      },
      onDoubleTap: () {
        if (currentUser != null) {
          _toggleLike(postId, likes);
        }
      },
      child: widgets.CheckInCard(
        checkIn: checkIn,
        onLike: () {
          if (currentUser != null) {
            _toggleLike(postId, likes);
          }
        },
      ),
    );
  }

  Widget _buildExploreCard(Map<String, dynamic> post, String postId) {
    final currentUser = context.read<AuthViewModel>().currentUser;
    final likes = List<String>.from(post['likes'] ?? []);
    final comments = (post['comments'] as List<dynamic>? ?? [])
        .map((comment) => Comment.fromMap(comment as Map<String, dynamic>))
        .toList();
    
    // Convert the post data to a CheckIn model
    final checkIn = CheckIn(
      id: postId,
      userId: post['userId'] ?? '',
      username: post['username'] ?? '',  // Make sure username is not null
      displayName: post['displayName'] ?? post['username'] ?? 'Anonymous',  // Fallback chain: displayName -> username -> 'Anonymous'
      content: post['content'] ?? '',
      imageUrl: post['imageUrl'],
      timestamp: post['timestamp'] is Timestamp ? post['timestamp'].toDate() : DateTime.now(),
      likedBy: likes,
      isLiked: currentUser != null && likes.contains(currentUser.id),
      comments: comments,
      placeName: post['placeName'] ?? '',
      caption: post['caption'] ?? '',
    );

    return GestureDetector(
      onTap: () {
        // TODO: Show post details
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (checkIn.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  checkIn.imageUrl!,
                  fit: BoxFit.cover,
                ),
              ),
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${checkIn.likedBy.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showUserProfile(String userId) {
    if (userId.isEmpty) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Expanded(
              child: FutureBuilder(
                future: context.read<ProfileService>().getUserProfile(userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final profile = snapshot.data;
                  if (profile == null) {
                    return const Center(child: Text('Profile not found'));
                  }

                  final currentUser = context.read<AuthViewModel>().currentUser;
                  final isCurrentUser = currentUser?.id == userId;

                  return Column(
                    children: [
                      // Profile Header
                      UserProfileCard(
                        userId: userId,
                        username: profile.username,
                        displayName: profile.displayName,
                        isCurrentUser: isCurrentUser,
                      ),
                      if (profile.bio?.isNotEmpty ?? false)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(profile.bio!),
                        ),
                      const Divider(),
                      // User's Posts
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _firestore
                              .collection('checkins')
                              .where('userId', isEqualTo: userId)
                              .orderBy('timestamp', descending: true)
                              .limit(20)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            if (snapshot.hasError) {
                              print('Firestore Error: ${snapshot.error}');
                              if (snapshot.error.toString().contains('failed-precondition')) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('Index needed for this query.'),
                                      const SizedBox(height: 10),
                                      SelectableText(
                                        'Click here to create index: ${snapshot.error.toString().split("create it here: ")[1]}',
                                        style: const TextStyle(color: Colors.blue),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return Center(child: Text('Error: ${snapshot.error}'));
                            }

                            final posts = snapshot.data?.docs ?? [];
                            if (posts.isEmpty) {
                              return Center(
                                child: Text(
                                  isCurrentUser 
                                    ? 'You haven\'t made any check-ins yet!'
                                    : 'No check-ins yet!',
                                ),
                              );
                            }

                            return ListView.builder(
                              controller: scrollController,
                              itemCount: posts.length,
                              itemBuilder: (context, index) {
                                return _buildPostCard(posts[index].data() as Map<String, dynamic>, posts[index].id);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
} 