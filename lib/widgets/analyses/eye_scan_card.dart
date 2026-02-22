import 'package:flutter/material.dart';
import '../../models/eye_measurement.dart';
import '../../models/eye_scan_result.dart';
import '../../models/eye_side.dart';

class EyeScanCard extends StatelessWidget {
  final EyeScanResult scan;

  const EyeScanCard({
    super.key,
    required this.scan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: _shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 12),
          _eyeTable("O'ng", scan.right),
          const SizedBox(height: 12),
          _eyeTable("Chap", scan.left),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        const Icon(Icons.remove_red_eye, size: 18),
        const SizedBox(width: 6),
        const Text("Avtorefraksiya", style: TextStyle(fontWeight: FontWeight.bold)),
        const Spacer(),
        if (scan.date != null)
          Text(scan.date!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        if (scan.pd != null) ...[
          const SizedBox(width: 8),
          Text("PD (Qorachiq masofasi) ${scan.pd}", style: const TextStyle(fontSize: 12)),
        ],
      ],
    );
  }

  Widget _eyeTable(String title, EyeSide side) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        _tableHeader(),
        if (side.avg != null) _row("O'rtacha", side.avg!),
        ...side.readings.asMap().entries.map(
              (e) => _row("R${e.key + 1}", e.value),
        ),
        if (side.se != null) _seRow(side.se!),
      ],
    );
  }

  Widget _tableHeader() {
    return const Row(
      children: [
        SizedBox(width: 40),
        Expanded(child: Text("Sfera", style: _headerStyle)),
        Expanded(child: Text("Silindr", style: _headerStyle)),
        Expanded(child: Text("O‘q", style: _headerStyle)),
      ],
    );
  }

  Widget _row(String label, EyeMeasurement m) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(m.sphere)),
          Expanded(child: Text(m.cylinder)),
          Expanded(child: Text(m.axis)),
        ],
      ),
    );
  }

  Widget _seRow(String se) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          const SizedBox(width: 40),
          const Text("SE (Sferik ko'rsatkich):", style: TextStyle(color: Colors.grey)),
          const SizedBox(width: 8),
          Text(se, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

const _shadow = [
  BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 10,
    offset: Offset(0, 4),
  )
];

const _headerStyle = TextStyle(
  fontSize: 12,
  color: Colors.grey,
  fontWeight: FontWeight.w600,
);
