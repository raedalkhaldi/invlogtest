import 'package:flutter/material.dart';
import '../models/checkin.dart';
import '../services/profile_service.dart';
import 'checkin_card.dart';

class LikedPostsTab extends StatelessWidget {
  final String userId;
  final ProfileService _profileService = ProfileService();

  LikedPostsTab({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CheckIn>>(
      stream: _profileService.getLikedPostsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return const Center(
            child: Text('No liked posts yet'),
          );
        }

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return CheckInCard(
              checkIn: post,
            );
          },
        );
      },
    );
  }
} 