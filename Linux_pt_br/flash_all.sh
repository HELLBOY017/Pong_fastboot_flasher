#!/bin/bash

echo "###########################################################"
echo "#                Pong Fastboot ROM Flasher                #"
echo "#                Desenvolvido/Testado por                 #"
echo "#  HELLBOY017, viralbanda, spike0en, PHATwalrus, arter97  #"
echo "#          [Nothing Phone (2) Telegram Dev Team]          #"
echo "###########################################################"

##----------------------------------------------------------##
if [ ! -d platform-tools ]; then
    wget https://dl.google.com/android/repository/platform-tools-latest-linux.zip -O platform-tools-latest.zip
    unzip platform-tools-latest.zip
    rm platform-tools-latest.zip
fi

fastboot=platform-tools/fastboot

if [ ! -f $fastboot ] || [ ! -x $fastboot ]; then
    echo "Fastboot cannot be executed. Aborting."
    exit 1
fi

# Variáveis ​​de partição
boot_partitions="boot vendor_boot dtbo recovery"
firmware_partitions="abl aop aop_config bluetooth cpucp devcfg dsp featenabler hyp imagefv keymaster modem multiimgoem multiimgqti qupfw qweslicstore shrm tz uefi uefisecapp xbl xbl_config xbl_ramdump"
logical_partitions="system system_ext product vendor vendor_dlkm odm"
vbmeta_partitions="vbmeta_system vbmeta_vendor"

function SetActiveSlot {
    $fastboot --set-active=a
    if [ $? -ne 0 ]; then
        echo "Ocorreu um erro ao mudar para o slot A. Abortando."
        exit 1
    fi
}

function handle_fastboot_error {
    if [ ! $FASTBOOT_ERROR = "n" ] || [ ! $FASTBOOT_ERROR = "N" ] || [ ! $FASTBOOT_ERROR = "" ]; then
       exit 1
    fi  
}

function ErasePartition {
    $fastboot erase $1
    if [ $? -ne 0 ]; then
        read -p "Falha ao apagar a partição $1. Deseja continuar? Se não tiver certeza, digite N. Pressionar a tecla Enter sem qualquer entrada continuará o script. (Y/N)" FASTBOOT_ERROR
        handle_fastboot_error
    fi
}

function FlashImage {
    $fastboot flash $1 $2
    if [ $? -ne 0 ]; then
        read -p "Falha ao flashar $2. Deseja continuar? Se não tiver certeza, digite N. Pressionar a tecla Enter sem qualquer entrada continuará o script. (Y/N)" FASTBOOT_ERROR
        handle_fastboot_error
    fi
}

function DeleteLogicalPartition {
    $fastboot delete-logical-partition $1
    if [ $? -ne 0 ]; then
        read -p "Falha ao excluir a partição $1. Deseja continuar? Se não tiver certeza, digite N. Pressionar a tecla Enter sem qualquer entrada continuará o script. (Y/N)" FASTBOOT_ERROR
        handle_fastboot_error
    fi
}

function CreateLogicalPartition {
    $fastboot create-logical-partition $1 $2
    if [ $? -ne 0 ]; then
        read -p "Falha na criação da partição $1. Deseja continuar? Se não tiver certeza, digite N. Pressionar a tecla Enter sem qualquer entrada continuará o script. (Y/N)" FASTBOOT_ERROR
        handle_fastboot_error
    fi
}

function ResizeLogicalPartition {
    for i in $logical_partitions; do
        for s in a b; do 
            DeleteLogicalPartition "${i}_${s}-cow"
            DeleteLogicalPartition "${i}_${s}"
            CreateLogicalPartition "${i}_${s}" \ "1"
        done
    done
}

function WipeSuperPartition {
    $fastboot wipe-super super_empty.img
    if [ $? -ne 0 ]; then 
        echo "A limpeza da partição super falhou. Reverter para excluir e criar partições lógicas."
        ResizeLogicalPartition
    fi
}
##----------------------------------------------------------##

echo "#####################################"
echo "# VERIFICANDO DISPOSITIVOS FASTBOOT #"
echo "#####################################"
$fastboot devices

ACTIVE_SLOT=$($fastboot getvar current-slot 2>&1 | awk 'NR==1{print $2}')
if [ ! $ACTIVE_SLOT = "waiting" ] && [ ! $ACTIVE_SLOT = "a" ]; then
    echo "###############################"
    echo "# ALTERANDO SLOT ATIVO PARA A #"
    echo "###############################"
    SetActiveSlot
fi

echo "####################"
echo "# FORMATANDO DADOS #"
echo "####################"
read -p "Limpar dados? (Y/N) " DATA_RESP
case $DATA_RESP in
    [yY] )
        echo 'Por favor, ignore o aviso "Você pretendia formatar esta partição?".'
        ErasePartition userdata
        ErasePartition metadata
        ;;
esac

echo "############################"
echo "# FLASHANDO PARTIÇÕES BOOT #"
echo "############################"
read -p "Flashar imagens em ambos os slots? Se não tiver certeza, digite N. (Y/N) " SLOT_RESP
case $SLOT_RESP in
    [yY] )
        SLOT="--slot=all"
        ;;
    *)
        SLOT="--slot=a"
        ;;
esac

if [ $SLOT = "--slot=all" ]; then
    for i in $boot_partitions; do
        for s in a b; do
            FlashImage "${i}_${s}" \ "$i.img"
        done
    done
else
    for i in $boot_partitions; do
        FlashImage "$i" \ "$i.img"
    done
fi

echo "##############################"
echo "# REINICIANDO PARA FASTBOOTD #"
echo "##############################"
$fastboot reboot fastboot
if [ $? -ne 0 ]; then
    echo "Ocorreu um erro ao reiniciar para o fastbootd. Abortando."
    exit 1
fi

echo "######################"
echo "# FLASHANDO FIRMWARE #"
echo "######################"
for i in $firmware_partitions; do
    FlashImage "$SLOT $i" \ "$i.img"
done

echo "####################"
echo "# FLASHANDO VBMETA #"
echo "####################"
read -p "Desativar inicialização verificada do Android? Se não tiver certeza, digite N. O bootloader não poderá ser bloqueado se você digitar Y. (Y/N) " VBMETA_RESP
case $VBMETA_RESP in
    [yY] )
        FlashImage "$SLOT vbmeta --disable-verity --disable-verification" \ "vbmeta.img"
        ;;
    *)
        FlashImage "$SLOT vbmeta" \ "vbmeta.img"
        ;;
esac

echo "###############################"
echo "# FLASHANDO PARTIÇÕES LÓGICAS #"
echo "###############################"
echo "Flashar imagens de partições lógicas?"
echo "Se você estiver prestes a instalar uma ROM personalizada que distribua suas próprias partições lógicas, digite N."
read -p "Se não tiver certeza, digite Y. (Y/N) " LOGICAL_RESP
case $LOGICAL_RESP in
    [yY] )
        if [ ! -f super.img ]; then
            if [ -f super_empty.img ]; then
                WipeSuperPartition
            else
                ResizeLogicalPartition
            fi
            for i in $logical_partitions; do
                FlashImage "$i" \ "$i.img"
            done
        else
            FlashImage "super" \ "super.img"
        fi
        ;;
esac

echo "#####################################"
echo "# FLASHANDO OUTRAS PARTIÇÕES VBMETA #"
echo "#####################################"
for i in $vbmeta_partitions; do
    case $VBMETA_RESP in
        [yY] )
            FlashImage "$i --disable-verity --disable-verification" \ "$i.img"
            ;;
        *)
            FlashImage "$i" \ "$i.img"
            ;;
    esac
done

echo "###############"
echo "# REINICIANDO #"
echo "###############"
read -p "Reiniciar para o sistema? Se não tiver certeza, digite Y. (Y/N) " REBOOT_RESP
case $REBOOT_RESP in
    [yY] )
        $fastboot reboot
        ;;
esac

echo "##########"
echo "# PRONTO #"
echo "##########"
echo "Firmware stock restaurado."
echo "Agora você pode bloquear novamente o bootloader se não tiver desabilitado a inicialização verificada do Android."
