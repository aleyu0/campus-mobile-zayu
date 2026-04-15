import 'dart:convert';
import 'package:arcgis_maps/arcgis_maps.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'esrimap_models.dart';

// -----------------------------------------------------------------------------
// Route result data object
// -----------------------------------------------------------------------------

/// Encapsulates the data returned from a successful route solve, so the widget
/// layer can handle graphics overlay and viewpoint updates.
class RouteResultData {
  final Geometry routeGeometry;
  final double totalTimeMinutes;
  final List<DirectionManeuver> maneuvers;

  const RouteResultData({
    required this.routeGeometry,
    required this.totalTimeMinutes,
    required this.maneuvers,
  });
}

// -----------------------------------------------------------------------------
// Service
// -----------------------------------------------------------------------------

class EsriMapService {
  // Service endpoints
  static const buildingsQueryUrl =
      'https://admin-enterprise-gis.ucsd.edu/server/rest/services/'
      'AdministrationServices/Buildings_Public/MapServer/0/query';
  static const poiQueryUrl =
      'https://services9.arcgis.com/mXNwDpiENQiMIzRv/arcgis/rest/services/'
      'Points_Of_Interest/FeatureServer/0/query';
  static const routeServiceUrl =
      'https://admin-enterprise-gis.ucsd.edu/server/rest/services/'
      'Wayfinding/Campus_Wayfinding_Network/NAServer/Route';

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _escSql(String input) => input.replaceAll("'", "''");

  // ---------------------------------------------------------------------------
  // Building queries
  // ---------------------------------------------------------------------------

  /// Query the Buildings (AGE) MapServer by text search.
  static Future<List<MapSearchResult>> queryBuildings(String query) async {
    await dotenv.load(fileName: ".env");
    final token = dotenv.env['ARCGIS_AGE_API_KEY'] ?? '';
    final escaped = _escSql(query);
    final where = "UPPER(FacilityLongName) LIKE UPPER('%$escaped%') "
        "OR UPPER(BuildingAliases) LIKE UPPER('%$escaped%')";

    final uri = Uri.parse(buildingsQueryUrl).replace(
      queryParameters: {
        'where': where,
        'outFields':
            'FacilityLongName,BuildingAliases,StreetAddress,City,Zipcode,Latitude,Longitude',
        'returnGeometry': 'false',
        'resultRecordCount': '8',
        'f': 'json',
        if (token.isNotEmpty) 'token': token,
      },
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) return [];

    final json = jsonDecode(response.body);
    final features = json['features'] as List<dynamic>? ?? [];

    return features.map<MapSearchResult>((f) {
      final attrs = f['attributes'] as Map<String, dynamic>;
      final name =
          (attrs['FacilityLongName'] as String?) ?? 'Unknown Building';
      final alias = (attrs['BuildingAliases'] as String?) ?? '';
      final street = (attrs['StreetAddress'] as String?) ?? '';
      final city = (attrs['City'] as String?) ?? '';
      final zip = (attrs['Zipcode'] as String?) ?? '';
      final lat = (attrs['Latitude'] as num?)?.toDouble() ?? 0.0;
      final lng = (attrs['Longitude'] as num?)?.toDouble() ?? 0.0;

      final addressParts = <String>[
        if (street.isNotEmpty) street,
        if (city.isNotEmpty) city,
        if (zip.isNotEmpty) zip,
      ];
      final fullAddress = addressParts.join(', ');
      final subtitle = alias.isNotEmpty ? alias : 'Building';

      return MapSearchResult(
        name: name,
        subtitle: subtitle,
        latitude: lat,
        longitude: lng,
        source: MapSearchSource.building,
        address: fullAddress,
      );
    }).where((r) => r.latitude != 0.0 && r.longitude != 0.0).toList();
  }

  // ---------------------------------------------------------------------------
  // POI queries
  // ---------------------------------------------------------------------------

  /// Fetches all distinct POI Class values from the FeatureServer.
  static Future<List<String>> fetchAllPoiClasses() async {
    try {
      final uri = Uri.parse(poiQueryUrl).replace(queryParameters: {
        'where': '1=1',
        'outFields': 'Class',
        'returnDistinctValues': 'true',
        'orderByFields': 'Class',
        'returnGeometry': 'false',
        'resultRecordCount': '200',
        'f': 'json',
      });
      final response = await http.get(uri);
      if (response.statusCode != 200) return [];
      final json = jsonDecode(response.body);
      final features = json['features'] as List<dynamic>? ?? [];
      final classes = features
          .map((f) => (f['attributes']['Class'] as String?) ?? '')
          .where((c) => c.isNotEmpty)
          .toList()
        ..sort();
      return classes;
    } catch (e) {
      debugPrint('Failed to fetch POI classes: $e');
      return [];
    }
  }

  /// Query the POIs (AGO) FeatureServer by text search.
  static Future<List<MapSearchResult>> queryPOIs(String query) async {
    final escaped = _escSql(query);
    final where = "UpdatedName LIKE '%$escaped%' "
        "OR C3DName LIKE '%$escaped%' "
        "OR C3DKeywords LIKE '%$escaped%'";
    return executePOIQuery(where);
  }

  /// Query POIs filtered by a specific Class value (for category taps).
  static Future<List<MapSearchResult>> queryPOIsByClass(
      String classValue) async {
    final escaped = _escSql(classValue);
    final where = "Class = '$escaped'";
    return executePOIQuery(where, maxResults: 100);
  }

  /// Shared POI query execution.
  static Future<List<MapSearchResult>> executePOIQuery(
    String where, {
    int maxResults = 8,
  }) async {
    final uri = Uri.parse(poiQueryUrl).replace(
      queryParameters: {
        'where': where,
        'outFields':
            'UpdatedName,C3DName,Class,Subclass,C3DDescription,URL,Latitude,Longitude',
        'returnGeometry': 'false',
        'resultRecordCount': '$maxResults',
        'f': 'json',
      },
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) return [];

    final json = jsonDecode(response.body);
    final features = json['features'] as List<dynamic>? ?? [];

    return features.map<MapSearchResult>((f) {
      final attrs = f['attributes'] as Map<String, dynamic>;
      final updatedName = (attrs['UpdatedName'] as String?) ?? '';
      final c3dName = (attrs['C3DName'] as String?) ?? '';
      final name = updatedName.isNotEmpty ? updatedName : c3dName;
      final poiClass = (attrs['Class'] as String?) ?? '';
      final subclass = (attrs['Subclass'] as String?) ?? '';
      final description = (attrs['C3DDescription'] as String?) ?? '';
      final url = (attrs['URL'] as String?) ?? '';
      final lat = (attrs['Latitude'] as num?)?.toDouble() ?? 0.0;
      final lng = (attrs['Longitude'] as num?)?.toDouble() ?? 0.0;

      final subtitle =
          subclass.isNotEmpty ? '$poiClass - $subclass' : poiClass;

      return MapSearchResult(
        name: name.isNotEmpty ? name : 'Unknown POI',
        subtitle: subtitle,
        latitude: lat,
        longitude: lng,
        source: MapSearchSource.poi,
        description: description,
        websiteUrl: url.isNotEmpty ? url : null,
      );
    }).where((r) => r.latitude != 0.0 && r.longitude != 0.0).toList();
  }

  // ---------------------------------------------------------------------------
  // Routing
  // ---------------------------------------------------------------------------

  /// Solves a route between [originLatLng] and [destination] using the Campus
  /// Wayfinding NAServer. Returns a [RouteResultData] on success, or `null`
  /// if no route could be found.
  static Future<RouteResultData?> solveRoute({
    required (double lat, double lng) originLatLng,
    required MapSearchResult destination,
    String travelMode = 'Walking',
  }) async {
    await dotenv.load(fileName: ".env");
    final token = dotenv.env['ARCGIS_AGE_API_KEY'] ?? '';

    final routeTask = RouteTask.withUri(Uri.parse(routeServiceUrl));
    routeTask.apiKey = token;
    await routeTask.load();

    final params = await routeTask.createDefaultParameters();
    params.returnDirections = true;
    final taskInfo = routeTask.getRouteTaskInfo();
    final matchingMode = taskInfo.travelModes
        .where((m) => m.name == travelMode)
        .firstOrNull;
    if (matchingMode != null) {
      params.travelMode = matchingMode;
    }

    final origin = Stop(ArcGISPoint(
      x: originLatLng.$2,
      y: originLatLng.$1,
      spatialReference: SpatialReference.wgs84,
    ));
    final dest = Stop(ArcGISPoint(
      x: destination.longitude,
      y: destination.latitude,
      spatialReference: SpatialReference.wgs84,
    ));
    params.setStops([origin, dest]);

    final result = await routeTask.solveRoute(params);
    if (result.routes.isEmpty) return null;

    final route = result.routes.first;
    final routeGeometry = route.routeGeometry;
    if (routeGeometry == null) return null;

    return RouteResultData(
      routeGeometry: routeGeometry,
      totalTimeMinutes: route.totalTime,
      maneuvers: route.directionManeuvers,
    );
  }
}