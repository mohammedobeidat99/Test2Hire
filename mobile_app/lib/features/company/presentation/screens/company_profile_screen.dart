import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/company_provider.dart';
import '../widgets/verification_status_banner.dart';

class CompanyProfileScreen extends StatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<AuthProvider>().user?.uid;
      if (uid != null) {
        context.read<CompanyProvider>().loadCompany(uid);
      }
    });
  }

  Future<void> _pickLogo(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      Uint8List? fileBytes = file.bytes;
      if (!kIsWeb && fileBytes == null && file.path != null) {
        final f = File(file.path!);
        if (await f.exists()) {
          fileBytes = await f.readAsBytes();
        }
      }
      if (fileBytes != null && context.mounted) {
        final provider = context.read<CompanyProvider>();
        final success = await provider.uploadLogo(fileBytes, file.name);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Company logo updated successfully.'
                  : (provider.errorMessage ?? 'Failed to upload company logo.'),
            ),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read selected image file.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CompanyProvider>();
    final company = provider.company;

    if (provider.isLoading && company == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded),
            tooltip: 'Edit Profile',
            onPressed: () => context.push('/company/edit-profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final uid = context.read<AuthProvider>().user?.uid;
          if (uid != null) {
            await context.read<CompanyProvider>().loadCompany(uid);
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (provider.errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          provider.errorMessage!,
                          style: AppTypography.bodySmall.copyWith(color: AppColors.error),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          final uid = context.read<AuthProvider>().user?.uid;
                          if (uid != null) {
                            context.read<CompanyProvider>().loadCompany(uid);
                          }
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ],
              // Logo & Company Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        Builder(
                          builder: (context) {
                            final logoProvider = getSafeImageProvider(company?.logoUrl);
                            return Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                                image: logoProvider != null
                                    ? DecorationImage(image: logoProvider, fit: BoxFit.cover)
                                    : null,
                              ),
                              child: logoProvider == null
                                  ? Center(
                                      child: Text(
                                        (company?.name != null && company!.name.isNotEmpty)
                                            ? company.name[0].toUpperCase()
                                            : 'C',
                                        style: AppTypography.displaySmall.copyWith(color: AppColors.primary),
                                      ),
                                    )
                                  : null,
                            );
                          },
                        ),
                        PositionedDirectional(
                          bottom: -4,
                          end: -4,
                          child: InkWell(
                            onTap: () => _pickLogo(context),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            company?.name ?? 'Company Name',
                            style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            company?.industry ?? 'Industry Sector',
                            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          if (company?.location != null) ...[
                            Text(
                              company?.location?.formatted ?? '',
                              style: AppTypography.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Verification Status Banner
              if (company != null) ...[
                VerificationStatusBanner(company: company),
                const SizedBox(height: 16),
              ],

              // Organization Details Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Organization Details', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 14),
                    _DetailRow(
                      icon: Icons.language_rounded,
                      label: 'Website',
                      value: (company?.website != null && company!.website!.isNotEmpty) ? company.website! : 'Not specified',
                    ),
                    const Divider(height: 20),
                    _DetailRow(
                      icon: Icons.groups_rounded,
                      label: 'Company Size',
                      value: company?.teamSize ?? 'Not specified',
                    ),
                    const Divider(height: 20),
                    _DetailRow(
                      icon: Icons.email_outlined,
                      label: 'Contact Email',
                      value: company?.contactEmail ?? 'Not specified',
                    ),
                    const Divider(height: 20),
                    _DetailRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: (company?.contactPhone != null && company!.contactPhone!.isNotEmpty) ? company.contactPhone! : 'Not specified',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // About Company Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('About the Organization', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(
                      (company?.description != null && company!.description.isNotEmpty)
                          ? company.description
                          : 'No company description added yet. Add an overview to attract top candidates.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: (company?.description != null && company!.description.isNotEmpty) ? AppColors.textPrimary : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              AppButton(
                text: 'Edit Company Profile',
                variant: AppButtonVariant.outline,
                onPressed: () => context.push('/company/edit-profile'),
              ),
              const SizedBox(height: 12),
              AppButton(
                text: 'Customize Career Site & Branding',
                icon: Icons.palette_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: () => context.push('/company/branding/edit'),
              ),
              if (company != null) ...[
                const SizedBox(height: 12),
                AppButton(
                  text: 'Preview Public Career Site',
                  icon: Icons.public_rounded,
                  variant: AppButtonVariant.outline,
                  onPressed: () => context.push('/company/${company.id}/careers'),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
