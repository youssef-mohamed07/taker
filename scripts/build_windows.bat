@echo off
echo ====================================================
echo  Building Tager ERP for Windows Desktop (Release)
echo ====================================================

echo 1. Fetching dependencies...
call flutter pub get

echo 2. Compiling Windows Release Executable...
call flutter build windows --release

echo ====================================================
echo  Build complete!
echo  Executable files are located in:
echo  build\windows\x64\runner\Release\
echo ====================================================
pause
