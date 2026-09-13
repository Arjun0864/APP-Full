import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/glass_card.dart';

const _kTermsAcceptedKey = 'terms_accepted_v1';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  static Future<bool> hasAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kTermsAcceptedKey) ?? false;
  }

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _ageConfirmed = false;
  bool _showTerms = false;
  bool _showPrivacy = false;

  bool get _canProceed => _termsAccepted && _privacyAccepted && _ageConfirmed;

  Future<void> _proceed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTermsAcceptedKey, true);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    if (_showTerms) return _buildTermsDocument(context);
    if (_showPrivacy) return _buildPrivacyDocument(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildHeader(),
                      const SizedBox(height: 32),
                      _buildCheckboxes(),
                      const SizedBox(height: 24),
                      _buildLegalNote(),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.gavel_rounded, color: Colors.white, size: 32),
        ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8), curve: Curves.elasticOut),
        const SizedBox(height: 20),
        Text('Before You Begin',
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800,
                color: AppColors.textPrimary, letterSpacing: -0.5))
            .animate().fadeIn(delay: 100.ms).slideX(begin: -0.2),
        const SizedBox(height: 8),
        Text(
          'Please review and accept our Terms of Service and Privacy Policy to continue.',
          style: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.5),
        ).animate().fadeIn(delay: 200.ms),
      ],
    );
  }

  Widget _buildCheckboxes() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildCheckItem(
            value: _termsAccepted,
            onChanged: (v) => setState(() => _termsAccepted = v ?? false),
            label: 'I have read and agree to the ',
            linkText: 'Terms of Service',
            onLinkTap: () => setState(() => _showTerms = true),
          ),
          Divider(color: AppColors.cardBorder, height: 24),
          _buildCheckItem(
            value: _privacyAccepted,
            onChanged: (v) => setState(() => _privacyAccepted = v ?? false),
            label: 'I have read and agree to the ',
            linkText: 'Privacy Policy',
            onLinkTap: () => setState(() => _showPrivacy = true),
          ),
          Divider(color: AppColors.cardBorder, height: 24),
          _buildCheckItem(
            value: _ageConfirmed,
            onChanged: (v) => setState(() => _ageConfirmed = v ?? false),
            label: 'I confirm that I am 13 years of age or older',
            linkText: '',
            onLinkTap: null,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2);
  }

  Widget _buildCheckItem({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String label,
    required String linkText,
    VoidCallback? onLinkTap,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24, height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
            checkColor: Colors.white,
            side: BorderSide(color: AppColors.cardBorder, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: linkText.isEmpty
              ? Text(label,
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 14, height: 1.4))
              : RichText(
                  text: TextSpan(
                    text: label,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                    children: [
                      TextSpan(
                        text: linkText,
                        style: TextStyle(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()..onTap = onLinkTap,
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildLegalNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'By using AI Video Generator, you agree that AI-generated content '
              'is for personal and commercial use within our license terms. '
              'You are responsible for ensuring generated content complies with '
              'applicable laws in your jurisdiction.',
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 11, height: 1.5),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GradientButton(
            text: 'Continue',
            onPressed: _canProceed ? _proceed : null,
            width: double.infinity,
            height: 54,
            gradientColors: _canProceed
                ? AppColors.accentGradient.colors
                : [AppColors.surfaceLight, AppColors.surfaceLight],
          ),
          if (!_canProceed) ...[
            const SizedBox(height: 8),
            Text(
              'Please accept all terms to continue',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  // ── Terms of Service Document ─────────────────────────────────────────────

  Widget _buildTermsDocument(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: Colors.white,
        title: const Text('Terms of Service'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => setState(() => _showTerms = false),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _docSection('Last Updated: January 1, 2025', isSubtitle: true),
            _docSection('1. Acceptance of Terms',
                body: 'By accessing or using AI Video Generator ("the App"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, please do not use the App. These Terms constitute a legally binding agreement between you and AI Video Generator ("we," "us," or "our").'),
            _docSection('2. Eligibility',
                body: 'You must be at least 13 years of age to use this App. By using the App, you represent and warrant that you meet this age requirement. If you are under 18, you represent that your parent or legal guardian has reviewed and agreed to these Terms on your behalf.'),
            _docSection('3. Account Registration',
                body: 'To access certain features, you must create an account. You agree to:\n• Provide accurate, current, and complete information\n• Maintain the security of your account credentials\n• Notify us immediately of any unauthorized access\n• Accept responsibility for all activities under your account\n\nWe reserve the right to terminate accounts that violate these Terms.'),
            _docSection('4. AI-Generated Content',
                body: 'The App uses artificial intelligence to generate images and videos based on your prompts. You acknowledge that:\n• AI-generated content may be unpredictable\n• You own the content you generate through the App\n• You are solely responsible for how you use generated content\n• Generated content must not violate any laws or third-party rights\n• We do not guarantee the accuracy, quality, or appropriateness of generated content'),
            _docSection('5. Prohibited Uses',
                body: 'You agree NOT to use the App to:\n• Generate content that is illegal, harmful, threatening, abusive, harassing, defamatory, or obscene\n• Create deepfakes or misleading content about real people without consent\n• Generate content that infringes intellectual property rights\n• Produce child sexual abuse material (CSAM) — strictly prohibited and will be reported to authorities\n• Circumvent security measures or access controls\n• Use the App for commercial purposes beyond your subscription tier\n• Reverse engineer, decompile, or disassemble the App\n• Use automated tools to access the App without authorization'),
            _docSection('6. Subscription and Payments',
                body: 'The App offers free and paid subscription tiers:\n• Free Tier: Limited credits per month with advertisements\n• Pro Tier: Enhanced credits, no watermarks, reduced ads\n• Ultra Tier: Unlimited credits, no ads, priority processing\n\nSubscriptions are billed monthly or annually. All payments are processed through Google Play or Apple App Store. Refunds are subject to the respective platform\'s refund policy. We reserve the right to modify pricing with 30 days notice.'),
            _docSection('7. Advertisements',
                body: 'Free tier users will see advertisements within the App. By using the free tier, you consent to viewing advertisements. Advertisements are served by third-party networks and are subject to their respective privacy policies. Pro and Ultra subscribers receive reduced or no advertisements as specified in their plan.'),
            _docSection('8. Intellectual Property',
                body: 'The App and its original content, features, and functionality are owned by AI Video Generator and are protected by international copyright, trademark, patent, trade secret, and other intellectual property laws. You retain ownership of content you generate using the App, subject to our license to use such content for service improvement.'),
            _docSection('9. Privacy',
                body: 'Your use of the App is also governed by our Privacy Policy, which is incorporated into these Terms by reference. Please review our Privacy Policy to understand our practices.'),
            _docSection('10. Disclaimer of Warranties',
                body: 'THE APP IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED. WE DISCLAIM ALL WARRANTIES INCLUDING IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT. WE DO NOT WARRANT THAT THE APP WILL BE UNINTERRUPTED, ERROR-FREE, OR FREE OF VIRUSES.'),
            _docSection('11. Limitation of Liability',
                body: 'TO THE MAXIMUM EXTENT PERMITTED BY LAW, AI VIDEO GENERATOR SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, INCLUDING LOSS OF PROFITS, DATA, OR GOODWILL, ARISING FROM YOUR USE OF THE APP. OUR TOTAL LIABILITY SHALL NOT EXCEED THE AMOUNT YOU PAID US IN THE PAST 12 MONTHS.'),
            _docSection('12. Indemnification',
                body: 'You agree to indemnify, defend, and hold harmless AI Video Generator and its officers, directors, employees, and agents from any claims, damages, losses, liabilities, costs, and expenses arising from your use of the App, violation of these Terms, or infringement of any third-party rights.'),
            _docSection('13. Governing Law',
                body: 'These Terms shall be governed by and construed in accordance with applicable laws. Any disputes shall be resolved through binding arbitration, except where prohibited by law. You waive any right to participate in class action lawsuits.'),
            _docSection('14. Changes to Terms',
                body: 'We reserve the right to modify these Terms at any time. We will notify you of significant changes via email or in-app notification. Continued use of the App after changes constitutes acceptance of the new Terms.'),
            _docSection('15. Contact Us',
                body: 'For questions about these Terms, please contact us at:\nsupport@aivideogenerator.app\n\nAI Video Generator\nAll rights reserved.'),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Privacy Policy Document ───────────────────────────────────────────────

  Widget _buildPrivacyDocument(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: Colors.white,
        title: const Text('Privacy Policy'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => setState(() => _showPrivacy = false),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _docSection('Last Updated: January 1, 2025', isSubtitle: true),
            _docSection('Introduction',
                body: 'AI Video Generator ("we," "us," or "our") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application. Please read this policy carefully. If you disagree with its terms, please discontinue use of the App.'),
            _docSection('1. Information We Collect',
                body: 'We collect the following types of information:\n\n'
                    'A. Information You Provide:\n'
                    '• Account information (name, email address)\n'
                    '• Profile information (avatar, preferences)\n'
                    '• Content you create (prompts, generated images/videos)\n'
                    '• Payment information (processed by Google/Apple, not stored by us)\n'
                    '• Communications with our support team\n\n'
                    'B. Automatically Collected Information:\n'
                    '• Device information (model, OS version, unique device identifiers)\n'
                    '• Usage data (features used, time spent, crash reports)\n'
                    '• IP address and approximate location (country/region)\n'
                    '• App performance metrics\n\n'
                    'C. Information from Third Parties:\n'
                    '• Google Sign-In: name, email, profile picture\n'
                    '• Apple Sign-In: name, email (may be anonymized)\n'
                    '• Firebase Authentication: authentication tokens'),
            _docSection('2. How We Use Your Information',
                body: 'We use collected information to:\n'
                    '• Provide, maintain, and improve the App\n'
                    '• Process transactions and manage subscriptions\n'
                    '• Send transactional emails (receipts, security alerts)\n'
                    '• Send promotional communications (with your consent)\n'
                    '• Analyze usage patterns to improve user experience\n'
                    '• Detect and prevent fraud, abuse, and security incidents\n'
                    '• Comply with legal obligations\n'
                    '• Respond to your requests and support inquiries\n'
                    '• Train and improve our AI models (anonymized data only)'),
            _docSection('3. Data Sharing and Disclosure',
                body: 'We do NOT sell your personal data. We may share information with:\n\n'
                    '• Service Providers: Firebase (Google), AI generation providers, payment processors, analytics providers — all bound by confidentiality agreements\n'
                    '• Legal Requirements: When required by law, court order, or government authority\n'
                    '• Safety: To protect the rights, property, or safety of our users or the public\n'
                    '• Business Transfers: In connection with a merger, acquisition, or sale of assets\n\n'
                    'Third-party AI providers receive your prompts to generate content. Please review their privacy policies.'),
            _docSection('4. Data Retention',
                body: 'We retain your data for as long as your account is active or as needed to provide services. You may request deletion of your account and associated data at any time. Some data may be retained for legal compliance purposes for up to 7 years. Generated content may be retained in anonymized form for AI model improvement.'),
            _docSection('5. Data Security',
                body: 'We implement industry-standard security measures including:\n'
                    '• Encryption in transit (TLS/HTTPS)\n'
                    '• Encryption at rest for sensitive data\n'
                    '• Android Keystore / iOS Keychain for local credential storage\n'
                    '• Regular security audits\n'
                    '• Access controls and authentication\n\n'
                    'No method of transmission over the internet is 100% secure. We cannot guarantee absolute security.'),
            _docSection('6. Your Rights',
                body: 'Depending on your location, you may have the right to:\n'
                    '• Access your personal data\n'
                    '• Correct inaccurate data\n'
                    '• Delete your data ("right to be forgotten")\n'
                    '• Restrict or object to processing\n'
                    '• Data portability\n'
                    '• Withdraw consent\n\n'
                    'To exercise these rights, contact us at privacy@aivideogenerator.app. We will respond within 30 days.'),
            _docSection('7. Children\'s Privacy',
                body: 'The App is not directed to children under 13. We do not knowingly collect personal information from children under 13. If we discover we have collected such information, we will delete it immediately. If you believe we have collected information from a child under 13, please contact us immediately.'),
            _docSection('8. Advertising',
                body: 'Free tier users see advertisements served by third-party ad networks. These networks may use cookies and similar technologies to serve relevant ads. We do not share your personal data with advertisers. You can opt out of personalized advertising through your device settings. Ad networks have their own privacy policies.'),
            _docSection('9. International Data Transfers',
                body: 'Your information may be transferred to and processed in countries other than your own. We ensure appropriate safeguards are in place for such transfers, including standard contractual clauses approved by relevant authorities.'),
            _docSection('10. Cookies and Tracking',
                body: 'The App uses Firebase Analytics and Crashlytics for performance monitoring. These tools collect anonymized usage data. You can opt out of analytics collection in the App settings. We do not use tracking cookies for advertising purposes in the mobile app.'),
            _docSection('11. Changes to This Policy',
                body: 'We may update this Privacy Policy periodically. We will notify you of material changes via in-app notification or email. Your continued use of the App after changes constitutes acceptance of the updated policy.'),
            _docSection('12. Contact Us',
                body: 'For privacy-related questions or to exercise your rights:\n\n'
                    'Email: privacy@aivideogenerator.app\n'
                    'Subject: Privacy Request\n\n'
                    'AI Video Generator\n'
                    'Data Protection Officer\n'
                    'support@aivideogenerator.app'),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _docSection(String title, {String? body, bool isSubtitle = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isSubtitle ? 12 : 16,
              fontWeight: isSubtitle ? FontWeight.w400 : FontWeight.w700,
              color: isSubtitle ? AppColors.textMuted : AppColors.textPrimary,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: 8),
            Text(
              body,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.6),
            ),
          ],
        ],
      ),
    );
  }
}
