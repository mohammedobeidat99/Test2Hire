import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/job_offer.dart';
import '../providers/company_offers_provider.dart';

class CompanyOffersScreen extends StatefulWidget {
  const CompanyOffersScreen({super.key});

  @override
  State<CompanyOffersScreen> createState() => _CompanyOffersScreenState();
}

class _CompanyOffersScreenState extends State<CompanyOffersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<CompanyOffersProvider>().listenCompanyOffers(user.uid);
      }
    });
  }

  void _showWithdrawDialog(BuildContext context, JobOffer offer) {
    final reasonController = TextEditingController();
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) => Consumer<CompanyOffersProvider>(
        builder: (ctx, provider, _) => StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text('Withdraw Job Offer'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Are you sure you want to withdraw the job offer to ${offer.candidateName}?'),
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
                      labelText: 'Reason for withdrawal',
                      hintText: 'e.g. Position filled, budget changes...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: provider.isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: provider.isSaving
                      ? null
                      : () async {
                          setDialogState(() => dialogError = null);
                          final nav = Navigator.of(ctx);
                          final messenger = ScaffoldMessenger.of(this.context);
                          final ok = await provider.withdrawOffer(
                            offer.id,
                            reason: reasonController.text.trim().isNotEmpty
                                ? reasonController.text.trim()
                                : null,
                          );
                          if (ok) {
                            if (nav.mounted) nav.pop();
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(provider.successMessage ?? 'Offer withdrawn successfully.'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } else if (dialogCtx.mounted) {
                            setDialogState(() {
                              dialogError = provider.errorMessage ?? 'Failed to withdraw offer.';
                            });
                          }
                        },
                  child: provider.isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Withdraw Offer'),
                ),
              ],
            );
          },
        ),
      ),
    ).whenComplete(reasonController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CompanyOffersProvider>();
    final dateFormat = DateFormat('MMM dd, yyyy', 'en_US');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Offers Extended'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Container(
            height: 46,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('All (${provider.totalCount})', null, provider),
                const SizedBox(width: 8),
                _buildFilterChip('Pending (${provider.pendingCount})', OfferStatus.pendingCandidate, provider),
                const SizedBox(width: 8),
                _buildFilterChip('Accepted (${provider.acceptedCount})', OfferStatus.accepted, provider),
                const SizedBox(width: 8),
                _buildFilterChip('Declined (${provider.declinedCount})', OfferStatus.declined, provider),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final user = context.read<AuthProvider>().user;
          if (user != null) await provider.loadCompanyOffers(user.uid);
        },
        child: provider.isLoading && provider.offers.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.offers.isEmpty
                ? LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: provider.errorMessage != null
                                ? Column(
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
                                          if (user != null) provider.loadCompanyOffers(user.uid);
                                        },
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Retry'),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.local_offer_outlined, size: 64, color: AppColors.textTertiary),
                                      const SizedBox(height: 16),
                                      Text('No Job Offers Found', style: AppTypography.headlineMedium),
                                      const SizedBox(height: 8),
                                      Text(
                                        provider.statusFilter == null
                                            ? 'You have not extended any offers yet. Review your shortlisted candidates to make an offer!'
                                            : 'No offers match the selected status filter.',
                                        textAlign: TextAlign.center,
                                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: provider.offers.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final offer = provider.offers[index];
                    final statusColor = _getStatusColor(offer.status);

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  child: Text(
                                    offer.candidateName.isNotEmpty
                                        ? offer.candidateName[0].toUpperCase()
                                        : 'C',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(offer.candidateName, style: AppTypography.titleLarge),
                                      Text(
                                        offer.jobTitle,
                                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
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

                            // Compensation & Start Date
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Offered Salary', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      const SizedBox(height: 2),
                                      Text(
                                        offer.formattedSalary,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFF047857),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (offer.startDate != null)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Target Start Date', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                        const SizedBox(height: 2),
                                        Text(
                                          offer.startDate!,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Expiry Date / Decline Reason
                            if (offer.isPending && offer.expiresAt != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.timer_outlined, size: 14, color: AppColors.warning),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Expires on: ${dateFormat.format(offer.expiresAt!)}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),

                            if (offer.isDeclined && offer.declineReason != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Decline Reason: "${offer.declineReason}"',
                                  style: const TextStyle(fontSize: 12, color: AppColors.error, fontStyle: FontStyle.italic),
                                ),
                              ),

                            // Actions
                            if (offer.isPending) ...[
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.cancel_outlined, size: 16, color: AppColors.error),
                                    label: const Text('Withdraw', style: TextStyle(color: AppColors.error)),
                                    onPressed: () => _showWithdrawDialog(context, offer),
                                  ),
                                ],
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

  Widget _buildFilterChip(String label, OfferStatus? status, CompanyOffersProvider provider) {
    final isSelected = provider.statusFilter == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => provider.setStatusFilter(status),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
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
