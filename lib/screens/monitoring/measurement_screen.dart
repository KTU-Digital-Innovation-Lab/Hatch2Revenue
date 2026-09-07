import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/batch.dart';
import '../../models/measurement.dart';
import '../../providers/measurement_provider.dart';
import '../../providers/weather_provider.dart';
import '../../services/flock_monitor_advice.dart';
import '../../utils/app_colors.dart';
import '../../utils/caps.dart';
import '../../utils/html_widgets.dart';

/// Flock monitoring for a single batch: weight, temperature and water,
/// each with a trend chart and a history list. Opened from the batch hub.
class MeasurementScreen extends StatefulWidget {
  final Batch batch;
  const MeasurementScreen({super.key, required this.batch});

  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends State<MeasurementScreen> {
  MeasurementType _type = MeasurementType.weight;

  Color _colorFor(MeasurementType t) {
    switch (t) {
      case MeasurementType.weight:
        return AppColors.purple;
      case MeasurementType.temperature:
        return AppColors.red;
      case MeasurementType.water:
        return AppColors.blue;
    }
  }

  String _hintFor(MeasurementType t) {
    switch (t) {
      case MeasurementType.weight:
        return 'Average bird weight in grams';
      case MeasurementType.temperature:
        return 'House temperature in °C';
      case MeasurementType.water:
        return 'Litres consumed';
    }
  }

  @override
  Widget build(BuildContext context) {
    final caps = Caps.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Monitoring · ${widget.batch.name}')),
      body: Consumer<MeasurementProvider>(
        builder: (context, provider, _) {
          final series = provider.series(widget.batch.id, _type);
          final latest = series.isEmpty ? null : series.last;
          final advice = switch (_type) {
            MeasurementType.weight =>
              FlockMonitorAdvice.weight(widget.batch, series),
            MeasurementType.temperature =>
              FlockMonitorAdvice.temperature(widget.batch, series),
            MeasurementType.water => FlockMonitorAdvice.water(series),
          };
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionHeader(
                icon: Icons.monitor_heart_outlined,
                title: 'Flock Monitoring',
                subtitle:
                    'Weight, temperature and water for ${widget.batch.name}',
                action: caps.canLogFeed
                    ? PrimaryBtn(
                        label: '+ Add reading',
                        onPressed: () => _addDialog(context, provider),
                      )
                    : null,
              ),
              const SizedBox(height: 14),
              _typeSelector(),
              const SizedBox(height: 16),
              if (latest != null) ...[
                _latestCard(latest),
                const SizedBox(height: 14),
              ],
              if (advice != null) ...[
                _adviceCard(advice),
                const SizedBox(height: 14),
              ],
              _trendCard(series),
              const SizedBox(height: 18),
              _historyCard(context, provider, series.reversed.toList(), caps),
              const SizedBox(height: 60),
            ],
          );
        },
      ),
    );
  }

  // ---- type selector ----
  Widget _typeSelector() {
    return Row(
      children: [
        for (var i = 0; i < MeasurementType.values.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  right: i < MeasurementType.values.length - 1 ? 8 : 0),
              child: _typeChip(MeasurementType.values[i]),
            ),
          ),
      ],
    );
  }

  Widget _typeChip(MeasurementType t) {
    final active = _type == t;
    final c = _colorFor(t);
    return GestureDetector(
      onTap: () => setState(() => _type = t),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? c.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? c : AppColors.border),
        ),
        child: Center(
          child: Text(
            t.label,
            style: GoogleFonts.inter(
              color: active ? c : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // ---- latest reading ----
  Widget _latestCard(Measurement m) {
    final c = _colorFor(_type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LATEST ${_type.label.toUpperCase()}',
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      letterSpacing: 0.6)),
              const SizedBox(height: 4),
              Text('${_trim(m.value)} ${_type.unit}',
                  style: GoogleFonts.poppins(
                      color: c, fontSize: 24, fontWeight: FontWeight.w700)),
            ],
          ),
          const Spacer(),
          Text(DateFormat('d MMM yyyy').format(m.date),
              style: GoogleFonts.inter(
                  color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  // ---- advice (weight/temp/water reading) ----
  Widget _adviceCard(FlockAdvice a) {
    final c = a.level == 'warn'
        ? AppColors.red
        : a.level == 'watch'
            ? AppColors.amber
            : AppColors.green;
    final icon =
        a.level == 'good' ? Icons.check_circle_outline : Icons.info_outline;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(a.message,
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary, fontSize: 12.5, height: 1.4)),
          ),
        ],
      ),
    );
  }

  // ---- trend chart ----
  Widget _trendCard(List<Measurement> series) {
    final c = _colorFor(_type);
    final label = _type == MeasurementType.weight
        ? 'Growth curve'
        : '${_type.label} trend';
    return HtmlCard(
      header: HtmlCardHeader(
        icon: Icons.show_chart,
        title: label,
        trailing: TagChip(label: 'in ${_type.unit}', color: c),
      ),
      body: series.length < 2
          ? Text(
              'Log at least two ${_type.label.toLowerCase()} readings and the '
              'trend shows here.',
              style: GoogleFonts.inter(
                  color: AppColors.textSecondary, fontSize: 12),
            )
          : SizedBox(height: 180, child: _lineChart(series, c)),
    );
  }

  Widget _lineChart(List<Measurement> series, Color c) {
    var maxV = series.first.value, minV = series.first.value;
    for (final m in series) {
      if (m.value > maxV) maxV = m.value;
      if (m.value < minV) minV = m.value;
    }
    final span = maxV - minV;
    final pad = span == 0 ? (maxV == 0 ? 1.0 : maxV * 0.2) : span * 0.15;
    final minY = _type == MeasurementType.weight ? 0.0 : (minV - pad);
    final maxY = maxV + pad;
    final yInterval = ((maxY - minY) / 3).clamp(0.1, double.infinity);
    final xInterval = (series.length / 4).ceilToDouble().clamp(1.0, 9999.0);

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        minX: 0,
        maxX: (series.length - 1).toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: AppColors.border, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: yInterval,
              getTitlesWidget: (value, meta) => Text(
                _trim(value),
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 9),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: xInterval,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= series.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('d/M').format(series[i].date),
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 9),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceLight,
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      '${_trim(s.y)} ${_type.unit}',
                      TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11),
                    ))
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < series.length; i++)
                FlSpot(i.toDouble(), series[i].value),
            ],
            isCurved: true,
            color: c,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: series.length <= 30),
            belowBarData:
                BarAreaData(show: true, color: c.withValues(alpha: 0.12)),
          ),
        ],
      ),
    );
  }

  // ---- history ----
  Widget _historyCard(BuildContext context, MeasurementProvider provider,
      List<Measurement> history, Caps caps) {
    return HtmlCard(
      header: HtmlCardHeader(
          icon: Icons.list_alt_outlined,
          title: '${_type.label} history'),
      bodyPadding: EdgeInsets.zero,
      body: history.isEmpty
          ? HtmlEmptyState(
              icon: Icons.monitor_heart_outlined,
              message: 'No ${_type.label.toLowerCase()} readings yet.',
              action: caps.canLogFeed
                  ? PrimaryBtn(
                      label: '+ Add reading',
                      small: true,
                      onPressed: () => _addDialog(context, provider))
                  : null,
            )
          : Column(
              children: [
                for (final m in history)
                  _historyRow(context, provider, m, caps),
              ],
            ),
    );
  }

  Widget _historyRow(BuildContext context, MeasurementProvider provider,
      Measurement m, Caps caps) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_trim(m.value)} ${_type.unit}',
                    style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text(
                  DateFormat('d MMM yyyy').format(m.date) +
                      (m.notes != null && m.notes!.isNotEmpty
                          ? ' · ${m.notes}'
                          : ''),
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          if (caps.canAmend)
            IconButton(
              icon: Icon(Icons.delete_outline,
                  color: AppColors.textSecondary, size: 20),
              onPressed: () => provider.removeRecord(m.id),
            ),
        ],
      ),
    );
  }

  // ---- add dialog ----
  void _addDialog(BuildContext context, MeasurementProvider provider) {
    final valueCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    var date = DateTime.now();
    final c = _colorFor(_type);
    final weather = context.read<WeatherProvider>();

    // Temperature can be seeded from the local outdoor forecast as a
    // starting point. A house usually runs warmer than outside, so the
    // farmer adjusts it — the app can suggest, not truly measure.
    if (_type == MeasurementType.temperature && weather.hasData) {
      valueCtrl.text = weather.data!.tempC.toStringAsFixed(1);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: Text('Add ${_type.label} reading'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              HtmlFormField(
                label: '${_type.label} (${_type.unit})',
                child: TextField(
                  controller: valueCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: htmlInputDec(_hintFor(_type)),
                ),
              ),
              if (_type == MeasurementType.temperature)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: weather.loading
                        ? null
                        : () async {
                            if (!weather.hasData) await weather.load();
                            final t = weather.data?.tempC;
                            if (t != null) {
                              ss(() => valueCtrl.text = t.toStringAsFixed(1));
                            }
                          },
                    icon: Icon(Icons.wb_sunny_outlined,
                        size: 16, color: AppColors.amber),
                    label: Text(
                      weather.hasData
                          ? 'From local weather (${weather.data!.tempC.toStringAsFixed(0)}°C) — adjust to your house'
                          : weather.loading
                              ? 'Getting local weather…'
                              : 'Use local outdoor temperature',
                      style: TextStyle(color: AppColors.amber, fontSize: 11),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Date',
                child: HtmlDateTile(
                  date: date,
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) ss(() => date = d);
                  },
                ),
              ),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Notes',
                child: TextField(
                  controller: notesCtrl,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: htmlInputDec('Optional'),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: c),
              onPressed: () {
                final v = double.tryParse(valueCtrl.text.trim());
                if (v == null || v <= 0) return;
                provider.addRecord(Measurement(
                  batchId: widget.batch.id,
                  date: date,
                  type: _type,
                  value: v,
                  notes: notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                ));
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  /// Trims trailing ".0" so 1450.0 reads 1450 but 34.5 stays 34.5.
  String _trim(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}
