import 'package:permission_handler/permission_handler.dart';

abstract class PermisionState {}

class PermisionInitial extends PermisionState {}

class PermisionLoading extends PermisionState {}

class PermisionSucess extends PermisionState {}

class PermisionError extends PermisionState {
  final String message;

  PermisionError(this.message);
}

class PermisionHasInternet extends PermisionState {}

class PermisionNoInternet extends PermisionState {
  final String message;

  PermisionNoInternet({this.message = "No Internet Connection"});
}

class InternetConnectionLost extends PermisionState {
  final String message;

  InternetConnectionLost({this.message = "Internet Connection Lost"});
}
