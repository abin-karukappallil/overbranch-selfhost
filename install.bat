@echo off
rem Compatibility shim: all logic lives in install.ps1.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
