import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/ui.dart';

/// Add a new child, or edit an existing one (pass [child]). Supports a photo.
class AddChildScreen extends StatefulWidget {
  final Child? child;
  const AddChildScreen({super.key, this.child});

  bool get isEdit => child != null;

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  late final _name = TextEditingController(text: widget.child?.fullName ?? '');
  late final _school = TextEditingController(text: widget.child?.school ?? '');
  late final _grade = TextEditingController(text: widget.child?.grade ?? '');
  late final _note = TextEditingController(
    text: widget.child?.noteForDriver ?? '',
  );
  DateTime? _birth;
  Uint8List? _photoBytes; // newly picked photo (not yet uploaded)
  String? _photoName;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final b = widget.child?.birthDate;
    if (b != null) _birth = DateTime.tryParse(b);
  }

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _photoBytes = bytes;
      _photoName = x.name;
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Укажите имя ребёнка');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final birthIso = _birth?.toIso8601String().split('T').first;
      final Child saved;
      if (widget.isEdit) {
        saved = await ChildrenService.update(
          widget.child!.id,
          fullName: _name.text.trim(),
          birthDate: birthIso,
          school: _school.text.trim(),
          grade: _grade.text.trim(),
          note: _note.text.trim(),
        );
      } else {
        saved = await ChildrenService.create(
          fullName: _name.text.trim(),
          birthDate: birthIso,
          school: _school.text.trim(),
          grade: _grade.text.trim(),
          note: _note.text.trim(),
        );
      }
      if (_photoBytes != null) {
        await ChildrenService.uploadPhoto(
          saved.id,
          _photoBytes!,
          _photoName ?? 'photo.jpg',
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = ApiClient.errorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить ребёнка?'),
        content: Text('${widget.child!.fullName} будет удалён из профиля.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Удалить',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ChildrenService.remove(widget.child!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = ApiClient.errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingPhoto = widget.child?.photo;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Изменить ребёнка' : 'Добавить ребёнка'),
        actions: [
          if (widget.isEdit)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Photo picker ──
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                children: [
                  Container(
                    height: 104,
                    width: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface2,
                      image: _photoBytes != null
                          ? DecorationImage(
                              image: MemoryImage(_photoBytes!),
                              fit: BoxFit.cover,
                            )
                          : (existingPhoto != null
                                ? DecorationImage(
                                    image: NetworkImage(existingPhoto),
                                    fit: BoxFit.cover,
                                  )
                                : null),
                    ),
                    child: (_photoBytes == null && existingPhoto == null)
                        ? const Icon(
                            Icons.child_care,
                            color: AppColors.muted,
                            size: 40,
                          )
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 34,
                      width: 34,
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.bg, width: 3),
                      ),
                      child: const Icon(
                        Icons.photo_camera,
                        color: AppColors.onBrand,
                        size: 17,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Имя ребёнка'),
          ),
          const SizedBox(height: 14),
          _dateField(),
          const SizedBox(height: 14),
          TextField(
            controller: _school,
            decoration: const InputDecoration(labelText: 'Школа / садик'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _grade,
            decoration: const InputDecoration(
              labelText: 'Класс',
              hintText: 'напр. 4 класс',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _note,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Комментарий для водителя',
              hintText: 'Например: забирать у второго подъезда',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            InlineError(_error!),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onBrand,
                      ),
                    )
                  : Text(widget.isEdit ? 'Сохранить' : 'Добавить'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField() {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: _birth ?? DateTime(2018),
          firstDate: DateTime(2005),
          lastDate: DateTime.now(),
        );
        if (d != null) setState(() => _birth = d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.cake_outlined, color: AppColors.muted, size: 20),
            const SizedBox(width: 12),
            Text(
              _birth == null
                  ? 'Дата рождения (необязательно)'
                  : '${_birth!.day.toString().padLeft(2, '0')}.${_birth!.month.toString().padLeft(2, '0')}.${_birth!.year}',
              style: TextStyle(
                color: _birth == null ? AppColors.muted : AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
