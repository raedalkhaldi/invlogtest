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

class _HomeScreenState extends State<HomeScreen> {
  final _firestore = FirebaseFirestore.instance;
  Stream<QuerySnapshot>? _checkInsStream;
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initCheckInsStream();
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

  Future<void> _toggleLike(String checkInId, List<String> currentLikes) async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    try {
      if (currentLikes.contains(user.id)) {
        // Unlike
        await _firestore.collection('checkins').doc(checkInId).update({
          'likedBy': FieldValue.arrayRemove([user.id]),
          'likes': FieldValue.increment(-1),
        });
      } else {
        // Like
        await _firestore.collection('checkins').doc(checkInId).update({
          'likedBy': FieldValue.arrayUnion([user.id]),
          'likes': FieldValue.increment(1),
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
          'Timeline',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _buildTimelineTab(),
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

  Widget _buildPostCard(CheckInModel checkIn) {
    final currentUser = context.read<AuthViewModel>().currentUser;

    return GestureDetector(
      onDoubleTap: () {
        if (currentUser != null) {
          _toggleLike(checkIn.id, checkIn.likedBy);
        }
      },
      child: widgets.CheckInCard(
        checkIn: checkIn,
        onLike: () {
          if (currentUser != null) {
            _toggleLike(checkIn.id, checkIn.likedBy);
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