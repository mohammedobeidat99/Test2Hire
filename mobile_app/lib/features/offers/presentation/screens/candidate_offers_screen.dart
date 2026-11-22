import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/job_offer.dart';
import '../providers/candidate_offers_provider.dart';

class CandidateOffersScreen extends StatefulWidget {
  const CandidateOffersScreen({super.key});

  @override
  State<CandidateOffersScreen> createState() => _CandidateOffersScreenState();
}

class _CandidateOffersScreenState extends State<CandidateOffersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<CandidateOffersProvider>().listenCandidateOffers(user.uid);
      }
    });
  }

  void _showOfferDetailsModal(BuildContext context, JobOffer offer) {
    final dateFormat = DateFormat('MMMM dd, yyyy', 'en_US');
    String? modalError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (mCtx) => Consumer<CandidateOffersProvider>(
        builder: (mCtx, provider, _) => StatefulBuilder(
          builder: (sheetCtx, setModalState) {
            final isResponding = provider.isResponding;
            final isArabic = Localizations.localeOf(sheetCtx).languageCode == 'ar';

            return Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetCtx).size.height * 0.85,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (modalError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          modalError!,
                          style: const TextStyle(color: AppColors.error, fontSize: 12),
                        ),
                      ),
                    ],
                  // Handle bar
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header Badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF047857).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.verified_rounded, color: Color(0xFF047857), size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(Localizations.localeOf(context).languageCode == 'ar' ? 'عرض عمل رسمي' : 'Formal Job Offer', style: AppTypography.headlineSmall),
                            Text(
                              offer.companyName,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Position and Compensation Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF047857).withValues(alpha: 0.08),
                          AppColors.primary.withValues(alpha: 0.04),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF047857).withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(Localizations.localeOf(context).languageCode == 'ar' ? 'المسمى الوظيفي' : 'POSITION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(offer.jobTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Text(Localizations.localeOf(context).languageCode == 'ar' ? 'المزايا المالية والراتب' : 'COMPENSATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(
                          offer.formattedSalary,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Key Details Table
                  if (offer.startDate != null) ...[
                    _buildDetailRow(
                      Icons.calendar_today_rounded,
                      Localizations.localeOf(context).languageCode == 'ar' ? 'تاريخ بدء العمل المتوقع' : 'Target Start Date',
                      offer.startDate!,
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (offer.expiresAt != null) ...[
                    _buildDetailRow(
                      Icons.timer_outlined,
                      Localizations.localeOf(context).languageCode == 'ar' ? 'تاريخ انتهاء صلاحية العرض' : 'Offer Expiration',
                      dateFormat.format(offer.expiresAt!),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Benefits list
                  if (offer.benefits.isNotEmpty) ...[
                    Text(Localizations.localeOf(context).languageCode == 'ar' ? 'المزايا والبدلات المضمنة' : 'Benefits & Perks Included', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: offer.benefits.map((b) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_outline, size: 14, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(b, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Notes & Letter Content
                  if (offer.termsAndNotes.isNotEmpty) ...[
                    Text(Localizations.localeOf(context).languageCode == 'ar' ? 'رسالة صاحب العمل' : 'Offer Message from Employer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.divider.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        offer.termsAndNotes,
                        style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Action Buttons (Accept / Decline)
                  if (offer.isPending && !offer.isExpired) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: isResponding
                                ? null
                                : () => _showDeclineDialog(context, offer, mCtx),
                            child: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'رفض العرض' : 'Decline'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF047857),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: isResponding
                                ? null
                                : () async {
                                    setModalState(() => modalError = null);
                                    final nav = Navigator.of(mCtx);
                                    final messenger = ScaffoldMessenger.of(this.context);

                                    final ok = await provider.respondToOffer(
                                      offerId: offer.id,
                                      response: 'ACCEPT',
                                    );

                                    if (ok) {
                                      if (nav.mounted) nav.pop();
                                      if (mounted) {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              isArabic
                                                  ? '🎉 مبارك! لقد تم قبول عرض العمل بنجاح!'
                                                  : '🎉 Congratulations! You have accepted the job offer!',
                                            ),
                                            backgroundColor: const Color(0xFF047857),
                                            duration: const Duration(seconds: 3),
                                          ),
                                        );
                                      }
                                    } else if (sheetCtx.mounted) {
                                      setModalState(() {
                                        modalError = provider.errorMessage ?? 'Failed to accept job offer.';
                                      });
                                    }
                                  },
                            child: isResponding
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Accept Job Offer', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _getStatusColor(offer.status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Status: ${offer.status.displayName}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(offer.status),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
          },
        ),
      ),
    );
  }

  void _showDeclineDialog(BuildContext context, JobOffer offer, BuildContext mCtx) {
    final reasonController = TextEditingController();
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) => Consumer<CandidateOffersProvider>(
        builder: (ctx, provider, _) => StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isArabic = Localizations.localeOf(dialogCtx).languageCode == 'ar';
            return AlertDialog(
              title: Text(isArabic ? 'رفض عرض العمل' : 'Decline Job Offer'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isArabic ? 'هل أنت متأكد من رغبتك في رفض هذا العرض؟' : 'Are you sure you want to decline this job offer?'),
                  if (dialogError != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        dialogError!,
                        style: const TextStyle(color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason for declining (Optional)',
                      hintText: 'e.g. Accepted another role, compensation...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: provider.isResponding ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: provider.isResponding
                      ? null
                      : () async {
                          setDialogState(() => dialogError = null);
                          final dialogNav = Navigator.of(ctx);
                          final sheetNav = Navigator.of(mCtx);
                          final messenger = ScaffoldMessenger.of(this.context);

                          final ok = await provider.respondToOffer(
                            offerId: offer.id,
                            response: 'DECLINE',
                            declineReason: reasonController.text.trim().isNotEmpty
                                ? reasonController.text.trim()
                                : null,
                          );

                          if (ok) {
                            if (dialogNav.mounted) dialogNav.pop();
                            if (sheetNav.mounted) sheetNav.pop();
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(isArabic ? 'تم رفض عرض العمل.' : 'Job offer declined.'),
                                  backgroundColor: AppColors.error,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          } else if (dialogCtx.mounted) {
                            setDialogState(() {
                              dialogError = provider.errorMessage ?? 'Failed to decline job offer.';
                            });
                          }
                        },
                  child: provider.isResponding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Decline Offer'),
                ),
              ],
            );
          },
        ),
      ),
    ).whenComplete(reasonController.dispose);
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<CandidateOffersProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.myOffersTitle ?? 'My Job Offers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final user = context.read<AuthProvider>().user;
              if (user != null) {
                provider.loadCandidateOffers(user.uid);
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final user = context.read<AuthProvider>().user;
          if (user != null) {
            await provider.loadCandidateOffers(user.uid);
          }
        },
        child: provider.isLoading && provider.offers.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.offers.isEmpty
                ? LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: provider.errorMessage != null
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                                      const SizedBox(height: 12),
                                      Text(
                                        provider.errorMessage!,
                                        textAlign: TextAlign.center,
                                        style: AppTypography.bodyMedium,
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          final user = context.read<AuthProvider>().user;
                                          if (user != null) provider.loadCandidateOffers(user.uid);
                                        },
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : EmptyStateWidget(
                                icon: Icons.workspace_premium_rounded,
                                title: l10n?.noOffersTitle ?? 'No Job Offers Yet',
                                description: l10n?.noOffersSubtitle ?? 'When a hiring company selects you after completing evaluations and interviews, your formal offer letters will appear here.',
                              ),
                      ),
                    ),
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.offers.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                    final offer = provider.offers[index];
                    final statusColor = _getStatusColor(offer.status);

                    return InkWell(
                      onTap: () => _showOfferDetailsModal(context, offer),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: offer.isPending
                                ? const Color(0xFF047857).withValues(alpha: 0.3)
                                : AppColors.border,
                            width: offer.isPending ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: const Color(0xFF047857).withValues(alpha: 0.1),
                                  child: const Icon(Icons.business_center_rounded, color: Color(0xFF047857)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(offer.jobTitle, style: AppTypography.titleLarge),
                                      Text(
                                        offer.companyName,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    offer.status.displayName,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Offered Compensation', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    const SizedBox(height: 2),
                                    Text(
                                      offer.formattedSalary,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF047857),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          offer.isPending ? 'Review & Sign' : 'View Details',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: offer.isPending ? const Color(0xFF047857) : AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 12,
                                        color: offer.isPending ? const Color(0xFF047857) : AppColors.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  ),
      ),
    );
  }

  Color _getStatusColor(OfferStatus status) {
    switch (status) {
      case OfferStatus.accepted:
        return const Color(0xFF047857);
      case OfferStatus.pendingCandidate:
        return AppColors.warning;
      case OfferStatus.declined:
      case OfferStatus.expired:
      case OfferStatus.withdrawn:
        return AppColors.error;
    }
  }
}
