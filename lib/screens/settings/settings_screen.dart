import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/html_widgets.dart';
import '../../utils/units.dart';

/// Personalisation — appearance, readability, farm units, and start-up.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const tabNames = [
    'Dashboard', 'Batch Lifecycle', 'Vaccination', 'Feed Monitor',
    'Egg Production', 'Mortality Log', 'Financials', 'Farm Profile', 'Analytics',
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Appearance ────────────────────────────────────────────
          HtmlCard(
            header: const HtmlCardHeader(
                icon: Icons.palette_outlined, title: 'Appearance'),
            body: Column(children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: theme.isDark,
                onChanged: (_) => theme.toggle(),
                activeThumbColor: AppColors.amber,
                title: Text('Night mode',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                subtitle: Text('Dark screen for early mornings and evenings',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                secondary: Icon(
                    theme.isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                    color: AppColors.amber),
              ),
              const Divider(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: s.highContrast,
                onChanged: s.setHighContrast,
                activeThumbColor: AppColors.amber,
                title: Text('High contrast',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                subtitle: Text('Stronger borders and darker text — easier in bright sun',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                secondary: Icon(Icons.contrast, color: AppColors.amber),
              ),
            ]),
          ),

          // ── Colour vision ─────────────────────────────────────────
          HtmlCard(
            header: const HtmlCardHeader(
                icon: Icons.visibility_outlined, title: 'Colour vision'),
            body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'The app uses green for good and red for danger. If those '
                'colours are hard to tell apart, pick the mode that suits '
                'your sight — the app switches to blue and orange instead.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.35),
              ),
              const SizedBox(height: 12),
              ...ColorVisionMode.values.map((m) => RadioListTile<ColorVisionMode>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: m,
                    // ignore: deprecated_member_use
                    groupValue: s.vision,
                    // ignore: deprecated_member_use
                    onChanged: (v) => v == null ? null : s.setVision(v),
                    activeColor: AppColors.amber,
                    title: Text(m.label,
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 13.5)),
                    subtitle: Text(m.hint,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                  )),
              const SizedBox(height: 8),
              // Live swatches so the effect is visible immediately.
              Row(children: [
                _swatch('Good', AppColors.green),
                _swatch('Warning', AppColors.amber),
                _swatch('Danger', AppColors.red),
                _swatch('Info', AppColors.cyan),
              ]),
            ]),
          ),

          // ── Readability ───────────────────────────────────────────
          HtmlCard(
            header: const HtmlCardHeader(
                icon: Icons.format_size, title: 'Text size'),
            body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('A', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                Expanded(
                  child: Slider(
                    value: s.textScale,
                    min: 0.9,
                    max: 1.4,
                    divisions: 5,
                    activeColor: AppColors.amber,
                    label: s.textScaleLabel,
                    onChanged: s.setTextScale,
                  ),
                ),
                Text('A', style: TextStyle(color: AppColors.textSecondary, fontSize: 22)),
              ]),
              Center(
                child: Text(s.textScaleLabel,
                    style: TextStyle(
                        color: AppColors.amber, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text('Preview: 12 crates collected today',
                    style: GoogleFonts.inter(
                        color: AppColors.textPrimary, fontSize: 14 * s.textScale)),
              ),
            ]),
          ),

          // ── Farm units ────────────────────────────────────────────
          HtmlCard(
            header: const HtmlCardHeader(
                icon: Icons.straighten, title: 'Farm units'),
            body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Set the crate and bag sizes your farm actually uses. '
                'Existing records are never altered — they are stored in '
                'eggs and kilograms and simply shown in your units.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.35),
              ),
              const SizedBox(height: 14),
              _stepper(
                context,
                label: 'Eggs per crate',
                value: '${s.eggsPerCrate}',
                onMinus: () => s.setEggsPerCrate(s.eggsPerCrate - 1),
                onPlus: () => s.setEggsPerCrate(s.eggsPerCrate + 1),
                hint: s.eggsPerCrate == Units.defaultEggsPerCrate ? 'Standard' : 'Custom',
              ),
              const SizedBox(height: 10),
              _stepper(
                context,
                label: 'Kilograms per bag',
                value: s.kgPerBag.toStringAsFixed(0),
                onMinus: () => s.setKgPerBag(s.kgPerBag - 5),
                onPlus: () => s.setKgPerBag(s.kgPerBag + 5),
                hint: s.kgPerBag == Units.defaultKgPerBag ? 'Standard' : 'Custom',
              ),
            ]),
          ),

          // ── Start-up & reminders ──────────────────────────────────
          HtmlCard(
            header: const HtmlCardHeader(
                icon: Icons.tune, title: 'Start-up & reminders'),
            body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              HtmlFormField(
                label: 'Screen to open first',
                child: DropdownButtonFormField<int>(
                  initialValue: s.startTab,
                  dropdownColor: AppColors.surfaceLight,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: htmlInputDec(),
                  items: List.generate(
                    tabNames.length,
                    (i) => DropdownMenuItem(
                        value: i,
                        child: Text(tabNames[i],
                            style: TextStyle(color: AppColors.textPrimary))),
                  ),
                  onChanged: (v) => v == null ? null : s.setStartTab(v),
                ),
              ),
              const SizedBox(height: 14),
              HtmlFormField(
                label: 'Vaccination reminder time',
                child: InkWell(
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: s.reminderHour, minute: 0),
                    );
                    if (t != null) s.setReminderHour(t.hour);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.amber.withValues(alpha: 0.5)),
                    ),
                    child: Row(children: [
                      Icon(Icons.schedule, size: 18, color: AppColors.amber),
                      const SizedBox(width: 10),
                      Text(
                        TimeOfDay(hour: s.reminderHour, minute: 0).format(context),
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      ),
                      const Spacer(),
                      Text('the day before',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),

          // ── Reset ─────────────────────────────────────────────────
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => _confirmReset(context),
            icon: Icon(Icons.restart_alt, size: 18, color: AppColors.red),
            label: Text('Reset all settings',
                style: TextStyle(color: AppColors.red)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.red.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text('These settings only change how the app looks and '
                'measures — your farm records are never affected.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text('Hatch2Revenue v1.6.0',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _swatch(String label, Color c) => Expanded(
        child: Column(children: [
          Container(
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5)),
        ]),
      );

  Widget _stepper(BuildContext context,
      {required String label,
      required String value,
      required VoidCallback onMinus,
      required VoidCallback onPlus,
      required String hint}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: AppColors.textPrimary, fontSize: 13.5)),
            Text(hint, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ]),
        ),
        IconButton(
          onPressed: onMinus,
          icon: Icon(Icons.remove_circle_outline, color: AppColors.textSecondary),
        ),
        SizedBox(
          width: 42,
          child: Text(value,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  color: AppColors.amber, fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        IconButton(
          onPressed: onPlus,
          icon: Icon(Icons.add_circle_outline, color: AppColors.amber),
        ),
      ]),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset settings?'),
        content: Text(
          'Colours, text size, farm units, start-up screen and reminder '
          'time go back to their defaults. Your farm records are not touched.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red, foregroundColor: Colors.white),
            onPressed: () {
              ctx.read<SettingsProvider>().resetAll();
              Navigator.pop(ctx);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
