@echo off
title Nothing Phone 2 Fastboot ROM Flasher (t.me/NothingPhone2)

echo ###########################################################
echo #                Pong Fastboot ROM Flasher                #
echo #                   Developed/Tested By                   #
echo #  HELLBOY017, viralbanda, spike0en, PHATwalrus, arter97  #
echo #          [Nothing Phone (2) Telegram Dev Team]          #
echo ###########################################################

cd %~dp0
set fastboot=.\platform-tools\fastboot.exe

if not exist %fastboot% (
    echo Fastboot cannot be executed. Aborting
    pause
    exit
)

echo #############################
echo # CHANGING ACTIVE SLOT TO A #
echo #############################
%fastboot% --set-active=a
if %errorlevel% neq 0 (
    echo Error occured while switching to slot A. Aborting
    pause
    exit
)

echo ###################
echo # FORMATTING DATA #
echo ###################
choice /m "Wipe Data?"
if %errorlevel% equ 1 (
    echo Please ignore "Did you mean to format this partition?" warnings.
    call :ErasePartition userdata
    call :ErasePartition metadata
)

echo ##########################
echo # FLASHING BOOT/RECOVERY #
echo ##########################
choice /m "Flash images on both slots? If unsure, say N."
if %errorlevel% equ 1 (
    set slot=all
) else (
    set slot=a
)

for %%i in (boot vendor_boot dtbo recovery) do (
    if %slot% equ all (
        for %%s in (a b) do (
            call :FlashImage %%i_%%s, %%i.img
        )
    ) else (
        call :FlashImage %%i, %%i.img
    )
)

echo ##########################             
echo # REBOOTING TO FASTBOOTD #       
echo ##########################
%fastboot% reboot fastboot
if %errorlevel% neq 0 (
    echo Error occured while rebooting to fastbootd. Aborting
    pause
    exit
)

echo #####################
echo # FLASHING FIRMWARE #
echo #####################
for %%i in (abl aop aop_config bluetooth cpucp devcfg dsp featenabler hyp imagefv keymaster modem multiimgoem multiimgqti qupfw qweslicstore shrm tz uefi uefisecapp xbl xbl_config xbl_ramdump) do (
    call :FlashImage "--slot=%slot% %%i", %%i.img
)

echo ###################
echo # FLASHING VBMETA #
echo ###################
set disable_avb=0
choice /m "Disable android verified boot?, If unsure, say N. Bootloader won't be lockable if you select Y."
if %errorlevel% equ 1 (
    set disable_avb=1
    call :FlashImage "--slot=%slot% vbmeta --disable-verity --disable-verification", vbmeta.img
) else (
    call :FlashImage "--slot=%slot% vbmeta", vbmeta.img
)

if not exist super.img (
    echo ###############################
    echo # FLASHING LOGICAL PARTITIONS #
    echo ###############################
    for %%i in (system system_ext product vendor vendor_dlkm odm) do (
        for %%s in (a b) do (
            call :DeleteLogicalPartition %%i_%%s-cow
            call :DeleteLogicalPartition %%i_%%s
            call :CreateLogicalPartition %%i_%%s, 1
        )
        call :FlashImage %%i, %%i.img
    )
) else (
    echo ##################
    echo # FLASHING SUPER #
    echo ##################
    call :FlashImage super, super.img
)

echo #################################
echo # FLASHING VBMETA SYSTEM/VENDOR #
echo #################################
for %%i in (vbmeta_system vbmeta_vendor) do (
    if %disable_avb% equ 1 (
        call :FlashImage "%%i --disable-verity --disable-verification", %%i.img
    ) else (
        call :FlashImage %%i, %%i.img
    )
)

echo #############
echo # REBOOTING #
echo #############
choice /m "Reboot to system? If unsure, say Y."
if %errorlevel% equ 1 (
    %fastboot% reboot
)

echo ########
echo # DONE #
echo ########
echo Stock firmware restored.
echo You may now optionally re-lock the bootloader if you haven't disabled android verified boot.

pause
exit

:DeleteLogicalPartition
%fastboot% delete-logical-partition %~1
if %errorlevel% neq 0 (
    call :Choice "Deleting %~1 partition failed"
)
exit /b

:CreateLogicalPartition
%fastboot% create-logical-partition %~1 %~2
if %errorlevel% neq 0 (
    call :Choice "Creating %~1 partition failed"
)
exit /b

:ErasePartition
%fastboot% erase %~1
if %errorlevel% neq 0 (
    call :Choice "Erasing %~1 partition failed"
)
exit /b

:FlashImage
%fastboot% flash %~1 %~2
if %errorlevel% neq 0 (
    call :Choice "Flashing %~2 failed"
)
exit /b

:Choice
choice /m "%~1 continue? If unsure say N"
if %errorlevel% equ 2 (
    exit
)
exit /b
