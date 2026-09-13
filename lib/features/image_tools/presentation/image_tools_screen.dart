import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/animated_input.dart';
import '../../prompts/presentation/saved_prompts_screen.dart';
import '../../prompts/providers/prompt_provider.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/gradient_button.dart';
import '../../../core/network/connectivity_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/image_tools_provider.dart';

class ImageToolsScreen extends ConsumerStatefulWidget {
  final String tool;
  const ImageToolsScreen({super.key, required this.tool});

  @override
  ConsumerState<ImageToolsScreen> createState() => _ImageToolsScreenState();
}

class _ImageToolsScreenState extends ConsumerState<ImageToolsScreen> {
  final _promptController = TextEditingController();
  bool _hasSourceImage = false;
  // ignore: unused_field
  XFile? _pickedImageFile;
  List<int>? _pickedImageBytes;     // ← bytes to send to backend

  static const _toolMeta = {
    'generate': _ToolMeta(
      title: 'Generate Image',
      subtitle: 'Create stunning images from text',
      icon: Icons.image_outlined,
      color: Color(0xFF7C3AED),
      needsPrompt: true,
      needsImage: false,
      hint: 'A majestic dragon flying over a medieval castle at sunset...',
    ),
    'remove_bg': _ToolMeta(
      title: 'Remove Background',
      subtitle: 'Clean background removal',
      icon: Icons.layers_clear_outlined,
      color: Color(0xFFEC4899),
      needsPrompt: false,
      needsImage: true,
      hint: '',
    ),
    'relight': _ToolMeta(
      title: 'Remove BG & Relight',
      subtitle: 'Remove background and add studio lighting',
      icon: Icons.wb_sunny_outlined,
      color: Color(0xFFF59E0B),
      needsPrompt: true,
      needsImage: true,
      hint: 'Describe the lighting style (e.g. warm sunset, studio white)...',
    ),
    'sketch': _ToolMeta(
      title: 'Sketch to Image',
      subtitle: 'Turn sketches into realistic images',
      icon: Icons.draw_outlined,
      color: Color(0xFF6366F1),
      needsPrompt: true,
      needsImage: true,
      hint: 'Describe the style and details...',
    ),
  };

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );
    if (img != null) {
      final bytes = await img.readAsBytes();
      setState(() {
        _pickedImageFile = img;
        _pickedImageBytes = bytes.toList();
        _hasSourceImage = true;
      });
    }
  }

  // ── Step 1: validate inputs, then generate ─────────────────────────────────
  void _onRunPressed() async {
    final meta = _toolMeta[widget.tool]!;

    if (meta.needsPrompt && _promptController.text.trim().isEmpty) {
      _showSnack('Please enter a prompt', AppColors.error);
      return;
    }
    if (meta.needsImage && !_hasSourceImage) {
      _showSnack('Please upload a source image', AppColors.error);
      return;
    }



    // Check internet connectivity
    final online = await ConnectivityService.instance.requireInternet(
      context,
      featureName: _toolMeta[widget.tool]?.title ?? 'AI Tool',
    );
    if (!online) return;

    // Generate directly
    ref.read(imageToolProvider.notifier).reset();
    await _runGeneration();

    // Refresh credits after generation
    ref.read(authProvider.notifier).refreshUserData();
  }

  Future<void> _runGeneration() async {
    // Pass actual image bytes to the provider
    final imageBase64 = _pickedImageBytes != null
        ? base64Encode(_pickedImageBytes!)
        : null;

    await ref.read(imageToolProvider.notifier).run(
          tool: widget.tool,
          prompt: _promptController.text.trim(),
          imageBase64: imageBase64,
        );
  }

  void _showSnack(String msg, Color color) {
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
    final meta = _toolMeta[widget.tool] ??
        _ToolMeta(
          title: 'Image Tool',
          subtitle: '',
          icon: Icons.image,
          color: AppColors.primary,
          needsPrompt: true,
          needsImage: false,
          hint: '',
        );
    final toolState = ref.watch(imageToolProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context, meta),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildToolHeader(meta),
                      const SizedBox(height: 20),
                      const SizedBox(height: 16),
                      if (meta.needsImage) _buildImageUpload(),
                      if (meta.needsImage) const SizedBox(height: 16),
                      if (meta.needsPrompt) _buildPromptInput(meta),
                      if (meta.needsPrompt) const SizedBox(height: 16),
                      if (toolState.status == ImageToolStatus.loading)
                        _buildProgress(toolState.progress)
                      else
                        GradientButton(
                          text: 'Run ${meta.title}',
                          onPressed: _onRunPressed,
                          width: double.infinity,
                          height: 54,
                          gradientColors: [
                            meta.color,
                            meta.color.withValues(alpha: 0.7)
                          ],
                          icon: Icon(meta.icon, color: Colors.white, size: 20),
                        ),
                      if (toolState.status == ImageToolStatus.done &&
                          (toolState.resultUrl != null || toolState.resultBase64 != null)) ...[
                        const SizedBox(height: 24),
                        _buildResult(toolState.resultUrl, toolState.resultBase64),
                      ],
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

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context, _ToolMeta meta) {
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
              color: meta.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: meta.color.withValues(alpha: 0.3)),
            ),
            child: Icon(meta.icon, color: meta.color, size: 18),
          ),
          const SizedBox(width: 10),
          Text(meta.title,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildToolHeader(_ToolMeta meta) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [meta.color, meta.color.withValues(alpha: 0.6)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(meta.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meta.title,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(meta.subtitle,
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
                  ),
                  child: const Text('Powered by VisionAI',
                      style: TextStyle(
                          color: Color(0xFF9F67FF),
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildImageUpload() {
    return GestureDetector(
      onTap: _pickImage,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: _hasSourceImage ? 180 : 130,
        decoration: BoxDecoration(
          color: _hasSourceImage
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hasSourceImage ? AppColors.primary : AppColors.cardBorder,
            width: _hasSourceImage ? 1.5 : 1,
          ),
        ),
        child: _hasSourceImage && _pickedImageBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(
                      Uint8List.fromList(_pickedImageBytes!),
                      fit: BoxFit.cover,
                    ),
                    // Overlay with change button
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text('Change',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                    // Check badge
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            color: Colors.white, size: 12),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.upload_file_outlined,
                    color: AppColors.textMuted,
                    size: 34,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload source image',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text('Tap to select from gallery',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildPromptInput(_ToolMeta meta) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Prompt',
            style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AnimatedInput(
                hint: meta.hint,
                controller: _promptController,
                maxLines: 3,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                IconButton(
                  tooltip: 'Save prompt',
                  onPressed: () async {
                    final current = _promptController.text.trim();
                    if (current.isEmpty) {
                      _showSnack('Prompt is empty', AppColors.error);
                      return;
                    }
                    final titleController = TextEditingController();
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Save Prompt'),
                        content: TextField(
                          controller: titleController,
                          decoration: const InputDecoration(hintText: 'Enter a title'),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      final title = titleController.text.trim();
                      if (title.isEmpty) {
                        _showSnack('Title is required', AppColors.error);
                        return;
                      }
                      final created = await ref.read(promptProvider.notifier).createPrompt(title, current);
                      if (created) {
                        _showSnack('Prompt saved', AppColors.success);
                      } else {
                        _showSnack('Failed to save prompt', AppColors.error);
                      }
                    }
                  },
                  icon: const Icon(Icons.bookmark_add_outlined),
                ),
                IconButton(
                  tooltip: 'Saved prompts',
                  onPressed: () async {
                    final result = await Navigator.push<String?>(
                      context,
                      MaterialPageRoute(builder: (_) => const SavedPromptsScreen()),
                    );
                    if (result != null && result.isNotEmpty) {
                      _promptController.text = result;
                    }
                  },
                  icon: const Icon(Icons.storage_outlined),
                ),
              ],
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 250.ms);
  }

  Widget _buildProgress(double progress) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              Text('Processing with AI...',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.surfaceLight,
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text('${(progress * 100).toInt()}% complete',
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildResult(String? url, String? base64Data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Generated Image',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        GlassCard(
          padding: EdgeInsets.zero,
          borderRadius: 20,
          child: Column(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                child: _buildImageWidget(url, base64Data),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: GradientButton(
                        text: 'Download',
                        onPressed: () => _downloadImage(url, base64Data),
                        height: 44,
                        gradientColors: [
                          AppColors.primary,
                          AppColors.secondary
                        ],
                        icon: const Icon(Icons.download,
                            color: Colors.white, size: 16),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GradientButton(
                        text: 'Share',
                        onPressed: () => _shareImage(url, base64Data),
                        height: 44,
                        gradientColors: [
                          AppColors.secondary,
                          AppColors.accent
                        ],
                        icon: const Icon(Icons.share,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2);
  }

  Widget _buildImageWidget(String? url, String? base64Data) {
    // Prefer base64 (direct from AI) over URL
    if (base64Data != null && base64Data.isNotEmpty) {
      try {
        final bytes = Uint8List.fromList(base64Decode(base64Data));
        return Image.memory(
          bytes,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _imagePlaceholder(),
        );
      } catch (_) {
        return _imagePlaceholder();
      }
    }
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 250,
            color: AppColors.surfaceLight,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => _imagePlaceholder(),
      );
    }
    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 250,
      color: AppColors.surfaceLight,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined,
                color: AppColors.textMuted, size: 48),
            const SizedBox(height: 8),
            Text('Image could not be loaded',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadImage(String? url, String? base64Data) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'visionai_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${dir.path}/$fileName');

      if (base64Data != null && base64Data.isNotEmpty) {
        final bytes = base64Decode(base64Data);
        await file.writeAsBytes(bytes);
        if (mounted) _showSnack('Image saved!', AppColors.success);
      } else if (url != null && url.isNotEmpty) {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          await file.writeAsBytes(response.bodyBytes);
          if (mounted) _showSnack('Image saved!', AppColors.success);
        } else {
          if (mounted) _showSnack('Download failed', AppColors.error);
        }
      } else {
        _showSnack('No image to download', AppColors.error);
      }
    } catch (e) {
      _showSnack('Download failed: $e', AppColors.error);
    }
  }

  Future<void> _shareImage(String? url, String? base64Data) async {
    try {
      final dir = await getTemporaryDirectory();
      const fileName = 'visionai_share.png';
      final file = File('${dir.path}/$fileName');

      if (base64Data != null && base64Data.isNotEmpty) {
        final bytes = base64Decode(base64Data);
        await file.writeAsBytes(bytes);
      } else if (url != null && url.isNotEmpty) {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          await file.writeAsBytes(response.bodyBytes);
        } else {
          await Share.share('Created with VisionAI ✨');
          return;
        }
      } else {
        await Share.share('Created with VisionAI ✨');
        return;
      }

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Created with VisionAI ✨',
      );
    } catch (e) {
      await Share.share('Created with VisionAI ✨');
    }
  }
}

class _ToolMeta {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool needsPrompt;
  final bool needsImage;
  final String hint;

  const _ToolMeta({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.needsPrompt,
    required this.needsImage,
    required this.hint,
  });
}
