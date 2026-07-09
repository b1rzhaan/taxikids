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
  int _homeVersion = 0;

  void _selectTab(int i) {
    setState(() {
      if (i == 0) _homeVersion++;
      _index = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DriverHomeScreen(key: ValueKey('driver-home-$_homeVersion')),
      const DriverTripsScreen(),
      const DriverEarningsScreen(),
      const DriverProfileScreen(),
    ];
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _index, children: pages),
      // Driver has no "order a ride" action → plain bar, no center button.
      bottomNavigationBar: AppBottomNav(
        index: _index,
        onTap: _selectTab,
        destinations: const [
          NavDest(Icons.home_outlined, Icons.home, 'Главная'),
          NavDest(Icons.assignment_outlined, Icons.assignment, 'Поездки'),
          NavDest(
            Icons.account_balance_wallet_outlined,
            Icons.account_balance_wallet,
            'Финансы',
          ),
          NavDest(Icons.person_outline, Icons.person, 'Профиль'),
        ],
      ),
    );
  }
}
