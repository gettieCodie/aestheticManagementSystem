import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/auth_gate.dart';
import 'app/nav_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/admin/state/admin_store.dart';
import 'features/auth/state/auth_controller.dart';
import 'features/billing/state/billing_store.dart';
import 'features/staff/state/staff_store.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const LuxiManagementApp());
}

class LuxiManagementApp extends StatelessWidget {
  const LuxiManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => NavController()),
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => AdminStore()),
        ChangeNotifierProvider(create: (_) => StaffStore()),
        ChangeNotifierProvider(create: (_) => BillingStore()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: 'Luxi Management',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: theme.mode,
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}
