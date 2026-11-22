import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/candidate_profile.dart';
import '../providers/profile_provider.dart';

class EditCertificationsLanguagesScreen extends StatefulWidget {
  const EditCertificationsLanguagesScreen({super.key});

  @override
  State<EditCertificationsLanguagesScreen> createState() => _EditCertificationsLanguagesScreenState();
}

class _EditCertificationsLanguagesScreenState extends State<EditCertificationsLanguagesScreen> {
  late List<CertificationItem> _certifications;
  late List<LanguageItem> _languages;

  final _certNameController = TextEditingController();
  final _certOrgController = TextEditingController();
  final _langNameController = TextEditingController();
  LanguageProficiency _selectedProficiency = LanguageProficiency.fluent;

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileProvider>().profile;
    _certifications = List<CertificationItem>.from(profile?.certifications ?? []);
    _languages = List<LanguageItem>.from(profile?.languages ?? []);
  }

  @override
  void dispose() {
    _certNameController.dispose();
    _certOrgController.dispose();
    _langNameController.dispose();
    super.dispose();
  }

  void _addCertification() {
    if (_certNameController.text.trim().isEmpty || _certOrgController.text.trim().isEmpty) return;
    setState(() {
      _certifications.add(
        CertificationItem(
          name: _certNameController.text.trim(),
          issuingOrganization: _certOrgController.text.trim(),
          issueDate: DateTime.now(),
        ),
      );
      _certNameController.clear();
      _certOrgController.clear();
    });
  }

  void _addLanguage() {
    if (_langNameController.text.trim().isEmpty) return;
    setState(() {
      _languages.add(
        LanguageItem(
          language: _langNameController.text.trim(),
          proficiency: _selectedProficiency,
        ),
      );
      _langNameController.clear();
    });
  }

  Future<void> _handleSave() async {
    final provider = context.read<ProfileProvider>();
    final success = await provider.updateCertificationsAndLanguages(
      certifications: _certifications,
      languages: _languages,
    );
    if (success && mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final provider = context.watch<ProfileProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n?.editCertificationsTitle ?? 'Certifications & Languages'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isArabic ? 'الشهادات المهنية والاحترافية' : 'Professional Certifications', style: AppTypography.headlineSmall),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      hint: 'Certificate Name (e.g. AWS Solutions Architect)',
                      controller: _certNameController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      hint: 'Issuing Organization (e.g. Amazon)',
                      controller: _certOrgController,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _addCertification,
                    icon: const Icon(Icons.add_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(50, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_certifications.isNotEmpty)
                ..._certifications.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final cert = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.military_tech_rounded, color: Colors.amber),
                      title: Text(cert.name, style: AppTypography.titleLarge),
                      subtitle: Text('${cert.issuingOrganization} • ${DateFormat.y().format(cert.issueDate)}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                        onPressed: () => setState(() => _certifications.removeAt(idx)),
                      ),
                    ),
                  );
                }),

              const Divider(height: 40),

              Text(isArabic ? 'اللغات المتقنة' : 'Languages Spoken', style: AppTypography.headlineSmall),
              const SizedBox(height: 12),
              AppTextField(
                hint: 'Language (e.g. Arabic, English)',
                controller: _langNameController,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<LanguageProficiency>(
                      isExpanded: true,
                      initialValue: _selectedProficiency,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        labelText: isArabic ? 'مستوى الإتقان' : 'Proficiency Level',
                      ),
                      items: LanguageProficiency.values.map((p) {
                        return DropdownMenuItem(
                          value: p,
                          child: Text(
                            p.localizedString(isArabic),
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMedium,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedProficiency = val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _addLanguage,
                    icon: const Icon(Icons.add_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(50, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_languages.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _languages.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final lang = entry.value;
                    return Chip(
                      label: Text('${lang.language} (${lang.proficiency.localizedString(isArabic)})'),
                      deleteIcon: const Icon(Icons.close_rounded, size: 16),
                      onDeleted: () => setState(() => _languages.removeAt(idx)),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 40),
              AppButton(
                text: l10n?.saveChanges ?? 'Save Details',
                isLoading: provider.isSaving,
                onPressed: _handleSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
