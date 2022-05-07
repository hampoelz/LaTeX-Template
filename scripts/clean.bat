@echo off
git clean -Xdf

for /F "usebackq delims=" %%d in (`"dir /ad/b/s | sort /R"`) do (
    echo %%d|FINDSTR /L ".git" >nul
    IF errorlevel 1 (
        rd "%%d"
    )
)

exit 0