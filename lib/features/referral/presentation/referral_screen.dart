import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../referral/providers/referral_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'apply_referral_screen.dart';
import '../../../core/theme/app_theme.dart';

class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(referralProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Referral')),
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: state.loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your referral code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: Text(state.referralCode ?? 'Generating...', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded),
                          onPressed: state.referralCode == null
                              ? null
                              : () {
                                  Clipboard.setData(ClipboardData(text: state.referralCode ?? ''));
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referral code copied')));
                                },
                        ),
                        IconButton(
                          icon: const Icon(Icons.share_rounded),
                          onPressed: state.referralCode == null
                              ? null
                              : () {
                                  Share.share('Join me on VisionAI! Use my code: ${state.referralCode}');
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(child: _InfoCard(title: 'Referrals', value: state.totalReferrals.toString())),
                      const SizedBox(width: 12),
                      Expanded(child: _InfoCard(title: 'Credits Earned', value: state.totalCreditsEarned.toString())),
                    ]),
                    const SizedBox(height: 20),

                    if (state.applied) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Referral applied', style: TextStyle(fontWeight: FontWeight.w700)),
                          if (state.referredBy != null) Text('Referred by: ${state.referredBy}'),
                        ]),
                      ),
                    ] else ...[
                      ElevatedButton(
                        onPressed: state.loading ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ApplyReferralScreen())),
                        child: const Text('Apply referral code'),
                      ),
                    ],

                    const SizedBox(height: 20),
                    const Text('Referral history', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (state.history.isEmpty) ...[
                      const Text('No referral history yet.'),
                    ] else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.history.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final item = state.history[idx];
                          final when = item['created_at'] as String? ?? '';
                          final credits = item['credits_awarded']?.toString() ?? '0';
                          final referee = item['referee_referral_code'] as String? ?? '';
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
                            child: Row(children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Code: $referee', style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 6), Text(when, style: TextStyle(color: AppColors.textMuted, fontSize: 12))])),
                              Text('+$credits', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.success)),
                            ]),
                          );
                        },
                      )
                    ],

                    if (state.error != null) ...[
                      const SizedBox(height: 16),
                      Text(state.error!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  const _InfoCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: AppColors.textMuted)), const SizedBox(height: 8), Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))]),
    );
  }
}

class _ReferralForm extends ConsumerStatefulWidget {
  @override
  ReferralFormState createState() => ReferralFormState();
}

class ReferralFormState extends ConsumerState<_ReferralForm> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(referralProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Referral code',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () {
            notifier.applyReferralCode(_controller.text);
          },
          child: const Text('Apply Code'),
        ),
      ],
    );
  }
}
