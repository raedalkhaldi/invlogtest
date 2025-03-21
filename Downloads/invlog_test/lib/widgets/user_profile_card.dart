import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/profile_service.dart';
import '../screens/profile/profile_screen.dart';

class UserProfileCard extends StatelessWidget {
  final String userId;
  final String username;
  final String? displayName;
  final bool isCurrentUser;

  const UserProfileCard({
    super.key,
    required this.userId,
    required this.username,
    this.displayName,
    required this.isCurrentUser,
  });

  void _navigateToProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(userId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final profileService = ProfileService();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            // Make avatar tappable
            GestureDetector(
              onTap: () => _navigateToProfile(context),
              child: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(
                  username[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Make username tappable
            Expanded(
              child: GestureDetector(
                onTap: () => _navigateToProfile(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName ?? username,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '@$username',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!isCurrentUser && currentUserId != null)
              FutureBuilder<bool>(
                future: profileService.isFollowing(currentUserId, userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  final isFollowing = snapshot.data ?? false;
                  return ElevatedButton(
                    onPressed: () {
                      if (isFollowing) {
                        profileService.unfollowUser(currentUserId, userId);
                      } else {
                        profileService.followUser(currentUserId, userId);
                      }
                    },
                    child: Text(isFollowing ? 'Following' : 'Follow'),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
} 