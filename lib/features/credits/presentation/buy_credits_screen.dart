import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/app_models.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/gradient_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/credits_provider.dart';

class BuyCreditsScreen extends ConsumerStatefulWidget {
  const BuyCreditsScreen({super.key});

  @override
  ConsumerState<BuyCreditsScreen> createState() => _BuyCreditsScreenState();
}

class _BuyCreditsScreenState extends ConsumerState<BuyCreditsScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 2; // Default to 100 credits (popular)
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _purchase() async {
    final pkg = CreditPackage.packages[_selectedIndex];

    // Step 1: Create Razorpay order on backend
    final order = await ref.read(creditsProvider.notifier).createRazorpayOrder(pkg);
    if (order == null || !mounted) return;

    // Step 2: Open Razorpay checkout
    // We use url_launcher to open Razorpay payment link
    // (razorpay_flutter package can also be used — add to pubspec.yaml)
    // For now we show a dialog explaining the payment flow
    _showRazorpayInstructions(order, pkg);
  }

  void _showRazorpayInstructions(RazorpayOrderInfo order, CreditPackage pkg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: pkg.gradientColors),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.payment, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Complete Payment',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pay ${pkg.displayPrice} for ${pkg.credits} credits',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Order ID: ${order.orderId}',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 16),
            Text(
              'Note: Add razorpay_flutter package to pubspec.yaml to enable in-app Razorpay checkout.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          // When razorpay_flutter is integrated, replace this with actual checkout
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Simulate successful payment for testing
              // In production: integrate razorpay_flutter and call verifyRazorpayPayment
              _handlePaymentSuccess(order, pkg);
            },
            child: Text('Simulate Payment (Dev)', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePaymentSuccess(RazorpayOrderInfo order, CreditPackage pkg) async {
    // In production this is called from Razorpay's onSuccess callback
    // with real orderId, paymentId, and signature
    // For now this is a dev-only simulation
    final success = await ref.read(creditsProvider.notifier).verifyRazorpayPayment(
      orderId: order.orderId,
      paymentId: 'pay_simulated_${DateTime.now().millisecondsSinceEpoch}',
      signature: 'simulated', // Backend will reject this — use real flow
      pkg: pkg,
    );
    if (success && mounted) {
      _confettiController.play();
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _showSuccessDialog(pkg);
    }
  }

  void _showSuccessDialog(CreditPackage pkg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: pkg.gradientColors),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bolt, color: Colors.white, size: 36),
                  ).animate().scale(begin: const Offset(0, 0), curve: Curves.elasticOut),
                  const SizedBox(height: 20),
                  Text(
                    '${pkg.credits} Credits Added!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your credits are ready to use. Start creating amazing AI content!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 28),
                  GradientButton(
                    text: 'Start Creating',
                    onPressed: () {
                      Navigator.pop(context);
                      context.go('/dashboard');
                    },
                    gradientColors: pkg.gradientColors,
                    width: double.infinity,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final creditsState = ref.watch(creditsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Stack(
          children: [
            SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildAppBar(context)),
                  SliverToBoxAdapter(child: _buildHeader(user)),
                  SliverToBoxAdapter(child: _buildPackages()),
                  SliverToBoxAdapter(child: _buildRewardedAdSection()),
                  SliverToBoxAdapter(child: _buildTransactionHistory(creditsState)),
                  SliverToBoxAdapter(child: _buildCTA(creditsState.isLoading)),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                colors: [AppColors.primary, AppColors.secondary, AppColors.accent, Colors.white],
                numberOfParticles: 40,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Icon(Icons.close, color: AppColors.textPrimary, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Buy Credits',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(UserModel? user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        children: [
          // Current balance card
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFEC4899)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.bolt, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Credits Remaining',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${user?.credits ?? 0} credits',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Top Up',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),
          const SizedBox(height: 20),
          // Credit costs info
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Credit Costs',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _costChip('Image', '3 credits'),
                    _costChip('Video', '20 credits'),
                    _costChip('Remove BG', '2 credits'),
                    _costChip('Relight', '10 credits'),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    );
  }

  Widget _costChip(String label, String cost) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt, size: 12, color: AppColors.warning),
          const SizedBox(width: 4),
          Text(
            '$label: $cost',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPackages() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'SELECT A PACKAGE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ...CreditPackage.packages.asMap().entries.map((entry) {
            final index = entry.key;
            final pkg = entry.value;
            final isSelected = _selectedIndex == index;
            return _buildPackageCard(pkg, isSelected, index);
          }),
        ],
      ),
    );
  }

  Widget _buildPackageCard(CreditPackage pkg, bool isSelected, int index) {
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: pkg.gradientColors.map((c) => c.withValues(alpha: 0.15)).toList(),
                )
              : null,
          color: isSelected ? null : AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? pkg.gradientColors[0] : AppColors.cardBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: pkg.gradientColors[0].withValues(alpha: 0.2),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Radio
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isSelected ? LinearGradient(colors: pkg.gradientColors) : null,
                border: isSelected ? null : Border.all(color: AppColors.cardBorder, width: 2),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 14),
            // Credits icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: pkg.gradientColors),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _creditsEmoji(pkg.credits),
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${pkg.credits} Credits',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                      ),
                      if (pkg.isPopular) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: pkg.gradientColors),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'POPULAR',
                            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (pkg.bonus != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      pkg.bonus!,
                      style: TextStyle(
                        fontSize: 11,
                        color: pkg.gradientColors[0],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    pkg.pricePerCredit,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            // Price
            ShaderMask(
              shaderCallback: (b) => LinearGradient(colors: pkg.gradientColors).createShader(b),
              child: Text(
                pkg.displayPrice,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (index * 80).ms).slideY(begin: 0.2);
  }

  String _creditsEmoji(int credits) {
    if (credits <= 10) return '⚡';
    if (credits <= 50) return '🔋';
    if (credits <= 100) return '💎';
    return '🚀';
  }

  Widget _buildRewardedAdSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.play_circle_outline, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Watch Ad → Get 2 Free Credits',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Watch a short 30-second ad to earn free credits',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => ref.read(creditsProvider.notifier).watchRewardedAd(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Watch',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildTransactionHistory(CreditsState creditsState) {
    if (creditsState.transactions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'RECENT TRANSACTIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 1.2,
              ),
            ),
          ),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: creditsState.transactions.take(5).toList().asMap().entries.map((entry) {
                final index = entry.key;
                final tx = entry.value;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: tx.isCredit
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              tx.isCredit ? Icons.add : Icons.remove,
                              color: tx.isCredit ? AppColors.success : AppColors.error,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.description,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  _formatDate(tx.createdAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${tx.isCredit ? '+' : '-'}${tx.credits}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: tx.isCredit ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (index < creditsState.transactions.length - 1 && index < 4)
                      Divider(height: 1, color: AppColors.cardBorder, indent: 64),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms);
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _buildCTA(bool isLoading) {
    final pkg = CreditPackage.packages[_selectedIndex];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        children: [
          GradientButton(
            text: 'Buy ${pkg.credits} Credits — ${pkg.displayPrice}',
            onPressed: isLoading ? null : _purchase,
            isLoading: isLoading,
            gradientColors: pkg.gradientColors,
            width: double.infinity,
            height: 58,
          ),
          const SizedBox(height: 12),
          Text(
            'Secure payment • Credits never expire • Instant delivery',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms);
  }
}
