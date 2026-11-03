import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/language.dart';
import '../services/medicine_search_service.dart';
import '../services/medicine_storage_service.dart';
import 'medicine_result_screen.dart';
import 'scan_screen.dart';
import 'history_screen.dart';
import 'favorites_screen.dart';
import 'language_screen.dart';

class MedicineAssistantScreen extends StatefulWidget {
  final Function(String medicineName)? onAddToPatientHistory;

  const MedicineAssistantScreen({super.key, this.onAddToPatientHistory});

  @override
  State<MedicineAssistantScreen> createState() => _MedicineAssistantScreenState();
}

class _MedicineAssistantScreenState extends State<MedicineAssistantScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final langCode = context.locale.languageCode;
      final result = await MedicineSearchService().searchMedicine(cleanQuery, langCode);

      if (result != null) {
        final medicineName = result["brand_name"] ?? result["generic_name"] ?? cleanQuery;
        await MedicineStorageService.addToHistory({
          "name": medicineName,
          "data": result,
        }, langCode);

        if (!mounted) return;
        setState(() => _isSearching = false);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MedicineResultScreen(
              medicineName: medicineName,
              data: result,
              onAddToPatientHistory: widget.onAddToPatientHistory,
            ),
          ),
        );
      } else {
        if (!mounted) return;
        setState(() {
          _isSearching = false;
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MedicineResultScreen(
              medicineName: cleanQuery,
              data: null,
              onAddToPatientHistory: widget.onAddToPatientHistory,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _errorMessage = 'Search error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentLang = languages.firstWhere(
      (l) => l.code == context.locale.languageCode,
      orElse: () => languages.first,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Card(
            elevation: 0,
            color: Colors.blue.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.blue.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: colorScheme.primary,
                        child: const Icon(Icons.medication_liquid_outlined, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Medicine Assistant (MediLens)',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Offline Medicine Information & OCR Identification',
                              style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.storage, size: 14, color: Colors.green.shade800),
                            const SizedBox(width: 4),
                            Text(
                              'Offline DB Ready',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LanguageScreen()),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.language, size: 14, color: Colors.blue.shade900),
                              const SizedBox(width: 4),
                              Text(
                                currentLang.name,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                              ),
                              const Icon(Icons.arrow_drop_down, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Medicine Search Input Field
          Text(
            'Search Medicine',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: _performSearch,
            decoration: InputDecoration(
              hintText: 'Search by brand name (e.g., Paracetamol) or generic name...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isSearching
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search),
              label: Text(_isSearching ? 'Searching...' : 'Search Offline Database'),
              onPressed: _isSearching ? null : () => _performSearch(_searchController.text),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          const SizedBox(height: 24),

          // OCR Scan Hero Banner
          Card(
            elevation: 0,
            color: Colors.teal.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.teal.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.camera_alt, color: Colors.teal.shade800, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'OCR Medicine Identification',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Snap a photo or select an image of your medicine strip/bottle to recognize text and find details instantly.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.center_focus_strong, size: 20),
                    label: Text('home.scanButton'.tr()),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ScanScreen(
                            onAddToPatientHistory: widget.onAddToPatientHistory,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Grid Options
          Text(
            'Quick Access',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _buildMenuCard(
                icon: Icons.history,
                title: 'home.history'.tr(),
                color: Colors.indigo,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HistoryScreen(
                        onAddToPatientHistory: widget.onAddToPatientHistory,
                      ),
                    ),
                  );
                },
              ),
              _buildMenuCard(
                icon: Icons.favorite,
                title: 'home.favorites'.tr(),
                color: Colors.red,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FavoritesScreen(
                        onAddToPatientHistory: widget.onAddToPatientHistory,
                      ),
                    ),
                  );
                },
              ),
              _buildMenuCard(
                icon: Icons.language,
                title: 'settings.languageTitle'.tr(),
                color: Colors.orange,
                subtitle: currentLang.name,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LanguageScreen(),
                    ),
                  );
                },
              ),
              _buildMenuCard(
                icon: Icons.info_outline,
                title: 'About Database',
                color: Colors.teal,
                subtitle: 'Offline SQLite',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'MediLens Medicine Assistant',
                    applicationVersion: '1.0.0',
                    children: [
                      const Text(
                        'Integrated into CareTimeline AI Patient Dashboard.\n\n'
                        'Includes offline SQLite medicine database with brand/generic search, '
                        'Google ML Kit OCR image recognition, multi-language support (English, Hindi, '
                        'Kannada, Tamil, Telugu, Malayalam), and offline caching.',
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.blue,
    String? subtitle,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
