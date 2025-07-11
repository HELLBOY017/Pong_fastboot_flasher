@echo off
title Nothing Phone 2 Fastboot ROM Flasher

echo #############################
echo # Pong Fastboot ROM Flasher #
echo #############################

cd %~dp0

if not exist platform-tools-latest (
    curl --ssl-no-revoke -L https://dl.google.com/android/repository/platform-tools-latest-windows.zip -o platform-tools-latest.zip
    Call :UnZipFile "%~dp0platform-tools-latest.zip", "%~dp0platform-tools-latest"
    del /f /q platform-tools-latest.zip
)

set fastboot=.\platform-tools-latest\platform-tools\fastboot.exe
if not exist %fastboot% (
    echo Fastboot cannot be executed. Aborting
    pause
    exit
)

set boot_partitions=boot vendor_boot dtbo recovery
set firmware_partitions=abl aop aop_config bluetooth cpucp devcfg dsp featenabler hyp imagefv keymaster modem multiimgoem multiimgqti qupfw qweslicstore shrm tz uefi uefisecapp xbl xbl_config xbl_ramdump
set logical_partitions=system system_ext product vendor vendor_dlkm odm
set junk_logical_partitions=null
set vbmeta_partitions=vbmeta_system vbmeta_vendor

echo #############################
echo # CHECKING FASTBOOT DEVICES #
echo #############################
%fastboot% devices

echo #############################
echo # CHANGING ACTIVE SLOT TO A #
echo #############################
call :SetActiveSlot

echo ###################
echo # FORMATTING DATA #
echo ###################
choice /m "Wipe Data?"
if %errorlevel% equ 1 (
    echo Please ignore "Did you mean to format this partition?" warnings.
    call :ErasePartition userdata
    call :ErasePartition metadata
)

echo ############################
echo # FLASHING BOOT PARTITIONS #
echo ############################
set slot=a
choice /m "Flash images on both slots? If unsure, say N."
if %errorlevel% equ 1 (
    set slot=all
)

if %slot% equ all (
    for %%i in (%boot_partitions%) do (
        for %%s in (a b) do (
            call :FlashImage %%i_%%s, %%i.img
        )
    ) 
) else (
    for %%i in (%boot_partitions%) do (
        call :FlashImage %%i_a, %%i.img
    )
)

echo ###################
echo # FLASHING VBMETA #
echo ###################
set disable_avb=0
choice /m "Disable android verified boot?, If unsure, say N. Bootloader won't be lockable if you select Y."
if %errorlevel% equ 1 (
    set disable_avb=1
    if %slot% equ all (
        for %%s in (a b) do (
            call :FlashImage "vbmeta_%%s --disable-verity --disable-verification", vbmeta.img
        )
    ) else (
        call :FlashImage "vbmeta_a --disable-verity --disable-verification", vbmeta.img
    )
) else (
    if %slot% equ all (
        for %%s in (a b) do (
            call :FlashImage "vbmeta_%%s", vbmeta.img
        )
    ) else (
        call :FlashImage "vbmeta_a", vbmeta.img
    )
)

echo #####################
echo # FLASHING FIRMWARE #
echo #####################
call :RebootFastbootD
if %slot% equ all (
    for %%i in (%firmware_partitions%) do (
        for %%s in (a b) do (
            call :FlashImage %%i_%%s, %%i.img
        )
    ) 
) else (
    for %%i in (%firmware_partitions%) do (
        call :FlashImage %%i_a, %%i.img
    )
)

echo ###############################
echo # FLASHING LOGICAL PARTITIONS #
echo ###############################
if not exist super.img (
    if exist super_empty.img (
        call :WipeSuperPartition
    ) else (
        call :HandleLogicalPartition
    )
    for %%i in (%logical_partitions%) do (
        call :FlashImage %%i_a, %%i.img
    )
) else (
    call :FlashSuper
)

echo ####################################
echo # FLASHING OTHER VBMETA PARTITIONS #
echo ####################################
for %%i in (%vbmeta_partitions%) do (
    if %disable_avb% equ 1 (
        call :FlashImage "%%i_a --disable-verity --disable-verification", %%i.img
    ) else (
        call :FlashImage %%i_a, %%i.img
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

pause
exit

:UnZipFile
powershell -ExecutionPolicy Bypass -Command "Expand-Archive -Path "%~1" -DestinationPath "%~2" -Force"
exit /b

:SetActiveSlot
%fastboot% set_active a
if %errorlevel% neq 0 (
    echo Error occured while switching to slot A. Aborting
    pause
    exit
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

:FlashSuper
call :RebootBootloader
%fastboot% flash super super.img
if %errorlevel% neq 0 (
    call :RebootFastbootD
    call :FlashImage super, super.img
)
exit /b

:RebootFastbootD
echo ##########################             
echo # REBOOTING TO FASTBOOTD #       
echo ##########################
%fastboot% reboot fastboot
if %errorlevel% neq 0 (
    echo Error occured while rebooting to fastbootd. Aborting
    pause
    exit
)
exit /b

:WipeSuperPartition
%fastboot% wipe-super super_empty.img
if %errorlevel% neq 0 (
    echo Wiping super partition failed. Fallback to deleting and creating logical partitions
    call :HandleLogicalPartition
)
exit /b

:HandleLogicalPartition
if %junk_logical_partitions% neq null (
    for %%i in (%junk_logical_partitions%) do (
        for %%s in (a b) do (
            call :DeleteLogicalPartition %%i_%%s-cow
            call :DeleteLogicalPartition %%i_%%s
        )
    )
)

for %%i in (%logical_partitions%) do (
    for %%s in (a b) do (
        call :DeleteLogicalPartition %%i_%%s-cow
        call :ResizeLogicalPartition %%i_%%s, 1
    )
)
exit /b

:DeleteLogicalPartition
echo %~1 | find /c "cow" 2>&1
if %errorlevel% equ 0 (
    set partition_is_cow=true
) else (
    set partition_is_cow=false
)
%fastboot% delete-logical-partition %~1
if %errorlevel% neq 0 (
    if %partition_is_cow% equ false (
        call :Choice "Deleting %~1 partition failed"
    )
)
exit /b

:ResizeLogicalPartition
%fastboot% resize-logical-partition %~1 %~2
if %errorlevel% neq 0 (
    call :Choice "Resizing %~1 partition failed"
)
exit /b

:RebootBootloader
echo ###########################             
echo # REBOOTING TO BOOTLOADER #       
echo ###########################
%fastboot% reboot bootloader
if %errorlevel% neq 0 (
    echo Error occured while rebooting to bootloader. Aborting
    pause
    exit
)
exit /b

:Choice
choice /m "%~1 continue? If unsure say N"
if %errorlevel% equ 2 (
    exit
)
exit /b
