@echo off
setlocal
cd /d "%~dp0"
call "%~dp0docker-up.bat" %*
