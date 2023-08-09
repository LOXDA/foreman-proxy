#!/bin/bash

export http_proxy=http://172.16.203.253:3128
export https_proxy=http://172.16.203.253:3128

# prepare smart_proxy tftp iPXE
apt-get -qy install git liblzma-dev
tfmappfqdn="tfm-app.lab.loxda.net"
cd /tmp
git clone http://mirror.lab.loxda.net/git/ipxe/ipxe.git/
cd ipxe/src
cat <<EOF > default.ipxe
#!ipxe
dhcp
chain http://${tfmappfqdn}/unattended/iPXE?bootstrap=1
EOF
# Enable FTP Support in iPXE
sed -i -e 's/#undef\s*DOWNLOAD_PROTO_FTP/#define DOWNLOAD_PROTO_FTP/g' config/general.h
sed -i -e 's/#undef\s*DOWNLOAD_PROTO_HTTPS/#define DOWNLOAD_PROTO_HTTPS/g' config/general.h
make bin/ipxe.pxe EMBED=default.ipxe TRUST=/etc/puppetlabs/puppet/ssl/certs/ca.pem
make bin/ipxe.lkrn EMBED=default.ipxe TRUST=/etc/puppetlabs/puppet/ssl/certs/ca.pem
# Build the EFI bootloader first
make bin-x86_64-efi/snp.efi EMBED=default.ipxe
make bin-x86_64-efi/ipxe.efi EMBED=default.ipxe
# The ESXi Legacy BIOS bootloader mboot.c32 needs COMBOOT enabled in iPXE
sed -i -e 's/\/\/#define\s*IMAGE_COMBOOT/#define       IMAGE_COMBOOT/g' config/general.h
# Build the Legacy BIOS Bootloader
make bin/undionly.kpxe EMBED=default.ipxe
# Copy bootloaders to TFTP root
cp bin/undionly.kpxe /srv/tftp/
cp bin/ipxe.pxe /srv/tftp/
cp bin/ipxe.lkrn /srv/tftp/
cp bin-x86_64-efi/ipxe.efi /srv/tftp/
cp bin-x86_64-efi/snp.efi /srv/tftp/

# deploy syslinux-3.86 (vmware support only this version, works well with everything else)
cd /tmp
wget https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/3.xx/syslinux-3.86.tar.gz
tar xfz syslinux-3.86.tar.gz
cp /tmp/syslinux-3.86/core/pxelinux.0 /srv/tftp/
find /tmp/syslinux-3.86/com32/ -name \*.c32 -exec cp {} /srv/tftp/ \;

# prepare OS medium for ESXi
apt-get -qy install nfs-common rsync
isonfspath="172.16.202.10:/nfs/ESXi/ESXi-6.7.0-8169922.iso"
mirrorfqdn="mirror.lab.loxda.net"
isonfsdir="/mnt/nfs"
isodir="/home/esxi"
isoesxi=$(basename ${isonfspath})
tmpmount=$(mktemp -d /tmp/.tmp.esxi.XXXXXX)
mkdir -p ${isodir} ; mkdir -p ${isonfsdir} ; mount -t nfs4 ${isonfspath/isoesxi} ${isonfsdir}
mount ${isonfsdir}/${isoesxi} ${tmpmount}/
mkdir -p ${isodir}/${isoesxi/.iso/}
cp -rv ${tmpmount}/* ${isodir}/${isoesxi/.iso/}/
umount ${isonfsdir} ; umount ${tmpmount} ; rm -r ${tmpmount}
cp ${isodir}/${isoesxi/.iso/}/boot.cfg ${isodir}/boot-${isoesxi/.iso/}.cfg
sed -e "s#/##g" -e "s#^prefix=.*#prefix=esxi/${isoesxi/.iso/}/#" -i ${isodir}/boot-${isoesxi/.iso/}.cfg
#sed -e "s#/##g" -e "s#^prefix=.*#prefix=http://${mirrorfqdn}:80/esxi/${isoesxi/.iso/}#" -i ${isodir}/boot-${isoesxi/.iso/}.cfg
cd /srv/tftp ; ln -s ${isodir} esxi

# http://mirror.lab.loxda.net:80/esxi/
