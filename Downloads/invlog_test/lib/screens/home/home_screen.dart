import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:invlog_test/providers/auth_view_model.dart';
import 'package:invlog_test/screens/auth/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/profile_service.dart';
import '../../widgets/user_profile_card.dart';
import '../../models/checkin_model.dart';
import '../../widgets/checkin_card.dart' as widgets;
import '../../screens/profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  Stream<QuerySnapshot>? _checkInsStream;
  final _commentController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initCheckInsStream();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _initCheckInsStream() {
    print('Initializing check-ins stream...'); // Debug log
    _checkInsStream = _firestore
        .collection('checkins')
        .orderBy('createdAt', descending: true)
        .snapshots()
        ..listen(
          (snapshot) {
            print('Received ${snapshot.docs.length} check-ins'); // Debug log
            if (snapshot.docs.isNotEmpty) {
              final firstDoc = snapshot.docs.first.data() as Map<String, dynamic>;
              print('Most recent check-in:');
              print('- id: ${snapshot.docs.first.id}');
              print('- createdAt: ${firstDoc['createdAt']}');
              print('- restaurantName: ${firstDoc['restaurantName']}');
            }
          },
          onError: (error) => print('Error in check-ins stream: $error'),
        );
  }

  Stream<QuerySnapshot> _getLikedCheckInsStream(String userId) {
    print('Getting liked check-ins stream for user: $userId'); // Debug log
    return _firestore
        .collection('checkins')
        .where('likes', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _toggleLike(String checkInId, List<String> currentLikes) async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    try {
      if (currentLikes.contains(user.id)) {
        // Unlike
        await _firestore.collection('checkins').doc(checkInId).update({
          'likes': FieldValue.arrayRemove([user.id]),
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        // Like
        await _firestore.collection('checkins').doc(checkInId).update({
          'likes': FieldValue.arrayUnion([user.id]),
          'likeCount': FieldValue.increment(1),
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

  void _navigateToUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(userId: userId),
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
        title: const Text(
          'InvLog',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Timeline'),
            Tab(text: 'Nearby'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTimelineTab(),
          _buildNearbyTab(),
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
            final doc = posts[index];
            final checkIn = CheckInModel.fromFirestore(doc);
            return _buildPostCard(checkIn);
          },
        );
      },
    );
  }

  Widget _buildNearbyTab() {
    final currentUser = context.watch<AuthViewModel>().currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Please log in to see liked posts'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _getLikedCheckInsStream(currentUser.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Error in liked posts stream: ${snapshot.error}'); // Debug log
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data?.docs ?? [];
        print('Received ${posts.length} liked posts'); // Debug log
        
        if (posts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No liked posts yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Double tap or tap the heart to like posts',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final doc = posts[index];
            final checkIn = CheckInModel.fromFirestore(doc);
            return _buildPostCard(checkIn);
          },
        );
      },
    );
  }

  Widget _buildPostCard(CheckInModel checkIn) {
    final currentUser = context.read<AuthViewModel>().currentUser;

    return GestureDetector(
      onDoubleTap: () {
        if (currentUser != null) {
          _toggleLike(checkIn.id, checkIn.likes);
        }
      },
      child: widgets.CheckInCard(
        checkIn: checkIn,
        onLike: () {
          if (currentUser != null) {
            _toggleLike(checkIn.id, checkIn.likes);
          }
        },
        onUserTap: _navigateToUserProfile,
      ),
    );
  }

  void _showUserProfile(String userId) {
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