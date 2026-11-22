import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/company_profile.dart';
import '../providers/company_provider.dart';

class EditCompanyProfileScreen extends StatefulWidget {
  const EditCompanyProfileScreen({super.key});

  @override
  State<EditCompanyProfileScreen> createState() => _EditCompanyProfileScreenState();
}

class _EditCompanyProfileScreenState extends State<EditCompanyProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _legalNameController;
  late final TextEditingController _industryController;
  late final TextEditingController _websiteController;
  late final TextEditingController _phoneController;
  late final TextEditingController _descController;
  late final TextEditingController _cityController;
  late final TextEditingController _countryController;
  late final TextEditingController _addressController;
  String _teamSize = '11-50 employees';

  final List<String> _teamSizes = [
    '1-10 employees',
    '11-50 employees',
    '51-200 employees',
    '201-500 employees',
    '500+ employees',
  ];

  @override
  void initState() {
    super.initState();
    final company = context.read<CompanyProvider>().company;
    _nameController = TextEditingController(text: company?.name ?? '');
    _legalNameController = TextEditingController(text: company?.legalName ?? '');
    _industryController = TextEditingController(text: company?.industry ?? 'Technology');
    _websiteController = TextEditingController(text: company?.website ?? '');
    _phoneController = TextEditingController(text: company?.contactPhone ?? '');
    _descController = TextEditingController(text: company?.description ?? '');
    _cityController = TextEditingController(text: company?.location?.city ?? '');
    _countryController = TextEditingController(text: company?.location?.country ?? '');
    _addressController = TextEditingController(text: company?.location?.address ?? '');
    if (company?.teamSize != null && _teamSizes.contains(company!.teamSize)) {
      _teamSize = company.teamSize!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _legalNameController.dispose();
    _industryController.dispose();
    _websiteController.dispose();
    _phoneController.dispose();
    _descController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<CompanyProvider>();
    final success = await provider.updateCompanyDetails(
      name: _nameController.text,
      legalName: _legalNameController.text,
      industry: _industryController.text,
      website: _websiteController.text,
      description: _descController.text,
      contactPhone: _phoneController.text,
      teamSize: _teamSize,
      location: _cityController.text.isNotEmpty || _countryController.text.isNotEmpty
          ? CompanyLocation(
              city: _cityController.text.trim(),
              country: _countryController.text.trim(),
              address: _addressController.text.trim(),
            )
          : null,
    );

    if (!mounted) return;
    if (success) {
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to update company profile.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CompanyProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Edit Company Profile'),
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
                  label: 'Brand / Trade Name',
                  controller: _nameController,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Company name required.' : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Registered Legal Name (Optional)',
                  hint: 'e.g. Acme Innovations LLC',
                  controller: _legalNameController,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Industry',
                  controller: _industryController,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Industry is required.' : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Official Website',
                  hint: 'https://company.com',
                  controller: _websiteController,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Organization Size', style: AppTypography.labelLarge),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _teamSize,
                      items: _teamSizes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _teamSize = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Contact Phone Number',
                  hint: '+1 234 567 8900',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'City',
                        hint: 'Amman',
                        controller: _cityController,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        label: 'Country',
                        hint: 'Jordan',
                        controller: _countryController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Headquarters Address',
                  hint: 'King Hussein Business Park, Bldg 4',
                  controller: _addressController,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Company Overview & Mission',
                  hint: 'Describe what your organization does, culture, and technologies used...',
                  controller: _descController,
                  maxLines: 4,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Description required.' : null,
                ),
                const SizedBox(height: 32),
                AppButton(
                  text: 'Save Company Profile',
                  isLoading: provider.isSaving,
                  onPressed: _handleSave,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
