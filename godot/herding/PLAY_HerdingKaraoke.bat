@echo off
rem TAGANT - Herding Karaoke (Ait Wadu valley). Runs the app on the laptop (window), without the Godot editor.
set GODOT=C:\Users\azoor\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe
rem first run only: import the valley, songs and textures (about a minute)
if not exist "%~dp0.godot" "%GODOT%" --headless --path "%~dp0." --import
start "" "%GODOT%" --path "%~dp0."
