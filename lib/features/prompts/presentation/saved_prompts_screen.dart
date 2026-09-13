import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/glass_card.dart';
import '../../prompts/providers/prompt_provider.dart';

class SavedPromptsScreen extends ConsumerStatefulWidget {
  const SavedPromptsScreen({super.key});

  @override
  ConsumerState<SavedPromptsScreen> createState() => _SavedPromptsScreenState();
}

class _SavedPromptsScreenState extends ConsumerState<SavedPromptsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    ref.read(promptProvider.notifier).fetchPrompts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    ref.read(promptProvider.notifier).fetchPrompts(_searchController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(promptProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Prompts'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration.collapsed(hintText: 'Search prompts...'),
                      onChanged: (_) => _onSearchChanged(),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _onSearchChanged(),
                    icon: const Icon(Icons.search),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (state.isLoading) ...[
              const Center(child: CircularProgressIndicator()),
            ] else if (state.error != null) ...[
              Center(child: Text(state.error!)),
            ] else if (state.prompts.isEmpty) ...[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.save_outlined, size: 56, color: AppColors.textMuted),
                      const SizedBox(height: 8),
                      Text('No saved prompts yet', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Expanded(
                child: ListView.separated(
                  itemCount: state.prompts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final p = state.prompts[i];
                    return GlassCard(
                      padding: const EdgeInsets.all(12),
                      child: ListTile(
                        title: Text(p.title, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                        subtitle: Text(p.prompt, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textSecondary)),
                        onTap: () {
                          Navigator.pop(context, p.prompt);
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.error),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Prompt'),
                                content: const Text('Are you sure you want to delete this saved prompt?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await ref.read(promptProvider.notifier).deletePrompt(p.id);
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
