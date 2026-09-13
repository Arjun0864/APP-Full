import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/gradient_button.dart';
import '../models/color_grade_models.dart';
import '../providers/color_grade_provider.dart';

import 'image_source_sheet.dart';

class ColorGradeReferenceScreen extends ConsumerStatefulWidget {
  const ColorGradeReferenceScreen({super.key});

  @override
  ConsumerState<ColorGradeReferenceScreen> createState() =>
      _ColorGradeReferenceScreenState();
}

class _ColorGradeReferenceScreenState
    extends ConsumerState<ColorGradeReferenceScreen> {

  static const _allowedExtensions = [
    'jpg', 'jpeg', 'cr2', 'cr3', 'nef', 'arw', 'dng', 'raf', 'rw2', 'orf', 'png', 'webp', 'tif', 'tiff'
  ];

  Future<void> _pickReferenceRaw() async {
    await ImageSourceSheet.show(
      context: context,
      title: 'Reference Original Image',
      subtitle: 'Choose from Photos/Gallery or Files (RAW supported)',
      allowMultiple: false,
      allowedExtensions: _allowedExtensions,
      onSelected: (paths) {
        if (paths.isNotEmpty && mounted) {
          ref.read(colorGradeProvider.notifier).setReferenceRaw(paths.first);
        }
      },
    );
  }

  Future<void> _pickReferenceGraded() async {
    await ImageSourceSheet.show(
      context: context,
      title: 'Reference Graded Image',
      subtitle: 'Choose from Photos/Gallery or Files (RAW supported)',
      allowMultiple: false,
      allowedExtensions: _allowedExtensions,
      onSelected: (paths) {
        if (paths.isNotEmpty && mounted) {
          ref.read(colorGradeProvider.notifier).setReferenceGraded(paths.first);
        }
      },
    );
  }

  bool _isActionInProgress = false;

  Future<void> _analyzeGrade() async {
    if (_isActionInProgress) return;
    setState(() => _isActionInProgress = true);
    try {
      await ref.read(colorGradeProvider.notifier).analyzeGrade();
      if (!mounted) return;
      final gradeState = ref.read(colorGradeProvider);
      if (gradeState.status == ColorGradeStatus.readyToBatch) {
        context.push('/color-grade/batch');
      }
    } finally {
      if (mounted) {
        setState(() => _isActionInProgress = false);
      }
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gradeState = ref.watch(colorGradeProvider);
    final isAnalyzing =
        gradeState.status == ColorGradeStatus.analyzingReference;
    final canAnalyze = gradeState.hasReferencePair && !isAnalyzing;

    ref.listen(colorGradeProvider, (_, next) {
      if (next.status == ColorGradeStatus.error && next.error != null) {
        _showSnack(next.error!, AppColors.error);
        ref.read(colorGradeProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration:
            BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildStepIndicator(activeStep: 0),
                      const SizedBox(height: 28),

                      // Reference Original
                      _sectionLabel('1. Reference Original (RAW or JPEG)'),
                      const SizedBox(height: 10),
                      _buildPickerZone(
                        label: 'Upload Reference Original',
                        sublabel: 'Supports RAW (CR2, NEF, ARW, DNG) & JPEG/PNG',
                        icon: Icons.camera_roll_outlined,
                        accentColor: AppColors.primary,
                        imagePath: gradeState.referenceRawPath,
                        onTap: _pickReferenceRaw,
                        delay: 0,
                      ),
                      const SizedBox(height: 20),

                      // Reference Graded
                      _sectionLabel('2. Reference Graded (RAW or JPEG)'),
                      const SizedBox(height: 10),
                      _buildPickerZone(
                        label: 'Upload Reference Graded',
                        sublabel: 'The same scene after manual color grading',
                        icon: Icons.palette_outlined,
                        accentColor: const Color(0xFF10B981),
                        imagePath: gradeState.referenceGradedPath,
                        onTap: _pickReferenceGraded,
                        delay: 80,
                      ),
                      const SizedBox(height: 28),

                      _buildInfoCard(),
                      const SizedBox(height: 28),

                      if (isAnalyzing)
                        _buildAnalyzingProgress()
                      else if (gradeState.status == ColorGradeStatus.error && gradeState.error != null)
                        _buildErrorCard(gradeState.error!)
                      else
                        GradientButton(
                          text: 'Analyze Grade Profile',
                          onPressed: canAnalyze ? _analyzeGrade : null,
                          width: double.infinity,
                          height: 54,
                          gradientColors: canAnalyze
                              ? [AppColors.primary, AppColors.secondary]
                              : [AppColors.textMuted, AppColors.textMuted],
                          icon: const Icon(Icons.analytics_outlined,
                              color: Colors.white, size: 20),
                        ).animate().fadeIn(delay: 300.ms),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sub-widgets ─────────────────────────────────────────────────────────────

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
              child: Icon(Icons.arrow_back_ios_new,
                  color: AppColors.textPrimary, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.palette_outlined,
                color: Color(0xFF10B981), size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            'AI Color Grade',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildHeader() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.palette_outlined,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reference Grading Engine',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Learns grade from reference pair & applies to mixed RAW + JPEG batches',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const _BadgeChip(
                        label: 'RAW + JPEG Supported',
                        color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    _BadgeChip(
                        label: 'Up to 200 batch',
                        color: AppColors.primary),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 50.ms);
  }

  Widget _buildStepIndicator({required int activeStep}) {
    const steps = ['Reference', 'Batch', 'Results'];
    return Row(
      children: List.generate(steps.length, (i) {
        final isActive = i == activeStep;
        final isDone = i < activeStep;
        final isLast = i == steps.length - 1;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isActive || isDone
                            ? const LinearGradient(colors: [
                                Color(0xFF10B981),
                                Color(0xFF3B82F6)
                              ])
                            : null,
                        color: isActive || isDone
                            ? null
                            : AppColors.surfaceLight,
                        border: Border.all(
                          color: isActive || isDone
                              ? Colors.transparent
                              : AppColors.cardBorder,
                        ),
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 14)
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.white
                                      : AppColors.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isActive
                            ? const Color(0xFF10B981)
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 1.5,
                    margin: const EdgeInsets.only(bottom: 14),
                    color: isDone
                        ? const Color(0xFF10B981)
                        : AppColors.cardBorder,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildPickerZone({
    required String label,
    required String sublabel,
    required IconData icon,
    required Color accentColor,
    required String? imagePath,
    required VoidCallback onTap,
    required int delay,
  }) {
    final hasImage = imagePath != null;
    final fileName = hasImage ? imagePath.split('/').last : null;
    final ext = hasImage ? fileName!.split('.').last.toUpperCase() : null;
    final isRaw = hasImage && BatchItem.checkIsRaw(ext!.toLowerCase());

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        height: hasImage ? 140 : 120,
        decoration: BoxDecoration(
          color: hasImage
              ? accentColor.withValues(alpha: 0.08)
              : AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasImage ? accentColor : AppColors.cardBorder,
            width: hasImage ? 1.5 : 1,
          ),
        ),
        child: hasImage
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isRaw ? const Color(0xFF7C3AED) : accentColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isRaw ? 'RAW ($ext)' : ext!,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            fileName!,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit, color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text('Change File', style: TextStyle(color: Colors.white, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.textMuted, size: 32),
                  const SizedBox(height: 8),
                  Text(label,
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(sublabel,
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
      ),
    ).animate().fadeIn(delay: delay.ms).slideY(begin: 0.05);
  }

  Widget _buildInfoCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: const Color(0xFF10B981).withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  color: Color(0xFF10B981), size: 16),
              const SizedBox(width: 8),
              Text(
                'How RAW + JPEG Color Grade Works',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow(Icons.looks_one_outlined,
              'Select reference pair: RAW+JPEG, JPEG+JPEG, or RAW+RAW'),
          _infoRow(Icons.looks_two_outlined,
              'Engine normalizes color spaces into CIE L*a*b* working space'),
          _infoRow(Icons.looks_3_outlined,
              'Applies learned grade to up to 200 mixed RAW + JPEG input files'),
          _infoRow(Icons.security_outlined,
              'Original files are never overwritten — exported to JPEG or TIFF'),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textMuted, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String errorMsg) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderColor: AppColors.error.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 22),
              const SizedBox(width: 10),
              Text(
                'Reference Analysis Failed',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            errorMsg,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          GradientButton(
            text: 'Retry Analysis',
            onPressed: _analyzeGrade,
            width: double.infinity,
            height: 46,
            gradientColors: const [AppColors.error, Color(0xFFF97316)],
            icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzingProgress() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation(Color(0xFF10B981)),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Analyzing color spaces & grade profile…',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              backgroundColor: AppColors.surfaceLight,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Normalizing color profiles & building LAB transformation…',
            style:
                TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String label;
  final Color color;
  const _BadgeChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}
