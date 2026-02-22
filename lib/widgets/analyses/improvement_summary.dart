import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../models/eye_scan_result.dart';
import '../../models/eye_side.dart';

class ImprovementSummary extends StatelessWidget {
  final List<EyeScanResult> scans;
  final int maxPoints;

  const ImprovementSummary({
    super.key,
    required this.scans,
    this.maxPoints = 12,
  });

  double _parse(String v) => double.tryParse(v) ?? 0;

  @override
  Widget build(BuildContext context) {
    if (scans.isEmpty) {
      return const SizedBox.shrink();
    }

    final rightPair = _latestPair(scans, isRight: true);
    final leftPair = _latestPair(scans, isRight: false);
    final rightDiff = _diffFromPair(rightPair);
    final leftDiff = _diffFromPair(leftPair);

    final chartScans = scans.length > maxPoints
        ? scans.sublist(0, maxPoints).reversed.toList()
        : scans.reversed.toList();

    final rightSpots = _buildSpots(chartScans, isRight: true);
    final leftSpots = _buildSpots(chartScans, isRight: false);
    final chartRange = _rangeFromSpots([...rightSpots, ...leftSpots]);

    if (rightDiff == null && leftDiff == null && rightSpots.isEmpty && leftSpots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: _shadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text("Ko'rishda trend", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("SE ma'lumotlari topilmadi", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: _shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text("Ko'rishda trend", style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                scans.length >= 2 ? "So'nggi 2 analiz" : "So'nggi analiz",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            scans.length >= 2
                ? "SE farqi: oldingi va hozirgi tahlil natijasini solishtiradi"
                : "SE farqi: so'nggi tahlil bo'yicha qisqa xulosa",
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _sideRow("O'ng ko'z", rightPair.previous, rightPair.current, rightDiff),
          const SizedBox(height: 12),
          _sideRow("Chap ko'z", leftPair.previous, leftPair.current, leftDiff),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text("SE trendi", style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                "So'nggi ${chartScans.length} analiz",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (rightSpots.isEmpty && leftSpots.isEmpty)
            const Text("Trend uchun yetarli ma'lumot yo'q", style: TextStyle(color: Colors.grey))
          else
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (chartScans.length - 1).toDouble(),
                  minY: chartRange.minY,
                  maxY: chartRange.maxY,
                  gridData: FlGridData(show: true, horizontalInterval: 1, verticalInterval: 1),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        getTitlesWidget: (value, meta) {
                          return Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 10, color: Colors.grey));
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (chartScans.length - 1).clamp(1, 6).toDouble(),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= chartScans.length) return const SizedBox.shrink();
                          if (index != 0 && index != chartScans.length - 1) return const SizedBox.shrink();
                          final label = chartScans[index].date?.trim();
                          final isSingle = chartScans.length == 1;
                          return Text(
                            label != null && label.isNotEmpty
                                ? label
                                : (isSingle ? "Hozirgi" : (index == 0 ? "Oldingi" : "Hozirgi")),
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    if (rightSpots.isNotEmpty)
                      LineChartBarData(
                        spots: rightSpots,
                        isCurved: true,
                        color: const Color(0xFF2D8CFF),
                        barWidth: 3,
                        dotData: FlDotData(show: true),
                      ),
                    if (leftSpots.isNotEmpty)
                      LineChartBarData(
                        spots: leftSpots,
                        isCurved: true,
                        color: const Color(0xFFFF9F1C),
                        barWidth: 3,
                        dotData: FlDotData(show: true),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: const [
              _LegendDot(color: Color(0xFF2D8CFF), label: "O'ng ko'z"),
              SizedBox(width: 12),
              _LegendDot(color: Color(0xFFFF9F1C), label: "Chap ko'z"),
            ],
          ),
        ],
      ),
    );
  }

  double? _seValue(EyeSide side) {
    final seRaw = side.se?.trim();
    if (seRaw != null && seRaw.isNotEmpty) {
      return _parse(seRaw);
    }

    final m = side.avg ?? (side.readings.isNotEmpty ? side.readings.first : null);
    if (m == null) return null;

    final sphereRaw = m.sphere.trim();
    final cylinderRaw = m.cylinder.trim();
    if (sphereRaw.isEmpty && cylinderRaw.isEmpty) return null;

    final sphere = _parse(sphereRaw);
    final cylinder = _parse(cylinderRaw);
    return sphere + (cylinder / 2);
  }

  double? _diff(EyeSide previousSide, EyeSide currentSide) {
    final prev = _seValue(previousSide);
    final curr = _seValue(currentSide);
    if (prev == null || curr == null) return null;
    return prev - curr;
  }

  _SePair _latestPair(List<EyeScanResult> list, {required bool isRight}) {
    double? current;
    double? previous;

    for (final scan in list) {
      final value = _seValue(isRight ? scan.right : scan.left);
      if (value == null) continue;
      if (current == null) {
        current = value;
      } else {
        previous = value;
        break;
      }
    }

    return _SePair(previous: previous, current: current);
  }

  double? _diffFromPair(_SePair pair) {
    if (pair.previous == null || pair.current == null) return null;
    return pair.previous! - pair.current!;
  }

  List<FlSpot> _buildSpots(List<EyeScanResult> list, {required bool isRight}) {
    final spots = <FlSpot>[];
    for (var i = 0; i < list.length; i++) {
      final value = _seValue(isRight ? list[i].right : list[i].left);
      if (value == null) continue;
      spots.add(FlSpot(i.toDouble(), value));
    }
    return spots;
  }

  _ChartRange _rangeFromSpots(List<FlSpot> spots) {
    if (spots.isEmpty) {
      return const _ChartRange(minY: -1, maxY: 1);
    }

    double minY = spots.first.y;
    double maxY = spots.first.y;
    for (final s in spots) {
      if (s.y < minY) minY = s.y;
      if (s.y > maxY) maxY = s.y;
    }

    final pad = ((maxY - minY).abs() * 0.15).clamp(0.25, 1.5);
    return _ChartRange(minY: minY - pad, maxY: maxY + pad);
  }

  Widget _sideRow(String label, double? prev, double? curr, double? diff) {
    final status = _statusLabel(diff);
    final color = _statusColor(diff);
    final formattedPrev = _formatSe(prev);
    final formattedCurr = _formatSe(curr);
    final formattedDiff = diff == null ? "--" : "${diff > 0 ? "+" : ""}${diff.toStringAsFixed(2)} D";

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE6E9EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              _statusChip(status, color),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _valuePill("Oldingi", formattedPrev),
              const SizedBox(width: 8),
              _valuePill("Hozirgi", formattedCurr),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    diff == null
                        ? Icons.remove
                        : (diff > 0 ? Icons.trending_up : (diff < 0 ? Icons.trending_down : Icons.remove)),
                    size: 16,
                    color: color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    formattedDiff,
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _diffBar(diff, color),
        ],
      ),
    );
  }

  Widget _valuePill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6E9EF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _diffBar(double? diff, Color color) {
    if (diff == null) {
      return Container(
        height: 6,
        decoration: BoxDecoration(
          color: const Color(0xFFE6E9EF),
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }

    const maxAbs = 3.0;
    final magnitude = diff.abs().clamp(0, maxAbs);
    final fraction = magnitude / maxAbs;

    return Stack(
      children: [
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFFE6E9EF),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        FractionallySizedBox(
          widthFactor: fraction,
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ],
    );
  }

  String _formatSe(double? value) {
    if (value == null) return "--";
    return value.toStringAsFixed(2);
  }

  String _statusLabel(double? diff) {
    if (diff == null) return "Ma'lumot yo'q";
    if (diff.abs() < 0.01) return "O'zgarish yo'q";
    return diff > 0 ? "Yaxshilandi" : "Yomonlashdi";
  }

  Color _statusColor(double? diff) {
    if (diff == null) return Colors.grey;
    if (diff.abs() < 0.01) return Colors.blueGrey;
    return diff > 0 ? Colors.green : Colors.red;
  }
}

const _shadow = [
  BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 10,
    offset: Offset(0, 4),
  )
];

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _SePair {
  final double? previous;
  final double? current;

  const _SePair({required this.previous, required this.current});
}

class _ChartRange {
  final double minY;
  final double maxY;

  const _ChartRange({required this.minY, required this.maxY});
}
