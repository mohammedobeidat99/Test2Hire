import 'package:flutter/material.dart';

class CompanyBranding {
  final String? tagline;
  final String? brandColorHex; // e.g. #1E40AF
  final String? coverImageUrl;
  final List<String> perksAndBenefits;
  final String? websiteUrl;
  final String? linkedinUrl;
  final String? twitterUrl;
  final String? githubUrl;
  final String? cultureVideoUrl;

  const CompanyBranding({
    this.tagline,
    this.brandColorHex,
    this.coverImageUrl,
    this.perksAndBenefits = const [],
    this.websiteUrl,
    this.linkedinUrl,
    this.twitterUrl,
    this.githubUrl,
    this.cultureVideoUrl,
  });

  Color get brandColor {
    if (brandColorHex == null || brandColorHex!.isEmpty) {
      return const Color(0xFF1E40AF);
    }
    try {
      final hex = brandColorHex!.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF1E40AF);
    }
  }

  factory CompanyBranding.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const CompanyBranding();
    return CompanyBranding(
      tagline: map['tagline'] as String?,
      brandColorHex: map['brandColorHex'] as String?,
      coverImageUrl: map['coverImageUrl'] as String?,
      perksAndBenefits: (map['perksAndBenefits'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      websiteUrl: map['websiteUrl'] as String?,
      linkedinUrl: map['linkedinUrl'] as String?,
      twitterUrl: map['twitterUrl'] as String?,
      githubUrl: map['githubUrl'] as String?,
      cultureVideoUrl: map['cultureVideoUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tagline': tagline,
      'brandColorHex': brandColorHex,
      'coverImageUrl': coverImageUrl,
      'perksAndBenefits': perksAndBenefits,
      'websiteUrl': websiteUrl,
      'linkedinUrl': linkedinUrl,
      'twitterUrl': twitterUrl,
      'githubUrl': githubUrl,
      'cultureVideoUrl': cultureVideoUrl,
    };
  }

  CompanyBranding copyWith({
    String? tagline,
    String? brandColorHex,
    String? coverImageUrl,
    List<String>? perksAndBenefits,
    String? websiteUrl,
    String? linkedinUrl,
    String? twitterUrl,
    String? githubUrl,
    String? cultureVideoUrl,
  }) {
    return CompanyBranding(
      tagline: tagline ?? this.tagline,
      brandColorHex: brandColorHex ?? this.brandColorHex,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      perksAndBenefits: perksAndBenefits ?? this.perksAndBenefits,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      linkedinUrl: linkedinUrl ?? this.linkedinUrl,
      twitterUrl: twitterUrl ?? this.twitterUrl,
      githubUrl: githubUrl ?? this.githubUrl,
      cultureVideoUrl: cultureVideoUrl ?? this.cultureVideoUrl,
    );
  }
}

class CompanyCareerPage {
  final String companyId;
  final String companyName;
  final String? logoUrl;
  final String industry;
  final String description;
  final String location;
  final CompanyBranding branding;
  final int activeJobsCount;
  final bool isApproved;

  const CompanyCareerPage({
    required this.companyId,
    required this.companyName,
    this.logoUrl,
    required this.industry,
    required this.description,
    required this.location,
    this.branding = const CompanyBranding(),
    this.activeJobsCount = 0,
    this.isApproved = true,
  });
}
