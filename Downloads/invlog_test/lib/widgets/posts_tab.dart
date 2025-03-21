import 'package:flutter/material.dart';
import '../models/checkin.dart';
import '../services/profile_service.dart';
import '../widgets/checkin_card.dart';

class _PostsTab extends StatelessWidget {
  final String userId;
  final ProfileService _profileService = ProfileService();

  _PostsTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CheckIn>>(
      stream: _profileService.getUserCheckInsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return const Center(child: Text('No posts yet'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CheckInCard(
                checkIn: post,
                onLike: () {
                  // TODO: Implement like functionality
                },
              ),
            );
          },
        );
      },
    );
  }
} 