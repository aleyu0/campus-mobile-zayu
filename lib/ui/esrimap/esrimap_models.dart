import 'package:flutter/material.dart';

// -----------------------------------------------------------------------------
// Model 
// -----------------------------------------------------------------------------

// Search results with Buildings and POIs.
class MapSearchResult {
  final String name;
  final String subtitle;
  final double latitude;
  final double longitude;
  final MapSearchSource source;
  final String address;
  final String description;
  final String? websiteUrl;

  const MapSearchResult({
    required this.name,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    required this.source,
    this.address = '',
    this.description = '',
    this.websiteUrl,
  });

  /// Serialize to JSON for SharedPreferences storage.
  Map<String, dynamic> toJson() => {
        'name': name,
        'subtitle': subtitle,
        'latitude': latitude,
        'longitude': longitude,
        'source': source.index,
        'address': address,
        'description': description,
        'websiteUrl': websiteUrl,
      };

  /// Deserialize from JSON.
  factory MapSearchResult.fromJson(Map<String, dynamic> json) {
    return MapSearchResult(
      name: json['name'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      source: MapSearchSource.values[json['source'] as int? ?? 0],
      address: json['address'] as String? ?? '',
      description: json['description'] as String? ?? '',
      websiteUrl: json['websiteUrl'] as String?,
    );
  }
}

enum MapSearchSource { building, poi }

// -----------------------------------------------------------------------------
// Category definitions
// -----------------------------------------------------------------------------

class SearchCategory {
  final String label;
  final IconData icon;
  final String poiClassValue; // maps to POI "Class" field value

  const SearchCategory({
    required this.label,
    required this.icon,
    required this.poiClassValue,
  });
}

/// default categories (highlight?) - TODO: investigate what categories are truly used the most
const searchCategories = [
  SearchCategory(
    label: 'Parking',
    icon: Icons.local_parking,
    poiClassValue: 'Parking',
  ),
  SearchCategory(
    label: 'Dining',
    icon: Icons.restaurant,
    poiClassValue: 'Dining and Beverage',
  ),
  SearchCategory(
    label: 'Recreation',
    icon: Icons.fitness_center,
    poiClassValue: 'Athletic Facilities',
  ),
  SearchCategory(
    label: 'Transit',
    icon: Icons.directions_bus,
    poiClassValue: 'Transit',
  ),
];