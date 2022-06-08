::
:: Copyright (c) 2022 Rene Hampölz
::
:: Use of this source code is governed by an MIT-style
:: license that can be found in the LICENSE file under
:: https://github.com/hampoelz/LaTeX-Template.
::

@echo off

:: minimum required git version: v2.22.0

set "remote=https://github.com/hampoelz/LaTeX-Template"
set "remote_branch=main"

set "update_branch=tmp/template"

set "commit_msg=chore: :twisted_rightwards_arrows: Merge changes from template"
set "commit_descr=Merged from %remote%/tree/%remote_branch%"

:: file storing the commit SHAs picked from template
set "tplver_file=.git\tplver"

:: file storing the current (not update) branch
set "currbr_file=.git\currbr"

:: commits ignored by cherry-pick (seperate with space)
set "ignore_SHAs=1371a4d"


set "refresh_env_path=scripts\refreshenv.bat"
set "refresh_env_url=https://raw.githubusercontent.com/hampoelz/LaTeX-Template/main/scripts/refreshenv.bat"

if exist "%currbr_file%" set /p branch=< "%currbr_file%"

call:refresh_env
call:check_git
call:check_git_version
call:init_empty

if [%1] == [] goto:start else (
    if [%1] == [/?]     call:show_usage
    if [%1] == [/help]  call:show_usage
    if [%1] == [/abort] call:abort
    goto:start
)

exit

:show_usage
    echo.|set /p ="usage: update.bat (/abort)"
    echo.
    echo.
    echo This script updates the current repository
    echo to the state of the template repository at:
    echo %remote%
    echo Changes are cherry-picked and merged
    exit

:refresh_env
    if not exist "%refresh_env_path%" (
        call curl -sL "%refresh_env_url%" -o refreshenv.bat
        call .\refreshenv.bat
        del .\refreshenv.bat
    ) else call "%refresh_env_path%"
    goto:EOF

:check_git
    call git rev-parse --is-inside-work-tree >nul 2>&1 || (
        echo.
        echo ========================================================
        echo      This script can only be used inside a git repo
        echo ========================================================
        echo.
        exit
    )
    goto:EOF

:check_git_version:
    set git_version=
    for /f "usebackq tokens=3 delims= " %%i in (`"git --version"`) do set "git_version=%%i"
    if "%git_version%" GEQ "2.22.0" goto:EOF
    echo.
    echo ========================================================
    echo           Please update your Git installation,
    echo           at least version 2.22.0 is required!
    echo.
    echo           Your installed version:
    echo              %git_version%
    echo ========================================================
    echo.
    choice /c YN /m "Would you like to continue anyway? The script could fail and cause issues."
    echo.
    if not %errorlevel% equ 1 exit
    goto:EOF

:check_unmerged
    call git update-index --refresh
    call git diff --quiet --exit-code --name-only --diff-filter=U || (
        echo.
        echo ========================================================
        echo    Please resolve conflicts and run the task again  
        echo     or select the abort option when starting the task
        echo ========================================================
        echo.
        exit
    )
    goto:EOF

:check_untracked
    call git update-index --refresh
    call git diff-index --quiet HEAD -- || (
        echo.
        echo ========================================================
        echo        There are untracked changes, please commit
        echo         your changes and run the task again
        echo ========================================================
        echo.
        exit
    )
    goto:EOF

:check_merge
    call git merge HEAD >nul 2>&1 || (
        echo.
        echo ========================================================
        echo    Sorry, another git workflow is already in progress
        echo ========================================================
        echo.
        exit
    )
    goto:EOF

:: check if update-branch exists and go ahead else goto parameter
:check_branch
    call git rev-parse --verify %update_branch% >nul 2>&1 || goto %~1
    goto:EOF

:init_empty
    call git rev-parse --verify HEAD >nul 2>&1 || call git commit --allow-empty -m "Initial commit"
    goto:EOF

:abort
    call:check_branch :eof
    echo --- abort cherry-pick ----
    call git cherry-pick --abort
    call:cleanup
    exit

:start
    :: if update branch not exists, start update else continue cherry-pick and merge
    call:check_branch :start_update

    :: skip empty picks and continue with cherry-pick 
    set "pick_sequencer=continue"
    call git diff --cached --quiet --exit-code && set pick_sequencer=skip
    call git -c core.editor=true cherry-pick --%pick_sequencer% >nul 2>&1
    call:check_unmerged
    goto:start_merge

    :start_update
    :: check if there is a git workflow in progress or there are untracked changes else create update-branch
    call:check_merge
    call:check_untracked

    :: get current branch
    call git branch --show-current > "%currbr_file%"
    set /p branch=< "%currbr_file%

    echo -- create update branch --
    call git checkout -b %update_branch%

    :: add template repo if not already added
    call git ls-remote --exit-code template >nul 2>&1 || call git remote add template %remote%
    call git fetch --quiet template

    echo ----- check updates ------
    setlocal enabledelayedexpansion
    :: read last picked commit - if not found, use branch
    set "lastpick="
    if exist "%tplver_file%" set /p lastpick=< "%tplver_file%"
    if "%lastpick%"=="" set lastpick=%branch%

    :: get non-equivalent commits
    set "commits="
    for /f "usebackq delims=" %%i in (`"git cherry %branch% template/%remote_branch% | findstr /i +"`) do (
        set "commit=%%i"

        for /f "usebackq delims=" %%j in (`"git rev-parse --short !commit:~2!"`) do set "commit=%%j"

        :: check if commit is not in ignore list
        echo %ignore_SHAs% | findstr "!commit!" >nul 2>&1 || (
            :: check if commit is not already picked
            call git log --exit-code --grep "!commit!" >nul 2>&1 && (
                :: add commit to cherry-pick list
                set "commits=!commits! !commit!"
            )   
        )
    )

    :: cleanup when no new commits found
    if "%commits%"=="" (
        echo.
        echo ========================================================
        echo           You are up to date with the template
        echo ========================================================
        echo.
        goto:cleanup
    )
    set commits=%commits:~1%

    :: add commits to tplver file for commit message to prevent double picking
    >"%tplver_file%" echo %commits%

    :: cherry-pick new commits from template
    call git cherry-pick --keep-redundant-commits -x %commits% >nul 2>&1
    call :check_unmerged

    endlocal

    :start_merge
    echo ------ merge update ------
    :: read picked commit list
    set /p picked_SHAs=< "%tplver_file%"

    :: merge update and commit
    call git checkout %branch%
    call git merge -X theirs --squash %update_branch%
    call git commit -m "%commit_msg%" -m "%commit_descr%" -m "(picked commits: %picked_SHAs%)"

    echo.
    echo ========================================================
    echo              Update was successfully merged
    echo ========================================================
    echo.

    :cleanup
    echo -------- cleanup ---------
    if exist "%tplver_file%" del "%tplver_file%"
    if exist "%currbr_file%" del "%currbr_file%"
    call git checkout %branch%
    call git branch -D %update_branch%
    call git remote remove template
    exit