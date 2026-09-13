import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../referral/providers/referral_provider.dart';

class ApplyReferralScreen extends ConsumerStatefulWidget {
  const ApplyReferralScreen({super.key});

  @override
  ConsumerState<ApplyReferralScreen> createState() => _ApplyReferralScreenState();
}

class _ApplyReferralScreenState extends ConsumerState<ApplyReferralScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    setState(() => _submitting = true);
    await ref.read(referralProvider.notifier).applyReferralCode(code);
    setState(() => _submitting = false);

    final error = ref.read(referralProvider).error;
    if (error != null) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Failed'),
          content: Text(error),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
          ],
        ),
      );
    } else {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referral code applied')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(referralProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Apply Referral Code')),
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Enter your friend\'s referral code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Referral code'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: (_submitting || state.applied) ? null : _submit,
            child: _submitting ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Apply'),
          ),
          const SizedBox(height: 12),
          if (state.applied) const Text('A referral code is already applied to your account.'),
          if (state.error != null) ...[
            const SizedBox(height: 12),
            Text(state.error!, style: const TextStyle(color: Colors.red)),
          ]
        ]),
      ),
    );
  }
}
