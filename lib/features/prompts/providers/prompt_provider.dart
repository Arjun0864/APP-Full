import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/secure_http_client.dart';
import '../../auth/providers/auth_provider.dart';

class SavedPrompt {
  final int id;
  final String title;
  final String prompt;
  final DateTime? createdAt;

  SavedPrompt({required this.id, required this.title, required this.prompt, this.createdAt});
}

class PromptState {
  final bool isLoading;
  final List<SavedPrompt> prompts;
  final String? error;

  const PromptState({this.isLoading = false, this.prompts = const [], this.error});

  PromptState copyWith({bool? isLoading, List<SavedPrompt>? prompts, String? error}) {
    return PromptState(
      isLoading: isLoading ?? this.isLoading,
      prompts: prompts ?? this.prompts,
      error: error,
    );
  }
}

class PromptNotifier extends StateNotifier<PromptState> {
  final Ref _ref;
  PromptNotifier(this._ref) : super(const PromptState());

  Future<void> fetchPrompts([String? q]) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final resp = await SecureHttpClient.instance.get('/prompts', queryParams: q != null && q.isNotEmpty ? {'q': q} : null);
      if (!resp.success || resp.data == null) {
        state = state.copyWith(isLoading: false, error: resp.errorMessage ?? 'Failed to load prompts');
        return;
      }

      final data = resp.data as Map<String, dynamic>;
      final items = (data['prompts'] as List<dynamic>? ?? []).map((e) {
        return SavedPrompt(
          id: e['id'] as int,
          title: e['title'] as String? ?? '',
          prompt: e['prompt'] as String? ?? '',
          createdAt: e['created_at'] != null ? DateTime.parse(e['created_at']).toLocal() : null,
        );
      }).toList();

      state = state.copyWith(isLoading: false, prompts: items);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Network error');
    }
  }

  Future<bool> createPrompt(String title, String promptText) async {
    // optimistic UI will insert after success
    try {
      final resp = await SecureHttpClient.instance.post('/prompts', body: {'title': title, 'prompt': promptText});
      if (!resp.success || resp.data == null) {
        return false;
      }
      final data = resp.data as Map<String, dynamic>;
      final p = SavedPrompt(
        id: data['id'] as int,
        title: data['title'] as String? ?? '',
        prompt: data['prompt'] as String? ?? '',
        createdAt: data['created_at'] != null ? DateTime.parse(data['created_at']).toLocal() : null,
      );

      state = state.copyWith(prompts: [p, ...state.prompts]);

      // Refresh auth to ensure no side effects necessary
      await _ref.read(authProvider.notifier).refreshUserData();

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deletePrompt(int id) async {
    // optimistic remove
    final previous = state.prompts;
    state = state.copyWith(prompts: previous.where((p) => p.id != id).toList());
    try {
      final resp = await SecureHttpClient.instance.delete('/prompts/$id');
      if (!resp.success) {
        state = state.copyWith(prompts: previous);
        return false;
      }
      return true;
    } catch (e) {
      state = state.copyWith(prompts: previous);
      return false;
    }
  }
}

final promptProvider = StateNotifierProvider<PromptNotifier, PromptState>((ref) {
  return PromptNotifier(ref);
});
