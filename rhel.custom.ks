# Begin pre-installation script
%pre --interpreter=/bin/bash --log /tmp/pre-install.log

# Setup the env (setting /dev/tty3 as default IO)
chvt 3
exec < /dev/tty3 > /dev/tty3 2>/dev/tty3

# Set $PATH to something robust
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

# Capture array of arguments
opts=($(cat /proc/cmdline))

# Iterate ${opts[@]} & extract args key/values
delcare -A args
if [ ${#opts[@]} -gt 1 ]; then
  for opt in "${opts[@]}"; do
    i=$((i+1))
    if [[ "${opt}" =~ = ]]; then
      key="$(echo "${opt}"|awk '{split($0, obj, "=");print obj[1]}')"
      value="$(echo "${opt}"|awk '{split($0, obj, "=");print obj[2]}')"
      args["${key}"]="${value}"
    else
      args[${i}]="${value}"
    fi
  done
fi

echo "${args[@]}"
sleep 15

# Force prompt if ${args[INSTALL]} not present
if [ -n "${args[INSTALL]}" ]; then
  install="no"
else
  install="yes"
fi

# Ensure user knows they are going to wipe out the machine
while [ "${install}" != "yes" ]; do
  clear
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
  echo '*  Do you wish to continue? Type "yes" to proceed                     *'
  echo '*                                                                     *'
  echo '***********************************************************************'
  echo
  read -p "Proceed with install? " install
done

# Clear the terminal
clear

# Prompt for root password, hash and write it out
if [ "${args[ROOTPW]}" == "" ]; then
  echo "Please enter root user password"
  pass="$(grub-crypt 2>/dev/null|tail -1)"
#else
  # Pass ${args[ROOTPW]} to grub-crypt regardless of stdin?
  # pass="${args[ROOTPW]}"
fi

# Write the hashed/salted ${pass} to /tmp/rootpw
echo "rootpw ${pass} --iscrypted" > /tmp/rootpw
cat /tmp/rootpw
sleep 5

# Set ${hostname}: ${args[HOSTNAME]} or value of `uname -n`
if [ "${args[HOSTNAME]}" == "" ]; then

  # If static DHCP enabled option 12 *might* contain the appropriate hostname
  hostname="$(uname -n|tr '[:lower:]' '[:upper:]')"
else
  hostname="$(echo "${args[HOSTNAME]}"|tr '[:lower:]' '[:upper:]')"
fi

# Set location to ${args[LOCATION]} or first 3 characters of ${hostname}
if [ "${args[LOCATION]}" == "" ]; then
  location="$(echo "\${hostname:0:3}")"
else
  location="${args[LOCATION]}"
fi

# NFS servers per location abbreviation (don't count on DNS)
declare -A nfs_servers
nfs_servers[PDX]="131.219.230.48"  # pdxnfsc01p
nfs_servers[SLC]="131.219.218.226" # slcnfsc01p

# Prompt for ${location} if it doesn't match the list
while [[ ! "${location}" =~ PPW|SLC ]]; do
  read -p "Physical location? [PPW|SLC] " location
done

# Mount point for NFS share
path="/var/tmp/unixbuild"

# Make sure the ${path} exists, make if not
if [ ! -d "${path}" ] ; then
  mkdir -p "${path}"
fi

# Write out /tmp/nfsshare file
echo "nfs --server=${nfs_servers[${location}]} --dir=${path}" > /tmp/nfsshare

# Set ${country} to geographic location (no way to auto-determine unless geoIP
# functionality exists in initramfs)
country="America"

# Set ${zone} based on ${location} value
case "${location}"; in
  PDX) zone="Los_Angeles" ;;
  SLC) zone="Denver" ;;
  *) zone="Los_Angeles" ;;
esac

# Write out /tmp/timezone
echo "timezone ${country}/${zone} --isUtc" > /tmp/timezone

# Use supplied ${args[IP]}, ${args[NETMASK]} & ${args[GATEWAY]} to write
# network configuration
echo "network --device=bond0 --bootproto=static --ip=${args[IP]} --netmask=${args[NETMASK]} --gateway=${args[GATEWAY]}" > /tmp/networking

%end

# Default installation settings

# Default language
lang en_US

# Default keyboard layout
keyboard us

# Include timezone
%include /tmp/timezone

# Include root password configuration
%include /tmp/rootpw

#platform x86, AMD64, or Intel EM64T

# Restart system after kicked
reboot

# Force text mode installation
text

# Use NFS share for installation media
%include /tmp/nfsshare

# Install GRUB
bootloader --location=mbr --append="rhgb quiet crashkernel=512MB audit=1"

# Clear out disk
zerombr
clearpart --all --initlabel

# Include disk configuration
%include /tmp/diskconfig

# Include networking configuration
%include /tmp/networking

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
%post --interpreter=/bin/bash

# Setup the env (setting /dev/tty3 as default IO)
chvt 3
exec < /dev/tty3 > /dev/tty3 2>/dev/tty3

# Set $PATH to something robust
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

# Capture array of arguments
opts=($(cat /proc/cmdline))

# Iterate ${opts[@]} & extract args key/values
delcare -A args
if [ ${#opts[@]} -gt 1 ]; then
  for opt in "${opts[@]}"; do
    i=$((i+1))
    if [[ "${opt}" =~ = ]]; then
      key="$(echo "${opt}"|awk '{split($0, obj, "=");print obj[1]}')"
      value="$(echo "${opt}"|awk '{split($0, obj, "=");print obj[2]}')"
      args["${key}"]="${value}"
    else
      args[${i}]="${value}"
    fi
  done
fi

# Set ${hostname}: ${args[HOSTNAME]} or value of `uname -n`
if [ "${args[HOSTNAME]}" == "" ]; then

  # If static DHCP enabled option 12 *might* contain the appropriate hostname
  hostname=$(uname -n|tr '[:lower:]' '[:upper:]')
else
  hostname="$(echo "${args[HOSTNAME]}"|tr '[:lower:]' '[:upper:]')"
fi

# Set location to ${args[LOCATION]} or first 3 characters of ${hostname}
if [ "${args[LOCATION]}" == "" ]; then
  location="$(echo "\${hostname:0:3}")"
else
  location="${args[LOCATION]}"
fi

# NFS servers per location abbreviation (don't count on DNS)
declare -A nfs_servers
nfs_servers[PDX]="131.219.230.48"  # pdxnfsc01p
nfs_servers[SLC]="131.219.218.226" # slcnfsc01p

# Prompt for ${location} if it doesn't match the list
while [[ ! "${location}" =~ PPW|SLC ]]; do
  read -p "Physical location? [PPW|SLC] " location
done

# Mount point for NFS share
path="/var/tmp/unixbuild"

# Make sure the ${path} exists, make if not
if [ ! -d "${path}" ] ; then
  mkdir -p "${path}"
fi

# Mount NFS share for %post processing
nfs=$(mount -t nfs -o nolock ${nfs_servers[${location}]} ${path})
if [ $? -ne 0 ]; then
  echo "An error occured mount ${nfs_servers[${location}]} @ ${path}, exiting"
  exit 1
fi

# Define a location for the RHEL build tool
build_tools="${path}/linux/build-tools/rhel-builder"

# Documentation @ http://moss.pacificorp.us/SiteDirectory/EntSys/Unix/OS/Documents/Servers%20and%20Hardware/Server%20Builds/RHEL%20Linux/rhel-builder.doc

# Make sure the NFS mount provided the directory
if [ ! -d "$(dirname "${build_tools})" ]; then
  echo "Unable to open $(dirname ${build_tools}), doesn't seem to exist on NFS share"
  exit 1
fi

# Does our build tool exist?
if [ ! -f "${build_tools}" ]; then
  echo "RHEL build tool doesn't seem to exist @ ${build_tools}"
  exit 1
fi

# Record a timestamped hostname string for build logs
folder=/var/tmp/$(hostname)-$(date +%Y%m%d-%H%M)

# Create a folder structure for operational logging
if [ ! -d "${folder}" ]; then
  mkdir -p ${folder}/{pre, post, build}
fi

# Go to $(dirname ${build_tools})
cd $(dirname ${build_tools})

# Run ${build_tools} to validate current configuration with logging
./${build_tools} -vc > ${folder}/pre/$(hostname)-$(date +%Y%m%d-%H%M).log

# Run ${build_tools} to make changes according to RHEL build guide standards
./${build_tools} -va kickstart > ${folder}/build/$(hostname)-$(date +%Y%m%d-%H%M).log

# Run ${build_tools} to validate changes
./${build_tools} -vc > ${folder}/post/$(hostname)-$(date +%Y%m%d-%H%M).log

# Examine 'post' build log for errors and make attempts to run each tool again

# Run the $(dirname ${build_tools})/scripts/config-network tool by itself
# because the argument requirements differ from all the other tools

# Once a second look & possible second run of failed tools is complete
# create an archive and put it somewhere for possible SOX compliance

%end
