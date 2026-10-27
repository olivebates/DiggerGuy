@echo off
cd /d "%~dp0"
if not exist "%~dp0.godot\global_script_class_cache.cfg" start /wait "Import Digger Guy" "%~dp0Godot_v4.7.2-stable_win64.exe" --headless --path "%~dp0." --editor --import --quit
start "Digger Guy" "%~dp0Godot_v4.7.2-stable_win64.exe" --path "%~dp0."
