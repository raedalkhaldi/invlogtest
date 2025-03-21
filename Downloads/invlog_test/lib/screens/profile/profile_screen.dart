import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/profile_provider.dart';
import '../../models/user_profile.dart';
import '../../models/checkin.dart';
import '../../services/profile_service.dart';
import '../../widgets/custom_app_bar.dart';
// Add this import for ThemeProvider
import 'dart:html' as html;
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_view_model.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  late final TabController _tabController;
  final ProfileService _profileService = ProfileService();
  int _currentIndex = 0;
  String? _effectiveUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _currentIndex,
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentIndex = _tabController.index;
        });
      }
    });
  }

  String _getUserId(BuildContext context) {
    if (_effectiveUserId != null) {
      return _effectiveUserId!;
    }
    
    // Use the provided userId or fall back to the current authenticated user
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    _effectiveUserId = widget.userId ?? authViewModel.currentUser?.id;
    
    if (_effectiveUserId == null) {
      // If no user ID is available, show an error
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No user ID available')),
        );
      });
      _effectiveUserId = '0'; // Dummy ID to prevent NPE
    }
    
    return _effectiveUserId!;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = _getUserId(context);
    
    return Scaffold(
      appBar: const CustomAppBar(title: 'Profile'),
      body: Column(
        children: [
          // Profile Info Section
          FutureBuilder<UserProfile?>(
            future: _profileService.getUserProfile(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final userProfile = snapshot.data;
              if (userProfile == null) {
                return const Center(child: Text('User not found'));
              }

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userProfile.displayName ?? userProfile.username,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text('@${userProfile.username}'),
                    if (userProfile.bio != null && userProfile.bio!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(userProfile.bio!),
                      ),
                  ],
                ),
              );
            },
          ),
          // Custom Tab Bar
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 2.0,
                ),
              ),
            ),
            child: Row(
              children: [
                _buildTab(0, 'Posts', Icons.grid_on),
                _buildTab(1, 'Liked', Icons.favorite),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _buildPostsList(),
                _buildLikedPostsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String text, IconData icon) {
    final isSelected = _currentIndex == index;
    
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _currentIndex = index;
            _tabController.animateTo(index);
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                width: 3.0,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('checkins')
          .where('userId', isEqualTo: _getUserId(context))
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: \\${snapshot.error}'));
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

  Widget _buildPostCard(Map<String, dynamic> post, String postId) {
    // Try to get the AuthViewModel safely
    AuthViewModel? authViewModel;
    try {
      authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    } catch (e) {
      // Provider not available
    }
    
    final currentUser = authViewModel?.currentUser;
    final likes = List<String>.from(post['likes'] ?? []);
    final isLiked = currentUser != null && likes.contains(currentUser.id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(post['username']?[0]?.toUpperCase() ?? 'A'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post['displayName'] ?? post['username'] ?? 'Anonymous',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        post['placeName'] ?? 'Unknown location',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (post['imageUrl'] != null) ...[
              const SizedBox(height: 8),
              Image.network(
                post['imageUrl'],
                fit: BoxFit.cover,
                width: double.infinity,
                height: 200,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image, size: 50),
                ),
              ),
            ],
            if (post['caption'] != null) ...[
              const SizedBox(height: 8),
              Text(post['caption']),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : null,
                ),
                const SizedBox(width: 4),
                Text('${likes.length}'),
                const SizedBox(width: 16),
                const Icon(Icons.comment_outlined),
                const SizedBox(width: 4),
                Text('${(post['comments'] ?? []).length}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLikedPostsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('checkins')
          .where('likes', arrayContains: _getUserId(context))
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data?.docs ?? [];
        if (posts.isEmpty) {
          return const Center(child: Text('No liked posts yet'));
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

  void launchFirebaseIndexUrl(BuildContext context, String url) {
    try {
      html.window.open(url, '_blank');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not open URL automatically'),
          action: SnackBarAction(
            label: 'Copy URL',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('URL copied to clipboard')),
              );
            },
          ),
        ),
      );
    }
  }

  void _toggleLike(String postId, List<String> likes) {
    final currentUser = context.read<AuthViewModel>().currentUser;
    if (currentUser == null) return;

    try {
      if (likes.contains(currentUser.id)) {
        // Unlike
        FirebaseFirestore.instance.collection('checkins').doc(postId).update({
          'likes': FieldValue.arrayRemove([currentUser.id])
        });
      } else {
        // Like
        FirebaseFirestore.instance.collection('checkins').doc(postId).update({
          'likes': FieldValue.arrayUnion([currentUser.id])
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
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
                      child: Text('No comments yet'),
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
                                  Column(
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
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 40, top: 4),
                                child: Text(comment['text'] ?? ''),
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
}

class ProfileHeader extends StatelessWidget {
  final String userId;
  final bool isCurrentUser;

  const ProfileHeader({
    super.key,
    required this.userId,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: context.read<ProfileProvider>().getUserProfile(userId),
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

        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      profile.username[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName?.isNotEmpty == true ? profile.displayName! : profile.username,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '@${profile.username}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (profile.bio?.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                Text(profile.bio!),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat('Check-ins', 127), // Replace with actual count
                  _buildStat('Following', profile.following.length),
                  _buildStat('Followers', profile.followers.length),
                ],
              ),
              const SizedBox(height: 16),
              if (isCurrentUser)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/edit-profile');
                    },
                    child: const Text('Edit Profile'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStat(String label, int value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}

class CheckInCard extends StatelessWidget {
  final CheckIn checkIn;

  const CheckInCard({
    super.key,
    required this.checkIn,
  });

  @override
  Widget build(BuildContext context) {
    final timestamp = checkIn.timestamp;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        checkIn.placeName ?? 'Unknown Place',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '@${checkIn.username} checked in at "${checkIn.placeName}"',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatTimestamp(timestamp),
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            if (checkIn.caption != null) ...[
              const SizedBox(height: 12),
              Text(checkIn.caption!),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    checkIn.isLiked
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: checkIn.isLiked ? Colors.red : null,
                  ),
                  onPressed: () {
                    // Handle like
                  },
                ),
                Text('${checkIn.likes}'),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.comment_outlined),
                  onPressed: () {
                    // Handle comment
                  },
                ),
                Text('${checkIn.comments.length}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }
} 