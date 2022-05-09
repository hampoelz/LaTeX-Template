@echo off

set branch=main

set remote=https://github.com/hampoelz/LaTeX-Template
set remote_branch=main

set update_branch=tmp/template

set "commit_msg=chore: :twisted_rightwards_arrows: Merge changes from template"
set "commit_descr=Merged from %remote%/tree/%remote_branch%"

:: file storing the commit SHA from the last commit picked from template
set tplver_file=.tplver

:: commits ignored by cherry-pick (seperate with space)
set "ignore_SHAs=1371a4dc935efd906cfa2d7eaa6d3e43b285a3df"

if [%1] == [] goto:start else (
    if [%1] == [/?]     call:show_usage
    if [%1] == [/help]  call:show_usage
    if [%1] == [/abort] call:abort
)

exit

:show_usage
echo usage: update.bat ^[--help^]
echo                   ^(--abort^)
exit

:check_unmerged
call git update-index --refresh
call git diff --quiet --exit-code --name-only --diff-filter=U || (
    echo.
    echo ========================================================
    echo    Please resolve conflicts and run the task again  
    echo     or abort the update using "update.bat /abort"
    echo ========================================================
    echo.
    exit
)
exit /b

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
exit /b

:check_merge
:: check if a merge or cherry-pick is in process
call git merge HEAD > nul 2>&1
if errorlevel 1 (
    echo.
    echo ========================================================
    echo    Sorry, another git workflow is already in progress
    echo ========================================================
    echo.
    exit
)
exit /b

:check_branch
:: check if update-branch exists and goto parameter else go ahead
call git rev-parse --verify %update_branch% > nul 2>&1
if errorlevel 1 goto %~1
exit /b

:abort
call:check_branch :eof
echo --- abort cherry-pick ----
call git cherry-pick --abort
call:cleanup
exit

:start
:: if update branch not exists, start update else continue cherry-pick and merge
call:check_branch :start_update

call git -c core.editor=true cherry-pick --continue > nul 2>&1
call:check_unmerged
goto:start_merge

:start_update
:: check if there is a git workflow in progress or there are untracked changes else create update-branch
call:check_merge
call:check_untracked

echo -- create update branch --
call git checkout -b %update_branch%

:: add template repo if not already added
call git ls-remote --exit-code template > nul 2>&1 || call git remote add template %remote%
call git fetch --quiet template


echo ----- check updates ------
setlocal enabledelayedexpansion
:: read last picked commit - if not found, use branch
set lastpick=
if exist %tplver_file% set /p lastpick=< %tplver_file%
if "%lastpick%"=="" set lastpick=%branch%

:: get non-equivalent commits since last update
set commits=
for /f "delims=" %%i in ('git cherry %lastpick% template/%remote_branch% ^| findstr /i "+"') do (
    set "commit=%%i"

    :: check if commits is not in ignore list
    echo.%ignore_SHAs%|findstr /C:"!commit:~2!" >nul 2>&1
    if errorlevel 1 (
        :: add commit to cherry-pick list and to tplver file for next update
        set "commits=!commits! !commit:~2!"
        >%tplver_file% echo !commit:~2! 
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

:: cherry-pick new commits from template
call git cherry-pick -x %commits% > nul 2>&1
call :check_unmerged

endlocal

:start_merge
echo ------ merge update ------
call git add %tplver_file%
call git checkout %branch%
call git merge --squash %update_branch%
set /p lastpick=< %tplver_file%
call git commit -m "%commit_msg%" -m "%commit_descr%" -m "Bump to commit %lastpick%"

echo.
echo ========================================================
echo              Update was successfully merged
echo ========================================================
echo.

:cleanup
echo -------- cleanup ---------
call git checkout %branch%
call git branch -D %update_branch%
call git remote remove template
exit