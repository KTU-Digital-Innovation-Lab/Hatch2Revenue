import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'app_colors.dart';

// ─── KPI CARD (with colored 2px top border like HTML .kpi) ──────────────────
class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color accentColor;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.accentColor,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    // A single Border can't mix borderRadius with non-uniform side colors
    // (Flutter throws "A borderRadius can only be given on borders with
    // uniform colors" at paint time), so the colored top accent is layered
    // on top of a plain rounded/uniform-border container instead. Both
    // layers are Positioned.fill/Positioned so they share the same bounds —
    // KpiCard is only ever used inside KpiGrid's tight GridView cells, so a
    // non-positioned child here would shrink to its content instead of
    // filling the cell, leaving the accent bar wider than the box below it.
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                if (sub case final sub?) ...[
                  const SizedBox(height: 4),
                  Text(
                    sub,
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── KPI GRID (responsive grid layout for a row of KpiCards) ────────────────
class KpiGrid extends StatelessWidget {
  final List<Widget> children;

  const KpiGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final cols = c.maxWidth < 400 ? 2 : 4;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: children,
        );
      },
    );
  }
}

// ─── SECTION HEADER (like HTML .section-header) ─────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final IconData? icon;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.amber, size: 22),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle!,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
          if (action != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: action!,
            ),
        ],
      ),
    );
  }
}

// ─── CARD (like HTML .card with card-head / card-body) ───────────────────────
class HtmlCard extends StatelessWidget {
  final Widget? header;
  final Widget body;
  final EdgeInsetsGeometry? bodyPadding;

  const HtmlCard({
    super.key,
    this.header,
    required this.body,
    this.bodyPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ?header,
          Padding(
            padding: bodyPadding ?? const EdgeInsets.all(16),
            child: body,
          ),
        ],
      ),
    );
  }
}

class HtmlCardHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final IconData? icon;

  const HtmlCardHeader({super.key, required this.title, this.trailing, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.textSecondary, size: 16),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

// ─── TAG CHIP (like HTML .tag) ───────────────────────────────────────────────
class TagChip extends StatelessWidget {
  final String label;
  final Color color;

  const TagChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

// ─── CAUSE BAR ROW (like HTML .cause-row) ────────────────────────────────────
class CauseBarRow extends StatelessWidget {
  final String label;
  final int percent;
  final Color color;
  final String valueLabel;

  const CauseBarRow({
    super.key,
    required this.label,
    required this.percent,
    required this.color,
    required this.valueLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (percent / 100).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 42,
            child: Text(
              valueLabel,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── EMPTY STATE (like HTML .empty-state) ────────────────────────────────────
class HtmlEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const HtmlEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 14),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ─── PRIMARY BUTTON (like HTML .btn.btn-primary) ─────────────────────────────
class PrimaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool small;

  const PrimaryBtn({
    super.key,
    required this.label,
    required this.onPressed,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.amber,
        foregroundColor: Colors.black,
        padding: small
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        textStyle: GoogleFonts.inter(
          fontSize: small ? 12 : 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      child: Text(label),
    );
  }
}

// ─── GHOST BUTTON (like HTML .btn.btn-ghost) ─────────────────────────────────
class GhostBtn extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool small;

  const GhostBtn({
    super.key,
    required this.label,
    required this.onPressed,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: BorderSide(color: AppColors.border),
        padding: small
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        textStyle: GoogleFonts.inter(
          fontSize: small ? 12 : 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label),
    );
  }
}

// ─── TABLE HELPERS ───────────────────────────────────────────────────────────
class HtmlTable extends StatelessWidget {
  final List<String> headers;
  final List<List<Widget>> rows;

  const HtmlTable({super.key, required this.headers, required this.rows});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 52,
        columnSpacing: 16,
        headingRowColor: const WidgetStatePropertyAll(Colors.transparent),
        dividerThickness: 0.5,
        border: TableBorder(
          horizontalInside: BorderSide(
            color: AppColors.border.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
        columns: headers
            .map(
              (h) => DataColumn(
                label: Text(
                  h.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            )
            .toList(),
        rows: rows
            .map(
              (cells) => DataRow(
                cells: cells.map((w) => DataCell(w)).toList(),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ─── STAGE PILL (like HTML .pill) ────────────────────────────────────────────
class StagePill extends StatelessWidget {
  final String label;
  final Color color;

  const StagePill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─── VACC STATUS BADGE ───────────────────────────────────────────────────────
class VaccStatusBadge extends StatelessWidget {
  final String status; // 'done', 'pending', 'overdue'

  const VaccStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'done':
        color = AppColors.green;
        break;
      case 'overdue':
        color = AppColors.red;
        break;
      default:
        color = AppColors.amber;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: GoogleFonts.inter(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─── DELETE ICON BUTTON ───────────────────────────────────────────────────────
class DelBtn extends StatelessWidget {
  final VoidCallback onTap;

  const DelBtn({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Icon(Icons.delete_outline, color: AppColors.textMuted, size: 18),
      ),
    );
  }
}

class EditBtn extends StatelessWidget {
  final VoidCallback onTap;

  const EditBtn({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Icon(Icons.edit_outlined, color: AppColors.cyan, size: 18),
      ),
    );
  }
}

// ─── SHARED DIALOG FORM HELPERS ──────────────────────────────────────────────

/// Decoration for dialog text inputs — hint text, no floating label
InputDecoration htmlInputDec([String hint = '']) => InputDecoration(
  hintText: hint.isEmpty ? null : hint,
  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
  filled: true,
  fillColor: AppColors.surfaceLight,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: AppColors.border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: AppColors.border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppColors.amber, width: 2),
  ),
);

/// Wraps a form field with an uppercase label above it (matches HTML <label> style)
class HtmlFormField extends StatelessWidget {
  final String label;
  final Widget child;

  const HtmlFormField({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 10,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// Displays a formatted date in a styled box — tappable if onTap is provided
class HtmlDateTile extends StatelessWidget {
  final DateTime date;
  final VoidCallback? onTap;

  const HtmlDateTile({super.key, required this.date, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: onTap != null
                ? AppColors.amber.withValues(alpha: 0.5)
                : AppColors.border,
          ),
        ),
        child: Text(
          DateFormat('d MMM yyyy').format(date),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
