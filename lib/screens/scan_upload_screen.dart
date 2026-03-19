import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_colors.dart';
import '../providers/theme_provider.dart';
import '../models/scan_model.dart';

class ScanUploadScreen extends StatefulWidget {
  const ScanUploadScreen({super.key});

  @override
  State<ScanUploadScreen> createState() => _ScanUploadScreenState();
}

class _ScanUploadScreenState extends State<ScanUploadScreen> with SingleTickerProviderStateMixin {
  double _uploadProgress = 0.0;
  bool _isUploading = false;
  bool _isEncrypting = false;
  bool _uploadComplete = false;
  bool _uploadError = false;
  String _statusMessage = 'Preparing upload...';
  
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Auto-start upload
    Future.delayed(const Duration(milliseconds: 500), _startUpload);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _startUpload() async {
    setState(() {
      _isEncrypting = true;
      _statusMessage = 'Encrypting scan data...';
    });

    // Simulate encryption
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isEncrypting = false;
      _isUploading = true;
      _statusMessage = 'Uploading to cloud...';
    });

    // Simulate upload progress
    for (int i = 0; i <= 100; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 50));
      setState(() {
        _uploadProgress = i / 100;
        if (i == 100) {
          _isUploading = false;
          _uploadComplete = true;
          _statusMessage = 'Upload complete!';
        }
      });
    }

    // Navigate back after success
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  void _cancelUpload() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Upload?'),
        content: const Text('Are you sure you want to cancel this upload?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, false);
            },
            child: Text('Yes', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
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
    final scan = args['scan'] as ScanModel?;

    return WillPopScope(
      onWillPop: () async {
        if (_isUploading || _isEncrypting) {
          _cancelUpload();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(textColor),

              // Content
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Upload Animation
                        _buildUploadAnimation(),

                        const SizedBox(height: 40),

                        // Status Card
                        _buildStatusCard(scan, cardColor, textColor, subtitleColor),

                        const SizedBox(height: 32),

                        // Progress Section
                        if (_isUploading || _isEncrypting)
                          _buildProgressSection(cardColor, textColor, subtitleColor),

                        if (_uploadComplete)
                          _buildSuccessSection(cardColor, textColor),

                        if (_uploadError)
                          _buildErrorSection(cardColor, textColor),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Button
              if (_isUploading || _isEncrypting)
                _buildCancelButton(cardColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          if (!_isUploading && !_isEncrypting)
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
          if (_isUploading || _isEncrypting) const SizedBox(width: 44),
          const SizedBox(width: 12),
          Text(
            'Upload Scan',
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

  Widget _buildUploadAnimation() {
    IconData icon;
    Color color;

    if (_uploadComplete) {
      icon = Icons.check_circle_rounded;
      color = AppColors.success;
    } else if (_uploadError) {
      icon = Icons.error_rounded;
      color = AppColors.error;
    } else if (_isEncrypting) {
      icon = Icons.lock_rounded;
      color = AppColors.warning;
    } else {
      icon = Icons.cloud_upload_rounded;
      color = AppColors.accentBlue;
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _uploadComplete || _uploadError ? 1.0 : _pulseAnimation.value,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: _uploadComplete
                  ? LinearGradient(
                      colors: [AppColors.success, AppColors.success.withOpacity(0.7)],
                    )
                  : _uploadError
                      ? LinearGradient(
                          colors: [AppColors.error, AppColors.error.withOpacity(0.7)],
                        )
                      : AppColors.accentGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 70,
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(
    ScanModel? scan,
    Color cardColor,
    Color textColor,
    Color subtitleColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _statusMessage,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          if (scan != null) ...[
            const SizedBox(height: 16),
            Divider(color: AppColors.lightGray),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.view_in_ar_rounded,
                  color: AppColors.accentBlue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    scan.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: subtitleColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  '${scan.createdAt.day}/${scan.createdAt.month}/${scan.createdAt.year}',
                  style: TextStyle(
                    fontSize: 14,
                    color: subtitleColor,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.high_quality_rounded,
                  color: subtitleColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  '${(scan.quality * 100).toInt()}% Quality',
                  style: TextStyle(
                    fontSize: 14,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressSection(Color cardColor, Color textColor, Color subtitleColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isEncrypting ? 'Encrypting...' : 'Uploading...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              Text(
                _isEncrypting ? '🔒' : '${(_uploadProgress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.accentBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _isEncrypting ? null : _uploadProgress,
              minHeight: 8,
              backgroundColor: AppColors.lightGray,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentBlue),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                _isEncrypting ? Icons.lock_rounded : Icons.cloud_upload_rounded,
                color: subtitleColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isEncrypting
                      ? 'Encrypting your data with AES-256'
                      : 'Uploading to secure cloud storage',
                  style: TextStyle(
                    fontSize: 13,
                    color: subtitleColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessSection(Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.success.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Upload Successful!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your scan has been securely uploaded to the cloud',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.mediumGray,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorSection(Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.error.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_rounded,
            color: AppColors.error,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Upload Failed',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please check your internet connection and try again',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.mediumGray,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _uploadError = false;
                _uploadProgress = 0.0;
              });
              _startUpload();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Retry Upload'),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton(Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: _cancelUpload,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.error, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'Cancel Upload',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
