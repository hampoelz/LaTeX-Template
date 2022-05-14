@echo off
git clean -Xdf

for /f "usebackq delims=" %%d in (`"dir /ad /s /b | sort /r"`) do (
    echo %%d | findstr /l ".git" >nul
    if errorlevel 1 rd "%%d"
)

exit 0