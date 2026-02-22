// import 'package:flutter/material.dart';
//
// enum FilterType { all, due, debt }
//
// class FilterChipsRow extends StatelessWidget {
//   final FilterType selected;
//   final ValueChanged<FilterType> onSelected;
//
//   const FilterChipsRow({
//     super.key,
//     required this.selected,
//     required this.onSelected,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return SingleChildScrollView(
//       scrollDirection: Axis.horizontal,
//       padding: const EdgeInsets.symmetric(horizontal: 8.0),
//       child: Row(
//         children: FilterType.values.map((filter) {
//           return Padding(
//             padding: const EdgeInsets.only(right: 10),
//             child: ChoiceChip(
//               label: Text(filter.name.toUpperCase()),
//               selected: selected == filter,
//               onSelected: (_) => onSelected(filter),
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }
// }
