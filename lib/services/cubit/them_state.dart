part of 'them_cubit.dart';

@immutable
sealed class MapState {}

final class MapInitial extends MapState {}

final class ThemDarkState extends MapState {}

final class ThemLightState extends MapState {}
