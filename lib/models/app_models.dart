import 'package:flutter/material.dart';

enum VideoStatus { pending, generating, completed, failed }
// PlanType kept for backward compat but only 'free' is used now
enum PlanType { free, pro, ultra }

// ── Generated Image Model ─────────────────────────────────────────────────────

class GeneratedImage {
  final String id;
  final String prompt;
  final String? imageBase64;
  final String? imageUrl;
  final String tool;
  final DateTime createdAt;
  final int creditsUsed;

  const GeneratedImage({
    required this.id,
    required this.prompt,
    this.imageBase64,
    this.imageUrl,
    required this.tool,
    required this.createdAt,
    required this.creditsUsed,
  });

  factory GeneratedImage.fromJson(Map<String, dynamic> json) {
    return GeneratedImage(
      id: json['id'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      imageBase64: json['image_base64'] as String?,
      imageUrl: json['image_url'] as String?,
      tool: json['tool'] as String? ?? 'generate',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      creditsUsed: (json['credits_used'] as int?) ?? 3,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'prompt': prompt,
        'image_base64': imageBase64,
        'image_url': imageUrl,
        'tool': tool,
        'created_at': createdAt.toIso8601String(),
        'credits_used': creditsUsed,
      };
}

// ── Credit Package Model ──────────────────────────────────────────────────────

class CreditPackage {
  final String id;
  final int credits;
  final double price;       // Display price (USD for reference)
  final int amountPaise;    // Razorpay amount in paise (INR × 100)
  final String? bonus;
  final bool isPopular;
  final List<Color> gradientColors;

  const CreditPackage({
    required this.id,
    required this.credits,
    required this.price,
    required this.amountPaise,
    this.bonus,
    this.isPopular = false,
    required this.gradientColors,
  });

  String get displayPrice => '₹${(amountPaise / 100).toStringAsFixed(0)}';
  String get pricePerCredit =>
      '₹${(amountPaise / 100 / credits).toStringAsFixed(2)}/credit';

  static const List<CreditPackage> packages = [
    CreditPackage(
      id: 'credits_10',
      credits: 10,
      price: 0.99,
      amountPaise: 9900,  // ₹99 -> 10 credits
      gradientColors: [Color(0xFF6B7280), Color(0xFF374151)],
    ),
    CreditPackage(
      id: 'credits_35',
      credits: 35,
      price: 2.99,
      amountPaise: 29900, // ₹299 -> 35 credits
      bonus: 'Starter Pack',
      gradientColors: [Color(0xFF3B82F6), Color(0xFF7C3AED)],
    ),
    CreditPackage(
      id: 'credits_80',
      credits: 80,
      price: 5.99,
      amountPaise: 59900, // ₹599 -> 80 credits
      bonus: 'Save 20%',
      isPopular: true,
      gradientColors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
    ),
    CreditPackage(
      id: 'credits_200',
      credits: 200,
      price: 11.99,
      amountPaise: 119900, // ₹1199 -> 200 credits
      bonus: 'Best Value (Save 35%)',
      gradientColors: [Color(0xFFEC4899), Color(0xFFF59E0B)],
    ),
  ];
}

// ── Transaction Model ─────────────────────────────────────────────────────────

enum TransactionType { purchase, deduction, reward, refund }

class Transaction {
  final String id;
  final TransactionType type;
  final int credits;
  final String description;
  final DateTime createdAt;
  final double? amount;

  const Transaction({
    required this.id,
    required this.type,
    required this.credits,
    required this.description,
    required this.createdAt,
    this.amount,
  });

  bool get isCredit => type == TransactionType.purchase || type == TransactionType.reward;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String? ?? '',
      type: _parseType(json['type'] as String? ?? 'deduction'),
      credits: (json['credits'] as int?) ?? 0,
      description: json['description'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      amount: (json['amount'] as num?)?.toDouble(),
    );
  }

  static TransactionType _parseType(String t) {
    switch (t) {
      case 'purchase': return TransactionType.purchase;
      case 'reward': return TransactionType.reward;
      case 'refund': return TransactionType.refund;
      default: return TransactionType.deduction;
    }
  }
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final String avatarUrl;
  final PlanType plan;
  final int credits;
  final int totalVideos;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.plan,
    required this.credits,
    required this.totalVideos,
  });

  UserModel copyWith({
    String? name,
    String? email,
    PlanType? plan,
    int? credits,
    int? totalVideos,
    String? avatarUrl,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      plan: plan ?? this.plan,
      credits: credits ?? this.credits,
      totalVideos: totalVideos ?? this.totalVideos,
    );
  }

  static const UserModel mock = UserModel(
    id: 'user_001',
    name: 'Alex Johnson',
    email: 'alex@example.com',
    avatarUrl: 'https://i.pravatar.cc/150?img=3',
    plan: PlanType.free,
    credits: 10,
    totalVideos: 0,
  );
}

class VideoModel {
  final String id;
  final String prompt;
  final String thumbnailUrl;
  final String videoUrl;
  final String? resultBase64; // base64-encoded video or image bytes from backend
  final bool isImageOnly;     // true when video generation fell back to image
  final VideoStatus status;
  final DateTime createdAt;
  final Duration duration;
  final bool hasWatermark;

  const VideoModel({
    required this.id,
    required this.prompt,
    required this.thumbnailUrl,
    required this.videoUrl,
    this.resultBase64,
    this.isImageOnly = false,
    required this.status,
    required this.createdAt,
    required this.duration,
    required this.hasWatermark,
  });

  VideoModel copyWith({
    String? thumbnailUrl,
    String? videoUrl,
    String? resultBase64,
    bool? isImageOnly,
    VideoStatus? status,
    bool? hasWatermark,
  }) {
    return VideoModel(
      id: id,
      prompt: prompt,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      resultBase64: resultBase64 ?? this.resultBase64,
      isImageOnly: isImageOnly ?? this.isImageOnly,
      status: status ?? this.status,
      createdAt: createdAt,
      duration: duration,
      hasWatermark: hasWatermark ?? this.hasWatermark,
    );
  }
}

class TemplateModel {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final String samplePrompt;
  final List<Color> colors;

  const TemplateModel({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.samplePrompt,
    required this.colors,
  });

  static const List<TemplateModel> templates = [
    TemplateModel(
      id: 't1',
      name: 'Cinematic',
      description: 'Epic movie-style visuals',
      emoji: '🎬',
      samplePrompt: 'A cinematic shot of a lone warrior standing on a cliff at sunset',
      colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)],
    ),
    TemplateModel(
      id: 't2',
      name: 'Nature',
      description: 'Beautiful natural landscapes',
      emoji: '🌿',
      samplePrompt: 'Lush green forest with sunlight filtering through the trees',
      colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
    ),
    TemplateModel(
      id: 't3',
      name: 'Sci-Fi',
      description: 'Futuristic worlds & tech',
      emoji: '🚀',
      samplePrompt: 'A spaceship traveling through a colorful nebula in deep space',
      colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
    ),
    TemplateModel(
      id: 't4',
      name: 'Abstract',
      description: 'Artistic visual patterns',
      emoji: '🎨',
      samplePrompt: 'Flowing abstract shapes with vibrant colors and smooth motion',
      colors: [Color(0xFFEC4899), Color(0xFFF59E0B)],
    ),
    TemplateModel(
      id: 't5',
      name: 'Urban',
      description: 'City life & architecture',
      emoji: '🏙️',
      samplePrompt: 'Busy city street at night with neon reflections on wet pavement',
      colors: [Color(0xFF374151), Color(0xFF7C3AED)],
    ),
    TemplateModel(
      id: 't6',
      name: 'Fantasy',
      description: 'Magical & mythical worlds',
      emoji: '✨',
      samplePrompt: 'An enchanted castle floating in the clouds surrounded by dragons',
      colors: [Color(0xFFF59E0B), Color(0xFFEC4899)],
    ),
  ];
}
