@echo off
chcp 65001 >nul
title 2. Quet - Cai Dat - Backup Driver Tu Dong (Driver Manager Pro)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0DriverManager.ps1"
