import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class OnboardingModel {
  final String title;
  final String description;
  final IconData icon;
  final LinearGradient gradient;
  final List<String> features;

  OnboardingModel({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.features,
  });
}

// 2026 Modern Onboarding Content
List<OnboardingModel> onboardingPages = [
  OnboardingModel(
    title: 'Scan Any Space\nInstantly',
    description: 'Transform physical spaces into precise 3D models using iPhone LiDAR technology',
    icon: Icons.view_in_ar_rounded,
    gradient: AppColors.primaryGradient,
    features: [
      'Real-time 3D capture',
      'Sub-2cm accuracy',
      'Indoor optimization',
    ],
  ),
  OnboardingModel(
    title: 'AI-Powered\nQuality Control',
    description: 'Get instant feedback with intelligent scan quality analysis and coverage metrics',
    icon: Icons.auto_awesome_rounded,
    gradient: AppColors.accentGradient,
    features: [
      'Live quality meter',
      'Coverage heatmap',
      'Smart suggestions',
    ],
  ),
  OnboardingModel(
    title: 'Work Offline,\nSync Later',
    description: 'Capture scans without internet. Encrypted data syncs automatically when connected',
    icon: Icons.cloud_sync_rounded,
    gradient: AppColors.coolGradient,
    features: [
      'Offline scanning',
      'Auto-sync queue',
      'End-to-end encryption',
    ],
  ),
  OnboardingModel(
    title: 'Professional\nDeliverables',
    description: 'Export engineering-grade floor plans, measurements, and 3D models instantly',
    icon: Icons.architecture_rounded,
    gradient: AppColors.warmGradient,
    features: [
      'CAD-ready exports',
      'Automated floor plans',
      'Detailed reports',
    ],
  ),
];
