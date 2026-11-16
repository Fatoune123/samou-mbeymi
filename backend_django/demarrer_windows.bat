@echo off
setlocal
cd /d "%~dp0"
if not exist ".venv\Scripts\python.exe" (
  echo Creation de l'environnement Python...
  py -3 -m venv .venv
  if errorlevel 1 goto erreur
)
call ".venv\Scripts\activate.bat"
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
if not exist ".env" (
  copy ".env.example" ".env" >nul
  echo Fichier .env cree depuis .env.example. Verifiez sa configuration.
)
python manage.py check
if errorlevel 1 goto erreur
python manage.py migrate
if errorlevel 1 goto erreur
python manage.py runserver
exit /b 0
:erreur
echo Une etape a echoue. Lisez le message ci-dessus puis consultez README_CORRIGE.md.
pause
exit /b 1
