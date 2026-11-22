import 'package:flutter/material.dart';
import 'package:mobile_app/core/constants/app_colors.dart';
import 'package:mobile_app/core/constants/app_typography.dart';
import 'package:mobile_app/features/career_site/domain/entities/company_career_page.dart';
import 'package:mobile_app/features/career_site/presentation/providers/career_page_provider.dart';
import 'package:provider/provider.dart';

class EditCompanyBrandingScreen extends StatefulWidget {
  final String companyId;

  const EditCompanyBrandingScreen({
    super.key,
    required this.companyId,
  });

  @override
  State<EditCompanyBrandingScreen> createState() => _EditCompanyBrandingScreenState();
}

class _EditCompanyBrandingScreenState extends State<EditCompanyBrandingScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _taglineController;
  late TextEditingController _coverUrlController;
  late TextEditingController _brandColorController;
  late TextEditingController _websiteController;
  late TextEditingController _linkedinController;
  late TextEditingController _twitterController;
  late TextEditingController _githubController;
  late TextEditingController _perkInputController;

  final List<String> _perks = [];

  final List<String> _presetBrandColors = [
    '#1E40AF', // Deep Blue
    '#0F172A', // Slate Dark
    '#047857', // Emerald
    '#7C3AED', // Violet
    '#BE185D', // Pink/Rose
    '#D97706', // Amber/Gold
    '#0EA5E9', // Sky Blue
  ];

  bool _initializedWithData = false;
  CareerPageProvider? _careerProvider;

  @override
  void initState() {
    super.initState();
    final currentProvider = context.read<CareerPageProvider>();
    final currentBranding = currentProvider.careerPage?.branding;

    _taglineController = TextEditingController(text: currentBranding?.tagline ?? '');
    _coverUrlController = TextEditingController(text: currentBranding?.coverImageUrl ?? '');
    _brandColorController = TextEditingController(
      text: (currentBranding != null &&
              currentBranding.brandColorHex != null &&
              currentBranding.brandColorHex!.isNotEmpty)
          ? currentBranding.brandColorHex!
          : '#1E40AF',
    );
    _websiteController = TextEditingController(text: currentBranding?.websiteUrl ?? '');
    _linkedinController = TextEditingController(text: currentBranding?.linkedinUrl ?? '');
    _twitterController = TextEditingController(text: currentBranding?.twitterUrl ?? '');
    _githubController = TextEditingController(text: currentBranding?.githubUrl ?? '');
    _perkInputController = TextEditingController();

    if (currentBranding != null) {
      _initializedWithData = true;
      if (currentBranding.perksAndBenefits.isNotEmpty) {
        _perks.addAll(currentBranding.perksAndBenefits);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _careerProvider = context.read<CareerPageProvider>();
      _careerProvider?.addListener(_onCareerProviderChanged);

      if (_careerProvider?.careerPage == null || _careerProvider?.careerPage?.companyId != widget.companyId) {
        _careerProvider?.listenCareerPage(widget.companyId);
      }
    });
  }

  void _onCareerProviderChanged() {
    if (!mounted || _initializedWithData) return;
    final page = _careerProvider?.careerPage;
    if (page != null) {
      setState(() {
        _populateFromBranding(page.branding);
      });
    }
  }

  void _populateFromBranding(CompanyBranding b) {
    if (_initializedWithData) return;
    _initializedWithData = true;
    _taglineController.text = b.tagline ?? '';
    _coverUrlController.text = b.coverImageUrl ?? '';
    if (b.brandColorHex != null && b.brandColorHex!.isNotEmpty) {
      _brandColorController.text = b.brandColorHex!;
    }
    _websiteController.text = b.websiteUrl ?? '';
    _linkedinController.text = b.linkedinUrl ?? '';
    _twitterController.text = b.twitterUrl ?? '';
    _githubController.text = b.githubUrl ?? '';
    _perks.clear();
    _perks.addAll(b.perksAndBenefits);
  }

  @override
  void dispose() {
    _careerProvider?.removeListener(_onCareerProviderChanged);
    _taglineController.dispose();
    _coverUrlController.dispose();
    _brandColorController.dispose();
    _websiteController.dispose();
    _linkedinController.dispose();
    _twitterController.dispose();
    _githubController.dispose();
    _perkInputController.dispose();
    super.dispose();
  }

  void _addPerk() {
    final text = _perkInputController.text.trim();
    if (text.isNotEmpty && !_perks.contains(text)) {
      setState(() {
        _perks.add(text);
        _perkInputController.clear();
      });
    }
  }

  void _removePerk(String perk) {
    setState(() {
      _perks.remove(perk);
    });
  }

  Future<void> _saveBranding() async {
    if (_formKey.currentState?.validate() != true) return;

    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final updatedBranding = CompanyBranding(
      tagline: _taglineController.text.trim().isNotEmpty ? _taglineController.text.trim() : null,
      coverImageUrl: _coverUrlController.text.trim().isNotEmpty ? _coverUrlController.text.trim() : null,
      brandColorHex: _brandColorController.text.trim(),
      perksAndBenefits: _perks,
      websiteUrl: _websiteController.text.trim().isNotEmpty ? _websiteController.text.trim() : null,
      linkedinUrl: _linkedinController.text.trim().isNotEmpty ? _linkedinController.text.trim() : null,
      twitterUrl: _twitterController.text.trim().isNotEmpty ? _twitterController.text.trim() : null,
      githubUrl: _githubController.text.trim().isNotEmpty ? _githubController.text.trim() : null,
    );

    final provider = context.read<CareerPageProvider>();
    final success = await provider.updateCompanyBranding(
          companyId: widget.companyId,
          branding: updatedBranding,
        );

    if (!mounted) return;
    if (success) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تم تحديث الهوية والبوابة المهنية بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
      nav.pop();
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'تعذر حفظ إعدادات الهوية، حاول مرة أخرى.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final careerProvider = context.watch<CareerPageProvider>();
    final isSaving = careerProvider.isSaving;

    if (careerProvider.isLoading && !_initializedWithData && careerProvider.careerPage == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('تخصيص الهوية والبوابة المهنية'),
          centerTitle: true,
          backgroundColor: AppColors.surface,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('تخصيص الهوية والبوابة المهنية'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: isSaving ? null : _saveBranding,
            child: isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'حفظ',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Intro
              Text(
                'إبراز العلامة التجارية وثقافة العمل',
                style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'تساعد هذه الإعدادات في تصميم بوابة توظيف احترافية تجذب أفضل الكفاءات للمنشأة.',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),

              // Tagline
              TextFormField(
                controller: _taglineController,
                decoration: const InputDecoration(
                  labelText: 'الشعار الترويجي للشركة (Company Tagline)',
                  hintText: 'مثال: نبني مستقبل الذكاء الاصطناعي في المنطقة',
                  prefixIcon: Icon(Icons.campaign_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Cover Image URL
              TextFormField(
                controller: _coverUrlController,
                decoration: const InputDecoration(
                  labelText: 'رابط صورة الغلاف (Cover Banner URL)',
                  hintText: 'https://example.com/cover.jpg',
                  prefixIcon: Icon(Icons.image_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Brand Theme Color Picker
              Text(
                'لون العلامة التجارية الأساسي (Primary Brand Color)',
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: _presetBrandColors.map((colorHex) {
                  final isSelected = _brandColorController.text.toUpperCase() == colorHex.toUpperCase();
                  Color color;
                  try {
                    color = Color(int.parse('FF${colorHex.replaceAll('#', '')}', radix: 16));
                  } catch (_) {
                    color = AppColors.primary;
                  }
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _brandColorController.text = colorHex;
                      });
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Perks and Benefits Section
              Text(
                'مزايا وبيئة العمل (Perks & Culture)',
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _perkInputController,
                      decoration: const InputDecoration(
                        hintText: 'مثال: تأمين طبي شامل، عمل عن بعد مرن...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onSubmitted: (_) => _addPerk(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _addPerk,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    child: const Text('إضافة'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _perks.map((p) {
                  return Chip(
                    label: Text(p),
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _removePerk(p),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Social Links
              Text(
                'الروابط والمنصات (Social & Web Presence)',
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _websiteController,
                decoration: const InputDecoration(
                  labelText: 'الموقع الرسمي للشركة (Website)',
                  prefixIcon: Icon(Icons.language_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _linkedinController,
                decoration: const InputDecoration(
                  labelText: 'رابط صفحة LinkedIn',
                  prefixIcon: Icon(Icons.business_center_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _twitterController,
                decoration: const InputDecoration(
                  labelText: 'حساب X / Twitter',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _githubController,
                decoration: const InputDecoration(
                  labelText: 'رابط GitHub المنظمة (إن وجد)',
                  prefixIcon: Icon(Icons.code_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving ? null : _saveBranding,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'حفظ التعديلات ونشر الهوية',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
