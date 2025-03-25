import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';
import '../../models/checkin_model.dart';
import '../../widgets/checkin_card.dart';
import '../../screens/auth/login_screen.dart';
import '../../providers/auth_view_model.dart';
import '../../screens/profile/followers_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ProfileService _profileService = ProfileService();
  bool _isFollowing = false;
  bool _isLoadingFollow = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    if (widget.userId != null && FirebaseAuth.instance.currentUser != null) {
      final isFollowing = await _profileService.isFollowing(widget.userId!);
      if (mounted) {
        setState(() {
          _isFollowing = isFollowing;
        });
      }
    }
  }

  Future<void> _toggleFollow(String userId) async {
    if (_isLoadingFollow) return;

    setState(() {
      _isLoadingFollow = true;
    });

    try {
      if (_isFollowing) {
        await _profileService.unfollowUser(userId);
      } else {
        await _profileService.followUser(userId);
      }
      
      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFollow = false;
        });
      }
    }
  }

  void _handleLogout(BuildContext context) async {
    try {
      await context.read<AuthViewModel>().signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging out: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final String profileId = widget.userId ?? currentUser!.uid;
    final bool isCurrentUser = profileId == currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (isCurrentUser)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _handleLogout(context),
            ),
        ],
      ),
      body: StreamBuilder<UserProfile?>(
        stream: _profileService.getUserProfileStream(profileId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final userProfile = snapshot.data;
          if (userProfile == null) {
            return const Center(child: Text('Profile not found'));
          }

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 200.0,
                  floating: false,
                  pinned: true,
                  actions: [
                    if (isCurrentUser)
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'logout') {
                            FirebaseAuth.instance.signOut();
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem<String>(
                            value: 'logout',
                            child: Row(
                              children: [
                                Icon(Icons.logout),
                                SizedBox(width: 8),
                                Text('Logout'),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        image: userProfile.profileImageUrl != null
                            ? DecorationImage(
                                image: NetworkImage(userProfile.profileImageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userProfile.displayName ?? userProfile.username,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '@${userProfile.username}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (userProfile.bio?.isNotEmpty ?? false)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(userProfile.bio!),
                                  ),
                              ],
                            ),
                            if (isCurrentUser)
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/edit-profile');
                                },
                                icon: const Icon(Icons.settings),
                                label: const Text('Edit Profile'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[200],
                                  foregroundColor: Colors.black,
                                ),
                              )
                            else if (currentUser != null)
                              _isLoadingFollow
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : ElevatedButton.icon(
                                    onPressed: () => _toggleFollow(profileId),
                                    icon: Icon(_isFollowing ? Icons.person_remove : Icons.person_add),
                                    label: Text(_isFollowing ? 'Unfollow' : 'Follow'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isFollowing ? Colors.grey[200] : Theme.of(context).primaryColor,
                                      foregroundColor: _isFollowing ? Colors.black : Colors.white,
                                    ),
                                  ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            StreamBuilder<int>(
                              stream: _profileService.getCheckInCountStream(userProfile.id),
                              builder: (context, snapshot) {
                                final count = snapshot.data ?? 0;
                                print('Check-in count: $count'); // Debug log
                                return _buildStatColumn(
                                  count.toString(),
                                  'Check-ins',
                                );
                              },
                            ),
                            StreamBuilder<UserProfile>(
                              stream: _profileService.getFollowingCountStream(userProfile.id),
                              builder: (context, snapshot) {
                                final following = snapshot.data?.following?.length ?? 0;
                                return _buildStatColumn(
                                  following.toString(),
                                  'Following',
                                  onTap: () {
                                    if (userProfile.id.isNotEmpty) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => FollowersScreen(
                                            userId: userProfile.id,
                                            isFollowers: false,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                            StreamBuilder<UserProfile>(
                              stream: _profileService.getFollowersCountStream(userProfile.id),
                              builder: (context, snapshot) {
                                final followers = snapshot.data?.followers?.length ?? 0;
                                return _buildStatColumn(
                                  followers.toString(),
                                  'Followers',
                                  onTap: () {
                                    if (userProfile.id.isNotEmpty) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => FollowersScreen(
                                            userId: userProfile.id,
                                            isFollowers: true,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: Theme.of(context).primaryColor,
                      unselectedLabelColor: Colors.grey,
                      tabs: const [
                        Tab(text: 'Check-ins'),
                        Tab(text: 'Likes'),
                        Tab(text: 'Favorites'),
                      ],
                    ),
                  ),
                  pinned: true,
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _CheckInsTab(userId: profileId),
                _LikesTab(userId: profileId),
                _FavoritesTab(userId: profileId),
              ],
            ),
          );
        },
      ),
      floatingActionButton: ElevatedButton(
        onPressed: () async {
          try {
            await _profileService.cleanupLikedByField();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cleanup completed successfully')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error during cleanup: $e')),
              );
            }
          }
        },
        child: const Text('Cleanup likedBy fields'),
      ),
    );
  }

  Widget _buildStats() {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final String profileId = widget.userId ?? currentUser!.uid;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        StreamBuilder<int>(
          stream: context.read<ProfileService>().getCheckInCountStream(profileId),
          builder: (context, snapshot) {
            final count = snapshot.data ?? 0;
            return _buildStatColumn(
              count.toString(),
              'Check-ins',
            );
          },
        ),
        StreamBuilder<UserProfile>(
          stream: context.read<ProfileService>().getFollowingCountStream(profileId),
          builder: (context, snapshot) {
            final count = snapshot.data?.following?.length ?? 0;
            return _buildStatColumn(
              count.toString(),
              'Following',
              onTap: () => _showFollowList(true),
            );
          },
        ),
        StreamBuilder<UserProfile>(
          stream: context.read<ProfileService>().getFollowersCountStream(profileId),
          builder: (context, snapshot) {
            final count = snapshot.data?.followers?.length ?? 0;
            return _buildStatColumn(
              count.toString(),
              'Followers',
              onTap: () => _showFollowList(false),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatColumn(String count, String label, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            count,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showFollowList(bool isFollowers) {
    // Implementation of _showFollowList method
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

class _CheckInsTab extends StatelessWidget {
  final String userId;
  final _profileService = ProfileService();

  _CheckInsTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CheckInModel>>(
      stream: _profileService.getUserCheckInsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final checkIns = snapshot.data ?? [];

        if (checkIns.isEmpty) {
          return const Center(child: Text('No check-ins yet'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: checkIns.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CheckInCard(
                checkIn: checkIns[index],
                onUserTap: (userId) {
                  // No need to navigate since we're already in the profile
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _LikesTab extends StatelessWidget {
  final String userId;
  final _profileService = ProfileService();

  _LikesTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    print('Building LikesTab for user: $userId'); // Debug log
    return StreamBuilder<List<CheckInModel>>(
      stream: _profileService.getLikedPostsStream(userId),
      builder: (context, snapshot) {
        // Add detailed debug logging
        print('LikesTab Stream Status: ${snapshot.connectionState}');
        if (snapshot.hasData) {
          print('Found ${snapshot.data?.length} liked posts');
          if (snapshot.data?.isNotEmpty ?? false) {
            final firstPost = snapshot.data!.first;
            print('First liked post ID: ${firstPost.id}');
            print('First liked post likes array: ${firstPost.likes}');
          }
        }
        if (snapshot.hasError) {
          print('LikesTab Error: ${snapshot.error}');
          if (snapshot.error is FirebaseException) {
            final error = snapshot.error as FirebaseException;
            print('Firebase error code: ${error.code}');
            print('Firebase error message: ${error.message}');
          }
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        final likedCheckIns = snapshot.data ?? [];
        if (likedCheckIns.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No liked check-ins yet',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: likedCheckIns.length,
          itemBuilder: (context, index) {
            final checkIn = likedCheckIns[index];
            print('Rendering liked checkIn: ${checkIn.id}'); // Debug log
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CheckInCard(
                checkIn: checkIn,
                onUserTap: (userId) {
                  Navigator.pushNamed(
                    context,
                    '/profile',
                    arguments: userId,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _FavoritesTab extends StatelessWidget {
  final String userId;
  final _profileService = ProfileService();

  _FavoritesTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CheckInModel>>(
      stream: _profileService.getLikedPostsStream(userId), // Reusing liked posts stream for now
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final favoriteCheckIns = snapshot.data ?? [];

        if (favoriteCheckIns.isEmpty) {
          return const Center(child: Text('No favorite check-ins'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: favoriteCheckIns.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CheckInCard(
                checkIn: favoriteCheckIns[index],
                onUserTap: (userId) {
                  // No need to navigate since we're already in the profile
                },
              ),
            );
          },
        );
      },
    );
  }
} 