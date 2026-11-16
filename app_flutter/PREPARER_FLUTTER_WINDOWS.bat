@echo off
setlocal
cd /d "%~dp0"
where flutter >nul 2>nul
if errorlevel 1 (
  echo ERREUR : Flutter n'est pas trouve dans PATH.
  echo Installez Flutter puis verifiez la commande : flutter doctor
  pause
  exit /b 1
)
if not exist "pubspec.yaml" (
  echo ERREUR : pubspec.yaml introuvable. Lancez ce fichier depuis le dossier app_flutter.
  pause
  exit /b 1
)
if not exist "android\app\src\main\AndroidManifest.xml" (
  echo Creation des plateformes Flutter Android, Web et Windows...
  flutter create --platforms=android,web,windows .
  if errorlevel 1 goto erreur
)
echo Configuration des autorisations vocales Android...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CONFIGURER_ANDROID_VOCAL.ps1"
if errorlevel 1 goto erreur
echo Installation des dependances Flutter...
flutter pub get
if errorlevel 1 goto erreur
echo Analyse statique Flutter...
flutter analyze
if errorlevel 1 goto erreur
echo Preparation terminee. Lancez ensuite : flutter run
echo Le backend Django doit deja fonctionner sur http://127.0.0.1:8000.
pause
exit /b 0
:erreur
echo Une etape Flutter a echoue. Lisez le message ci-dessus.
pause
exit /b 1
