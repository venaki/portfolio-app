import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'firebase_options.dart';

const _devMode = bool.fromEnvironment('DEV_MODE');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!_devMode) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  runApp(const ProviderScope(child: PortfolioApp()));
}
