# InvLog - Location Check-in App

InvLog is a social check-in application built with Flutter that allows users to share their locations and experiences with others.

## Features

### Authentication
- Email and password sign-up/login
- User profile creation with username and display name
- Secure authentication using Firebase Auth

### Check-ins
- Create location-based check-ins with place names
- Add captions to your check-ins
- Automatic location detection using device GPS
- View check-ins in a timeline format
- Explore other users' check-ins in a grid view

### Social Features
- Like/unlike check-ins
- View likes count on each check-in
- Comment on check-ins
- View user profiles
- See user's check-in history
- Real-time updates using Firebase

### User Interface
- Clean and modern Material Design
- Bottom navigation for easy access to main features:
  - Timeline: View all check-ins in chronological order
  - Explore: Discover check-ins from all users
  - Check-in: Create new location check-ins
  - Profile: View and manage your profile
- Responsive layout that works on both mobile and web platforms

### Technical Features
- Real-time data synchronization with Firebase
- Efficient data loading and pagination
- Location services integration
- State management using Provider
- Clean architecture and code organization

## Project Structure

```
lib/
├── main.dart                 # Application entry point
├── models/                   # Data models
│   ├── checkin.dart         # Check-in model
│   ├── comment.dart         # Comment model
│   └── user_profile.dart    # User profile model
├── providers/               # State management
│   └── auth_view_model.dart # Authentication state management
├── screens/                 # UI screens
│   ├── auth/               # Authentication screens
│   │   └── login_screen.dart
│   ├── checkin/            # Check-in functionality
│   │   └── checkin_screen.dart
│   ├── home/               # Main app screens
│   │   └── home_screen.dart
│   └── profile/            # Profile screens
│       └── profile_screen.dart
├── services/               # Business logic and API calls
│   └── profile_service.dart # User profile management
└── widgets/               # Reusable UI components
    ├── checkin_card.dart  # Check-in display widget
    └── user_profile_card.dart # User profile display widget
```

## Component Relationships

### Authentication Flow
```dart
LoginScreen -> AuthViewModel -> Firebase Auth
  ↳ Success -> HomeScreen
  ↳ Error -> Show error message
```

### Check-in Creation Flow
```dart
CheckInScreen
  ↳ Gets location using Geolocator
  ↳ Creates Firestore document
  ↳ Updates Timeline in HomeScreen
```

### Timeline Implementation
```dart
HomeScreen
  ├── StreamBuilder<QuerySnapshot>
  │   └── Listens to Firestore 'checkins' collection
  └── _buildPostCard()
      └── Creates CheckInCard widget for each document
```

### Check-in Card Implementation
```dart
CheckInCard
  ├── Displays user info, location, and timestamp
  ├── Handles likes through onLike callback
  └── Shows comments count and place name
```

## Key Components

### Models

#### CheckIn Model
```dart
class CheckIn {
  final String id;
  final String userId;
  final String username;
  final String? displayName;
  final String content;
  final String? imageUrl;
  final DateTime timestamp;
  final List<String> likedBy;
  final bool isLiked;
  final List<Comment> comments;
  final String? placeName;
  final String? caption;
}
```

### Screens

#### HomeScreen
- Manages bottom navigation
- Implements timeline and explore views
- Handles check-in interactions (likes, comments)
- Uses StreamBuilder for real-time updates

#### CheckInScreen
- Handles location detection
- Manages check-in form
- Creates Firestore documents
- Provides user feedback

### Widgets

#### CheckInCard
- Displays check-in information
- Handles user interactions
- Shows like and comment counts
- Formats timestamps and location data

## Data Flow

### Like Function Implementation
```dart
_toggleLike(String checkInId, List<String> currentLikes) async {
  final user = context.read<AuthViewModel>().currentUser;
  if (user == null) return;

  try {
    if (currentLikes.contains(user.id)) {
      // Unlike
      await _firestore.collection('checkins')
        .doc(checkInId)
        .update({
          'likes': FieldValue.arrayRemove([user.id])
        });
    } else {
      // Like
      await _firestore.collection('checkins')
        .doc(checkInId)
        .update({
          'likes': FieldValue.arrayUnion([user.id])
        });
    }
  } catch (e) {
    // Handle error
  }
}
```

### Check-in Creation
```dart
await FirebaseFirestore.instance.collection('checkins').add({
  'userId': user.uid,
  'username': userProfile.username,
  'displayName': userProfile.displayName,
  'content': content,
  'placeName': placeName,
  'caption': caption,
  'location': GeoPoint(latitude, longitude),
  'timestamp': FieldValue.serverTimestamp(),
  'likes': [],
  'comments': [],
});
```

## Firebase Structure

### Firestore Collections

#### users
```json
{
  "uid": {
    "username": "string",
    "displayName": "string",
    "bio": "string",
    "createdAt": "timestamp"
  }
}
```

#### checkins
```json
{
  "checkInId": {
    "userId": "string",
    "username": "string",
    "displayName": "string",
    "content": "string",
    "placeName": "string",
    "caption": "string",
    "location": "geopoint",
    "timestamp": "timestamp",
    "likes": ["userId"],
    "comments": [{
      "userId": "string",
      "text": "string",
      "timestamp": "timestamp"
    }]
  }
}
```

## Getting Started

### Prerequisites
- Flutter SDK
- Firebase account
- Google Maps API key (for location features)

### Installation
1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Configure Firebase:
   - Create a new Firebase project
   - Add your Firebase configuration files
   - Enable Authentication and Firestore
4. Run the app using `flutter run`

## Dependencies
- firebase_core
- firebase_auth
- cloud_firestore
- provider
- geolocator
- intl
- flutter_material_design

## Contributing
Feel free to submit issues and enhancement requests.

## License
This project is licensed under the MIT License - see the LICENSE file for details. 