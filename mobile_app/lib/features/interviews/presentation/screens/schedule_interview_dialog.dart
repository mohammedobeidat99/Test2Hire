import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../applications/domain/entities/job_application.dart';
import '../../domain/entities/interview.dart';
import '../providers/company_interviews_provider.dart';

class ScheduleInterviewDialog extends StatefulWidget {
  final JobApplication application;

  const ScheduleInterviewDialog({super.key, required this.application});

  @override
  State<ScheduleInterviewDialog> createState() => _ScheduleInterviewDialogState();
}

class _ScheduleInterviewDialogState extends State<ScheduleInterviewDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _meetingUrlController;
  late final TextEditingController _locationController;
  late final TextEditingController _interviewersController;

  InterviewType _selectedType = InterviewType.videoCall;
  final List<DateTime> _proposedSlots = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: 'Technical Interview: ${widget.application.jobTitle}',
    );
    _descriptionController = TextEditingController(
      text: 'Live interview evaluation and technical discussion.',
    );
    _meetingUrlController = TextEditingController();
    _locationController = TextEditingController();
    _interviewersController = TextEditingController();

    // Default slot tomorrow at 10:00 AM
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _proposedSlots.add(DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10, 0));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _meetingUrlController.dispose();
    _locationController.dispose();
    _interviewersController.dispose();
    super.dispose();
  }

  Future<void> _pickSlotDateTime(int? index) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: index != null ? _proposedSlots[index] : now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: index != null
          ? TimeOfDay.fromDateTime(_proposedSlots[index])
          : const TimeOfDay(hour: 10, minute: 0),
    );

    if (pickedTime == null || !mounted) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      if (index != null) {
        _proposedSlots[index] = combined;
      } else {
        _proposedSlots.add(combined);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CompanyInterviewsProvider>();
    final dateFormat = DateFormat('EEE, MMM d, yyyy - h:mm a');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.video_call_outlined, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Schedule Interview: ${widget.application.candidateName}',
              style: AppTypography.titleLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Interview Title *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 12),

              // Interview Type Selector
              DropdownButtonFormField<InterviewType>(
                isExpanded: true,
                initialValue: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Interview Format',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.meeting_room_outlined),
                ),
                items: InterviewType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.displayName),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedType = val);
                },
              ),
              const SizedBox(height: 12),

              // Conditional URL or Location
              if (_selectedType == InterviewType.videoCall) ...[
                TextFormField(
                  controller: _meetingUrlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Meeting Link (Optional)',
                    hintText: 'https://meet.google.com/xxx-yyyy-zzz',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                  validator: (val) {
                    final trimmed = val?.trim() ?? '';
                    if (trimmed.isEmpty) return null;
                    final uri = Uri.tryParse(trimmed);
                    if (uri == null ||
                        !(uri.scheme == 'http' || uri.scheme == 'https') ||
                        uri.host.isEmpty) {
                      return 'Please enter a valid http(s) meeting link';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 4),
                const Text(
                  'Paste your Google Meet, Zoom, Teams, or company meeting link (optional).',
                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                ),
                const SizedBox(height: 12),
              ] else if (_selectedType == InterviewType.inPerson) ...[
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Office Location / Address *',
                    hintText: 'e.g. Building 4, Floor 2, Meeting Room A',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Location is required for in-person interviews'
                      : null,
                ),
                const SizedBox(height: 12),
              ],

              // Proposed Time Slots
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Proposed Time Slot(s)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  if (_proposedSlots.length < 3)
                    TextButton.icon(
                      onPressed: () => _pickSlotDateTime(null),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Slot', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 4),

              ..._proposedSlots.asMap().entries.map((entry) {
                final idx = entry.key;
                final slot = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dateFormat.format(slot),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                        icon: const Icon(Icons.edit, size: 16, color: AppColors.textSecondary),
                        onPressed: () => _pickSlotDateTime(idx),
                      ),
                      if (_proposedSlots.length > 1) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(6),
                          icon: const Icon(Icons.close, size: 16, color: AppColors.error),
                          onPressed: () => setState(() => _proposedSlots.removeAt(idx)),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),

              TextFormField(
                controller: _interviewersController,
                decoration: const InputDecoration(
                  labelText: 'Interviewers (Comma-separated)',
                  hintText: 'e.g. Sarah Connor (Lead Dev), John Doe (HR)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people_outline),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Instructions / Agenda',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 2,
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: provider.isSaving
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  if (_proposedSlots.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please add at least one proposed time slot.')),
                    );
                    return;
                  }

                  final slots = _proposedSlots.asMap().entries.map((e) {
                    return InterviewSlot(
                      slotIndex: e.key,
                      startTime: e.value,
                      endTime: e.value.add(const Duration(minutes: 45)),
                      isSelected: _proposedSlots.length == 1,
                    );
                  }).toList();

                  final interviewers = _interviewersController.text
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toList();

                  final nav = Navigator.of(context);
                  final scaffoldMessenger = ScaffoldMessenger.of(context);

                  final id = await provider.scheduleInterview(
                    applicationId: widget.application.id,
                    title: _titleController.text.trim(),
                    description: _descriptionController.text.trim(),
                    interviewType: _selectedType,
                    meetingUrl: _meetingUrlController.text.trim().isNotEmpty
                        ? _meetingUrlController.text.trim()
                        : null,
                    location: _locationController.text.trim().isNotEmpty
                        ? _locationController.text.trim()
                        : null,
                    slots: slots,
                    interviewerNames: interviewers,
                  );

                  if (!mounted) return;
                  if (id != null) {
                    nav.pop();
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Interview scheduled and invitation dispatched!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
          child: provider.isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Dispatch Invitation'),
        ),
      ],
    );
  }
}
