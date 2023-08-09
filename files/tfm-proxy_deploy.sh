#!/bin/bash
#
# FOREMAN DEPLOY : FOREMAN PROXY (+dhcp +tftp)
#

wget https://apt.puppet.com/puppet6-release-buster.deb
dpkg -i puppet6-release-buster.deb
apt-get -qy update
apt --yes install puppet-agent

REQUIRED_PKG=foreman-installer
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
echo Checking for $REQUIRED_PKG: $PKG_OK
if [ "" = "$PKG_OK" ]; then
  echo "No $REQUIRED_PKG. Setting up $REQUIRED_PKG."
apt-get --yes install gnupg
wget -q https://deb.theforeman.org/pubkey.gpg -O- | apt-key add -
cat > /etc/apt/sources.list.d/foreman.list <<EOF
# Debian Buster
deb http://deb.theforeman.org/ buster 2.3
# Plugins compatible with Stable
deb http://deb.theforeman.org/ plugins 2.3
EOF
apt-get -qy update
apt-get --yes install $REQUIRED_PKG || exit 1
fi

/opt/puppetlabs/bin/puppet ssl bootstrap --server tfm-puppet.loxda.net

echo quit | openssl s_client -showcerts -servername server -connect tfm-puppet.loxda.net:8140 > /usr/local/share/ca-certificates/tfm-puppet-CA.crt
update-ca-certificates

foreman-installer \
--skip-puppet-version-check \
--no-enable-foreman \
--no-enable-foreman-cli \
--no-enable-puppet \
--enable-foreman-proxy \
--foreman-proxy-puppet-group=root \
--foreman-proxy-foreman-base-url=https://tfm-app.loxda.net \
--foreman-proxy-trusted-hosts=tfm-app.loxda.net \
--foreman-proxy-registered-name=tfm-proxy.loxda.net \
--foreman-proxy-register-in-foreman=true \
--foreman-proxy-oauth-consumer-key=CRZYZDNfLKq6iWb9dsChNVDrFDzgfBRG \
--foreman-proxy-oauth-consumer-secret=mQbuA2RKgsx8WuyP6ouoWGPaykhs56DQ \
--foreman-proxy-httpboot=true \
--foreman-proxy-templates=true \
--foreman-proxy-templates-listen-on=both \
--foreman-proxy-http=true \
--foreman-proxy-puppet=true \
--foreman-proxy-puppetca=true \
--foreman-proxy-puppet-url=https://tfm-puppet.loxda.net:8140 \
--foreman-proxy-dhcp=true \
--foreman-proxy-dhcp-managed=true \
--foreman-proxy-dhcp-pxefilename "undionly.kpxe" \
--foreman-proxy-dhcp-subnets="['172.16.202.0/24']" \
--foreman-proxy-dhcp-gateway="172.16.202.253" \
--foreman-proxy-dhcp-nameservers="172.16.202.253" \
--foreman-proxy-tftp=true \
--foreman-proxy-tftp-managed=true \
--puppet-codedir="/etc/puppetlabs/code" \
--enable-foreman-proxy-plugin-remote-execution-ssh \
--enable-foreman-proxy-plugin-ansible

systemctl restart foreman-proxy.service

cat > /root/deploy_tftp_ipxe.sh <<EOF
## deploy & upgrade iPXE from ipxe.org
#
#We need lzma libraries
apt-get --yes install git liblzma-dev
cd /tmp
git clone git://git.ipxe.org/ipxe.git
cd ipxe/src
cat <<EOF > default.ipxe
#!ipxe
dhcp
chain http://tfm-proxy.loxda.net:8000/unattended/iPXE
EOF
# Enable FTP Support in iPXE
sed -i -e 's/#undef\s*DOWNLOAD_PROTO_FTP/#define DOWNLOAD_PROTO_FTP/g' config/general.h
# Build the EFI bootloader first
make bin-x86_64-efi/snp.efi EMBED=default.ipxe
make bin-x86_64-efi/ipxe.efi EMBED=default.ipxe
# The ESXi Legacy BIOS bootloader mboot.c32 needs COMBOOT enabled in iPXE
sed -i -e 's/\/\/#define\s*IMAGE_COMBOOT/#define       IMAGE_COMBOOT/g' config/general.h
# Build the Legacy BIOS Bootloader
make bin/undionly.kpxe EMBED=default.ipxe
# Copy bootloaders to TFTP root
cp bin/undionly.kpxe /srv/tftp/
cp bin-x86_64-efi/ipxe.efi /srv/tftp/
cp bin-x86_64-efi/snp.efi /srv/tftp/
EOF
chmod +x /root/deploy_tftp_ipxe.sh
./root/deploy_tftp_ipxe.sh
