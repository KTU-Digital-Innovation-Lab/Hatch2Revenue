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
    // The card sizes to its CONTENT (label + value + sub) so it never
    // clips — it grows for long values and larger system font sizes. The
    // 2px accent line sits flush at the top, clipped to the rounded corners
    // by the container. Inside a KpiGrid row it also stretches to the
    // tallest card's height so the row stays visually even.
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 2, color: accentColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                // Long values (big money figures) shrink to fit the width.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
                if (sub case final sub?) ...[
                  const SizedBox(height: 4),
                  Text(
                    sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
        const spacing = 12.0;
        // Lay the cards out in rows that keep their NATURAL height, so a
        // card is never squeezed into a fixed cell and clipped — it grows
        // for long values or a larger system font size instead. Within a
        // row IntrinsicHeight + stretch keeps every card the same height as
        // its tallest neighbour, so the grid still reads as an even grid.
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += cols) {
          if (rows.isNotEmpty) rows.add(const SizedBox(height: spacing));
          final cells = <Widget>[];
          for (var j = 0; j < cols; j++) {
            if (j > 0) cells.add(const SizedBox(width: spacing));
            final idx = i + j;
            // Empty trailing cells keep the last row's card widths aligned
            // with the rows above instead of stretching to full width.
            cells.add(Expanded(
              child: idx < children.length
                  ? children[idx]
                  : const SizedBox.shrink(),
            ));
          }
          rows.add(IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: cells,
            ),
          ));
        }
        return Column(children: rows);
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
  final ImageProvider? iconImage;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.icon,
    this.iconImage,
  });

  @override
  Widget build(BuildContext context) {
    // See HtmlCardHeader: depend on brightness so const instances rebuild
    // on a light/dark switch and the title is never left black-on-black.
    final titleColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFF1F5F0)
        : const Color(0xFF1F2937);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (iconImage != null) ...[
                ImageIcon(iconImage, color: AppColors.amber, size: 22),
                const SizedBox(width: 8),
              ] else if (icon != null) ...[
                Icon(icon, color: AppColors.amber, size: 22),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: titleColor,
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
    // Depend on the theme's brightness so this rebuilds on a light/dark
    // switch even when used as `const` — const widgets are canonicalised
    // and otherwise keep their first-built colour, leaving the title black
    // on a dark background.
    final titleColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFF1F5F0)
        : const Color(0xFF1F2937);
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
                color: titleColor,
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
            width: 68,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                valueLabel,
                maxLines: 1,
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
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
  final IconData? icon;
  final String message;
  final Widget? action;
  final ImageProvider? iconImage;

  const HtmlEmptyState({
    super.key,
    this.icon,
    required this.message,
    this.action,
    this.iconImage,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconImage != null)
              ImageIcon(iconImage, size: 40, color: AppColors.textMuted)
            else if (icon != null)
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
class HtmlTable extends StatefulWidget {
  final List<String> headers;
  final List<List<Widget>> rows;

  /// Optional date for each row (parallel to [rows]). When supplied, the
  /// list is grouped by calendar day (newest first) and shows only the most
  /// recent [defaultDayGroups] days by default, with a "Show earlier"
  /// toggle for the rest — so a log that grows every day stays short
  /// without the farmer having to operate a filter. The per-card Date field
  /// is dropped because the day header already carries it. Omit [dates] for
  /// non-dated tables (stock, a schedule) to get a plain card list.
  final List<DateTime>? dates;
  final int defaultDayGroups;

  const HtmlTable({
    super.key,
    required this.headers,
    required this.rows,
    this.dates,
    this.defaultDayGroups = 7,
  });

  @override
  State<HtmlTable> createState() => _HtmlTableState();
}

class _HtmlTableState extends State<HtmlTable> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    // Rendered as a stacked LABEL : value card per row rather than a
    // horizontally-scrolling DataTable — on a phone a wide table pushes the
    // most important column (amount, crates) off the right edge where it
    // gets cut. Cards wrap every value so nothing is ever clipped. Cells
    // whose header is blank (action buttons) sit bottom-right of the card.
    if (widget.rows.isEmpty) return const SizedBox.shrink();

    // Callers place HtmlTable inside a zero-padding HtmlCard body (the old
    // DataTable scrolled edge to edge), so the card list adds its own inset.
    const pad = EdgeInsets.fromLTRB(12, 12, 12, 12);

    // Undated tables (stock, a schedule) keep the plain flat list.
    if (widget.dates == null) {
      return Padding(
        padding: pad,
        child: Column(
          children: [
            for (var r = 0; r < widget.rows.length; r++) ...[
              if (r > 0) const SizedBox(height: 8),
              _rowCard(widget.rows[r]),
            ],
          ],
        ),
      );
    }

    // Group rows by calendar day, newest first. The day header replaces the
    // per-card Date field, so drop that column from the cards below.
    final dates = widget.dates!;
    final dateCol = widget.headers
        .indexWhere((h) => h.trim().toLowerCase() == 'date');
    final order = List<int>.generate(widget.rows.length, (i) => i)
      ..sort((a, b) => dates[b].compareTo(dates[a]));
    final groups = <_DayGroup>[];
    for (final i in order) {
      final d = dates[i];
      final key = DateTime(d.year, d.month, d.day);
      if (groups.isEmpty || groups.last.day != key) groups.add(_DayGroup(key));
      groups.last.rowIndices.add(i);
    }

    final canCollapse = groups.length > widget.defaultDayGroups;
    final visible = (!_showAll && canCollapse)
        ? groups.take(widget.defaultDayGroups).toList()
        : groups;
    final hiddenDays = groups.length - visible.length;

    return Padding(
      padding: pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var g = 0; g < visible.length; g++) ...[
            if (g > 0) const SizedBox(height: 14),
            _dayHeader(visible[g]),
            const SizedBox(height: 8),
            for (var k = 0; k < visible[g].rowIndices.length; k++) ...[
              if (k > 0) const SizedBox(height: 8),
              _rowCard(widget.rows[visible[g].rowIndices[k]], skipCol: dateCol),
            ],
          ],
          if (canCollapse) ...[
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _showAll = !_showAll),
                child: Text(
                  _showAll
                      ? 'Show less'
                      : 'Show earlier ($hiddenDays more day${hiddenDays == 1 ? '' : 's'})',
                  style: GoogleFonts.inter(
                    color: AppColors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dayHeader(_DayGroup g) {
    final n = g.rowIndices.length;
    return Row(
      children: [
        Text(
          _dayLabel(g.day),
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: AppColors.border)),
        const SizedBox(width: 10),
        Text('$n',
            style:
                GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    final base = DateFormat('EEE d MMM').format(day);
    return day.year != now.year ? '$base ${day.year}' : base;
  }

  Widget _rowCard(List<Widget> cells, {int skipCol = -1}) {
    final headers = widget.headers;
    final fields = <Widget>[];
    final actions = <Widget>[];
    for (var i = 0; i < cells.length; i++) {
      if (i == skipCol) continue; // date shown in the day header instead
      final header = i < headers.length ? headers[i] : '';
      if (header.trim().isEmpty) {
        actions.add(cells[i]);
        continue;
      }
      if (fields.isNotEmpty) fields.add(const SizedBox(height: 8));
      fields.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 88,
              child: Text(
                header.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  letterSpacing: 0.5,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Align (not a bare Expanded) so pills/chips size to their
            // content while long text wraps to the available width.
            Expanded(
              child: Align(alignment: Alignment.centerLeft, child: cells[i]),
            ),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ...fields,
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Row(mainAxisSize: MainAxisSize.min, children: actions),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayGroup {
  _DayGroup(this.day);
  final DateTime day;
  final List<int> rowIndices = [];
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
    borderSide: BorderSide(color: AppColors.amber, width: 2),
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

/// The batch field shown when a form was opened FROM a batch, e.g. from
/// the batch hub. The flock is fixed and displayed as a locked row
/// rather than a dropdown, so the farmer can see which flock they are
/// recording against and cannot pick the wrong one by accident.
class LockedBatchField extends StatelessWidget {
  final String batchName;

  const LockedBatchField({super.key, required this.batchName});

  @override
  Widget build(BuildContext context) {
    return HtmlFormField(
      label: 'Batch / Flock',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.green.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 15, color: AppColors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                batchName,
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
