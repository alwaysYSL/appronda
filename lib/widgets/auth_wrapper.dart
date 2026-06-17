import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:appronda/services/auth_service.dart';
import 'package:appronda/screens/login_screen.dart';
import 'package:appronda/screens/home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Checking connection state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F172A),
            body: Center(
              child: CircularProgressIndicator(
                color: Colors.cyanAccent,
              ),
            ),
          );
        }

        // If user is authenticated, direct them to HomeScreen
        if (snapshot.hasData) {
          return const HomeScreen();
        }

        // If not authenticated, direct them to LoginScreen
        return const LoginScreen();
      },
    );
  }
}
