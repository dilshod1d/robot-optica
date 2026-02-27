import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:robot_optica/widgets/common/app_loader.dart';
import 'package:robot_optica/widgets/common/empty_state.dart';
import '../../models/customer_model.dart';
import '../../models/sms_log_model.dart';
import '../../models/sms_log_time_filter.dart';
import '../../services/sms_log_service.dart';
import '../../widgets/messages/sms_log_card.dart';
import '../../widgets/messages/sms_log_filter_bar.dart';


class CustomerSmsLogTab extends StatefulWidget {
  final CustomerModel customer;

  const CustomerSmsLogTab({super.key, required this.customer});

  @override
  State<CustomerSmsLogTab> createState() => _CustomerSmsLogTabState();
}

class _CustomerSmsLogTabState extends State<CustomerSmsLogTab> {
  final SmsLogService _service = SmsLogService();

  SmsLogTimeFilter _currentFilter = SmsLogTimeFilter.today;

  List<SmsLogModel> _logs = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;

  int _columnsForWidth(double width) {
    const minWidth = 360.0;
    const maxColumns = 3;
    if (width <= 0) return 1;
    final count = (width / minWidth).floor();
    return count.clamp(1, maxColumns);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitial();
    });
  }

  DateTime? _getAfterDate() {
    final now = DateTime.now();
    switch (_currentFilter) {
      case SmsLogTimeFilter.today:
        return DateTime(now.year, now.month, now.day);
      case SmsLogTimeFilter.thisWeek:
        return now.subtract(const Duration(days: 7));
      case SmsLogTimeFilter.thisMonth:
        return now.subtract(const Duration(days: 30));
      case SmsLogTimeFilter.all:
        return null;
    }
  }

  Future<void> _loadInitial() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _logs = [];
      _lastDoc = null;
      _hasMore = true;
    });

    final result = await _service.fetchLogsByCustomer(
      opticaId: widget.customer.opticaId,
      customerId: widget.customer.id,
      after: _getAfterDate(),
    );

    print('result: $result');

    setState(() {
      _logs = result;
      _isLoading = false;
      _hasMore = result.length == 20;
      if (result.isNotEmpty) {
        _lastDoc = result.last.firestoreDoc; // you must expose this
      }
    });
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    final result = await _service.fetchLogsByCustomer(
      opticaId: widget.customer.opticaId,
      customerId: widget.customer.id,
      after: _getAfterDate(),
      startAfterDoc: _lastDoc,
    );

    setState(() {
      _logs.addAll(result);
      _isLoading = false;
      _hasMore = result.length == 20;
      if (result.isNotEmpty) {
        _lastDoc = result.last.firestoreDoc;
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// Filter bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: SmsLogFilterBar(
            currentFilter: _currentFilter,
            onFilterChanged: (newFilter) {
              setState(() => _currentFilter = newFilter);
              _loadInitial();
            },
          ),
        ),

        /// Content area (MUST be constrained)
        Expanded(
          child: _isLoading && _logs.isEmpty
              ? const AppLoader()
              : _logs.isEmpty
                  ? const EmptyState()
                  : NotificationListener<ScrollNotification>(
                      onNotification: (scroll) {
                        if (scroll.metrics.pixels >=
                            scroll.metrics.maxScrollExtent - 200) {
                          if (!_isLoading && _hasMore) {
                            _loadMore();
                          }
                        }
                        return false;
                      },
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final columns =
                              _columnsForWidth(constraints.maxWidth);
                          const spacing = 12.0;

                          if (columns <= 1) {
                            return ListView.builder(
                              itemCount: _logs.length + (_hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index < _logs.length) {
                                  return SmsLogCard(log: _logs[index]);
                                } else {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: AppLoader(
                                      size: 80,
                                      fill: false,
                                    ),
                                  );
                                }
                              },
                            );
                          }

                          final availableWidth =
                              constraints.maxWidth - (12 * 2);
                          final itemWidth = (availableWidth -
                                  (spacing * (columns - 1))) /
                              columns;

                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Wrap(
                                  spacing: spacing,
                                  runSpacing: spacing,
                                  children: _logs.map((log) {
                                    return SizedBox(
                                      width: itemWidth,
                                      child: SmsLogCard(log: log),
                                    );
                                  }).toList(),
                                ),
                                if (_hasMore)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: AppLoader(
                                      size: 80,
                                      fill: false,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

}
