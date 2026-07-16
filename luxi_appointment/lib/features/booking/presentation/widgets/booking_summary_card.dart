import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../models/branch_model.dart';
import '../../models/client_info.dart';
import '../../models/service_model.dart';
import 'upload_profile_widget.dart';

/// Read-only summary of every booking selection, shown on the review step.
class BookingSummaryCard extends StatelessWidget {
  const BookingSummaryCard({
    super.key,
    required this.service,
    required this.branch,
    required this.date,
    required this.time,
    required this.client,
  });

  final ServiceModel? service;
  final BranchModel? branch;
  final DateTime? date;
  final TimeOfDay? time;
  final ClientInfo client;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Appointment section
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _SectionLabel(label: 'Appointment', icon: Icons.event_rounded),
                const SizedBox(height: 12),
                _SummaryRow(
                  label: 'Service',
                  value: service?.name ?? '—',
                  trailing:
                      service != null ? Formatters.peso(service!.price) : null,
                ),
                _SummaryRow(label: 'Branch', value: branch?.name ?? '—'),
                _SummaryRow(
                  label: 'Date',
                  value: date != null ? Formatters.date(date!) : '—',
                ),
                _SummaryRow(
                  label: 'Time',
                  value: time != null ? Formatters.time(time!) : '—',
                ),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          // Client section
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    _SectionLabel(
                        label: 'Your details', icon: Icons.person_rounded),
                    const Spacer(),
                    ProfilePhotoPreview(photoPath: client.photoPath, size: 44),
                  ],
                ),
                const SizedBox(height: 12),
                _SummaryRow(label: 'Full name', value: _dash(client.fullName)),
                _SummaryRow(label: 'Email', value: _dash(client.email)),
                _SummaryRow(label: 'Phone', value: _dash(client.phone)),
                _SummaryRow(label: 'Facebook', value: _dash(client.facebook)),
                _SummaryRow(
                  label: 'Profile photo',
                  value: client.hasPhoto ? 'Attached' : 'Not added',
                ),
              ],
            ),
          ),
        ],
      ),
    ).withDefaultTextStyle(text.bodyMedium);
  }

  static String _dash(String v) => v.trim().isEmpty ? '—' : v;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}

extension _DefaultTextStyle on Widget {
  Widget withDefaultTextStyle(TextStyle? style) {
    if (style == null) return this;
    return DefaultTextStyle.merge(style: style, child: this);
  }
}
