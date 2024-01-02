#!/bin/bash

echo "#################################################"
echo "#           Pong Fastboot ROM Flasher           #"
echo "#              Developed/Tested By              #"
echo "#  Hellboy017, Ali Shahawez, Spike, Phatwalrus  #"
echo "#     [Nothing Phone (2) Telegram Dev Team]     #"
echo "#################################################"

echo "#############################"
echo "# CHANGING ACTIVE SLOT TO A #"
echo "#############################"
fastboot --set-active=a

echo "###################"
echo "# FORMATTING DATA #"
echo "###################"
read -p "Wipe Data? (Y/N) " DATA_RESP
case $DATA_RESP in
    [yY] )
        echo 'Please ignore "Did you mean to format this partition?" warnings.'
        fastboot erase userdata
        fastboot erase metadata
        ;;
esac

read -p "Flash images on both slots? If unsure, say N. (Y/N) " SLOT_RESP
case $SLOT_RESP in
    [yY] )
        SLOT="--slot=all"
        ;;
esac

echo "##########################"
echo "# FLASHING BOOT/RECOVERY #"
echo "##########################"
for i in boot vendor_boot dtbo recovery; do 
    fastboot flash $SLOT $i $i.img
done

echo "##########################"             
echo "# REBOOTING TO FASTBOOTD #"       
echo "##########################"
fastboot reboot fastboot

echo  "#####################"
echo  "# FLASHING FIRMWARE #"
echo  "#####################"
for i in abl aop aop_config bluetooth cpucp devcfg dsp featenabler hyp imagefv keymaster modem multoem multqti qupfw qweslicstore shrm tz uefi uefisecapp vbmeta vbmeta_system vbmeta_vendor xbl xbl_config xbl_ramdump; do
    fastboot flash $SLOT $i $i.img
done

echo "###############################"
echo "# FLASHING LOGICAL PARTITIONS #"
echo "###############################"
for i in system system_ext product vendor vendor_dlkm odm; do
    for s in a b; do
        fastboot delete-logical-partition ${i}_${s}-cow
        fastboot delete-logical-partition ${i}_${s}
        fastboot create-logical-partition ${i}_${s} 1
    done

    fastboot flash $i $i.img
done

echo "#############"
echo "# REBOOTING #"
echo "#############"
read -p "Reboot to system? If unsure, say Y. (Y/N) " REBOOT_RESP
case $REBOOT_RESP in
    [yY] )
        fastboot reboot
        ;;
esac

exit 1
