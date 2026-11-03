import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/medicine_storage_service.dart';
import 'medicine_result_screen.dart';

class HistoryScreen extends StatefulWidget {
  final Function(String medicineName)? onAddToPatientHistory;

  const HistoryScreen({super.key, this.onAddToPatientHistory});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> medicines = [];

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    final data = await MedicineStorageService.getHistory();
    if (!mounted) return;
    setState(() {
      medicines = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("history.title".tr()),
      ),
      body: medicines.isEmpty
          ? Center(
              child: Text("history.no_data".tr()),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: medicines.length,
              itemBuilder: (context, index) {
                final medicine = medicines[index];
                final name = medicine["name"]?.toString() ?? "Unknown";
                final data = medicine["data"];

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.medication),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      data != null && data['indications_and_usage'] != null
                          ? _truncateWithEllipsis(40, _parseField(data['indications_and_usage']))
                          : "history.scannedToday".tr(),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MedicineResultScreen(
                            medicineName: name,
                            data: data,
                            onAddToPatientHistory: widget.onAddToPatientHistory,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  String _truncateWithEllipsis(int cutoff, String myString) {
    return (myString.length <= cutoff) ? myString : '${myString.substring(0, cutoff)}...';
  }

  String _parseField(dynamic value) {
    if (value == null) return "";
    if (value is String) return value;
    if (value is List && value.isNotEmpty) return value.first.toString();
    return value.toString();
  }
}
