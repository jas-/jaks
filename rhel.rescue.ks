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


# Force response from user
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
  echo '*                             Welcome!                                *'
  echo '*                                                                     *'
  echo '*  There are several tools provided in this environment to assist     *'
  echo '*  in performing a security audit of the filesystem(s) attached to    *'
  echo '*  to this system.                                                    *'
  echo '*                                                                     *'
  echo '*  Do you wish to continue?  Type "yes" to proceed                    *'
  echo '*                                                                     *'
  echo '***********************************************************************'
  read -p "Proceed with install? " install
done


# Assemble all physical disks/LVM's etc

# Perform chkrootkit analysis against volumes

# Perform clam-av scan against volumes

# Mount all volumes & create necessary chroot env

# Bind tools from live env to /chroot/usr/{bin,sbin}

# Perform rkhunter scan of chroot env

# Perform lynis hardening report

# Exit chroot env & remove chroot resources (/proc, /sys etc)

# Copy VM environment (KVM) for cuckoo file analysis & create a snapshot

# Use cuckoo to analyze files generated from chkrootkit, clam-av & lynis reports

# Clean up & exit

# Let the user know we are restarting
echo "Restarting ... "
shutdown -r now

%end

#fin