#!/bin/bash
#start check if internet connection
if ping -q -c 1 -W 1 8.8.8.8 >/dev/null; then
    printf "Connection Detected\n"
    printf "--------- \n -------\n"
    #if operating system
    if [ "$os" == "Darwin" ]; then
        printf "$os \n"
        printf "Unable to continue script"
        exit 2
    else
        #assume linux
        #check for dtc, install if missing
        printf "Installing requirements\n"
        sudo apt update -y
        command -v dtc || sudo apt-get install -y device-tree-compiler &> /dev/null
        command -v git || sudo apt-get install -y git &> /dev/null
        command -v wget || sudo apt-get install -y wget &> /dev/null
        command -v md5sum || sudo apt-get install -y md5sum &> /dev/null 
        command -v mkimage || sudo apt-get install -y u-boot-tools &> /dev/null
        
        
        #check if gdownloader is installed
            #git google downloader
        #use for downloading from gdrive
        if [ -d ~/Git/gdown.pl ];then
            printf "gdownloader already installed\n"
        else
            printf "Installing gdownloader\n"
            mkdir ~/Git
            cd ~/Git
            sudo git clone https://github.com/circulosmeos/gdown.pl.git &> /dev/null
        fi
        #check if pluto-firmware-modifications gitclone is present 
        #may take a few extra seconds to confirm this is installed somewhere on the device
        plutoGit=$(find ~/ -type d -name "pluto-firmware-modifications")
        #if empty assume no match found and install
        if [ -z "$plutoGit" ];then
            mkdir ~/Git
            cd ~/Git
            git clone https://github.com/daniestevez/pluto-firmware-modifications.git
            plutoGit="~/Git/pluto-firmware-modifications"
        else
            #assume "pluto-firmware-modifications" installed
            printf "pluto-firmware-modifications already installed to $plutoGit\n"
        #end if operating system
    fi
else
    printf "Internet connection Not Detected\n"
    exit 2
fi

#assume internet and packages required are installed
#define dir and var
frm1="$plutoGit/original_frm"
frm1URL="https://drive.google.com/drive/folders/1Q5I-Dpf1LxL1LGETBxscvf3UanD-lLYY"
frm2="$plutoGit/new_frm"
build="${frm}/build"
plutoS="${frm}/pluto.its"
plutoB="${frm}/pluto.itb"
plutoURL="https://raw.githubusercontent.com/analogdevicesinc/plutosdr-fw/master/scripts/pluto.its"

#make dirs for frms and build
mkdir -p $frm1 $frm2 $build
#download frm from google
sudo ~/Git/gdown.pl/gdown.pl "$frm1URL" "$frm1"

dtc -O dts $frm1/pluto.frm | $plutoGit/extract_data_dts.py /dev/stdin
#This will extract the data files inside the FIT image. 
#The filenames of the extracted files are chosen according to the description 
#field in the corresponding node of the FDT tree. 
#The files need to be renamed according to the filenames expected by the pluto.its file.

#location of zynq-pluto needs to be determined*****
for file in zynq-pluto*; do 
    mv $file ${file}.dtb
done

mv FPGA system_top.bit
mv Linux zImage
mv Ramdisk rootfs.cpio.gz
###zcat may be an option to edit gz file without decompressing


#Now we can replace some of these files as required with our modifications, 
#and build the FIT image and .frm file as described in the ADI Wiki.
#This requires mkimage, which is usually contained in the package uboot-tools in Linux 
#distributions.

mkdir $frm2 && wget $plutoURL -O ${frm2}/pluto.its
mkimage -f $plutoS $plutoB
md5sum $plutoB | cut -d ' ' -f 1 > ${frm2}/pluto.frm.md5
cat $plutoB ${frm2}/pluto.frm.md5 > ${frm2}/pluto.frm