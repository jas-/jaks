###############################################
# Begin %pre configuration script             #
###############################################
%pre --interpreter=/bin/bash


###############################################
# Environment variables & settings            #
###############################################

# Setup the env (setting /dev/tty3 as default IO)
chvt 3
exec < /dev/tty3 > /dev/tty3 2>/dev/tty3

# Set $PATH to something robust
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin


###############################################
# Default API arguments                       #
###############################################

# Set DEBUG = false, pauses occur at each report
DEBUG=false

# Set INSTALL = false; if not user is prompted to wipe system
# This will not prevent prompts if ROOTPW &/or LOCATION cannot be determined
INSTALL=false

# ROOTPW is empty but should be provided as command line arg to facilitate
# automation (no user interaction)
ROOTPW=

# LOCATION is empty but can be provided as command line arg to facilitate
# automation (no user interaction). If the HOSTNAME parameter first three
# characters match MST or PST this is not required for automation
LOCATION=

# HOSTNAME is empty but if provided & conforms to naming standard will be used
# to set LOCATION. Also, if HOSTNAME is not provided every attempt is made to
# use a DHCP provided hostname
HOSTNAME=

# IPADDR can be used to setup the network. If it is not provided the tool will
# attempt to obtain the value from anything provided by DHCP. It will take
# precedence over anything provided by DHCP as well
IPADDR=

# NETMASK like IPADDR can be used to setup the network. DHCP settings will be
# used in the event is not present.
NETMASK=

# GATEWAY can also be specified or the DHCP provided gateway will be used
GATEWAY=

# DVD is used for DVD or no network based installations
DVD=false

# Please see document for available server prefixes per timezone
# http://moss.pacificorp.us/SiteDirectory/EntSys/Unix/OS/Documents/Servers%20and%20Hardware/Server%20Builds/Server%20Naming%20Standard%20PPW.docx

# Naming standard prefix array for Pacific Standard Time systems
pst_prefix=(ALB AST BND COG COO CRC ENT GPS HDR KFL LIN MAD MED MER PBC PCC PDX
PEN PFO PMO POR ROS STA TER TOK WAL WIL)

# Naming standard prefix array for Mountain Standard Time systems
mst_prefix=(AMF BLU CAR CDC COD COT CUR DJP DEL DOG EDM EVA EWM GAD GRA GRC HNG
HTR HUR IDF JBP JOV LAK LAR LAV LAY MOA MON NAU OGD PAC PGA PIO PRC PRE RAW RCH
REX RIG RIV ROC SAN SAT SCC SHE SLC SMI TOO TRE UTB VER WBC)


###############################################
# General configuration variables             #
###############################################

# Global variable for hostname
hostname=

# Global variable for location
location=

# Mount point for NFS share
path="/unixshr/linux/kickstart"

# Set ${country} to geographic location (echo "Hostname: ${hostname}"
# no way to auto-determine unless geoIP functionality exists in initramfs)
country="America"

# Pacific Standard Time specific options
pst_nfsserver="131.219.230.48"  # pdxnfsc01p
pst_timezone="Los_Angeles"

# Mountain Standard Time specific options
mst_nfsserver="131.219.218.226" # slcnfsc01p
mst_timezone="Denver"

# Disk debugging log
dlog=/tmp/disks.log


###############################################
# Disk specific variables & templates         #
###############################################

# 100GB in bytes; definitively determines vm or physical installation
gbytes=107374182400

# Physical group creation variable
pv_tmpl="part {ID} --size={SIZE} --grow --ondisk={DISK}"

# 'optappvg' volgroup variable; used when phsyical disks > 1
vg_tmpl="volgroup optappvg {ID} --pesize=4096"

# 'optapplv' variable for logical volume creation
lv_tmpl="logvol /opt/app --fstype=ext4 --name=optapplv --vgname={VOLGROUP} \
--size={SIZE} --grow --percent=75"

# Define a template for disk configurations
read -d '' disk_template <<"EOF"
# Zero the MBR
zerombr

# Clear out partitions for {DISKS}
clearpart --all --initlabel --drives={DISKS}

# Create a /boot partition on {PRIMARY} of 500MB
part /boot --size=500 --fstype="ext4" --ondisk={PRIMARY}

# Create a memory partition of {SWAP}MB on {PRIMARY}
#part swap --size={SWAP} --ondisk={PRIMARY}

# Create an LVM partition of {SIZE}MB on {PRIMARY}
part pv.root --size={SIZE} --ondisk={PRIMARY} --grow --asprimary

# Create the root volume group
volgroup rootvg pv.root

# Create a memory partition of {SWAP}MB
logvol swap --fstype="swap" --name="swaplv" --vgname="rootvg" --size={SWAP}

# Create logical volume for the / mount point
logvol / --fstype="ext4" --name="rootlv" --vgname="rootvg" --size={ROOTLVSIZE}

# Create logical volume for the /var mount point
logvol /var --fstype="ext4" --name="varlv" --vgname="rootvg" --size={VARLVSIZE}

# Create logical volume for the /export/home mount point
logvol /export/home --fstype="ext4" --name="homelv" --vgname="rootvg" \
--size={HOMELVSIZE}

# Create logical volume for the /tmp mount point
logvol /tmp --fstype="ext4" --fsoptions=nosuid,nodev,noexec --name="tmplv" \
--vgname="rootvg" --size={TMPLVSIZE}

EOF

# 'Extra' disk report
read -d '' extra_disk_report <<"EOF"
Extended:
  Logical Volume Configuration:
    |_ optapppv       {disks}
    | |_ optappvg                   {size}MB
    |___|_ optapplv:  /opt/app      {optapp_size}MB
EOF

# 'VM' disk report
vm_disk_report="    |___|_ optapplv:  /opt/app      {optapp_size}MB"

# Final disk report
read -d '' disk_report <<"EOF"
Disk configuration:

Primary:
  Physical Partitions:
    |_ {disk}1:          /boot         500MB
  Logical Volume Configuration:
    |_ rootpv         {disk}
    | |_ rootvg                     {size}MB
    |   |_ swaplv:    swap          {swap}MB
    |   |_ rootlv:    /             {root_size}MB
    |   |_ varlv:     /var          {var_size}MB
    |   |_ homelv:    /export/home  {home_size}MB
    |   |_ tmplv:     /tmp          {tmp_size}MB
EOF


###############################################
# Function definitions - general              #
###############################################

# Pause function handle pausing if ${DEBUG} = true
function pause()
{
  local continue=
  while [ "${continue}" != "yes" ]; do
    read -p "Paused; Continue? " continue
    echo ""
  done
}

# Search array
function in_array()
{
  local args=("${@}")
  local needle="${args[0]}"
  local haystack=("${args[@]:1}")

  for i in ${haystack[@]}; do
    if [[ ${i} == ${needle} ]]; then
      return 0
    fi
  done

  return 1
}


# Function to handle moving build tools in %pre
# This might be best served as a recursive function
# to ensure we get the tools copied over
function copytools()
{
  # If /mnt/stage2 exists just get the tools from there
  if [ -d /mnt/stage2/build-tools ]; then

    # Copy tools from /mnt/stage2
    cp -fr /mnt/stage2/build-tools /tmp
  else

    # Local variable to handle device for mounting
    local point=

    # If /dev/sda1 is a block device use that to look for tools
    if [ -b /dev/sda1 ]; then
      point=/dev/sda1
    fi

    # If ${point} still empty & /dev/sr0 is a block device look there
    if [[ -b /dev/sr0 ]] && [[ "${point}" == "" ]]; then
      point=/dev/sr0
    fi

    # Make our mount point if it doesn't exist
    if [ ! -d /tmp/tfs ]; then
      mkdir /tmp/tfs
    fi

    # Mount ${point}
    mount ${point} /tmp/tfs

    # If it mounts try to get our build tools
    if [ -d /tmp/tfs/build-tools ]; then
      cp -fr /tmp/tfs/build-tools /tmp/
    fi

    # Unmount and cleanup
    umount /tmp/tfs
    rm -f /tmp/tfs
  fi
}


# Function to handle API boot params
function bootparams()
{
  # Capture array of arguments
  local opts=($(cat /proc/cmdline))

  # Iterate ${opts[@]} & extract args key/values
  if [ ${#opts[@]} -gt 1 ]; then
    for opt in "${opts[@]}"; do
      i=$((i+1))
      key="$(echo "${opt}"|awk '{split($0, obj, "=");print obj[1]}')"
      value="$(echo "${opt}"|awk '{split($0, obj, "=");print obj[2]}')"
      eval ${key}=${value}
    done
  fi
}


# Confirmation of installation function
function confirminstall()
{
  # Force prompt if ${INSTALL} not present
  if [ "${INSTALL}" != "true" ]; then
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
    echo '*  Do you wish to continue?  Type "yes" to proceed                    *'
    echo '*                                                                     *'
    echo '***********************************************************************'
    echo
    read -p "Proceed with install? " install
  done
}


# Configures the root user
function configureroot()
{

  # If ${ROOTPW} preset copy to ${pass}
  if [ "${ROOTPW}" != "" ]; then
    pass="${ROOTPW}"
  fi

  # Prompt for root password, hash and write it out
  while [ "${pass}" == "" ]; do
    echo "No root password specified; use ROOTPW=<pass> as boot arg to skip"
    read -sp "Enter root user password: " pass
    echo ""
  done

  # Write ${pass} to rootpw 
  echo "rootpw ${pass}" > /tmp/ks-rootpw
}


# Configure the hostname (either arg or dhcp)
function configurehostname()
{
  # Set ${hostname}: ${args[HOSTNAME]} or value of `uname -n`
  if [ "${HOSTNAME}" == "" ]; then

    # If static DHCP enabled option 12 *might* contain the appropriate hostname
    hostname="$(uname -n|awk '{print toupper($0)}')"
  else
    hostname="$(echo "${HOSTNAME}"|awk '{print toupper($0)}')"
  fi
}


# Configure the location
function configurelocation()
{
  # Set ${location} to ${LOCATION} or first 3 characters of ${hostname}
  if [ "${LOCATION}" == "" ]; then
    location="$(echo "${hostname:0:3}"|awk '{print toupper($0)}')"
  else
    location="$(echo "${LOCATION}"|awk '{print toupper($0)}')"
  fi

  # If ${location} != MST || PST then search 
  if [[ ! "${location}" =~ ^PST$ ]] && [[ ! "${location}" =~ ^MST$ ]]; then

    # Search for ${location} in ${mst_prefix}
    mst_res=$(in_array ${location} ${mst_prefix[@]})
    if [ $? -eq 0 ]; then
      location="MST"
      echo "Found MST as location"
    fi

    # Search for ${location} in ${pst_prefix}
    pst_res=$(in_array ${location} ${pst_prefix[@]})
    if [ $? -eq 0 ]; then
      location="PST"
      echo "Found PST as location"
    fi
  fi

  # Prompt for ${location} if it doesn't match the list
  while [[ ! "${location}" =~ ^PST$ ]] && [[ ! "${location}" =~ ^MST$ ]]; do
    echo "Could not determine location from hostname provided."
    read -p "Physical location? [MST|PST] " location
    echo ""
  done
}


# Setup NFS & timezone configurations
function configurenfszones()
{
  # Setup NFS & timezone for MST location
  if [ "${location}" == "MST" ]; then
    zone="${mst_timezone}"
    nfs_server="${mst_nfsserver}"
  fi

  # Setup NFS & timezone for PST location
  if [ "${location}" == "PST" ]; then
    zone="${pst_timezone}"
    nfs_server="${pst_nfsserver}"
  fi

  # Write out /tmp/timezone
  echo "timezone ${country}/${zone} --isUtc" > /tmp/ks-timezone

  # Write out /tmp/nfsshare file
  echo "nfs --server=${nfs_server} --dir=${path}" > /tmp/ks-nfsshare
}


###############################################
# Function definitions - math                 #
###############################################

# Calculate kilobytes to bytes
function kb2b()
{
  echo $(expr ${1} \* 1024)
}


# Calculate mb2bytes to bytes
function mb2b()
{
  echo $(expr ${1} \* 1024 \* 1024)
}


# Calculate gigabytes to MB
function gb2mb()
{
  echo $(expr ${1} \* 1024)
}


# Calculate gigabytes to KB
function gb2kb()
{
  echo $(expr ${1} \* 1024 \* 1024)
}


# Calculate gigabytes to bytes
function gb2b()
{
  echo $(expr ${1} \* 1024 \* 1024 \* 1024)
}


# Calculate kilobytes to MB
function kb2mb()
{
  echo $(expr ${1} / 1024)
}


# Calculate bytes to MB
function b2mb()
{
  echo $(expr ${1} / 1024 / 1024)
}


# Return bytes based on % of total
function percent()
{
  total=${1}
  percent=${2}

  echo $((${total} / 100 * ${percent}))
}


###############################################
# Function definitions - disks                #
###############################################

# Function to handle disk template creation for dynamic disks
function configuredisks()
{
  local disk="${1}"  # comma seperated list; i.e. sda:size,sdb:size etc
  local swap="${2}"  # swap disk space (physical memory x 1)

  local optapp=0     # Is set to 1 when multiple disks are used for /opt/app

  # Convert ${disks} into an array (${disks[@]})
  IFS=',' read -a disks <<< "${disk}"

  # If ${#disks[@]} > 1 send to 'multipledisks()' function
  if [ ${#disks[@]} -gt 1 ]; then

     # Call multipledisks() which creates a complex entry to handle /opt/app
    multipledisks "${disk}"

    # Set ${optapp} = 1 to prevent duplication on primary disk
    optapp=1
  fi

  # Copy ${disks[0]} to ${disk}
  local disk="$(echo "${disks[0]}"|awk '{split($0, obj, ":");print obj[1]}')"

  # Copy ${disks[0]} to ${size}
  local size=$(echo "${disks[0]}"|awk '{split($0, obj, ":");print obj[2]}')

  # Make a copy of ${size} for evaluating paritition scheme
  local evalsize=${size}

  # First remove 500 (/boot) & ${swap} from ${size}
  size=$(expr ${size} - $(expr $(mb2b 500) + ${swap}))

  # If the system is booted as UEFI vs. legacy BIOS we need to remove 200MB
  # because kickstart allocates 200MB as /boot/efi
  if [ -d /sys/firmware/efi ]; then
    size=$(expr ${size} - $(mb2b 200))
  fi

  # If ${evaldisk} size > 100GB; assume physical
  if [ ${evalsize} -gt ${gbytes} ]; then

    # 100GB / LVM
    root_size=$(gb2b 100)

    # 40GB /var LVM
    var_size=$(gb2b 40)

    # 10GB /export/home LVM
    home_size=$(gb2b 10)

    # 2GB /tmp LVM
    tmp_size=$(gb2b 2)
  fi

  # If ${evalsize} size == 100GB; assume vm
  if [ ${evalsize} -eq ${gbytes} ]; then

    # 40GB / LVM
    root_size=$(gb2b 40)

    # 20GB /var LVM
    var_size=$(gb2b 20)

    # 10GB /export/home LVM
    home_size=$(gb2b 10)

    # 2GB /tmp LVM
    tmp_size=$(gb2b 2)
  fi

  # If ${evaldisk} size < 100GB; split disk 
  if [ ${evalsize} -lt ${gbytes} ]; then

    # Allocate 40% of ${size} for /root (rootlv)
    root_size=$(percent ${size} 40)

    # Allocate 20% of ${size} for /var (varlv)
    var_size=$(percent ${size} 20)

    # Allocate 10% of ${size} for /export/home (homelv)
    home_size=$(percent ${size} 10)

    # Allocate 2% of ${size} for /tmp (tmplv)
    tmp_size=$(percent ${size} 2)
  fi

  # Validate that we have some partition sizes
  if [[ -z ${root_size} ]] || [[ -z ${var_size} ]] || [[ -z ${home_size} ]] || \
      [[ -z ${tmp_size} ]]; then
    echo "Partition sizes were not determined, exiting"
    exit 1
  fi

  # Add ${root_size}, ${var_size}, ${home_size} & ${tmp_size}
  total_parts=$(expr ${root_size} + ${var_size} + ${home_size} + ${tmp_size})

  # Calculate ${optapp_size} based on ${size} - ${total_parts}
  total_size=$(expr ${size} - ${total_parts})

  # Remove 2% overhead from ${optapp_size}
  optapp_size=$(expr ${total_size} - $(percent ${total_size} 2))

  # If /opt/app isn't defined create it in /tmp/ks-diskconfig-extra
  if [ ${optapp} -eq 0 ]; then
    echo "$(echo "${lv_tmpl}" |
      sed -e "s|{VOLGROUP}|rootvg|g" \
          -e "s|{SIZE}|$(b2mb ${optapp_size})|g")" >> /tmp/ks-diskconfig-extra

    # Also generate a report
    echo "${vm_disk_report}" |
      sed -e "s|{optapp_size}|$(b2mb ${optapp_size})|g" \
        > /tmp/ks-report-disks-extra
  fi

  # If ${DEBUG} is true log
  if [ "${DEBUG}" == "true" ]; then
    echo "" >> ${dlog}
    echo "PV: pv.root ${disk} $(b2mb ${size})MB (${size} bytes)" >> ${dlog}
    echo "VG Total: $(b2mb ${size})MB (${size} bytes)" >> ${dlog}
    echo "" >> ${dlog}
    echo "LV Total: $(b2mb ${total_parts})MB (${total_parts} bytes)" >> ${dlog}
    echo "  LV root: $(b2mb ${root_size})MB (${root_size} bytes)" >> ${dlog}
    echo "  LV var: $(b2mb ${var_size})MB (${var_size} bytes)" >> ${dlog}
    echo "  LV home: $(b2mb ${home_size})MB (${home_size} bytes)" >> ${dlog}
    echo "  LV tmp: $(b2mb ${tmp_size})MB (${tmp_size} bytes)" >> ${dlog}
    if [ ${optapp} -eq 0 ]; then
      echo "  LV optapp: $(b2mb ${optapp_size})MB (${optapp_size} bytes)" >> ${dlog}
    fi
  fi

  # Write out /tmp/ks-diskconfig using ${disk_template}
  echo "${disk_template}" |
    sed -e "s|{DISKS}|${disk}|g" \
        -e "s|{SWAP}|$(b2mb ${swap})|g" \
        -e "s|{SIZE}|$(b2mb ${size})|g" \
        -e "s|{PRIMARY}|${disk}|g" \
        -e "s|{ROOTLVSIZE}|$(b2mb ${root_size})|g" \
        -e "s|{VARLVSIZE}|$(b2mb ${var_size})|g" \
        -e "s|{HOMELVSIZE}|$(b2mb ${home_size})|g" \
        -e "s|{TMPLVSIZE}|$(b2mb ${tmp_size})|g" >> /tmp/ks-diskconfig

  # Write a report of the disk configuration
  echo "${disk_report}" |
    sed -e "s|{disk}|${disk}|g" \
        -e "s|{swap}|$(b2mb ${swap})|g" \
        -e "s|{size}|$(b2mb ${size})|g" \
        -e "s|{root_size}|$(b2mb ${root_size})|g" \
        -e "s|{var_size}|$(b2mb ${var_size})|g" \
        -e "s|{home_size}|$(b2mb ${home_size})|g" \
        -e "s|{tmp_size}|$(b2mb ${tmp_size})|g" >> /tmp/ks-report-disks

}


# Function to handle extending /opt/app with multiple disks
function multipledisks()
{
  local disk="${1}"

  # Convert ${disks} into an array (${disks[@]})
  #IFS=',' read -a disks <<< "${disk}"
  disks=($(echo "${disk}"|awk 'BEGIN{RS=","}{print $1}'|sort -t: -k1))

  # Make copy of ${disks[@]:1}yes
  local copy=(${disks[@]:1})

  # If ${DEBUG} is true log
  if [ "${DEBUG}" == "true" ]; then
    echo "Disk(s): ${copy[*]}" >> ${dlog}
  fi

  # Get rid of this ${primary} & ${size} are not used here

  # Get the first element as our primary volumegroup
  local primary="$(echo "${disks[0]}"|awk '{split($0, o, ":");print o[1]}')"

  # Get the size (in bytes) of our primary volumegroup
  local size=$(echo "${disks[0]}"|awk '{split($0, o, ":");print o[2]}')

  # If ${#copy[@]} > 1 then split & iterate extending the optappvg volume group
  if [ ${#copy[@]} -gt 1 ]; then

    # Set our counter to 0
    local i=0

    # Set iteration disk size to 0
    local msize=0

    # Set total volume group size to 0
    local vsize=0

    # Placeholder for the volume group list
    local vgrplst=

    # Iterate ${copy[@]} & split into disk & size
    for dsk in ${copy[@]}; do

      # Increment each iteration
      i=$((i+1))

      # Create a new physical group name
      local dname="pv.optapp.${i}"

      # Concatinate ${dname} for the volume group creation
      if [ "${vgrplst}" == "" ]; then
        vgrplst="${dname}"
      else
        vgrplst="${vgrplst} ${dname}"
      fi

      # Get the disk name from ${dsk}
      dskname="$(echo "${dsk}"|awk '{split($0, obj, ":");print obj[1]}')"

      # Get the ${msize}
      msize=$(echo "${dsk}"|awk '{split($0, obj, ":");print obj[2]}')

      # Remove 2% overhead from ${msize}
      tsize=$(expr ${msize} - $(percent ${msize} 2))

      # If ${DEBUG} is true log
      if [ "${DEBUG}" == "true" ]; then
        echo "PV: ${dname} [${dskname} $(b2mb ${msize})MB (${msize} bytes)] ${tsize}" >> ${dlog}
      fi

      # Add ${tsize} to ${vsize}
      vsize=$(expr ${tsize} + ${vsize})

      # Combine ${dskname} to ${rdn} create value of disks for disk report
      if [ "${rdn}" != "" ]; then
        rdn="${rdn}, ${dskname}"
      else
        rdn="${dskname}"
      fi

      # Make ks-diskconfig-extra with comment
      echo "" >> /tmp/ks-diskconfig-extra
      echo "# Create new physical volume on ${dskname} as ${dname}" \
        >> /tmp/ks-diskconfig-extra

      # Generate changes for ${pv_tmpl} and write to /tmp/ks-diskconfig-extra
      echo "$(echo "${pv_tmpl}" |
        sed -e "s|{ID}|${dname}|g" \
            -e "s|{SIZE}|$(b2mb ${tsize})|g" \
            -e "s|{DISK}|${dskname}|g")" >> /tmp/ks-diskconfig-extra

    done
  fi

  # Create a header for our volume group
  echo "" >> /tmp/ks-diskconfig-extra
  echo "# Create new volume group with all physical volumes" \
    >> /tmp/ks-diskconfig-extra

  # Generate changes for ${vg_tmpl} and write to /tmp/ks-diskconfig-extra
  echo "$(echo "${vg_tmpl}" |
    sed -e "s|{ID}|${vgrplst}|g")" >> /tmp/ks-diskconfig-extra

  # Create a header for our the logical volume
  echo "" >> /tmp/ks-diskconfig-extra
  echo "# Create new logical volume for optapp" \
    >> /tmp/ks-diskconfig-extra

  # Generate changes for ${lv_tmpl} and write to /tmp/ks-diskconfig-extra
  echo "$(echo "${lv_tmpl}" |
    sed -e "s|{VOLGROUP}|optappvg|g" \
        -e "s|{SIZE}|$(b2mb ${vsize})|g")" >> /tmp/ks-diskconfig-extra

  # Generate report for 'extra' disks
  echo "${extra_disk_report}" |
    sed -e "s|{size}|$(b2mb ${vsize})|g" \
        -e "s|{disks}|${rdn}|g" \
        -e "s|{optapp_size}|$(b2mb ${vsize})|g" > /tmp/ks-report-disks-extra
}


###############################################
# Network configuration functions             #
###############################################

# IPv4 validation function
function valid_ip()
{
  local  ip=${1}
  local  stat=1

  if [[ ${ip} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    OIFS=$IFS
    IFS='.'
    ip=(${ip})
    IFS=$OIFS
    if [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && \
      ${ip[3]} -le 255 ]]; then
      stat=$?
    fi
  fi

  echo $stat
}

# Configure the network based on argument list
function configurenetwork()
{
  # Set /tmp/ks-networking to prevent failures
  echo "" > /tmp/ks-networking

  # Use ${ip}, ${netmask} & ${gateway} if present from command line args
  # Only copy these values if ${IPADDR}, ${NETMASK} & ${GATEWAY} don't exist
  # to ensure ability to set network to something other than possible build net
  if [[ "${ip}" != "" ]] && [[ "${netmask}" != "" ]] && \
      [[ "${gateway}" != "" ]] && [[ "${IPADDR}" == "" ]] && \
      [[ "${NETMASK}" == "" ]] && [[ "${GATEWAY}" == "" ]]; then

    # Make sure they are valid
    if [[ $(valid_ip "${ip}") -eq 0 ]] || \
        [[ $(valid_ip "${netmask}") -eq 0 ]] || \
        [[ $(valid_ip "${gateway}") -eq 0 ]]; then
      IPADDR=${ip}
      NETMASK=${netmask}
      GATEWAY=${gateway}
    fi
  fi

  # Is ${IPADDR}, ${NETMASK} & ${GATEWAY} present from args list?
  if [[ "${IPADDR}" != "" ]] && [[ "${NETMASK}" != "" ]] && \
      [[ "${GATEWAY}" != "" ]]; then
  
    # Validate IPv4 addresses for ${IPADDR}, ${NETMASK} & ${GATEWAY}
    if [[ $(valid_ip "${IPADDR}") -ne 0 ]] || \
        [[ $(valid_ip "${NETMASK}") -ne 0 ]] || \
        [[ $(valid_ip "${GATEWAY}") -ne 0 ]]; then

      # Be informative about the failure
      [[ $(valid_ip "${IPADDR}") -ne 0 ]] && echo "${IPADDR} is invalid"
      [[ $(valid_ip "${NETMASK}") -ne 0 ]] && echo "${NETMASK} is invalid"
      [[ $(valid_ip "${GATEWAY}") -ne 0 ]] && echo "${GATEWAY} is invalid"
      exit 1
    fi

    # Update /tmp/ks-arguments with network information
    sed -i "s/^IPADDR.*/IPADDR ${IPADDR}/g" /tmp/ks-arguments
    sed -i "s/^NETMASK.*/NETMASK ${GATEWAY}/g" /tmp/ks-arguments
    sed -i "s/^GATEWAY.*/GATEWAY ${GATEWAY}/g" /tmp/ks-arguments
  else

    # Check to see if anything was applied via DHCP
    IPADDR="$(ifconfig eth0 | grep inet | cut -d : -f 2 | cut -d " " -f 1)"
    NETMASK="$(ifconfig eth0 | grep inet | cut -d : -f 4 | head -1)"
    GATEWAY="$(route -n | grep ^0.0.0.0 | cut -b 17-32 | cut -d " " -f 1)"

    # Validate IPv4 addresses for ${IPADDR}, ${NETMASK} & ${GATEWAY}
    if [[ $(valid_ip "${IPADDR}") -ne 0 ]] || \
        [[ $(valid_ip "${NETMASK}") -ne 0 ]] || \
        [[ $(valid_ip "${GATEWAY}") -ne 0 ]]; then

      # Be informative about the failure
      [[ $(valid_ip "${IPADDR}") -ne 0 ]] && echo "${IPADDR} is invalid"
      [[ $(valid_ip "${NETMASK}") -ne 0 ]] && echo "${NETMASK} is invalid"
      [[ $(valid_ip "${GATEWAY}") -ne 0 ]] && echo "${GATEWAY} is invalid"
      exit 1
    fi

    # Update /tmp/ks-arguments with network information
    sed -i "s/^IPADDR.*/IPADDR ${IPADDR}/g" /tmp/ks-arguments
    sed -i "s/^NETMASK.*/NETMASK ${GATEWAY}/g" /tmp/ks-arguments
    sed -i "s/^GATEWAY.*/GATEWAY ${GATEWAY}/g" /tmp/ks-arguments
  fi

  # Use supplied ${IPADDR}, ${NETMASK} & ${GATEWAY} to write network config
  echo "network --bootproto=static --hostname=${hostname} --ip=${IPADDR} \
    --netmask=${NETMASK} --gateway=${GATEWAY}" > /tmp/ks-networking

}


###############################################
# Handling boot parameters                    #
###############################################

# Set up the API defaults provided from /proc/cmdline
bootparams

# Clear the terminal
clear

###############################################
# Copy build tools to temporary memory fs     #
###############################################

# Set up the API defaults provided from /proc/cmdline
copytools

# Clear the terminal
clear


###############################################
# If ${INSTALL} != true, require confirmation #
###############################################

# Make sure user knows it will wipe out the system
confirminstall

# Clear the terminal
clear


###############################################
# Configuration for the root password         #
###############################################

# Handle root password
configureroot

# Clear the terminal
clear


###############################################
# Configuration for the hostname              #
###############################################

# Configure the hostname
configurehostname

# Clear the terminal
clear


###############################################
# Configuration for the physical location     #
###############################################

# Configure the physical location
configurelocation

# Clear the terminal
clear


###############################################
# Configuration for the NFS share & zone      #
###############################################

# Setup timezone & NFS specific configurations
configurenfszones

# Clear the terminal
clear

###############################################
# Create a simple to parse file of options    #
###############################################

# Write arguments to /tmp/ks-arguments
cat <<EOF > /tmp/ks-arguments
DEBUG ${DEBUG}
INSTALL ${INSTALL}
DVD ${DVD}
LOCATION ${LOCATION}
HOSTNAME ${HOSTNAME}
IPADDR ${IPADDR}
GATEWAY ${GATEWAY}
EOF


###############################################
# Print out a general configuration report    #
###############################################

# Generate a report of general configuration
cat <<EOF > /tmp/ks-report-general
General options:
  DEBUG:         ${DEBUG}
  INSTALL:       ${INSTALL}
  ROOTPW:        ${pass}

Location options:
  COUNTRY:       ${country}
  TIMEZONE:      ${zone}
  LOCATION:      ${location}

NFS server:
  SERVER:        ${nfs_server}
  SHARE:         ${path}

EOF

# Clear the terminal
clear
cat /tmp/ks-report-general

# If ${DEBUG} is set to true; pause
if [ "${DEBUG}" == "true" ]; then
  pause
fi


###############################################
# Configuration for DVD installations         #
###############################################

# If ${DVD} set to true write out a config
if [ "${DVD}" == "true" ]; then
  echo "cdrom" > /tmp/ks-installation
else
  touch /tmp/ks-installation
fi


###############################################
# Configuration for the networking            #
###############################################

# Generate networking configuration
configurenetwork

# Clear the terminal
clear

###############################################
# Print out the network configuration report  #
###############################################

# Generate a report of general configuration
cat <<EOF > /tmp/ks-report-network
Network configuration:
  HOSTNAME:      ${hostname}
  IPADDR:        ${IPADDR}
  NETMASK:       ${NETMASK}
  GATEWAY:       ${GATEWAY}

EOF

# Print the report
cat /tmp/ks-report-network

# If ${DEBUG} is set to true; pause
if [ "${DEBUG}" == "true" ]; then
  pause
fi


###############################################
# Configuration for physical disks            #
###############################################

# Determine the amount of memory on the system, used for our swap partition
swap=$(kb2b $(cat /proc/meminfo|awk '$0 ~ /^MemTotal/{print $2}'))

# If ${DEBUG} is true log
if [ "${DEBUG}" == "true" ]; then
  echo "Boot: 500MB ($(mb2b 500) bytes)" >> ${dlog}
  echo "Swap: $(b2mb ${swap})MB (${swap} bytes)" >> ${dlog}
fi

# Get a collection of physical disks
#  Filters disk partitions & converts blocks to bytes
dsks=($(cat -n /proc/partitions |
        awk '$1 > 1 && $5 ~ /^s[a-z]+$/{print $5":"$4 * 1024}'|sort -t: -k1))

# If ${DEBUG} is true log
if [ "${DEBUG}" == "true" ]; then
  echo "Disk(s): ${dsks}" >> ${dlog}
  echo "" >> ${dlog}
fi

# Make sure ${disks[@]} is > 0
if [ ! ${#dsks[@]} -gt 0 ]; then
  echo "No physical disks present! Cannot create necessary disk configuration"
  exit 1
fi

# Iterate ${disks[@]} & remove USB devices
for item in ${dsks[@]}; do

  # Extract the disk
  disk="$(echo "${item}"|awk '{split($0, o, ":");print o[1]}')"

  # Extract the disk size
  size="$(echo "${item}"|awk '{split($0, o, ":");print o[2]}')"

  # Skip ${disk} if it is a USB device
  link="$(readlink -f /sys/class/block/${disk}/device|grep usb)"

  if [ "${link}" == "" ]; then

    # Wipe the MBR of each disk to account for 'clearpart' deficiencies
    bogus=$(dd if=/dev/zero of=/dev/${disk} bs=1 count=512)

    disks+=("${disk}:${size}")

    # If ${DEBUG} is true log
    if [ "${DEBUG}" == "true" ]; then
      echo "Wiped: ${disk} $(b2mb ${size})MB (${size} bytes)" >> ${dlog}
    fi

  fi
done

# If ${#disks[@]} > 1 combine as a comma seperated list
if [ ${#disks[@]} -gt 1 ]; then
  dsk="${disks[@]}"
  disks="${dsk// /,}"
fi

# Create disk configuration files /tmp/ks-diskconfig & /tmp/ks-diskconfig-extra
configuredisks "${disks}" "${swap}"


###############################################
# Print out the disk configuration report     #
###############################################

# Make sure our disk configuration file exist
if [[ ! -f /tmp/ks-diskconfig ]] || [[ ! -f /tmp/ks-diskconfig-extra ]]; then
  echo "Disk configuration files were not created"
  exit 1
fi

# Combine disk configuration files & remove temporary
cat /tmp/ks-diskconfig-extra >> /tmp/ks-diskconfig

# Remove the combined disk configuration
rm /tmp/ks-diskconfig-extra

# Make sure our disk report files exist
if [[ ! -f /tmp/ks-report-disks ]] || \
    [[ ! -f /tmp/ks-report-disks-extra ]]; then
  echo "Disk report files were not created"
  exit 1
fi

# Combine disk report files & remove temporary
cat /tmp/ks-report-disks-extra >> /tmp/ks-report-disks
rm /tmp/ks-report-disks-extra

# Clear the terminal
clear

# Print the disk configuration report
cat /tmp/ks-report-disks
echo ""

# If ${DEBUG} is set to true; pause
if [ "${DEBUG}" == "true" ]; then
  pause
fi


%end
###############################################
# End %pre configuration script             #
###############################################


###############################################
# Begin kick start automation procedures      #
###############################################

# Setup the installation media (if any)
%include /tmp/ks-installation

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

# Use NFS or DVD for installation media
%include /tmp/ks-nfsshare

# Include disk configuration
%include /tmp/ks-diskconfig

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

# Provide a local REPO
repo --name="Red Hat Enterprise Linux"  --baseurl=file:/mnt/source --cost=100

# Handle package installation
%packages
@base
%end
###############################################
# End kick start automation procedures      #
###############################################


###############################################
# Begin %post non-chroot configuration        #
###############################################
%post --nochroot --interpreter=/bin/bash --erroronfail


###############################################
# Environment variables, functions & settings #
###############################################

# Setup the env (setting /dev/tty3 as default IO)
chvt 3
exec < /dev/tty3 > /dev/tty3 2>/dev/tty3

clear

# Set $PATH to something robust
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

# Pause function handle pausing if ${DEBUG} = true
function pause() {
  local continue=
  while [ "${continue}" != "yes" ]; do
    read -p "Paused; continue? " continue
    echo ""
  done
}

# Set our env variables from /tmp/ks-arguments
DEBUG="$(cat /tmp/ks-arguments|awk '$0 ~ /^DEBUG/{print $2}')"
INSTALL="$(cat /tmp/ks-arguments|awk '$0 ~ /^INSTALL/{print $2}')"
DVD="$(cat /tmp/ks-arguments|awk '$0 ~ /^DVD/{print $2}')"
HOSTNAME="$(cat /tmp/ks-arguments|awk '$0 ~ /^HOSTNAME/{print $2}')"
IPADDR="$(cat /tmp/ks-arguments|awk '$0 ~ /^IPADDR/{print $2}')"
NETMASK="$(cat /tmp/ks-arguments|awk '$0 ~ /^NETMASK/{print $2}')"
GATEWAY="$(cat /tmp/ks-arguments|awk '$0 ~ /^GATEWAY/{print $2}')"


###############################################
# Create mount point for NFS share in chroot  #
###############################################

# Mount point for NFS share or DVD build-tool configuration
path="/mnt/sysimage/var/tmp/unixbuild"

# Make sure the ${path} exists, make if not
if [ ! -d "${path}" ] ; then
  mkdir -p "${path}"
fi


###############################################
# If ${DVD} is true copy tools from DVD       #
###############################################

# If ${DVD} set is false get NFS mounts ready
if [ "${DVD}" == "true" ]; then

  # Copy the local DVD build-tools to the local chroot env
  mkdir -p ${path}/linux/build-tools
  cp -fr /tmp/build-tools/* ${path}/linux/build-tools/

  # Generate a %pre (non-chroot) configuration report
  cat <<EOF > /tmp/ks-report-post
Post installation: (pre-chroot)
  ENV:
    - Copied configurations to chroot environment
    - Copied RHEL build tools to chroot environment

EOF

fi

###############################################
# Aquire NFS server settings for chroot env   #
###############################################

# Attempt to get our previously written ${nfs_share} from /tmp/ks-nfsshare
if [ ! -f /tmp/ks-nfsshare ]; then
  echo "/tmp/ks-nfsshare file is missing, exiting"
  do_mount=false
else

  # Split up /tmp/ks-nfsshare to get our nfs server
  nfs_server="$(cat /tmp/ks-nfsshare |
    awk '$0 ~ /^nfs/{split($2, obj, "=");print obj[2]}')"
fi

# Make sure we have something for ${nfs_server}
if [ "${nfs_server}" == "" ]; then
  echo "Could not get the NFS server"
  do_mount=false
fi


###############################################
# Make sure the NFS server is accessible      #
###############################################

# Make sure we can connect to ${nfs_server}
ping=$(ping -c1 ${nfs_server})
if [ $? -ne 0 ]; then
  echo "Could not contact the ${nfs_server}, check routing table (gateway)"
  do_mount=false
fi


###############################################
# Setup NFS mount in chroot @ /mnt/sysimage   #
###############################################

# IF ${do_mount} != false (NFS server online) ignore ${DVD} & mount NFS share
# to ensure we are using the latest build configuration tools
if [ "${do_mount}" != "false" ]; then

  # Mount NFS share for %post processing
  nfs=$(mount -t nfs -o nolock ${nfs_server}:/unixshr ${path})
  if [ $? -ne 0 ]; then
    echo "An error occured mount ${nfs_server} @ ${path}, exiting"
  fi

  # Generate a %pre (non-chroot) configuration report
  cat <<EOF > /tmp/ks-report-post
Post installation: (pre-chroot)
  ENV:
    - Copied configurations to chroot environment
  NFS:
    - Created NFS mount points
    - Verified NFS server responding to ICMP requests
    - Mounted NFS server in chroot environment

EOF

fi

###############################################
# Expose /tmp/ks* files to chroot env         #
###############################################

# Copy all of our configuration files from %pre to /mnt/sysimage/tmp
cp /tmp/ks* /mnt/sysimage/tmp

###############################################
# Print %post (non-chroot) report             #
###############################################

# Clear the terminal
clear
cat /tmp/ks-report-post

# If ${DEBUG} is set to true; pause
if [ "${DEBUG}" == "true" ]; then
  pause
fi


%end
###############################################
# End %post non-chroot configuration        #
###############################################


###############################################
# Begin %post chroot configuration            #
###############################################
%post --interpreter=/bin/bash --erroronfail


###############################################
# Environment variables, functions & settings #
###############################################

# Setup the env (setting /dev/tty3 as default IO)
chvt 3
exec < /dev/tty3 > /dev/tty3 2>/dev/tty3

# Set $PATH to something robust
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

clear

# Pause function handle pausing if ${DEBUG} = true
function pause() {
  local continue=
  while [ "${continue}" != "yes" ]; do
    read -p "Paused; continue? " continue
    echo ""
  done
}

# Set our env variables from /tmp/ks-arguments
DEBUG="$(cat /tmp/ks-arguments|awk '$0 ~ /^DEBUG/{print $2}')"
INSTALL="$(cat /tmp/ks-arguments|awk '$0 ~ /^INSTALL/{print $2}')"
HOSTNAME="$(cat /tmp/ks-arguments|awk '$0 ~ /^HOSTNAME/{print $2}')"
IPADDR="$(cat /tmp/ks-arguments|awk '$0 ~ /^IPADDR/{print $2}')"
NETMASK="$(cat /tmp/ks-arguments|awk '$0 ~ /^NETMASK/{print $2}')"
GATEWAY="$(cat /tmp/ks-arguments|awk '$0 ~ /^GATEWAY/{print $2}')"

# Mount point for NFS share
path="/var/tmp/unixbuild"

# Define a location for the RHEL build tool
build_tools="${path}/linux/build-tools"


###############################################
# Validate build-tools location (NFS mount)   #
###############################################

# Make sure the NFS mount provided the directory
if [ ! -d "${build_tools}" ]; then
  echo "Unable to open ${build_tools}"
  exit 1
fi


###############################################
# Validate build-tools exist (actual file)    #
###############################################

# Does our build tool exist?
if [ ! -f "${build_tools}/rhel-builder" ]; then
  echo "RHEL build tool doesn't seem to exist @ ${build_tools}/rhel-builder"
  exit 1
fi


###############################################
# Create build audit folder structure         #
###############################################

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

# Go to ${build_tools}
cd ${build_tools}

echo "Please wait; auto-configuring system according to build standards"


###############################################
# Run build-tools to validate current env.    #
###############################################

# Run ${build_tools} to validate current configuration with logging
./rhel-builder -vc \
  > ${folder}/pre/$(hostname)-$(date +%Y%m%d-%H%M).log 2>/dev/null


###############################################
# Configure according to RHEL build standard  #
###############################################

# Run ${build_tools} to make changes according to RHEL build guide standards
./rhel-builder -va kickstart \
  > ${folder}/build/$(hostname)-$(date +%Y%m%d-%H%M).log 2>/dev/null


###############################################
# Run build-tools to validate build           #
###############################################

# Run ${build_tools} to validate changes
./rhel-builder -vc \
  > ${folder}/post/$(hostname)-$(date +%Y%m%d-%H%M).log 2>/dev/null


###############################################
# Examine post build log for errors           #
###############################################

# log file name
log_file="${folder}/build/$(hostname)-$(date +%Y%m%d)*.log"

# Get total number of tools configured to run
total=$(awk '$0 ~ /^\[/{print}' rhel-builder|wc -l)

# Get an array of configuration scripts that were run
tools=($(awk '$0 ~ /^Executing:/{print $2}' ${log_file}))

# Provide the total number of scripts run
total_tools=${#tools[@]}

# Get an array of configuration scripts that failed
failed_tools=($(awk '{if (match($0, /.*An error.*\.(.*);.*/, obj)){print "."substr(obj[1], 1, length(obj[1]-1))}}' ${log_file}))

# Provide the total number of failed scripts run
total_failed_tools=${#failed_tools[@]}

# Get an array of configuration scripts that succeeded
successful_tools=($(awk '{if (match($0, /.*\.(.*)'\''.*successfully.*/, obj)){print "."obj[1]}}' ${log_file}))

# Provide the total number of failed scripts run
total_successful_tools=${#successful_tools[@]}


###############################################
# Re-run failed jobs individually             #
###############################################

# Should this be implemented? Or just force review of the logs?


###############################################
# Check for config-network tool               #
###############################################

# Run the $(dirname ${build_tools})/scripts/config-network tool by itself
# because the argument requirements differ from all the other tools

# Exit if config-network tool doesn't exist
if [ ! -f ${build_tools}/scripts/config-network ]; then
  echo "${build_tools}/scripts/config-network missing"
  exit 1
fi

# Change into scripts/ subfolder if scripts/config-network exists
cd ${build_tools}/scripts/  

# Make sure our configuration data exists
if [ ! -f /tmp/ks-networking ]; then
  echo "/tmp/ks-networking file is missing, exiting"
  exit 1
fi


###############################################
# Get network parameters for config-network   #
###############################################

# Obtain ${IPADDR}, ${NETMASK} & ${GATEWAY} from /tmp/ks-networking
net="$(cat /tmp/ks-networking)"
IPADDR="$(echo "${net}" |
  awk '{if (match($0, /ip=([[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/, obj)){print obj[1]}}')"
NETMASK="$(echo "${net}" |
  awk '{if (match($0, /netmask=([[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/, obj)){print obj[1]}}')"
GATEWAY="$(echo "${net}" |
  awk '{if (match($0, /gateway=([[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/, obj)){print obj[1]}}')"


###############################################
# Configure network (802.1 or single) adapter #
###############################################

# Run ./config-network with network params to auto-configure bonded interfaces
# for physical servers & non-bonded interfaces for virtual machine guests
./config-network -va kickstart -n "${IPADDR}" -s "${NETMASK}" -g "${GATEWAY}" \
  > ${folder}/build/$(hostname)-$(date +%Y%m%d-%H%M)-config-network.log 2>/dev/null


###############################################
# Generate a %post (chroot) report            #
###############################################

# Generate a %post (chroot) configuration report
cat <<EOF > /tmp/ks-report-post-chroot
Post installation: (chroot)
  ENV:
    - Validation of build tool existence
    - Creation of reporting structure for build process
  BUILD:
    - Logs for each stage of configuration created
    - Statistical information for build:
      - Total tools run:         ${total_tools}
      - Total successful tools:  ${total_successful_tools}
      - Total failed tools:      ${total_failed_tools}
  BACKUP:
    - Backup of kickstart configurations:
      - Location & timezone configuration
      - Default root user configuration
      - NFS installation configuration
      - Physical disk configuration
    - Backup of build logs:
      - Pre RHEL build configuration validation
      - RHEL build configuration results
      - Post RHEL build configuration validation
    - Secured reports & configurations @ /root/$(hostname)-$(date +%Y%m%d)

EOF


###############################################
# Create backup of build configuration files  #
###############################################

# Make a backup of /tmp/ks* to ${folder}/kickstart
rm /tmp/ks-script-*
cp /tmp/ks* ${folder}/kickstart

# Organize the files
mkdir ${folder}/kickstart/configs

# Create a timestamped filename
filename=${folder}/$(hostname)-$(date +%Y%m%d).log

# Combine the reports
cat ${folder}/kickstart/ks-report-general > ${filename}
cat ${folder}/kickstart/ks-report-network >> ${filename}
cat ${folder}/kickstart/ks-report-disks >> ${filename}
cat ${folder}/kickstart/ks-report-post >> ${filename}
cat ${folder}/kickstart/ks-report-post-chroot >> ${filename}

# Remove the old reports
rm ${folder}/kickstart/ks-report*

# Move the configuration files used
mv ${folder}/kickstart/ks-* ${folder}/kickstart/configs

# Move the ks.cfg to the current hostname.ks
mv ${folder}/kickstart/ks.cfg ${folder}/kickstart/$(hostname).ks

# Remove everything else
rm ${folder}/ks-*

# Move build logs into their own folder
mkdir -p ${folder}/build-logs
mv -f ${folder}/pre ${folder}/build-logs
mv -f ${folder}/build ${folder}/build-logs
mv -f ${folder}/post ${folder}/build-logs

###############################################
# Setup appropriate permissions on backup     #
###############################################

# Set some permissions to account for root pw
chown -R root:root ${folder}
chmod -R 600 ${folder}

###############################################
# Print %post (non-chroot) report             #
###############################################

# Clear the terminal
clear
cat /tmp/ks-report-post-chroot

# If ${DEBUG} is set to true; pause
if [ "${DEBUG}" == "true" ]; then
  pause
fi

%end
###############################################
# End %post chroot configuration              #
###############################################

#fin