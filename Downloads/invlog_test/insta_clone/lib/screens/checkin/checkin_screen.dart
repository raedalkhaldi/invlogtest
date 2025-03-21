import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../../providers/auth_provider.dart';
import '../../providers/checkin_provider.dart';
import '../../models/checkin_model.dart';
import '../../services/checkin_service.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _captionController = TextEditingController();
  List<Map<String, dynamic>> _nearbyRestaurants = [];

  @override
  void initState() {
    super.initState();
    _loadNearbyRestaurants();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _loadNearbyRestaurants() async {
    // TODO: Get actual location and nearby restaurants
    final checkInService = CheckInService();
    _nearbyRestaurants = await checkInService.getNearbyRestaurants(
      const GeoPoint(0, 0), // Replace with actual location
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      context.read<CheckInProvider>().setSelectedPhoto(File(image.path));
    }
  }

  Future<void> _createCheckIn() async {
    if (_formKey.currentState?.validate() ?? false) {
      final authProvider = context.read<AuthProvider>();
      final checkInProvider = context.read<CheckInProvider>();
      
      if (authProvider.user != null) {
        await checkInProvider.createCheckIn(
          authProvider.user!.uid,
          const GeoPoint(0, 0), // Replace with actual location
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check In'),
      ),
      body: Consumer<CheckInProvider>(
        builder: (context, checkInProvider, child) {
          if (checkInProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Restaurant Selection
                  DropdownButtonFormField<String>(
                    value: checkInProvider.selectedRestaurant,
                    decoration: const InputDecoration(
                      labelText: 'Select Restaurant',
                      border: OutlineInputBorder(),
                    ),
                    items: _nearbyRestaurants.map((restaurant) {
                      return DropdownMenuItem<String>(
                        value: restaurant['name'],
                        child: Text(restaurant['name']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      checkInProvider.setSelectedRestaurant(value);
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a restaurant';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Photo Selection
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: checkInProvider.selectedPhoto != null
                          ? Image.file(
                              checkInProvider.selectedPhoto!,
                              fit: BoxFit.cover,
                            )
                          : const Icon(Icons.add_a_photo, size: 50),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Caption
                  TextFormField(
                    controller: _captionController,
                    decoration: const InputDecoration(
                      labelText: 'Caption (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    onChanged: (value) {
                      checkInProvider.setCaption(value);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Error Message
                  if (checkInProvider.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        checkInProvider.error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _createCheckIn,
                    child: const Text('Check In'),
                  ),
                  const SizedBox(height: 32),

                  // Recent Check-ins
                  const Text(
                    'Recent Check-ins',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: checkInProvider.checkIns.length,
                    itemBuilder: (context, index) {
                      final checkIn = checkInProvider.checkIns[index];
                      return _CheckInCard(checkIn: checkIn);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CheckInCard extends StatelessWidget {
  final CheckInModel checkIn;

  const _CheckInCard({required this.checkIn});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (checkIn.photoUrl != null)
            Image.network(
              checkIn.photoUrl!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  checkIn.restaurantName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (checkIn.caption != null)
                  Text(checkIn.caption!),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        checkIn.likedBy.contains(context.read<AuthProvider>().user?.uid)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: Colors.red,
                      ),
                      onPressed: () {
                        if (context.read<AuthProvider>().user != null) {
                          context.read<CheckInProvider>().likeCheckIn(
                            checkIn.id,
                            context.read<AuthProvider>().user!.uid,
                          );
                        }
                      },
                    ),
                    Text('${checkIn.likes} likes'),
                    const Spacer(),
                    Text(
                      '${checkIn.createdAt.day}/${checkIn.createdAt.month}/${checkIn.createdAt.year}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 