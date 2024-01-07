@echo off
title Nothing Phone 2 Fastboot ROM Flasher (t.me/NothingPhone2)

echo ###########################################################
echo #                Pong Fastboot ROM Flasher                #
echo #                   Developed/Tested By                   #
echo #  HELLBOY017, viralbanda, spike0en, PHATwalrus, arter97  #
echo #          [Nothing Phone (2) Telegram Dev Team]          #
echo ###########################################################

echo #############################
echo # CHANGING ACTIVE SLOT TO A #
echo #############################
fastboot --set-active=a

echo ###################
echo # FORMATTING DATA #
echo ###################
choice /m "Wipe Data?"
if %errorlevel% equ 1 (
    echo Please ignore "Did you mean to format this partition?" warnings.
    fastboot erase userdata
    fastboot erase metadata
)

choice /m "Flash images on both slots? If unsure, say N."
if %errorlevel% equ 1 (
    set slot=--slot=all
) else (
    set slot=--slot=a
)

echo ##########################
echo # FLASHING BOOT/RECOVERY #
echo ##########################
for %%i in (boot vendor_boot dtbo recovery) do (
    fastboot flash %slot% %%i %%i.img
)

echo ##########################             
echo # REBOOTING TO FASTBOOTD #       
echo ##########################
fastboot reboot fastboot

echo #####################
echo # FLASHING FIRMWARE #
echo #####################
for %%i in (abl aop aop_config bluetooth cpucp devcfg dsp featenabler hyp imagefv keymaster modem multiimgoem multiimgqti qupfw qweslicstore shrm tz uefi uefisecapp vbmeta vbmeta_system vbmeta_vendor xbl xbl_config xbl_ramdump) do (
    fastboot flash %slot% %%i %%i.img
)

echo Flash logical partition images?
echo If you're about to install a custom ROM that distributes its own logical partitions, say N.
choice /m "If unsure, say Y."
if %errorlevel% equ 1 (
    echo ###############################
    echo # FLASHING LOGICAL PARTITIONS #
    echo ###############################
    for %%i in (system system_ext product vendor vendor_dlkm odm) do (
        for %%s in (a b) do (
            fastboot delete-logical-partition %%i_%%s-cow
            fastboot delete-logical-partition %%i_%%s
            fastboot create-logical-partition %%i_%%s 1
        )

        fastboot flash %%i %%i.img
    )
)

echo #############
echo # REBOOTING #
echo #############
choice /m "Reboot to system? If unsure, say Y."
if %errorlevel% equ 1 (
    fastboot reboot
)

echo ########
echo # DONE #
echo ########
echo Stock firmware restored.
echo You may now optionally re-lock the bootloader.

pause
