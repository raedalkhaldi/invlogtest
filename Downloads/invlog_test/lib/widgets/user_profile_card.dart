import 'package:flutter/material.dart';
import '../services/profile_service.dart';

class UserProfileCard extends StatelessWidget {
  final String userId;
  final String username;
  final String? displayName;
  final bool isCurrentUser;
  final ProfileService profileService;

  UserProfileCard({
    super.key,
    required this.userId,
    required this.username,
    this.displayName,
    required this.isCurrentUser,
  }) : profileService = ProfileService();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName ?? username,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '@$username',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (!isCurrentUser)
              FutureBuilder<bool>(
                future: profileService.isFollowing(userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }

                  final isFollowing = snapshot.data ?? false;

                  return TextButton.icon(
                    onPressed: () async {
                      try {
                        if (isFollowing) {
                          await profileService.unfollowUser(userId);
                        } else {
                          await profileService.followUser(userId);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${e.toString()}')),
                          );
                        }
                      }
                    },
                    icon: Icon(
                      isFollowing ? Icons.person_remove : Icons.person_add,
                      size: 20,
                    ),
                    label: Text(isFollowing ? 'Unfollow' : 'Follow'),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
} 