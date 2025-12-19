import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location_test/services/cubit/them_cubit.dart';
import 'package:location_test/services/location_services.dart';
import 'package:location_test/services/permision_cubit/permision_cubit.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => PermisionCubit()),
        BlocProvider(create: (context) => MapCubit()),
      ],
      child: MaterialApp(debugShowCheckedModeBanner: false, home: MapScreen()),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  bool _isLoading = false;
  Set<Marker> _markers = {};
  bool _isDarkMode = false;
  String? _darkMapStyle;
  LatLng? _selectedLocation;
  bool _showLocationInfo = false;
  Placemark? _selectedPlacemark;
  bool _isLoadingPlaceInfo = false;
  Set<Polyline> _polylines = {};
  bool _isLoadingDirections = false;
  String? _routeDistance;
  String? _routeDuration;
  static const String _googleApiKey = 'AIzaSyAFgOhX0kNXrT68UVtRXYS7N7jgoKbQkHw';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    Future<void> loadMapStyle() async {
      _darkMapStyle = await rootBundle.loadString('assets/map_light.json');
    }
  }

  // دالة لعرض الاتجاهات على الخريطة
  Future<void> _drawDirections() async {
    if (_currentLocation == null || _selectedLocation == null) {
      _showErrorSnackBar('لا يمكن رسم المسار');
      return;
    }

    setState(() {
      _isLoadingDirections = true;
      _routeDistance = null;
      _routeDuration = null;
    });

    try {
      // استدعاء Google Directions API
      final String url =
          'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${_currentLocation!.latitude},${_currentLocation!.longitude}'
          '&destination=${_selectedLocation!.latitude},${_selectedLocation!.longitude}'
          '&mode=driving'
          '&key=$_googleApiKey';
      // '&language=ar'; // للحصول على النتائج بالعربية

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] != 'OK') {
          print(
            'Directions API Error: ${data['status']} - ${data['error_message'] ?? ''}',
          );
        }

        if (data['status'] == 'OK') {
          final route = data['routes'][0];
          final polylinePoints = PolylinePoints(
            apiKey: 'AIzaSyAFgOhX0kNXrT68UVtRXYS7N7jgoKbQkHw',
          );

          // فك تشفير الـ polyline
          String encodedPolyline = route['overview_polyline']['points'];
          List<PointLatLng> decodedPoints = PolylinePoints.decodePolyline(
            encodedPolyline,
          );

          // تحويل النقاط إلى LatLng
          List<LatLng> polylineCoordinates = decodedPoints
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

          // الحصول على المسافة والوقت
          final leg = route['legs'][0];
          _routeDistance = leg['distance']['text'];
          _routeDuration = leg['duration']['text'];

          setState(() {
            _polylines.clear();
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('route'),
                color: Colors.blue,
                width: 5,
                points: polylineCoordinates,
                geodesic: true,
              ),
            );
            _isLoadingDirections = false;
          });

          // تحريك الكاميرا لعرض المسار بالكامل
          LatLngBounds bounds = _createBounds(polylineCoordinates);
          _mapController?.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 100),
          );

          _showErrorSnackBar('تم رسم المسار بنجاح ✓');
        } else {
          throw Exception('API Error: ${data['status']}');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('خطأ في رسم المسار: $e');
      setState(() {
        _isLoadingDirections = false;
      });

      // في حالة فشل API، ارسم خط مستقيم
      _drawStraightLine();
    }
  }

  // دالة لرسم خط مستقيم بين الموقع الحالي والموقع المحدد
  void _drawStraightLine() {
    if (_currentLocation == null || _selectedLocation == null) return;

    List<LatLng> polylineCoordinates = [_currentLocation!, _selectedLocation!];

    double distance = LocationService.calculateDistance(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      _selectedLocation!.latitude,
      _selectedLocation!.longitude,
    );

    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          color: Colors.blue,
          width: 5,
          points: polylineCoordinates,
          patterns: [PatternItem.dash(30), PatternItem.gap(20)],
        ),
      );
      _routeDistance = '${(distance / 1000).toStringAsFixed(2)} كم (خط مباشر)';
      _routeDuration = null;
    });

    LatLngBounds bounds = _createBounds(polylineCoordinates);
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  // إنشاء حدود للكاميرا
  LatLngBounds _createBounds(List<LatLng> positions) {
    final southwestLat = positions
        .map((p) => p.latitude)
        .reduce((a, b) => a < b ? a : b);
    final southwestLon = positions
        .map((p) => p.longitude)
        .reduce((a, b) => a < b ? a : b);
    final northeastLat = positions
        .map((p) => p.latitude)
        .reduce((a, b) => a > b ? a : b);
    final northeastLon = positions
        .map((p) => p.longitude)
        .reduce((a, b) => a > b ? a : b);

    return LatLngBounds(
      southwest: LatLng(southwestLat, southwestLon),
      northeast: LatLng(northeastLat, northeastLon),
    );
  }

  // عند الضغط على الخريطة
  void _onMapTapped(LatLng location) async {
    setState(() {
      _selectedLocation = location;
      _showLocationInfo = true;
      _isLoadingPlaceInfo = true;
      _selectedPlacemark = null;
      _polylines.clear(); // مسح الخطوط السابقة
      _routeDistance = null;
      _routeDuration = null;

      // إضافة Marker للمكان المحدد
      _markers.removeWhere((m) => m.markerId.value == 'selected_location');
      _markers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: location,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    });

    // الحصول على معلومات المكان
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        setState(() {
          _selectedPlacemark = placemarks.first;
          _isLoadingPlaceInfo = false;
        });
      }
    } catch (e) {
      print('خطأ في الحصول على معلومات المكان: $e');
      setState(() {
        _isLoadingPlaceInfo = false;
      });
    }
  }

  // بناء صف المعلومات
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // تحميل ملف تنسيق الخريطة
  Future<void> loadMapStyle() async {
    if (_isDarkMode) {
      _darkMapStyle = await rootBundle.loadString('assets/map_dark.json');
      return;
    }
    _darkMapStyle = await rootBundle.loadString('assets/map_light.json');
  }

  // الحصول على الموقع الحالي
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    LatLng? location = await LocationService.getCurrentLatLng();

    if (location != null) {
      setState(() {
        _currentLocation = location;
        _markers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: location,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            ),
            infoWindow: const InfoWindow(title: 'موقعك الحالي'),
          ),
        );
      });

      // تحريك الكاميرا للموقع الحالي
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: location, zoom: 15),
        ),
      );
    } else {
      _showErrorSnackBar('فشل الحصول على الموقع');
    }

    setState(() => _isLoading = false);
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleDarkMode() {
    log('Toggle Dark Mode');
    setState(() {
      log('Toggle Dark Mode');
      _isDarkMode = !_isDarkMode;
      loadMapStyle();
    });

    if (_mapController != null) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // الخريطة
          GoogleMap(
            polylines: _polylines,
            style: _darkMapStyle,
            initialCameraPosition: CameraPosition(
              target:
                  _currentLocation ??
                  const LatLng(30.0444, 31.2357), // القاهرة افتراضياً
              zoom: 15,
            ),
            mapType: MapType.normal,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            onTap: _onMapTapped, // عند الضغط على الخريطة
            onMapCreated: (controller) {
              _mapController = controller;
            },
          ),

          // زر الموقع الحالي
          Positioned(
            bottom: 20,
            right: 16,
            child: FloatingActionButton(
              shape: _isDarkMode
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: Colors.blue, width: 1),
                    )
                  : null,
              onPressed: _isLoading ? null : _getCurrentLocation,
              backgroundColor: _isDarkMode
                  ? Color.fromARGB(209, 31, 31, 31)
                  : Colors.white,
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),
          Positioned(
            bottom: 90,
            right: 16,
            child: FloatingActionButton(
              shape: _isDarkMode
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: Colors.blue, width: 1),
                    )
                  : null,
              onPressed: _toggleDarkMode,
              backgroundColor: _isDarkMode
                  ? Color.fromARGB(209, 31, 31, 31)
                  : Colors.white,
              child: Icon(
                _isDarkMode ? Icons.light_mode : Icons.dark_mode,
                color: Colors.blue,
              ),
            ),
          ),

          // معلومات الموقع المحدد
          if (_showLocationInfo && _selectedLocation != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _selectedPlacemark?.name ?? 'معلومات الموقع',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _showLocationInfo = false;
                                // _markers.removeWhere(
                                //   (m) =>
                                //       m.markerId.value == 'selected_location',
                                // );
                              });
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // عرض معلومات المكان أو Loading
                      if (_isLoadingPlaceInfo)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else ...[
                        // اسم الشارع
                        if (_selectedPlacemark?.street != null &&
                            _selectedPlacemark!.street!.isNotEmpty)
                          _buildInfoRow(
                            Icons.location_on,
                            'الشارع',
                            _selectedPlacemark!.street!,
                          ),

                        // المنطقة
                        if (_selectedPlacemark?.subLocality != null &&
                            _selectedPlacemark!.subLocality!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.place,
                            'المنطقة',
                            _selectedPlacemark!.subLocality!,
                          ),
                        ],

                        // المدينة
                        if (_selectedPlacemark?.locality != null &&
                            _selectedPlacemark!.locality!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.location_city,
                            'المدينة',
                            _selectedPlacemark!.locality!,
                          ),
                        ],

                        // الدولة
                        if (_selectedPlacemark?.country != null &&
                            _selectedPlacemark!.country!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.flag,
                            'الدولة',
                            _selectedPlacemark!.country!,
                          ),
                        ],

                        // الرمز البريدي
                        if (_selectedPlacemark?.postalCode != null &&
                            _selectedPlacemark!.postalCode!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.mail,
                            'الرمز البريدي',
                            _selectedPlacemark!.postalCode!,
                          ),
                        ],

                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.gps_fixed,
                          'الإحداثيات',
                          '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                        ),
                      ],

                      if (_currentLocation != null) ...[
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.social_distance,
                          'المسافة من موقعك',
                          '${(LocationService.calculateDistance(_currentLocation!.latitude, _currentLocation!.longitude, _selectedLocation!.latitude, _selectedLocation!.longitude) / 1000).toStringAsFixed(2)} كم',
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // فتح في تطبيق الخرائط
                                print('فتح في الخرائط');
                                if (_selectedLocation != null) {
                                  _drawDirections();
                                } else {
                                  _showErrorSnackBar(
                                    'لم يتم تحديد موقع الوجهة',
                                  );
                                }
                              },
                              icon: const Icon(Icons.directions, size: 18),
                              label: const Text('توجيهات'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                // مشاركة الموقع
                                print('مشاركة الموقع');
                              },
                              icon: const Icon(Icons.share, size: 18),
                              label: const Text('مشاركة'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
