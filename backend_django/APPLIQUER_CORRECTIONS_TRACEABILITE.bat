@echo off
setlocal
cd /d "%~dp0"

echo ==============================================
echo SAMOU MBEYMI - Activation de la tracabilite
echo ==============================================
echo.
if not exist "manage.py" (
    echo ERREUR : manage.py est introuvable.
    pause
    exit /b 1
)

if exist "db.sqlite3" (
    echo Sauvegarde de la base de donnees avant migration...
    python -c "import shutil,datetime; shutil.copy2('db.sqlite3','db_backup_traceabilite_'+datetime.datetime.now().strftime('%%Y%%m%%d_%%H%%M%%S')+'.sqlite3')"
    if errorlevel 1 (
        echo ERREUR : la sauvegarde a echoue. Aucune migration lancee.
        pause
        exit /b 1
    )
)

echo.
echo Etat des migrations avant application :
python manage.py showmigrations pertes
if errorlevel 1 (
    echo ERREUR : impossible de lire les migrations.
    pause
    exit /b 1
)

echo.
echo Application des migrations en attente (dont la protection de l'historique)...
python manage.py migrate
if errorlevel 1 (
    echo ERREUR : migration non terminee. Conservez la sauvegarde.
    pause
    exit /b 1
)

echo.
echo Verification du projet...
python manage.py check
if errorlevel 1 (
    echo ATTENTION : Django signale des problemes. Consultez le message ci-dessus.
    pause
    exit /b 1
)

echo.
echo SUCCES : migrations appliquees et verification terminee.
echo Lancez ensuite : python manage.py runserver
pause
