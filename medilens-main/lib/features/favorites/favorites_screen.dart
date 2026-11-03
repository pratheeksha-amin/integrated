import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/medicine_storage_service.dart';
import '../medicine/medicine_result_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Map<String, dynamic>> medicines = [];

  @override
  void initState() {
    super.initState();
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    final data = await MedicineStorageService.getFavourite();
    setState(() {
      medicines = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("favorites.title".tr()),
      ),
      body: medicines.isEmpty
          ? Center(
              child: Text("favorites.no_data".tr()),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: medicines.length,
              itemBuilder: (context, index) {
                final medicine = medicines[index];
                final name = medicine["name"]?.toString() ?? "Unknown";
                final data = medicine["data"];

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.redAccent,
                      child: Icon(Icons.favorite, color: Colors.white),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      data != null && data['indications_and_usage'] != null
                          ? _truncateWithEllipsis(40, _parseField(data['indications_and_usage']))
                          : 'medicineResult.title'.tr(),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.favorite, color: Colors.red),
                      onPressed: () async {
                        await MedicineStorageService.removeFavourite(name);
                        loadFavorites();
                      },
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MedicineResultScreen(
                            medicineName: name,
                            data: data,
                          ),
                        ),
                      );
                      loadFavorites();
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
