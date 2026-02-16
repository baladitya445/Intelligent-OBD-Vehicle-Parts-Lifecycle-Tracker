import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    print('🔐 AuthWrapper build method called');

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        print('🔄 AuthWrapper StreamBuilder called');
        print('📊 Connection state: ${snapshot.connectionState}');
        print('📈 Has data: ${snapshot.hasData}');
        print('👤 User: ${snapshot.data?.email ?? "No user"}');

        // Show loading screen while checking auth
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('⏳ Showing loading screen');
          return const Scaffold(
            backgroundColor: Colors.blue,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 20),
                  Text(
                    'Loading...',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
          );
        }

        // For now, always show home screen (skip authentication)
        // Later you can add proper login logic here
        print('✅ Showing HomeScreen (bypassing auth for now)');
        return const HomeScreen();
      },
    );
  }
}
