import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_colors.dart';
import '../providers/theme_provider.dart';
import '../services/local_scan_storage_service.dart';
import '../services/scan_export_service.dart';
import '../models/scan_point_model.dart';
import '../providers/local_scan_provider.dart';

class ScanDetailScreen extends StatefulWidget {
  const ScanDetailScreen({super.key});

  @override
  State<ScanDetailScreen> createState() => _ScanDetailScreenState();
}

class _ScanDetailScreenState extends State<ScanDetailScreen> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showEditDialog(ScanSession scan) {
    _nameController.text = scan.name;
    _notesController.text = scan.metadata['notes'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Scan'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Scan Name',
                prefixIcon: Icon(Icons.edit_rounded, color: AppColors.accentBlue),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                prefixIcon: Icon(Icons.note_rounded, color: AppColors.accentBlue),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final provider = this.context.read<LocalScanProvider>();
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(this.context);
              await provider.renameSession(scan.id, _nameController.text);
              if (mounted) {
                nav.pop();
                setState(() {});
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text('Scan updated successfully'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(ScanSession scan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Scan?'),
        content: Text('Are you sure you want to delete "${scan.name}"? This action cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final provider = this.context.read<LocalScanProvider>();
              final nav = Navigator.of(this.context);
              final messenger = ScaffoldMessenger.of(this.context);
              await provider.deleteSession(scan.id);
              if (mounted) {
                nav.pop();
                nav.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text('Scan deleted'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showShareOptions(ScanSession scan) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        final isDark = themeProvider.isDarkMode;
        final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
        
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.mediumGray,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Share / Export Scan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.charcoal,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildShareOption(
                Icons.file_download_rounded,
                'Export as OBJ',
                'Universal 3D format',
                isDark,
                () => _exportAndShare(scan, ExportFormat.obj),
              ),
              _buildShareOption(
                Icons.file_download_rounded,
                'Export as PLY',
                'Point cloud with confidence data',
                isDark,
                () => _exportAndShare(scan, ExportFormat.ply),
              ),
              _buildShareOption(
                Icons.table_chart_rounded,
                'Export as CSV',
                'Spreadsheet format',
                isDark,
                () => _exportAndShare(scan, ExportFormat.csv),
              ),
              _buildShareOption(
                Icons.data_object_rounded,
                'Export Metadata (JSON)',
                'Scan info and statistics',
                isDark,
                () => _exportAndShare(scan, ExportFormat.json),
              ),
              _buildShareOption(
                Icons.folder_zip_rounded,
                'Export Full Bundle',
                'All formats (OBJ + PLY + JSON)',
                isDark,
                () => _exportBundle(scan),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportAndShare(ScanSession scan, ExportFormat format) async {
    final origin = ScanExportService.getShareOrigin(context);
    Navigator.pop(context); // close bottom sheet

    // Show loading
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Text('Exporting as ${format.name.toUpperCase()}...'),
          ],
        ),
        backgroundColor: AppColors.accentBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 10),
      ),
    );

    try {
      // Load points from encrypted storage
      List<ScanPoint> points = [];
      if (scan.filePath != null && scan.filePath!.isNotEmpty) {
        points = await LocalScanStorageService.instance.loadPointCloud(scan.filePath!);
      }

      if (points.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No point cloud data available for this scan'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      final result = await ScanExportService.instance.exportAndShare(
        format: format,
        sessionId: scan.id,
        scanName: scan.name,
        points: points,
        session: scan,
        sharePositionOrigin: origin,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Exported ${format.name.toUpperCase()} (${result.fileSizeFormatted})'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _exportBundle(ScanSession scan) async {
    final origin = ScanExportService.getShareOrigin(context);
    Navigator.pop(context); // close bottom sheet

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Exporting full bundle...'),
          ],
        ),
        backgroundColor: AppColors.accentBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 10),
      ),
    );

    try {
      List<ScanPoint> points = [];
      if (scan.filePath != null && scan.filePath!.isNotEmpty) {
        points = await LocalScanStorageService.instance.loadPointCloud(scan.filePath!);
      }

      if (points.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No point cloud data available for this scan'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      final results = await ScanExportService.instance.exportBundle(
        sessionId: scan.id,
        scanName: scan.name,
        points: points,
        session: scan,
        sharePositionOrigin: origin,
      );

      final totalSize = results.fold<int>(0, (sum, r) => sum + r.fileSize);
      final sizeStr = totalSize < 1024 * 1024
          ? '${(totalSize / 1024).toStringAsFixed(1)} KB'
          : '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Bundle exported — ${results.length} files ($sizeStr)'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bundle export failed: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _navigateTo3DViewer(ScanSession scan) async {
    List<ScanPoint> points = [];
    if (scan.filePath != null && scan.filePath!.isNotEmpty) {
      try {
        points = await LocalScanStorageService.instance.loadPointCloud(scan.filePath!);
      } catch (_) {}
    }
    if (!mounted) return;
    Navigator.pushNamed(context, '/3d-viewer', arguments: {
      'session': scan,
      'points': points,
    });
  }

  Widget _buildShareOption(IconData icon, String label, String subtitle, bool isDark, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.accentBlue),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : AppColors.charcoal,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: AppColors.mediumGray),
      ),
      trailing: Icon(Icons.arrow_forward_ios_rounded, color: AppColors.mediumGray, size: 16),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColor = isDark ? const Color(0xFF0F172A) : AppColors.offWhite;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.charcoal;
    final subtitleColor = isDark ? Colors.white70 : AppColors.darkGray;

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    final scan = args['session'] as ScanSession?;

    if (scan == null) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: Text('Error: Scan not found', style: TextStyle(color: textColor)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(textColor),

            // Content
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 20),

                  // 3D Preview Thumbnail
                  _build3DPreview(scan, cardColor),

                  const SizedBox(height: 24),

                  // Scan Info Card
                  _buildScanInfoCard(scan, cardColor, textColor, subtitleColor),

                  const SizedBox(height: 24),

                  // Stats Grid
                  _buildStatsGrid(scan, cardColor, textColor, subtitleColor),

                  const SizedBox(height: 24),

                  // Notes Section
                  _buildNotesSection(scan, cardColor, textColor, subtitleColor),

                  const SizedBox(height: 24),

                  // Action Buttons
                  _buildActionButtons(scan, cardColor),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomButtons(scan, cardColor),
    );
  }

  Widget _buildHeader(Color textColor) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.lightGray,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: textColor,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Scan Details',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _build3DPreview(ScanSession scan, Color cardColor) {
    return GestureDetector(
      onTap: () => _navigateTo3DViewer(scan),
      child: Container(
      height: 200,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 3D Preview Placeholder
          Center(
            child: Icon(
              Icons.view_in_ar_rounded,
              size: 80,
              color: AppColors.accentBlue.withValues(alpha: 0.3),
            ),
          ),
          // Play Button Overlay
          Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentBlue.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          // View in 3D Label
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Tap to view in 3D',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildScanInfoCard(
    ScanSession scan,
    Color cardColor,
    Color textColor,
    Color subtitleColor,
  ) {
    final statusColor = scan.status == ScanStatus.completed
        ? AppColors.success
        : scan.status == ScanStatus.exported
            ? AppColors.accentBlue
            : AppColors.warning;
    final statusLabel = scan.status == ScanStatus.completed
        ? 'Completed'
        : scan.status == ScanStatus.exported
            ? 'Exported'
            : 'Pending';
    
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.view_in_ar_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scan.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scan.roomType ?? '—',
                      style: TextStyle(
                        fontSize: 13,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      scan.status == ScanStatus.completed
                          ? Icons.check_circle_rounded
                          : scan.status == ScanStatus.exported
                              ? Icons.cloud_done_rounded
                              : Icons.pending_rounded,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: AppColors.lightGray),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.calendar_today_rounded,
            'Created',
            '${scan.createdAt.day}/${scan.createdAt.month}/${scan.createdAt.year} at ${scan.createdAt.hour}:${scan.createdAt.minute.toString().padLeft(2, '0')}',
            subtitleColor,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.security_rounded,
            'Storage',
            'Encrypted AES-256 (Local)',
            subtitleColor,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(
    ScanSession scan,
    Color cardColor,
    Color textColor,
    Color subtitleColor,
  ) {
    final points = scan.pointCount;
    final coverage = scan.coveragePercent * 100;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.high_quality_rounded,
                label: 'Quality',
                value: '${(scan.qualityScore * 100).toInt()}%',
                color: AppColors.success,
                cardColor: cardColor,
                textColor: textColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.pie_chart_rounded,
                label: 'Coverage',
                value: '${coverage.toInt()}%',
                color: AppColors.accentBlue,
                cardColor: cardColor,
                textColor: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.scatter_plot_rounded,
                label: 'Points',
                value: points >= 1000 ? '${(points / 1000).toStringAsFixed(1)}K' : '$points',
                color: AppColors.lavender,
                cardColor: cardColor,
                textColor: textColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.layers_rounded,
                label: 'Segments',
                value: '${scan.segments?.length ?? 0}',
                color: AppColors.mint,
                cardColor: cardColor,
                textColor: textColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color cardColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.mediumGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(
    ScanSession scan,
    Color cardColor,
    Color textColor,
    Color subtitleColor,
  ) {
    final notes = scan.metadata['notes'] ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.note_rounded, color: AppColors.accentBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Notes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            notes.isEmpty ? 'No notes added' : notes,
            style: TextStyle(
              fontSize: 14,
              color: notes.isEmpty ? AppColors.mediumGray : subtitleColor,
              fontStyle: notes.isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ScanSession scan, Color cardColor) {
    return Column(
      children: [
        _buildActionButton(
          icon: Icons.edit_rounded,
          label: 'Edit Name & Notes',
          color: AppColors.accentBlue,
          onTap: () => _showEditDialog(scan),
        ),
        const SizedBox(height: 12),
        // Upload to Vault
        _buildActionButton(
          icon: scan.isExported
              ? Icons.verified_rounded
              : Icons.cloud_upload_rounded,
          label: scan.isExported
              ? 'Already Uploaded ✓'
              : 'Upload to Vault',
          color: scan.isExported ? AppColors.success : AppColors.warning,
          onTap: () async {
            final result = await Navigator.pushNamed(
              context,
              '/scan-vault-upload',
              arguments: {'session': scan},
            );
            if (result == true && mounted) {
              setState(() {});
            }
          },
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          icon: Icons.share_rounded,
          label: 'Share / Export Scan',
          color: AppColors.lavender,
          onTap: () => _showShareOptions(scan),
        ),
        const SizedBox(height: 12),
        if (scan.status == ScanStatus.completed)
          _buildActionButton(
            icon: Icons.file_download_rounded,
            label: 'Export Scan Files',
            color: AppColors.success,
            onTap: () {
              Navigator.pushNamed(
                context,
                '/scan-upload',
                arguments: {'session': scan},
              );
            },
          ),
        if (scan.status == ScanStatus.completed) const SizedBox(height: 12),
        _buildActionButton(
          icon: Icons.delete_rounded,
          label: 'Delete Scan',
          color: AppColors.error,
          onTap: () => _showDeleteDialog(scan),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons(ScanSession scan, Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentBlue.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () => _navigateTo3DViewer(scan),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.view_in_ar_rounded, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'View in 3D',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
