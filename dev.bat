@echo off
title Focus System (dev)
rem Starts the Node.js backend (port 4000) and the website (port 3000) in two windows.

if not exist "%~dp0backend\node_modules" (
  echo Installing backend dependencies...
  pushd "%~dp0backend" && call npm install && call npx prisma migrate deploy && popd
)
if not exist "%~dp0website\node_modules" (
  echo Installing website dependencies...
  pushd "%~dp0website" && call npm install && popd
)

start "Focus System API :4000" cmd /k "cd /d %~dp0backend && npm run dev"
start "Focus System Website :3000" cmd /k "cd /d %~dp0website && npm run dev"

timeout /t 6 >nul
start http://localhost:3000
