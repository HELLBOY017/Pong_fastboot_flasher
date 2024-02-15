@echo off
title Nothing Phone 2 Fastboot ROM Flasher (t.me/NothingPhone2)

echo ###########################################################
echo #                Pong Fastboot ROM Flasher                #
echo #                Desenvolvido/Testado por                 #
echo #  HELLBOY017, viralbanda, spike0en, PHATwalrus, arter97  #
echo #          [Nothing Phone (2) Telegram Dev Team]          #
echo ###########################################################

cd %~dp0

if not exist platform-tools-latest (
    curl -L https://dl.google.com/android/repository/platform-tools-latest-windows.zip -o platform-tools-latest.zip
    Call :UnZipFile "%~dp0platform-tools-latest", "%~dp0platform-tools-latest.zip"
    del /f /q platform-tools-latest.zip
)

set fastboot=.\platform-tools-latest\platform-tools\fastboot.exe
if not exist %fastboot% (
    echo Fastboot não pode ser executado. Abortando.
    pause
    exit
)

set boot_partitions=boot vendor_boot dtbo recovery
set firmware_partitions=abl aop aop_config bluetooth cpucp devcfg dsp featenabler hyp imagefv keymaster modem multiimgoem multiimgqti qupfw qweslicstore shrm tz uefi uefisecapp xbl xbl_config xbl_ramdump
set logical_partitions=system system_ext product vendor vendor_dlkm odm
set vbmeta_partitions=vbmeta_system vbmeta_vendor

echo #####################################
echo # VERIFICANDO DISPOSITIVOS FASTBOOT #
echo #####################################
%fastboot% devices

%fastboot% getvar current-slot 2>&1 | find /c "current-slot: a" > tmpFile.txt
set /p active_slot= < tmpFile.txt
del /f /q tmpFile.txt
if %active_slot% equ 0 (
    echo ###############################
    echo # ALTERANDO SLOT ATIVO PARA A #
    echo ###############################
    call :SetActiveSlot
)

echo ####################
echo # FORMATANDO DADOS #
echo ####################
choice /m "Limpar dados?"
if %errorlevel% equ 1 (
    echo Por favor, ignore o aviso "Você pretendia formatar esta partição?".
    call :ErasePartition userdata
    call :ErasePartition metadata
)

echo ############################
echo # FLASHANDO PARTIÇÕES BOOT #
echo ############################
choice /m "Flashar imagens em ambos os slots? Se não tiver certeza, digite N."
if %errorlevel% equ 1 (
    set slot=all
) else (
    set slot=a
)

if %slot% equ all (
    for %%i in (%boot_partitions%) do (
        for %%s in (a b) do (
            call :FlashImage %%i_%%s, %%i.img
        )
    ) 
) else (
    for %%i in (%boot_partitions%) do (
        call :FlashImage %%i, %%i.img
    )
)

echo ##############################
echo # REINICIANDO PARA FASTBOOTD #
echo ##############################
%fastboot% reboot fastboot
if %errorlevel% neq 0 (
    echo Ocorreu um erro ao reiniciar para o fastbootd. Abortando.
    pause
    exit
)

echo ######################
echo # FLASHANDO FIRMWARE #
echo ######################
for %%i in (%firmware_partitions%) do (
    call :FlashImage "--slot=%slot% %%i", %%i.img
)

echo ####################
echo # FLASHANDO VBMETA #
echo ####################
set disable_avb=0
choice /m "Desativar inicialização verificada do Android? Se não tiver certeza, digite N. O bootloader não poderá ser bloqueado se você digitar Y."
if %errorlevel% equ 1 (
    set disable_avb=1
    call :FlashImage "--slot=%slot% vbmeta --disable-verity --disable-verification", vbmeta.img
) else (
    call :FlashImage "--slot=%slot% vbmeta", vbmeta.img
)

echo ###############################
echo # FLASHANDO PARTIÇÕES LÓGICAS #
echo ###############################
echo Flashar imagens de partições lógicas?
echo Se você estiver prestes a instalar uma ROM personalizada que distribua suas próprias partições lógicas, digite N.
choice /m "Se não tiver certeza, digite Y."
if %errorlevel% equ 1 (
    if not exist super.img (
        if exist super_empty.img (
            call :WipeSuperPartition
        ) else (
            call :ResizeLogicalPartition
        )
        for %%i in (%logical_partitions%) do (
            call :FlashImage %%i, %%i.img
        )
    ) else (
        call :FlashImage super, super.img
    )
)

echo #####################################
echo # FLASHANDO OUTRAS PARTIÇÕES VBMETA #
echo #####################################
for %%i in (%vbmeta_partitions%) do (
    if %disable_avb% equ 1 (
        call :FlashImage "%%i --disable-verity --disable-verification", %%i.img
    ) else (
        call :FlashImage %%i, %%i.img
    )
)

echo ###############
echo # REINICIANDO #
echo ###############
choice /m "Reiniciar para o sistema? Se não tiver certeza, digite Y."
if %errorlevel% equ 1 (
    %fastboot% reboot
)

echo ##########
echo # PRONTO #
echo ##########
echo Firmware stock restaurado.
echo Agora você pode bloquear novamente o bootloader se não tiver desabilitado a inicialização verificada do Android.

pause
exit

:UnZipFile
set vbs="%temp%\_.vbs"
if exist %vbs% del /f /q %vbs%
>%vbs%  echo Set fso = CreateObject("Scripting.FileSystemObject")
>>%vbs% echo If NOT fso.FolderExists("%~1") Then
>>%vbs% echo fso.CreateFolder("%~1")
>>%vbs% echo End If
>>%vbs% echo set objShell = CreateObject("Shell.Application")
>>%vbs% echo set FilesInZip=objShell.NameSpace("%~2").items
>>%vbs% echo objShell.NameSpace("%~1").CopyHere(FilesInZip)
>>%vbs% echo Set fso = Nothing
>>%vbs% echo Set objShell = Nothing
cscript //nologo %vbs%
if exist %vbs% del /f /q %vbs%
exit /b

:ErasePartition
%fastboot% erase %~1
if %errorlevel% neq 0 (
    call :Choice "Falha ao apagar a partição %~1."
)
exit /b

:SetActiveSlot
%fastboot% --set-active=a
if %errorlevel% neq 0 (
    echo Ocorreu um erro ao mudar para o slot A. Abortando.
    pause
    exit
)
exit /b

:WipeSuperPartition
%fastboot% wipe-super super_empty.img
if %errorlevel% neq 0 (
    echo A limpeza da partição super falhou. Reverter para excluir e criar partições lógicas.
    call :ResizeLogicalPartition
)
exit /b

:ResizeLogicalPartition
for %%i in (%logical_partitions%) do (
    for %%s in (a b) do (
        call :DeleteLogicalPartition %%i_%%s-cow
        call :DeleteLogicalPartition %%i_%%s
        call :CreateLogicalPartition %%i_%%s, 1
    )
)
exit /b

:DeleteLogicalPartition
%fastboot% delete-logical-partition %~1
if %errorlevel% neq 0 (
    call :Choice "Falha ao excluir a partição %~1"
)
exit /b

:CreateLogicalPartition
%fastboot% create-logical-partition %~1 %~2
if %errorlevel% neq 0 (
    call :Choice "Falha na criação da partição %~1"
)
exit /b

:FlashImage
%fastboot% flash %~1 %~2
if %errorlevel% neq 0 (
    call :Choice "Falha ao flashar %~2"
)
exit /b

:Choice
choice /m "%~1 continuar? Se não tiver certeza, digite N."
if %errorlevel% equ 2 (
    exit
)
exit /b
