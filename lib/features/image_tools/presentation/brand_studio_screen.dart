import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/animated_input.dart';

class BrandStudioScreen extends ConsumerStatefulWidget {
  const BrandStudioScreen({super.key});

  @override
  ConsumerState<BrandStudioScreen> createState() => _BrandStudioScreenState();
}

class _BrandStudioScreenState extends ConsumerState<BrandStudioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _brandNameController = TextEditingController();
  final _promptController = TextEditingController();
  String _selectedStyle = 'Modern';
  String _selectedAsset = 'Logo';
  bool _isGenerating = false;
  List<String> _generatedAssets = [];

  static const _styles = ['Modern', 'Minimal', 'Bold', 'Elegant', 'Playful', 'Tech'];
  static const _assetTypes = ['Logo', 'Banner', 'Product Shot', 'Social Post', 'Icon', 'Poster'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _brandNameController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_brandNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enter your brand name'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    setState(() => _isGenerating = true);
    await Future.delayed(const Duration(milliseconds: 2500));
    final seed = (_brandNameController.text + _selectedAsset + _selectedStyle)
        .hashCode
        .abs() %
        300;
    setState(() {
      _isGenerating = false;
      _generatedAssets = List.generate(
        4,
        (i) => 'https://picsum.photos/seed/brand_${seed + i}/400/400',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              _buildHeroBanner(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCreateTab(),
                    _buildGalleryTab(),
                    _buildStylesTab(),
                  ],
                ),
              ),
            ],
          ),
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
              child: Icon(Icons.arrow_back_ios_new,
                  color: AppColors.textPrimary, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Brand Studio',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                Text('Powered by VisionAI',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildHeroBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Create Brand Assets',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  const SizedBox(height: 6),
                  Text(
                    'Logos, banners, product shots & more — all AI-generated',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.business_center_outlined,
                  color: Colors.white, size: 28),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2);
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Create'),
            Tab(text: 'Gallery'),
            Tab(text: 'Styles'),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand name
          Text('Brand Name',
              style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          AnimatedInput(
            hint: 'e.g. NovaTech, Bloom, Apex...',
            controller: _brandNameController,
            prefixIcon: Icon(Icons.business_outlined,
                color: AppColors.textMuted, size: 18),
          ),
          const SizedBox(height: 16),

          // Asset type
          Text('Asset Type',
              style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _assetTypes.map((type) {
              final isSelected = _selectedAsset == type;
              return GestureDetector(
                onTap: () => setState(() => _selectedAsset = type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppColors.primaryGradient : null,
                    color: isSelected ? null : AppColors.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : AppColors.cardBorder,
                    ),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Style
          Text('Style',
              style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _styles.map((style) {
              final isSelected = _selectedStyle == style;
              return GestureDetector(
                onTap: () => setState(() => _selectedStyle = style),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accent.withValues(alpha: 0.2)
                        : AppColors.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accent
                          : AppColors.cardBorder,
                    ),
                  ),
                  child: Text(
                    style,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Additional prompt
          Text('Additional Details (optional)',
              style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          AnimatedInput(
            hint: 'Blue and white color scheme, professional, clean...',
            controller: _promptController,
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          GradientButton(
            text: 'Generate Brand Assets',
            onPressed: _isGenerating ? null : _generate,
            isLoading: _isGenerating,
            width: double.infinity,
            height: 54,
            gradientColors: const [Color(0xFF7C3AED), Color(0xFFEC4899)],
            icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),

          if (_generatedAssets.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Generated Assets',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _generatedAssets.length,
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        _generatedAssets[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.surfaceLight,
                          child: Icon(Icons.image,
                              color: AppColors.textMuted, size: 40),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.download,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: (index * 100).ms).scale(
                    begin: const Offset(0.9, 0.9));
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGalleryTab() {
    if (_generatedAssets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFFEC4899)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.photo_library_outlined,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text('No assets yet',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('Generate your first brand asset',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textMuted)),
          ],
        ),
      ).animate().fadeIn();
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _generatedAssets.length,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            _generatedAssets[index],
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: AppColors.surfaceLight,
              child: Icon(Icons.image,
                  color: AppColors.textMuted, size: 40),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStylesTab() {
    final styleExamples = [
      {'name': 'Modern', 'desc': 'Clean lines, geometric shapes', 'colors': [const Color(0xFF7C3AED), const Color(0xFF3B82F6)]},
      {'name': 'Minimal', 'desc': 'Simple, whitespace-focused', 'colors': [const Color(0xFF6B7280), const Color(0xFF374151)]},
      {'name': 'Bold', 'desc': 'Strong typography, high contrast', 'colors': [const Color(0xFFEF4444), const Color(0xFFF59E0B)]},
      {'name': 'Elegant', 'desc': 'Refined, luxury aesthetic', 'colors': [const Color(0xFFD4AF37), const Color(0xFF92400E)]},
      {'name': 'Playful', 'desc': 'Fun, colorful, energetic', 'colors': [const Color(0xFFEC4899), const Color(0xFF8B5CF6)]},
      {'name': 'Tech', 'desc': 'Futuristic, digital, precise', 'colors': [const Color(0xFF06B6D4), const Color(0xFF3B82F6)]},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: styleExamples.length,
      itemBuilder: (context, index) {
        final style = styleExamples[index];
        final colors = style['colors'] as List<Color>;
        return GestureDetector(
          onTap: () {
            setState(() => _selectedStyle = style['name'] as String);
            _tabController.animateTo(0);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: colors.map((c) => c.withValues(alpha: 0.12)).toList()),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: colors.first.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: colors),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      (style['name'] as String)[0],
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(style['name'] as String,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      Text(style['desc'] as String,
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: AppColors.textMuted, size: 18),
              ],
            ),
          ).animate().fadeIn(delay: (index * 60).ms).slideX(begin: 0.2),
        );
      },
    );
  }
}
