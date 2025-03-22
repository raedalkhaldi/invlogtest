import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/main_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'providers/auth_view_model.dart';
import 'providers/checkin_provider.dart';
import 'services/profile_service.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => CheckInProvider()),
        Provider(create: (_) => ProfileService()),
      ],
      child: MaterialApp(
        title: 'InvLog',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const MainScreen(),
        routes: {
          '/edit-profile': (context) => const EditProfileScreen(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
} 