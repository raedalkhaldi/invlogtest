import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';

class FollowersScreen extends StatelessWidget {
  final String userId;
  final bool isFollowers; // true for followers, false for following
  final ProfileService _profileService = ProfileService();

  FollowersScreen({
    Key? key,
    required this.userId,
    required this.isFollowers,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isFollowers ? 'Followers' : 'Following'),
      ),
      body: StreamBuilder<List<UserProfile>>(
        stream: isFollowers
            ? _profileService.getFollowersStream(userId)
            : _profileService.getFollowingStream(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return Center(
              child: Text(
                isFollowers ? 'No followers yet' : 'Not following anyone',
                style: const TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: user.profileImageUrl != null
                      ? NetworkImage(user.profileImageUrl!)
                      : null,
                  child: user.profileImageUrl == null
                      ? Text(user.username[0].toUpperCase())
                      : null,
                ),
                title: Text(user.displayName ?? user.username),
                subtitle: Text('@${user.username}'),
                trailing: !isFollowers
                    ? TextButton(
                        onPressed: () async {
                          try {
                            await _profileService.unfollowUser(user.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Unfollowed ${user.username}'),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                              ),
                            );
                          }
                        },
                        child: const Text('Unfollow'),
                      )
                    : null,
                onTap: () {
                  // Navigate to user's profile
                  Navigator.pushNamed(
                    context,
                    '/profile',
                    arguments: user.id,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
} 