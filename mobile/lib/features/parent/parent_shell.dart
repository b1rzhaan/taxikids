import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../widgets/app_bottom_nav.dart';
import 'parent_home_screen.dart';
import 'history_screen.dart';
import 'wallet_screen.dart';
import 'create_trip_screen.dart';
import 'profile_screen.dart';

class ParentShell extends StatefulWidget {
  const ParentShell({super.key});

  @override
  State<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends State<ParentShell> {
  int _index = 0;
  Key _homeKey = UniqueKey();

  List<Widget> get _pages => [
        ParentHomeScreen(key: _homeKey),
        const HistoryScreen(),
        const WalletScreen(),
        const ProfileScreen(),
      ];

  Future<void> _order() async {
    final created = await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const CreateTripScreen()));
    if (created != null && mounted) {
      // Refresh the home tab and jump to it.
      setState(() {
        _homeKey = UniqueKey();
        _index = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: AppBottomNav(
        index: _index,
        onTap: (i) => setState(() => _index = i),
        onCenter: _order,
        centerIcon: Icons.local_taxi,
        destinations: const [
          NavDest(Icons.home_outlined, Icons.home, 'Главная'),
          NavDest(Icons.receipt_long_outlined, Icons.receipt_long, 'Поездки'),
          NavDest(Icons.account_balance_wallet_outlined,
              Icons.account_balance_wallet, 'Кошелёк'),
          NavDest(Icons.person_outline, Icons.person, 'Профиль'),
        ],
      ),
    );
  }
}
