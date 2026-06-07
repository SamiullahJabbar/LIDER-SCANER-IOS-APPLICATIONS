import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_colors.dart';
import '../providers/theme_provider.dart';
import '../services/local_scan_storage_service.dart';
import '../providers/local_scan_provider.dart';

class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  List<ScanSession> _allScans = [];
  List<ScanSession> _filteredScans = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadScans();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadScans() async {
    setState(() => _isLoading = true);
    final provider = context.read<LocalScanProvider>();
    await provider.loadScanHistory();
    setState(() {
      _allScans = provider.scanHistory;
      _applyFilter();
      _isLoading = false;
    });
  }

  void _filterScans(String filter) {
    setState(() {
      _selectedFilter = filter;
      _applyFilter();
    });
  }
  
  void _applyFilter() {
    List<ScanSession> filtered;
    if (_selectedFilter == 'All') {
      filtered = _allScans;
    } else if (_selectedFilter == 'Completed') {
      filtered = _allScans.where((s) => s.status == ScanStatus.completed).toList();
    } else if (_selectedFilter == 'Exported') {
      filtered = _allScans.where((s) => s.status == ScanStatus.exported).toList();
    } else {
      filtered = _allScans;
    }
    
    // Apply search
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((s) {
        final roomType = s.roomType ?? '';
        return s.name.toLowerCase().contains(query) ||
            roomType.toLowerCase().contains(query);
      }).toList();
    }
    
    _filteredScans = filtered;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColor = isDark ? const Color(0xFF0F172A) : AppColors.offWhite;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.charcoal;
    final subtitleColor = isDark ? Colors.white70 : AppColors.darkGray;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            _buildAppBar(textColor),

            // Filter Chips
            _buildFilterChips(cardColor, textColor),

            // Scans List
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _filteredScans.isEmpty
                      ? _buildEmptyState(textColor, subtitleColor)
                      : _buildScansList(cardColor, textColor, subtitleColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(Color textColor) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_rounded,
              color: textColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scan History',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  '${_filteredScans.length} scans',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.mediumGray,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              _showSearchDialog();
            },
            icon: Icon(
              Icons.search_rounded,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(Color cardColor, Color textColor) {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        children: [
          _buildFilterChip('All', cardColor, textColor),
          const SizedBox(width: 12),
          _buildFilterChip('Completed', cardColor, textColor),
          const SizedBox(width: 12),
          _buildFilterChip('Exported', cardColor, textColor),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, Color cardColor, Color textColor) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => _filterScans(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: isSelected ? null : cardColor,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primaryBlue.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : textColor,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildScansList(Color cardColor, Color textColor, Color subtitleColor) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _filteredScans.length,
      itemBuilder: (context, index) {
        return _buildScanCard(
          _filteredScans[index],
          cardColor,
          textColor,
          subtitleColor,
        );
      },
    );
  }

  Widget _buildScanCard(
    ScanSession scan,
    Color cardColor,
    Color textColor,
    Color subtitleColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(
              context,
              '/scan-detail',
              arguments: {'session': scan},
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: AppColors.accentGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.view_in_ar_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scan.name,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: subtitleColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${scan.createdAt.day}/${scan.createdAt.month}/${scan.createdAt.year}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: subtitleColor,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.room_outlined,
                                size: 14,
                                color: subtitleColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                scan.roomType ?? '—',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Status icon
                    Icon(
                      scan.status == ScanStatus.exported
                          ? Icons.cloud_done_rounded
                          : scan.status == ScanStatus.completed
                              ? Icons.check_circle_rounded
                              : Icons.pending_rounded,
                      color: scan.status == ScanStatus.exported
                          ? AppColors.accentBlue
                          : scan.status == ScanStatus.completed
                              ? AppColors.success
                              : AppColors.mediumGray,
                      size: 28,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.high_quality_rounded,
                        label: 'Quality',
                        value: '${(scan.qualityScore * 100).toInt()}%',
                        color: _getQualityColor(scan.qualityScore),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.scatter_plot_rounded,
                        label: 'Points',
                        value: '${scan.pointCount}',
                        color: AppColors.lavender,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getQualityColor(double quality) {
    if (quality >= 0.8) return AppColors.success;
    if (quality >= 0.5) return AppColors.warning;
    return AppColors.error;
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildEmptyState(Color textColor, Color subtitleColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 100,
            color: AppColors.lightGray,
          ),
          const SizedBox(height: 24),
          Text(
            'No scans found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Start scanning to see your history',
            style: TextStyle(
              fontSize: 15,
              color: subtitleColor,
            ),
          ),
        ],
      ),
    );
  }
  
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Search Scans'),
          content: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search by name or room type...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) {
              setState(() {
                _applyFilter();
              });
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _applyFilter());
                Navigator.pop(ctx);
              },
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }
}
