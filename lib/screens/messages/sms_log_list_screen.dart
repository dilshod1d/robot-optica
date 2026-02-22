import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:robot_optica/widgets/common/app_loader.dart';
import '../../models/sms_log_model.dart';
import '../../models/sms_log_time_filter.dart';
import '../../services/sms_log_service.dart';
import '../../widgets/messages/sms_log_card.dart';
import '../../widgets/messages/sms_log_filter_bar.dart';

class SmsLogListScreen extends StatefulWidget {
  final String opticaId;

  const SmsLogListScreen({super.key, required this.opticaId});

  @override
  State<SmsLogListScreen> createState() => _SmsLogListScreenState();
}

class _SmsLogListScreenState extends State<SmsLogListScreen> {
  final SmsLogService _service = SmsLogService();

  SmsLogTimeFilter _currentFilter = SmsLogTimeFilter.today;

  List<SmsLogModel> _logs = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;

  static const int _pageSize = 20;

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

    final result = await _service.fetchAllLogs(
      opticaId: widget.opticaId,
      after: _getAfterDate(),
      limit: _pageSize,
    );

    setState(() {
      _logs = result;
      _isLoading = false;
      _hasMore = result.length == _pageSize;
      if (result.isNotEmpty) {
        _lastDoc = result.last.firestoreDoc;
      }
    });
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    final result = await _service.fetchAllLogs(
      opticaId: widget.opticaId,
      after: _getAfterDate(),
      startAfterDoc: _lastDoc,
      limit: _pageSize,
    );

    setState(() {
      _logs.addAll(result);
      _isLoading = false;
      _hasMore = result.length == _pageSize;
      if (result.isNotEmpty) {
        _lastDoc = result.last.firestoreDoc;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Tarixi'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: SmsLogFilterBar(
              currentFilter: _currentFilter,
              onFilterChanged: (newFilter) {
                setState(() => _currentFilter = newFilter);
                _loadInitial();
              },
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (scroll) {
                if (scroll.metrics.pixels >=
                    scroll.metrics.maxScrollExtent - 200) {
                  if (!_isLoading && _hasMore) {
                    _loadMore();
                  }
                }
                return false;
              },
              child: _logs.isEmpty && !_isLoading
                  ? const Center(child: Text('SMS tarixi mavjud emas'))
                  : ListView.builder(
                itemCount: _logs.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < _logs.length) {
                    return SmsLogCard(log: _logs[index]);
                  } else {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: AppLoader(
                        size: 80,
                        fill: false,
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
