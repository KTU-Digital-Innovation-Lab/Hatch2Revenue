import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'app_colors.dart';

// ─── KPI CARD ────────────────────────────────────────────────────────────────
class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final String? icon;
  final Color accentColor;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.accentColor,
    this.sub,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border(
          top: BorderSide(color: accentColor, width: 3),
          left: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
          right: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.poppins(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              if (sub case final sub?) ...[
                const SizedBox(height: 4),
                Text(
                  sub,
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
          if (icon != null)
            Positioned(
              top: 0,
              right: 0,
              child: Opacity(
                opacity: 0.18,
                child: Text(icon!, style: const TextStyle(fontSize: 22)),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── SECTION HEADER ──────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                subtitle!,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
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

// ─── HTML CARD ────────────────────────────────────────────────────────────────
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
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
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

  const HtmlCardHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.08),
        border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

// ─── TAG CHIP ─────────────────────────────────────────────────────────────────
class TagChip extends StatelessWidget {
  final String label;
  final Color color;

  const TagChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─── CAUSE BAR ROW ───────────────────────────────────────────────────────────
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
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 7,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (percent / 100).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
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
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── EMPTY STATE ──────────────────────────────────────────────────────────────
class HtmlEmptyState extends StatelessWidget {
  final String icon;
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
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 34)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ─── PRIMARY BUTTON (green, rounded pill) ────────────────────────────────────
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
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        padding: small
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 7)
            : const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        textStyle: GoogleFonts.poppins(
          fontSize: small ? 12 : 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 1,
        shadowColor: AppColors.green.withValues(alpha: 0.3),
      ),
      child: Text(label),
    );
  }
}

// ─── GHOST BUTTON ─────────────────────────────────────────────────────────────
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
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.green, width: 1.5),
        padding: small
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
            : const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        textStyle: GoogleFonts.poppins(
          fontSize: small ? 12 : 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(label),
    );
  }
}

// ─── TABLE HELPERS ────────────────────────────────────────────────────────────
class HtmlTable extends StatelessWidget {
  final List<String> headers;
  final List<List<Widget>> rows;

  const HtmlTable({super.key, required this.headers, required this.rows});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 46,
        dataRowMaxHeight: 56,
        columnSpacing: 20,
        headingRowColor: const WidgetStatePropertyAll(AppColors.surfaceLight),
        dividerThickness: 0.5,
        border: TableBorder(
          horizontalInside: BorderSide(
            color: AppColors.border.withValues(alpha: 0.8),
            width: 0.5,
          ),
        ),
        columns: headers
            .map(
              (h) => DataColumn(
                label: Text(
                  h.toUpperCase(),
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
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

// ─── STAGE PILL ───────────────────────────────────────────────────────────────
class StagePill extends StatelessWidget {
  final String label;
  final Color color;

  const StagePill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── VACC STATUS BADGE ────────────────────────────────────────────────────────
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
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── DELETE / EDIT ICON BUTTONS ───────────────────────────────────────────────
class DelBtn extends StatelessWidget {
  final VoidCallback onTap;

  const DelBtn({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const Padding(
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
        child: Icon(Icons.edit_outlined, color: AppColors.green, size: 18),
      ),
    );
  }
}

// ─── SHARED DIALOG FORM HELPERS ───────────────────────────────────────────────

InputDecoration htmlInputDec([String hint = '']) => InputDecoration(
  hintText: hint.isEmpty ? null : hint,
  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
  filled: true,
  fillColor: AppColors.surfaceLight,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppColors.border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppColors.border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppColors.green, width: 2),
  ),
);

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
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

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
                ? AppColors.green.withValues(alpha: 0.5)
                : AppColors.border,
          ),
        ),
        child: Text(
          DateFormat('d MMM yyyy').format(date),
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─── CHECKLIST ITEM (checkmark bullet) ───────────────────────────────────────
class ChecklistItem extends StatelessWidget {
  final String text;
  final Color? checkColor;

  const ChecklistItem({super.key, required this.text, this.checkColor});

  @override
  Widget build(BuildContext context) {
    final color = checkColor ?? AppColors.green;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check, size: 12, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
