::
:: Copyright (c) 2022 Rene Hampölz
::
:: Use of this source code is governed by an MIT-style
:: license that can be found in the LICENSE file under
:: https://github.com/hampoelz/LaTeX-Template.
::

@echo off

set "gh_repo=hampoelz/LaTeX-Template"
set "remote_branch=main"

set "cwd_setup=%temp%\LatexSetup"
set "cwd_template=%cd%\LatexTemplate"

set "cwd_vscode=%LocalAppData%\Programs\Microsoft VS Code\bin"
set "texdir=%LocalAppData%\Programs\TeXLive"
set "cwd_git=%LocalAppData%\Programs\Git"

set "refresh_env_url=https://raw.githubusercontent.com/hampoelz/LaTeX-Template/main/scripts/refreshenv.bat"

set "setup_vscode_url=https://aka.ms/win32-x64-user-stable"
set "setup_vscode=vscode-user.exe"

set "setup_texlive_url=https://mirror.ctan.org/systems/texlive/tlnet/install-tl.zip"
set "setup_texlive=texlive.zip"

set "setup_git_url=https://github.com/git-for-windows/git/releases/download/v2.37.3.windows.1/PortableGit-2.37.3-64-bit.7z.exe"
set "setup_git=portablegit.exe"

set "setup_template_url=https://raw.githubusercontent.com/%gh_repo%/%remote_branch%/scripts/update.bat"
set "setup_template=template.bat"

echo.
echo ========================================================
echo     This script installs and configures all required
echo       software to use the latex template repository
echo.
echo     The following software will be installed:
echo       vs-code, texlive, git
echo.
echo     The following vs-code addons will be installed:
echo       latex-workshop, latex-utilities,
echo       code-spell-checker, gitlens
echo.
echo.
echo           - Copyright (c) 2022 Rene Hampoelz -         
echo    --------------------------------------------------   
echo      By using this script you accept this project's
echo      MIT license found in the LICENSE file under
echo      https://github.com/hampoelz/LaTeX-Template
echo      and the licenses of the software that will
echo      be installed by this script.
echo    --------------------------------------------------   
echo ========================================================
echo.

choice /c YN /m "Continue with the script?"
echo.
if %errorlevel% equ 2 exit

:: name the repository folder as well as the script file name if it has changed
if not "%~n0" == "install" set "cwd_template=%cd%\%~n0"

if not exist "%cwd_setup%" mkdir "%cwd_setup%"

call:check_space
call:check_miktex

if not "%1" == "/installonly" if not exist "%cwd_vscode%\code" call:install_vscode
call:configure_vscode

call latexmk --help >nul 2>&1 || call:install_texlive

set "git_path=%cwd_git%\bin;%cwd_git%\usr\bin;%cwd_git%\mingw64\bin"
call git --help >nul 2>&1 && (
    for /f "usebackq tokens=3 delims= " %%i in (`"git --version"`) do if "%%i" LSS "2.22.0" (
        call:install_git
    )
) || call:install_git

call git config user.name >nul && git config user.email >nul || call:configure_git

:: Brodcast WM_SETTINGCHANGE to propagate the change to the environment variable list
::   Credits to https://github.com/ObjectivityLtd/PSCI/blob/master/PSCI/Public/utils/Update-EnvironmentVariables.ps1
powershell -command "&{Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition '[DllImport(\"user32.dll\", SetLastError = true, CharSet = CharSet.Auto)] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);' ; [win32.nativemethods]::SendMessageTimeout([intptr]0xffff, 0x1a, [uintptr]::Zero, \"Environment\", 2, 5000, [ref][uintptr]::zero)}" >nul

if not "%1" == "/installonly" (
    call:setup_template
    start /min cmd /c call code "%cwd_template%"
    cd "%cwd_template%"
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


:check_space
    for /f "usebackq delims== tokens=2" %%x in (`wmic logicaldisk where "DeviceID='%cwd_setup:~0,2%:'" get FreeSpace /format:value`) do set /a "space_temp=%%x/1024/1024"
    for /f "usebackq delims== tokens=2" %%x in (`wmic logicaldisk where "DeviceID='%LocalAppData:~0,2%:'" get FreeSpace /format:value`) do set /a "space_data=%%x/1024/1024"

    if "%space_temp%" GEQ "205" if "%space_data%" GEQ "5120" (
        cls
        echo.
        echo ========================================================
        echo                    Not enough space!
        echo ========================================================
        echo.
        echo You need at least 5 gigabytes of free space to
        echo install the required software on your device.
        echo.
        pause
        exit
    )
    goto:EOF

:check_miktex
    call miktex --help >nul 2>&1 && (
        cls
        echo.
        echo ========================================================
        echo            Please uninstall MikTeX to proceed
        echo ========================================================
        echo.
        echo The script will open a window listing all your installed
        echo programs - look for MikTeX and uninstall it to proceed.
        echo.
        pause
        call appwiz.cpl
        echo.
        echo After MikTeX has been uninstalled press any key to continue.
        echo.
        pause
        call:refresh_env
        goto:check_miktex
    )
    goto:EOF

:install_vscode
    echo.
    echo ========================================================
    echo     Download and install Microsoft Visual Studio Code
    echo ========================================================
    echo.
    cd "%cwd_setup%"
    call curl -L "%setup_vscode_url%" -o %setup_vscode%
    call .\%setup_vscode% /VERYSILENT /CURRENTUSER /NORESTART /MERGETASKS="addtopath,!runcode" /LOG="%cwd_setup%\%setup_vscode%.log"
    call:refresh_env
    goto:EOF


:configure_vscode
    cd "%cwd_setup%"

    setlocal enabledelayedexpansion

    set "installed_exts="
    for /f "usebackq delims=" %%i in (`"code --list-extensions"`) do (
        set "installed_exts=!installed_exts! %%i"
    )

    echo %installed_exts% | findstr "James-Yu.latex-workshop" | findstr "tecosaur.latex-utilities" | findstr "eamodio.gitlens" | findstr "streetsidesoftware.code-spell-checker" >nul 2>&1 || (
        echo.
        echo ========================================================
        echo    Install required and recommended VSCode extensions
        echo ========================================================
        echo.

        call code --install-extension James-Yu.latex-workshop
        call code --install-extension tecosaur.latex-utilities
        call code --install-extension eamodio.gitlens
        call code --install-extension streetsidesoftware.code-spell-checker
    )
    endlocal
    goto:EOF

:install_texlive
    echo.
    echo ========================================================
    echo               Download TeX Live setup files
    echo ========================================================
    echo.
    cd "%cwd_setup%"
    call curl -L "%setup_texlive_url%" -o %setup_texlive%
    call tar -xvf "%cwd_setup%\%setup_texlive%"

    echo.
    echo ========================================================
    echo                     Install TeX Live
    echo ========================================================
    echo.
    cd "%cwd_setup%\install-tl-*\."
    call .\install-tl-windows.bat -texdir "%texdir%"  -no-doc-install -no-src-install -non-admin -no-interaction -no-gui
    call:refresh_env
    cd "%cwd_setup%"
    goto:EOF

:install_git
    echo.
    echo ========================================================
    echo                 Download and install Git
    echo ========================================================
    echo.
    cd "%cwd_setup%"
    call curl -L "%setup_git_url%" -o %setup_git%
    call .\%setup_git% -o"%cwd_git%" -y
    call:add_env "%git_path%"
    goto:EOF

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

    if not defined mail ( set /p mail="Email: %mail%" ) else echo Email: %mail%
    if not defined name ( set /p name="Name:  %name%" ) else echo Name:  %name%
    echo.

    if not defined mail (
        echo --------------------------------------------
        echo  Please enter your e-mail address.
        echo.
        echo  This is important because every Git commit
        echo  uses this information, and it's immutably
        echo  baked into the commits you start creating.
        echo --------------------------------------------
        echo.
        pause
        goto:configure_git
    )
    if not defined name (
        echo --------------------------------------------
        echo  Please enter your name.
        echo.
        echo  This is important because every Git commit
        echo  uses this information, and it's immutably
        echo  baked into the commits you start creating.
        echo --------------------------------------------
        echo.
        pause
        goto:configure_git
    )

    echo.
    choice /c YN /m "Are the details you entered correct?"
    echo.
    if %errorlevel% equ 2 (
        set mail=
        set name=
        goto:configure_git
    )

    call git config --global user.email "%mail%"
    call git config --global user.name "%name%"
    goto:EOF

:setup_template
    echo.
    echo ========================================================
    echo     Download update script from template repository
    echo ========================================================
    echo.
    cd "%cwd_setup%"
    call curl -L %setup_template_url% -o %setup_template%

    echo.
    echo ========================================================
    echo           Initialize and update new repository
    echo ========================================================
    echo.
    if exist "%cwd_template%" (
        echo The specified directory already exists!
        exit
    )
    mkdir "%cwd_template%"
    cd "%cwd_template%"
    call git init
    call cmd /k "%cwd_setup%\%setup_template%"
    call latexmk -g --interaction=nonstopmode
    cd "%cwd_setup%"
    goto:EOF

:add_env
    set user_path=
    for /f "usebackq skip=2 tokens=1-2*" %%a in (`"%WinDir%\System32\Reg query HKCU\Environment /v Path 2>&1"`) do set user_path=%%c
    call "%WinDir%\System32\Reg" add "HKCU\Environment" /f /v Path /d "%~1;%user_path%"
    set "path=%~1;%path%"
    goto:EOF

:refresh_env
    echo.
    echo ------------------------------
    cd "%cwd_setup%"
    if not exist refreshenv.bat call curl -sL "%refresh_env_url%" -o refreshenv.bat
    call .\refreshenv.bat
    echo ------------------------------
    echo.
    goto:EOF