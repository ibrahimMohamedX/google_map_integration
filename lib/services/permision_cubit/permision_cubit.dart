import 'dart:developer';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'permision_states.dart';

class PermisionCubit extends Cubit<PermisionState> {
  PermisionCubit() : super(PermisionInitial());

  bool internetConnected = false;
  bool isRequested = false;

  Future<void> checkInternetConnection() async {
    emit(PermisionLoading());
    try {
      emit(PermisionLoading());
      final bool isConnected = await InternetConnection().hasInternetAccess;
      if (isConnected) {
        internetConnected = true;
        emit(PermisionHasInternet());
      } else {
        internetConnected = false;
        emit(PermisionNoInternet(message: "No Internet Connection"));
      }
    } catch (e) {
      emit(PermisionError(e.toString()));
    }
  }

  Future<void> requestLocationPermissionOnce() async {
    // if (isRequested) return;

    final status = await Permission.location.request();
    if (status.isGranted) {
      emit(PermisionSucess());
      isRequested = true;
    } else if (status.isPermanentlyDenied) {
      emit(PermisionError("Location permission permanently denied"));
    } else {
      emit(PermisionError("Location permission denied"));
    }
  }

  // void listenToInternetConnection() {
  //   try {
  //     InternetConnection().onStatusChange.listen((InternetStatus status) {
  //       if (status == InternetStatus.connected) {
  //         internetConnected = true;
  //       } else {
  //         internetConnected = false;
  //         emit(InternetConnectionLost(message: "Internet Connection Lost"));
  //       }
  //     });
  //   } catch (e) {
  //     emit(PermisionError(e.toString()));
  //   }
  // }

  // Future<void> checkPermission(Permission permission) async {
  //   emit(PermisionLoading());
  //   try {
  //     final status = await permission.status;
  //     emit(PermisionStatusState({permission: status}));
  //   } catch (e) {
  //     emit(PermisionError(e.toString()));
  //   }
  // }

  // Future<void> requestPermission(Permission permission) async {
  //   emit(PermisionLoading());
  //   try {
  //     final status = await permission.request();
  //     emit(PermisionStatusState({permission: status}));
  //   } catch (e) {
  //     emit(PermisionError(e.toString()));
  //   }
  // }

  // Future<void> checkAll(List<Permission> permissions) async {
  //   emit(PermisionLoading());
  //   try {
  //     final Map<Permission, PermissionStatus> result = {};
  //     for (final p in permissions) {
  //       result[p] = await p.status;
  //     }
  //     emit(PermisionStatusState(result));
  //   } catch (e) {
  //     emit(PermisionError(e.toString()));
  //   }
  // }
}
