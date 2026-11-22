import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/profile_provider.dart';

class EditPersonalInfoScreen extends StatefulWidget {
  const EditPersonalInfoScreen({super.key});

  @override
  State<EditPersonalInfoScreen> createState() => _EditPersonalInfoScreenState();
}

class _EditPersonalInfoScreenState extends State<EditPersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _headlineController;
  late final TextEditingController _aboutController;
  late final TextEditingController _phoneController;
  late final TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileProvider>().profile;
    _nameController = TextEditingController(text: profile?.fullName ?? '');
    _headlineController = TextEditingController(text: profile?.headline ?? '');
    _aboutController = TextEditingController(text: profile?.about ?? '');
    _phoneController = TextEditingController(text: profile?.phoneNumber ?? '');
    _locationController = TextEditingController(text: profile?.location ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _headlineController.dispose();
    _aboutController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ProfileProvider>();
    final success = await provider.updatePersonalInfo(
      fullName: _nameController.text,
      headline: _headlineController.text,
      about: _aboutController.text,
      phoneNumber: _phoneController.text,
      location: _locationController.text,
    );

    if (success && mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<ProfileProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n?.editPersonalInfoTitle ?? 'Edit Personal Info'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (provider.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      provider.errorMessage!,
                      style: AppTypography.bodySmall.copyWith(color: AppColors.error),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                AppTextField(
                  label: l10n?.fullName ?? 'Full Name',
                  controller: _nameController,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Full name is required.' : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: l10n?.headline ?? 'Professional Headline',
                  hint: 'e.g. Senior Flutter Developer | Mobile Architect',
                  controller: _headlineController,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Headline is required.' : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: l10n?.phoneNumber ?? 'Phone Number',
                  hint: '+1 234 567 8900',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: l10n?.location ?? 'Location',
                  hint: 'Amman, Jordan / Remote',
                  controller: _locationController,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: l10n?.aboutMe ?? 'About / Summary',
                  hint: 'Brief summary of your professional background, passions, and achievements...',
                  controller: _aboutController,
                  maxLines: 4,
                  validator: (val) => val == null || val.trim().isEmpty ? 'About summary is required.' : null,
                ),
                const SizedBox(height: 32),
                AppButton(
                  text: l10n?.saveChanges ?? 'Save Changes',
                  isLoading: provider.isSaving,
                  onPressed: _handleSave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
