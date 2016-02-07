# Begin pre-installation script
%pre --interpreter=/bin/bash --log /tmp/ks-pre-install.log

# Setup the env (setting /dev/tty3 as default IO)
chvt 3
exec < /dev/tty3 > /dev/tty3 2>/dev/tty3

# Set $PATH to something robust
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

# Capture array of arguments
opts=($(cat /proc/cmdline))

# Iterate ${opts[@]} & extract args key/values
if [ ${#opts[@]} -gt 1 ]; then
  for opt in "${opts[@]}"; do
    i=$((i+1))
    if [[ "${opt}" =~ = ]]; then
      key="$(echo "${opt}"|awk '{split($0, obj, "=");print obj[1]}')"
      value="$(echo "${opt}"|awk '{split($0, obj, "=");print obj[2]}')"
      eval ${key}=${value}
      echo "${key}: ${value}" >> /tmp/ks-pre-install.log
    fi
  done

# Clear the terminal
clear

# Print out the list of arguments
cat <<EOF
Specified argument list:
  General options:
    INSTALL:       ${INSTALL}
    ROOTPW:        ${ROOTPW}

  Location options:
    LOCATION:      ${LOCATION}

  Networking options:
    HOSTNAME:      ${HOSTNAME}
    IPADDR:        ${IPADDR}
    NETMASK:       ${NETMASK}
    GATEWAY:       ${GATEWAY}
EOF

fi

sleep 15

# Force prompt if ${INSTALL} not present
if [ "${INSTALL}" != "true" ]; then
  install="no"
else
  install="yes"
fi

# Ensure user knows they are going to wipe out the machine
while [ "${install}" != "yes" ]; do
  echo '***********************************************************************'
  echo '*  __________               .__  _____.__                             *'
  echo '*  \______   \_____    ____ |__|/ ____\__| ____  _________________    *'
  echo '*   |     ___/\__  \ _/ ___\|  \   __\|  |/ ___\/  _ \_  __ \____ \   *' 
  echo '*   |    |     / __ \\  \___|  ||  |  |  \  \__(  <_> )  | \/  |_> >  *'
  echo '*   |____|    (____  /\___  >__||__|  |__|\___  >____/|__|  |   __/   *'
  echo '*                  \/     \/                  \/            |__|      *'
  echo '*                                                                     *'
  echo '*                            W A R N I N G                            *'
  echo '*                                                                     *'
  echo '*  This process will install a completely new operating system.       *'
  echo '*                                                                     *'
  echo '*  Do you wish to continue?  Type "yes" to proceed                    *'
  echo '*                                                                     *'
  echo '***********************************************************************'
  echo
  read -p "Proceed with install? " install
done

# Clear the terminal
clear

# If ${ROOTPW} preset copy to ${pass}
if [ "${ROOTPW}" != "" ]; then
  pass="${ROOTPW}"
fi

# Prompt for root password, hash and write it out
while [ "${pass}" == "" ]; do
  read -sp "Please enter root user password: " pass
  echo ""
done

# Write ${pass} to roopw 
echo "rootpw ${pass}" > /tmp/ks-rootpw
echo "rootpw: ${pass}" >> /tmp/ks-pre-install.log

# Set ${hostname}: ${args[HOSTNAME]} or value of `uname -n`
if [ "${HOSTNAME}" == "" ]; then

  # If static DHCP enabled option 12 *might* contain the appropriate hostname
  hostname="$(uname -n|awk '{print toupper($0)}')"
else
  hostname="$(echo "${HOSTNAME}"|awk '{print toupper($0)}')"
fi
echo "hostname: ${hostname}" >> /tmp/ks-pre-install.log

# Set ${country} to geographic location (echo "Hostname: ${hostname}"
# no way to auto-determine unless geoIP functionality exists in initramfs)
country="America"

# Set location to ${LOCATION} or first 3 characters of ${hostname}
if [ "${LOCATION}" == "" ]; then
  location="$(echo "${hostname:0:3}"|awk '{print toupper($0)}')"
else
  location="$(echo "${LOCATION}"|awk '{print toupper($0)}')"
fi

# Prompt for ${location} if it doesn't match the list
while [[ ! "${location}" =~ PDX ]] && [[ ! "${location}" =~ SLC ]]; do
  read -p "Physical location? [PDX|SLC] " location
done
echo "location: ${location}" >> /tmp/ks-pre-install.log

# Use ${location} to determine NFS server (don't count on DNS)
if [ "${location}" == "SLC" ]; then
  zone="Denver"
  nfs_server="131.219.218.226" # slcnfsc01p
fi

if [ "${location}" == "PDX" ]; then
  zone="Los_Angeles"
  nfs_server="131.219.220.48" # pdxnfsc01p
fi

# If ${zone} still not defined setup a default
if [ "${zone}" == "" ]; then
  zone="Los_Angeles"
  nfs_server="131.219.220.48" # pdxnfsc01p
fi

# Write out /tmp/timezone
echo "timezone ${country}/${zone} --isUtc" > /tmp/ks-timezone
echo "timezone: ${country}/${zone}" >> /tmp/ks-pre-install.log

# Write out /tmp/nfsshare file
echo "nfs --server=${nfs_server} --dir=${path}" > /tmp/ks-nfsshare
echo "nfs server: ${nfs_server}" >> /tmp/ks-pre-install.log

# IPv4 validation function
function valid_ip()
{
  local  ip=$1
  local  stat=1

  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    OIFS=$IFS
    IFS='.'
    ip=($ip)
    IFS=$OIFS
    [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
      stat=$?
  fi

  return $stat
}

# Set /tmp/ks-networking to prevent failures
echo "" > /tmp/ks-networking

# Is ${IPADDR}, ${NETMASK} & ${GATEWAY} present from args list?
if [[ "${IPADDR}" != "" ]] && [[ "${NETMASK}" != "" ]] && [[ "${GATEWAY}" != "" ]]; then

  # Validate IPv4 addresses for ${IPADDR}, ${NETMASK} & ${GATEWAY}
  if [[ $(valid_ip "${IPADDR}") -ne 0 ]] || [[ $(valid_ip "${NETMASK}") -ne 0 ]] || [[ $(valid_ip "${GATEWAY}") -ne 0 ]]; then

    # Be informative about the failure
    [[ $(valid_ip "${IPADDR}") -ne 0 ]] && echo "${IPADDR} is invalid"
    [[ $(valid_ip "${NETMASK}") -ne 0 ]] && echo "${NETMASK} is invalid"
    [[ $(valid_ip "${GATEWAY}") -ne 0 ]] && echo "${GATEWAY} is invalid"
    exit 1
  fi
else
  # Check to see if anything was applied via DHCP
  IPADDR="$(ifconfig eth0 | grep inet | cut -d : -f 2 | cut -d " " -f 1)"
  NETMASK="$(ifconfig eth0 | grep inet | cut -d : -f 4 | head -1)"
  GATEWAY="$(route | grep default | cut -b 17-32 | cut -d " " -f 1)"

  # Validate IPv4 addresses for ${IPADDR}, ${NETMASK} & ${GATEWAY}
  if [[ $(valid_ip "${IPADDR}") -ne 0 ]] || [[ $(valid_ip "${NETMASK}") -ne 0 ]] || [[ $(valid_ip "${GATEWAY}") -ne 0 ]]; then

    # Be informative about the failure
    [[ $(valid_ip "${IPADDR}") -ne 0 ]] && echo "${IPADDR} is invalid"
    [[ $(valid_ip "${NETMASK}") -ne 0 ]] && echo "${NETMASK} is invalid"
    [[ $(valid_ip "${GATEWAY}") -ne 0 ]] && echo "${GATEWAY} is invalid"
    exit 1
  fi
fi

# Use supplied ${IPADDR}, ${NETMASK} & ${GATEWAY} to write network configuration
echo "network --bootproto=static --hostname=${hostname} --ip=${IPADDR} --netmask=${NETMASK} --gateway=${GATEWAY}" > /tmp/ks-networking
echo "ipaddr: ${IPADDR}" >> /tmp/ks-pre-install.log
echo "netmask: ${NETMASK}" >> /tmp/ks-pre-install.log
echo "gateway: ${GATEWAY}" >> /tmp/ks-pre-install.log

%end

# Force text mode installation
text

# Default language
lang en_US

# Default keyboard layout
keyboard us

# Include timezone
%include /tmp/ks-timezone

# Include root password configuration
%include /tmp/ks-rootpw

#platform x86, AMD64, or Intel EM64T

# Restart system after kicked
reboot

# Use NFS share for installation media
%include /tmp/ks-nfsshare

# Clear out disk
zerombr
clearpart --all --initlabel --drives=sda

# Include disk configuration
#%include /tmp/ks-diskconfig

# Install GRUB
bootloader --location=mbr --append="rhgb quiet crashkernel=512MB audit=1"

# Include networking configuration
%include /tmp/ks-networking

# Specify authentication hashing algorithm
# (why is 'useshadow' even an option anymore?)
auth --passalgo=sha512 --useshadow

# Disable selinux policies
selinux --disabled

# Disable firewall
firewall --disabled

# Don't install X, riddled with vulns
skipx

firstboot --disable

# Handle package installation
%packages
@base
%end

# Begin post-installation script
%post --nochroot --interpreter=/bin/bash --log /tmp/ks-post-install.log

# Setup the env (setting /dev/tty3 as default IO)
chvt 3
exec < /dev/tty3 > /dev/tty3 2>/dev/tty3

# Set $PATH to something robust
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

# Copy all of our configuration files from %pre to /mnt/sysimage/tmp
cp /tmp/ks* /mnt/sysimage/tmp
clear
echo "Copied all temporary scripts to chroot env."

# Attempt to get our previously written ${nfs_share} from /tmp/ks-nfsshare
if [ ! -f /tmp/ks-nfsshare ]; then
  echo "/tmp/ks-nfsshare file is missing, exiting"
  exit 1
fi

echo "Found /tmp/ks-nfsshare!"

# Split up /tmp/ks-nfsshare to get our nfs server
nfs_server="$(cat /tmp/ks-nfsshare|awk '$0 ~ /^nfs/{split($2, obj, "=");print obj[2]}')"

# Make sure we have something for ${nfs_server}
if [ "${nfs_server}" == "" ]; then
  echo "Could not get the NFS server"
  exit 1
fi

echo "Set our NFS server to ${nfs_server}"

# Mount point for NFS share
path="/mnt/sysimage/var/tmp/unixbuild"

# Make sure the ${path} exists, make if not
if [ ! -d "${path}" ] ; then
  mkdir -p "${path}"
fi

# Make sure we can connect to ${nfs_server}
ping=$(ping -c1 ${nfs_server})
if [ $? -ne 0 ]; then
  echo "Could not contact the ${nfs_server}, check routing table (gateway)"
  exit 1
fi

# Mount NFS share for %post processing
nfs=$(mount -t nfs -o nolock ${nfs_server}:/unixshr ${path})
if [ $? -ne 0 ]; then
  echo "An error occured mount ${nfs_server} @ ${path}, exiting"
  exit 1
fi

echo "Mounted ${nfs_server} @ ${path}"

%end

%post --interpreter=/bin/bash --log /tmp/ks-post-install.log

# Setup the env (setting /dev/tty3 as default IO)
chvt 3
exec < /dev/tty3 > /dev/tty3 2>/dev/tty3

# Set $PATH to something robust
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

clear
echo "Now in the chroot env"

# Mount point for NFS share
path="/var/tmp/unixbuild"

# Define a location for the RHEL build tool
build_tools="${path}/linux/build-tools"

echo "Our build tools should be @ ${build_tools}"

# Documentation @ http://moss.pacificorp.us/SiteDirectory/EntSys/Unix/OS/Documents/Servers%20and%20Hardware/Server%20Builds/RHEL%20Linux/rhel-builder.doc

# Make sure the NFS mount provided the directory
if [ ! -d "${build_tools}" ]; then
  echo "Unable to open ${build_tools}"
  exit 1
fi

echo "Our NFS share is mounted @ ${build_tools}"

# Does our build tool exist?
if [ ! -f "${build_tools}/rhel-builder" ]; then
  echo "RHEL build tool doesn't seem to exist @ ${build_tools}/rhel-builder"
  exit 1
fi

echo "Our build tools exist!"

# Record a timestamped hostname string for build logs
folder=/root/$(hostname)-$(date +%Y%m%d-%H%M)

# Create a folder structure for operational logging
if [ ! -d "${folder}" ]; then
  mkdir -p ${folder}/
  mkdir -p ${folder}/kickstart
  mkdir -p ${folder}/pre
  mkdir -p ${folder}/build
  mkdir -p ${folder}/post
fi

echo "Created ${folder}"

# Make a backup of /tmp/ks* to ${folder}/kickstart
echo "Created backup of configuration & kickstart files"
cp /tmp/ks* ${folder}/kickstart

# Go to ${build_tools}
cd ${build_tools}

# Run ${build_tools} to validate current configuration with logging
echo "Performing initial state validation"
./rhel-builder -vc > ${folder}/pre/$(hostname)-$(date +%Y%m%d-%H%M).log

sleep 30

"# Run ${build_tools} to make changes according to RHEL build guide standards
echo "Performing OS build"
./rhel-builder -va kickstart > ${folder}/build/$(hostname)-$(date +%Y%m%d-%H%M).log

sleep 30

# Run ${build_tools} to validate changes
echo "Performing post build state validation"
./rhel-builder -vc > ${folder}/post/$(hostname)-$(date +%Y%m%d-%H%M).log

sleep 30

# Examine 'post' build log for errors and make attempts to run each tool again?

# Run the $(dirname ${build_tools})/scripts/config-network tool by itself
# because the argument requirements differ from all the other tools

# Exit if config-network tool doesn't exist
if [ ! -f scripts/config-network ]; then
  echo "scripts/config-network tool does not exist in specified location"
  exit 1
fi

# Change into scripts/ subfolder if scripts/config-network exists
cd ${build_tools/scripts/  

# Make sure our configuration data exists
if [ ! -f /tmp/ks-networking ]; then
  echo "/tmp/ks-networking file is missing, exiting"
  exit 1
fi

# Obtain ${IPADDR}, ${NETMASK} & ${GATEWAY} from /tmp/ks-networking
IPADDR="$(cat /tmp/ks-networking|awk '{if (match($0, /ip=([[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/, obj)){print obj[1]}}')"
NETMASK="$(cat /tmp/ks-networking|awk '{if (match($0, /netmask=([[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/, obj)){print obj[1]}}')"
GATEWAY="$(cat /tmp/ks-networking|awk '{if (match($0, /gateway=([[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/, obj)){print obj[1]}}')"

# Run ./config-network with network params to auto-configure bonded interfaces
# for physical servers & non-bonded interfaces for virtual machine guests
./config-network -va kickstart -n "${IPADDR}" -s "${NETMASK}" -g "${GATEWAY}" > ${folder}/build/$(hostname)-$(date +%Y%m%d-%H%M)-config-network.log

while [ "${input}" != "yes" ]; then
  read -p "Continue? " input
done
continue=

%end
