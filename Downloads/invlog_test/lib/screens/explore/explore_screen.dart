import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_view_model.dart';
import '../../models/checkin_model.dart';
import '../../widgets/checkin_card.dart' as widgets;
import '../profile/profile_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _firestore = FirebaseFirestore.instance;
  Stream<QuerySnapshot>? _exploreStream;

  @override
  void initState() {
    super.initState();
    _initExploreStream();
  }

  void _initExploreStream() {
    _exploreStream = _firestore
        .collection('checkins')
        .orderBy('timestamp', descending: true)
        .limit(50)
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Explore',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
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

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final doc = posts[index];
              final checkIn = CheckInModel.fromFirestore(doc);
              return _buildPostCard(checkIn);
            },
          );
        },
      ),
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
} 