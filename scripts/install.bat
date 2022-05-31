::
:: Copyright (c) 2022 Rene Hampölz
::
:: Use of this source code is governed by an MIT-style
:: license that can be found in the LICENSE file under
:: https://github.com/hampoelz/LaTeX-Template.
::

@echo off

set "cwd_setup=%temp%\LatexSetup"
set "cwd_template=%cd%\LatexTemplate"

set "cwd_vscode=%LocalAppData%\Programs\Microsoft VS Code\bin"
set "cwd_perl=%LocalAppData%\Programs\Perl"
set "cwd_miktex=%LocalAppData%\Programs\MiKTeX\miktex\bin\x64"
set "cwd_git=%LocalAppData%\Programs\Git"

set "setup_vscode_url=https://aka.ms/win32-x64-user-stable"
set "setup_vscode=vscode-user.exe"

set "setup_perl_url=https://strawberryperl.com/download/5.32.1.1/strawberry-perl-5.32.1.1-64bit.zip"
set "setup_perl=strawberry-perl.zip"

set "setup_miktex_url=https://miktex.org/download/win/miktexsetup-x64.zip"
set "setup_miktex=miktexsetup.zip"

set "setup_git_url=https://github.com/git-for-windows/git/releases/download/v2.36.1.windows.1/PortableGit-2.36.1-64-bit.7z.exe"
set "setup_git=portablegit.exe"

set "setup_template_url=https://raw.githubusercontent.com/hampoelz/LaTeX-Template/main/scripts/update.bat"
set "setup_template=template.bat"

echo.
echo ========================================================
echo     This script installs and configures all required
echo       software to use the latex template repository
echo.
echo     The following software will be installed:
echo       vs-code, strawberry-perl, miktex, git
echo ========================================================
echo.

choice /c YN /m "Continue with the script?"
echo.
if %errorlevel% equ 2 exit

:: name the repository folder as well as the script file name if it has changed
if not "%~n0" == "install" set "cwd_template=%cd%\%~n0"

if not exist "%cwd_setup%" mkdir "%cwd_setup%"

if not exist "%cwd_vscode%\code" call:install_vscode
call:configure_vscode

call perl --help >nul 2>&1 || call:install_perl

call miktex --help >nul 2>&1 || call:install_miktex
call latexmk --help >nul 2>&1 || call:configure_miktex

call git --help >nul 2>&1 || call:install_git
call git config user.name >nul && git config user.email >nul || call:configure_git

if not "%1" == "/installonly" (
    call:setup_template
    start /min cmd /c call "%cwd_vscode%\code" "%cwd_template%"
)

echo.
echo ========================================================
echo       The required software has been successfully
echo                 installed and configured
echo ========================================================
echo.

if not "%~n0" == "install" (
    (goto) 2>nul & del "%~f0"
)

exit


:install_vscode
echo.
echo ========================================================
echo     Download and install Microsoft Visual Studio Code
echo ========================================================
echo.
cd "%cwd_setup%"
call curl -L "%setup_vscode_url%" -o %setup_vscode%
call .\%setup_vscode% /VERYSILENT /CURRENTUSER /NORESTART /MERGETASKS=addtopath,!runcode /LOG="%cwd_setup%\%setup_vscode%.log"
exit /b


:configure_vscode
cd "%cwd_vscode%"

setlocal enabledelayedexpansion

set "installed_exts="
for /f "usebackq delims=" %%i in (`".\code --list-extensions"`) do (
    set "installed_exts=!installed_exts! %%i"
)

echo %installed_exts% | findstr "James-Yu.latex-workshop" | findstr "tecosaur.latex-utilities" | findstr "streetsidesoftware.code-spell-checker" | findstr "streetsidesoftware.code-spell-checker-german" >nul 2>&1 || (
    echo.
    echo ========================================================
    echo    Install required and recommended VSCode extensions
    echo ========================================================
    echo.

    call .\code --install-extension James-Yu.latex-workshop
    call .\code --install-extension tecosaur.latex-utilities
    call .\code --install-extension streetsidesoftware.code-spell-checker
    call .\code --install-extension streetsidesoftware.code-spell-checker-german
)
endlocal
cd "%cwd_setup%"
exit /b


:install_perl
echo.
echo ========================================================
echo      Download Strawberry Perl binaries and scripts
echo ========================================================
echo.
cd "%cwd_setup%"
call curl -L "%setup_perl_url%" -o %setup_perl%

echo.
echo ========================================================
echo       Unpack Strawberry Perl binaries and scripts
echo ========================================================
echo.
mkdir "%cwd_perl%"
cd "%cwd_perl%"
call tar -xvf "%cwd_setup%\%setup_perl%"
cd "%cwd_setup%"

echo.
echo ========================================================
echo         Run Strawberry Perl post-install scripts
echo ========================================================
echo.
cd "%cwd_perl%"
call .\relocation.pl.bat
call .\update_env.pl.bat --nosystem
cd "%cwd_setup%"
exit /b


:install_miktex
echo.
echo ========================================================
echo               Download MiKTeX setup files
echo ========================================================
echo.
cd "%cwd_setup%"
call curl -L "%setup_miktex_url%" -o %setup_miktex%
call tar -xvf "%cwd_setup%\%setup_miktex%"

echo.
echo ========================================================
echo          Download MiKTeX essential package-set
echo ========================================================
echo.
cd "%cwd_setup%"
call .\miktexsetup_standalone.exe --verbose --shared=no --package-set=essential download

echo.
echo ========================================================
echo           Install MiKTeX essential package-set
echo ========================================================
echo.
cd "%cwd_setup%"
call .\miktexsetup_standalone.exe --verbose --shared=no --package-set=essential install
set "path=%path%;%cwd_miktex%\"
setx path "%path%"
exit /b


:configure_miktex
echo.
echo ========================================================
echo      Configure MiKTeX and install required packages
echo ========================================================
echo.
cd "%cwd_miktex%"
call .\initexmf.exe --set-config-value=[MPM]AutoInstall=yes
call .\miktex.exe packages check-update
call .\miktex.exe packages update
call .\miktex.exe packages install latexmk
cd "%cwd_setup%"
exit /b


:install_git
echo.
echo ========================================================
echo                 Download and install Git
echo ========================================================
echo.
cd "%cwd_setup%"
call curl -L "%setup_git_url%" -o %setup_git%
call .\%setup_git% -o"%cwd_git%" -y
set "path=%path%;%cwd_git%\bin;%cwd_git%\usr\bin;%cwd_git%\mingw64\bin"
setx path "%path%"
exit /b

:configure_git
cls
echo.
echo ========================================================
echo            Configure Git - email and username
echo ========================================================
echo.

echo.
echo Please enter your details below
echo.

set /p mail="Email: "
set /p name="Name:  "

echo.
choice /c YN /m "Are the details you entered correct?"
if %errorlevel% equ 2 goto:configure_git

call git config --global user.email "%mail%"
call git config --global user.name "%name%"
exit /b

:setup_template
echo.
echo ========================================================
echo     Download update script from template repository
echo ========================================================
echo.
cd "%cwd_setup%"
curl -L %setup_template_url% -o %setup_template%

echo.
echo ========================================================
echo           Initialize and update new repository
echo ========================================================
echo.
mkdir "%cwd_template%"
cd "%cwd_template%"
call git init
call cmd /k "%cwd_setup%\%setup_template%"
cd "%cwd_setup%"
exit /b