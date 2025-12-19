import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

part 'them_state.dart';

class MapCubit extends Cubit<MapState> {
  MapCubit() : super(MapInitial());
  AppTheme isDark = AppTheme.Light;
  bool isDarkmode = false;

  void changeAppTheme() {
    if (isDark == AppTheme.Light) {
      isDark = AppTheme.Dark;
      emit(ThemDarkState());
    } else {
      isDark = AppTheme.Light;
      emit(ThemLightState());
    }
  }

  void changeMapTheme() async {
    if (isDark == AppTheme.Light) {
      isDark = AppTheme.Dark;
      emit(ThemDarkState());
    } else {
      isDark = AppTheme.Light;
      emit(ThemLightState());
    }
  }
}

enum AppTheme { Light, Dark }
