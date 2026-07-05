import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import 'add_child_screen.dart';

class ChildrenScreen extends StatefulWidget {
  const ChildrenScreen({super.key});

  @override
  State<ChildrenScreen> createState() => _ChildrenScreenState();
}

class _ChildrenScreenState extends State<ChildrenScreen> {
  List<Child> _children = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _children = await ChildrenService.list();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _add() async {
    final added = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const AddChildScreen()));
    if (added == true) _load();
  }

  Future<void> _edit(Child c) async {
    final changed = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => AddChildScreen(child: c)));
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мои дети')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: _children.isEmpty
                        ? ListView(children: const [
                            SizedBox(height: 120),
                            Center(
                              child: Column(children: [
                                Icon(Icons.child_care,
                                    size: 48, color: AppColors.muted),
                                SizedBox(height: 8),
                                Text('Добавьте первого ребёнка',
                                    style: TextStyle(color: AppColors.muted)),
                              ]),
                            ),
                          ])
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _children.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => _card(_children[i]),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _add,
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить ребёнка'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _card(Child c) {
    final line = [
      if (c.grade.isNotEmpty) c.grade,
      if (c.age != null) '${c.age} лет',
    ].join(' · ');
    return GestureDetector(
      onTap: () => _edit(c),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(c),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(c.fullName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16)),
                        ),
                        if (c.isPrimary) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: AppColors.brand,
                                borderRadius: BorderRadius.circular(999)),
                            child: const Text('Основной',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    if (line.isNotEmpty)
                      Text(line,
                          style: const TextStyle(color: AppColors.muted)),
                    if (c.school.isNotEmpty)
                      Text(c.school,
                          style: const TextStyle(color: AppColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
          const Divider(height: 20),
          Text('Особенности',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          const SizedBox(height: 2),
          Text(c.noteForDriver.isEmpty ? 'Нет' : c.noteForDriver,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
      ),
    );
  }

  Widget _avatar(Child c) {
    if (c.photo != null && c.photo!.isNotEmpty) {
      return CircleAvatar(radius: 26, backgroundImage: NetworkImage(c.photo!));
    }
    return InitialAvatar(c.fullName, radius: 26);
  }
}
