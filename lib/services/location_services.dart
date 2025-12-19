import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationService {
  /// الحصول على الموقع الحالي للجهاز
  /// يرجع Position أو null في حالة الفشل
  static Future<Position?> getCurrentLocation() async {
    try {
      // التحقق من تفعيل خدمة الموقع
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('⚠️ خدمة الموقع غير مفعلة');
        // يمكنك فتح إعدادات الموقع
        await Geolocator.openLocationSettings();
        return null;
      }

      // التحقق من الصلاحيات
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('⚠️ تم رفض صلاحيات الموقع');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('⚠️ صلاحيات الموقع مرفوضة بشكل دائم');
        await Geolocator.openAppSettings();
        return null;
      }

      // الحصول على الموقع الحالي
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      print(
        '✅ تم الحصول على الموقع: ${position.latitude}, ${position.longitude}',
      );
      return position;
    } catch (e) {
      print('❌ خطأ في الحصول على الموقع: $e');
      return null;
    }
  }

  /// تحويل Position إلى LatLng للاستخدام مع Google Maps
  static LatLng positionToLatLng(Position position) {
    return LatLng(position.latitude, position.longitude);
  }

  /// الحصول على الموقع الحالي مباشرة كـ LatLng
  static Future<LatLng?> getCurrentLatLng() async {
    Position? position = await getCurrentLocation();
    if (position != null) {
      return positionToLatLng(position);
    }
    return null;
  }

  /// تتبع الموقع بشكل مستمر (Stream)
  static Stream<Position> trackLocation() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3, // التحديث كل 10 متر
      ),
    );
  }

  /// حساب المسافة بين نقطتين بالمتر
  static double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// التحقق من صلاحيات الموقع بدون طلبها
  static Future<bool> hasLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}
