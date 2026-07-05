import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../widgets/app_bottom_nav.dart';
import 'driver_home_screen.dart';
import 'driver_trips_screen.dart';
import 'driver_earnings_screen.dart';
import 'driver_profile_screen.dart';

class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _index = 0;
  final _pages = const [
    DriverHomeScreen(),
    DriverTripsScreen(),
    DriverEarningsScreen(),
    DriverProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _index, children: _pages),
      // Driver has no "order a ride" action → plain bar, no center button.
      bottomNavigationBar: AppBottomNav(
        index: _index,
        onTap: (i) => setState(() => _index = i),
        destinations: const [
          NavDest(Icons.home_outlined, Icons.home, 'Главная'),
          NavDest(Icons.assignment_outlined, Icons.assignment, 'Поездки'),
          NavDest(Icons.account_balance_wallet_outlined,
              Icons.account_balance_wallet, 'Финансы'),
          NavDest(Icons.person_outline, Icons.person, 'Профиль'),
        ],
      ),
    );
  }
}
