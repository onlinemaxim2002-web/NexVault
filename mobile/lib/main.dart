import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/home_shell.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: Config.supabaseUrl, publishableKey: Config.supabaseKey);
  runApp(const CloudStorageApp());
  app.start();
}

class CloudStorageApp extends StatelessWidget {
  const CloudStorageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Config.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          if (app.startupError != null) {
            return Scaffold(body: ErrorRetry(message: app.startupError!, onRetry: app.start));
          }
          if (!app.ready) return const SplashScreen();
          return const HomeShell();
        },
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_upload, size: 88, color: Colors.white),
          SizedBox(height: 16),
          Text(Config.appName, style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
          SizedBox(height: 32),
          CircularProgressIndicator(color: Colors.white),
        ]),
      ),
    );
  }
}
