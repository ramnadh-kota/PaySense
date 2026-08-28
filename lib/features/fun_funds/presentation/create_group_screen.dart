import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/fun_funds_group.dart';
import 'package:paysense/shared/providers/fun_funds_provider.dart';
import 'package:uuid/uuid.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _memberController = TextEditingController();
  final List<String> _members = [];
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _memberController.dispose();
    super.dispose();
  }

  void _addMember() {
    final name = _memberController.text.trim();
    if (name.isEmpty) return;
    if (_members.any((m) => m.toLowerCase() == name.toLowerCase())) {
      setState(() => _error = '"$name" is already in this group.');
      return;
    }
    setState(() {
      _members.add(name);
      _memberController.clear();
      _error = null;
    });
  }

  void _removeMember(String name) {
    setState(() => _members.remove(name));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the group a name.');
      return;
    }
    if (_members.length < 2) {
      setState(() => _error = 'Add at least 2 members to split expenses.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    await ref.read(funFundsGroupsProvider.notifier).addGroup(
          FunFundsGroup(
            id: const Uuid().v4(),
            name: name,
            memberNames: List<String>.unmodifiable(_members),
            createdAt: DateTime.now(),
          ),
        );

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('New Group'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Text(
              'Group name',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'e.g. Goa Trip'),
            ),
            const SizedBox(height: 24),
            Text(
              'Members',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _memberController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: 'Add a member by name'),
                    onSubmitted: (_) => _addMember(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addMember,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            if (_members.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _members
                    .map(
                      (member) => Chip(
                        label: Text(member),
                        onDeleted: () => _removeMember(member),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Create Group'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
