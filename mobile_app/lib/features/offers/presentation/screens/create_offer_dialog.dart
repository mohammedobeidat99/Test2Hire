import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../applications/domain/entities/job_application.dart';
import '../../domain/entities/job_offer.dart';
import '../providers/company_offers_provider.dart';

class CreateOfferDialog extends StatefulWidget {
  final JobApplication application;

  const CreateOfferDialog({super.key, required this.application});

  @override
  State<CreateOfferDialog> createState() => _CreateOfferDialogState();
}

class _CreateOfferDialogState extends State<CreateOfferDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _salaryController;
  late final TextEditingController _benefitsController;
  late final TextEditingController _notesController;

  String _currency = 'USD';
  SalaryPeriod _salaryPeriod = SalaryPeriod.annual;
  DateTime _startDate = DateTime.now().add(const Duration(days: 14));
  int _expiresInDays = 7;

  final List<String> _currencies = [
    'USD',
    'EUR',
    'GBP',
    'SAR',
    'AED',
    'EGP',
    'JOD',
    'KWD',
    'QAR',
    'BHD',
    'OMR',
    'CAD',
  ];

  @override
  void initState() {
    super.initState();
    _salaryController = TextEditingController(text: '75000');
    _benefitsController = TextEditingController(
      text: 'Comprehensive Health Insurance, 401(k) Matching, Flexible Remote Work, Annual Learning Stipend',
    );
    _notesController = TextEditingController(
      text: 'We were thoroughly impressed by your performance in the technical assessment and interview! We are thrilled to welcome you to the team.',
    );
  }

  @override
  void dispose() {
    _salaryController.dispose();
    _benefitsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CompanyOffersProvider>();
    final dateFormat = DateFormat('MMM dd, yyyy', 'en_US');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF047857).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.verified_rounded, color: Color(0xFF047857), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Extend Job Offer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  'Candidate: ${widget.application.candidateName}',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Position Header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.work_outline_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.application.jobTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Offered Salary & Currency
                const Text('Compensation & Currency *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Currency Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _currency,
                          items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _currency = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Salary Input
                    Expanded(
                      child: TextFormField(
                        controller: _salaryController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'e.g. 85000',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Invalid salary';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Salary Period (Annual vs Monthly)
                const Text('Payment Frequency', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _salaryPeriod = SalaryPeriod.annual),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _salaryPeriod == SalaryPeriod.annual
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : AppColors.divider.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _salaryPeriod == SalaryPeriod.annual ? AppColors.primary : AppColors.border,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Annual Salary',
                              style: TextStyle(
                                fontWeight: _salaryPeriod == SalaryPeriod.annual ? FontWeight.bold : FontWeight.normal,
                                color: _salaryPeriod == SalaryPeriod.annual ? AppColors.primary : AppColors.textPrimary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _salaryPeriod = SalaryPeriod.monthly),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _salaryPeriod == SalaryPeriod.monthly
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : AppColors.divider.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _salaryPeriod == SalaryPeriod.monthly ? AppColors.primary : AppColors.border,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Monthly Salary',
                              style: TextStyle(
                                fontWeight: _salaryPeriod == SalaryPeriod.monthly ? FontWeight.bold : FontWeight.normal,
                                color: _salaryPeriod == SalaryPeriod.monthly ? AppColors.primary : AppColors.textPrimary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Start Date & Expiry
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Proposed Start Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _startDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) setState(() => _startDate = picked);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Text(dateFormat.format(_startDate), style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Offer Validity (Days)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            initialValue: _expiresInDays,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 3, child: Text('3 Days')),
                              DropdownMenuItem(value: 7, child: Text('7 Days (Standard)')),
                              DropdownMenuItem(value: 14, child: Text('14 Days')),
                              DropdownMenuItem(value: 30, child: Text('30 Days')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _expiresInDays = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Benefits & Perks
                const Text('Benefits & Perks (Comma-separated)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _benefitsController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Health Insurance, Remote Allowance, Gym, Stock Options',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(10),
                  ),
                ),
                const SizedBox(height: 16),

                // Terms & Welcome Notes
                const Text('Offer Letter & Welcome Note', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Add a personal note, reporting structure, or onboarding instructions...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(10),
                  ),
                ),
                if (provider.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      provider.errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF047857),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: provider.isSaving
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;

                  final salary = double.parse(_salaryController.text.trim());
                  final benefitsList = _benefitsController.text
                      .split(',')
                      .map((b) => b.trim())
                      .where((b) => b.isNotEmpty)
                      .toList();

                  final nav = Navigator.of(context);
                  final scaffoldMessenger = ScaffoldMessenger.of(context);

                  final offerId = await provider.extendJobOffer(
                    applicationId: widget.application.id,
                    offeredSalary: salary,
                    salaryCurrency: _currency,
                    salaryPeriod: _salaryPeriod,
                    startDate: DateFormat('yyyy-MM-dd').format(_startDate),
                    expiresInDays: _expiresInDays,
                    benefits: benefitsList,
                    termsAndNotes: _notesController.text.trim(),
                  );

                  if (!mounted) return;
                  if (offerId != null) {
                    nav.pop();
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Formal job offer extended to candidate!'),
                        backgroundColor: Color(0xFF047857),
                      ),
                    );
                  }
                },
          child: provider.isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Extend Job Offer'),
        ),
      ],
    );
  }
}
