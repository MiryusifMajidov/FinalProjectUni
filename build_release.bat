@echo off
echo ============================================
echo  CheckMate - Play Store Release Build
echo ============================================

echo [1/3] Cleaning...
call flutter clean

echo [2/3] Getting packages...
call flutter pub get

echo [3/3] Building App Bundle...
call flutter build appbundle --release ^
  --obfuscate ^
  --split-debug-info=build/debug-info

echo.
echo ============================================
echo  DONE!
echo  AAB: build\app\outputs\bundle\release\app-release.aab
echo  Debug symbols: build\debug-info\  (ZIP edib Play Console'a yukle)
echo ============================================
pause
