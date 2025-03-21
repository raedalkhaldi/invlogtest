import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/user_provider.dart';
import '../../providers/checkin_provider.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadUserProfile(widget.userId);
      context.read<CheckInProvider>().loadUserCheckIns(widget.userId);
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      context.read<UserProvider>().setSelectedPhoto(File(pickedFile.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (widget.userId == context.read<UserProvider>().currentUser?.uid)
            IconButton(
              icon: Icon(_isEditing ? Icons.save : Icons.edit),
              onPressed: () {
                if (_isEditing) {
                  if (_formKey.currentState!.validate()) {
                    context.read<UserProvider>().updateProfile(widget.userId);
                  }
                }
                setState(() {
                  _isEditing = !_isEditing;
                });
              },
            ),
        ],
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          if (userProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (userProvider.error != null) {
            return Center(child: Text(userProvider.error!));
          }

          final user = userProvider.currentUser;
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: userProvider.selectedPhoto != null
                                ? FileImage(userProvider.selectedPhoto!)
                                : (user.photoUrl != null
                                    ? NetworkImage(user.photoUrl!)
                                    : null) as ImageProvider?,
                            child: userProvider.selectedPhoto == null &&
                                    user.photoUrl == null
                                ? const Icon(Icons.person, size: 50)
                                : null,
                          ),
                          if (_isEditing)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: CircleAvatar(
                                backgroundColor: Theme.of(context).primaryColor,
                                radius: 18,
                                child: IconButton(
                                  icon: const Icon(Icons.camera_alt, size: 18),
                                  onPressed: _pickImage,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_isEditing)
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                initialValue: user.username,
                                decoration: const InputDecoration(
                                  labelText: 'Username',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a username';
                                  }
                                  return null;
                                },
                                onChanged: (value) =>
                                    userProvider.setUsername(value),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                initialValue: user.bio,
                                decoration: const InputDecoration(
                                  labelText: 'Bio',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 3,
                                onChanged: (value) => userProvider.setBio(value),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: [
                            Text(
                              user.username ?? 'No username',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            if (user.bio != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                user.bio!,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ],
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatColumn(
                            'Check-ins',
                            user.checkInCount ?? 0,
                          ),
                          _buildStatColumn(
                            'Followers',
                            user.followers.length,
                          ),
                          _buildStatColumn(
                            'Following',
                            user.following.length,
                          ),
                        ],
                      ),
                      if (widget.userId != userProvider.currentUser?.uid) ...[
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            if (userProvider.isFollowing(widget.userId)) {
                              userProvider.unfollowUser(
                                userProvider.currentUser!.uid,
                                widget.userId,
                              );
                            } else {
                              userProvider.followUser(
                                userProvider.currentUser!.uid,
                                widget.userId,
                              );
                            }
                          },
                          child: Text(
                            userProvider.isFollowing(widget.userId)
                                ? 'Unfollow'
                                : 'Follow',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(),
                Consumer<CheckInProvider>(
                  builder: (context, checkInProvider, child) {
                    if (checkInProvider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final checkIns = checkInProvider.checkIns;
                    if (checkIns.isEmpty) {
                      return const Center(
                        child: Text('No check-ins yet'),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: checkIns.length,
                      itemBuilder: (context, index) {
                        final checkIn = checkIns[index];
                        return ListTile(
                          leading: checkIn.photoUrl != null
                              ? CircleAvatar(
                                  backgroundImage:
                                      NetworkImage(checkIn.photoUrl!),
                                )
                              : const CircleAvatar(
                                  child: Icon(Icons.restaurant),
                                ),
                          title: Text(checkIn.restaurantName),
                          subtitle: Text(
                            checkIn.caption ?? 'No caption',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  checkIn.likedBy.contains(widget.userId)
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: checkIn.likedBy.contains(widget.userId)
                                      ? Colors.red
                                      : null,
                                ),
                                onPressed: () {
                                  checkInProvider.likeCheckIn(
                                    checkIn.id,
                                    widget.userId,
                                  );
                                },
                              ),
                              Text('${checkIn.likes}'),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatColumn(String label, int count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
} 