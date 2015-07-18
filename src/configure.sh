#!/bin/bash
set -e

log_file="installation.log"

#Repo list, repo for Devian is dynamic
REPO_URL_CENTOS6="http://yum.puppetlabs.com/puppetlabs-release-el-6.noarch.rpm"
REPO_URL_CENTOS7="http://yum.puppetlabs.com/puppetlabs-release-el-7.noarch.rpm"

##--------------------------------------------##
flavour=""

print_msg() {
  case $1 in
      "red" )
          msg="\e[1;31m $2" ;;
      "green" )
          msg="\e[1;32m $2" ;;
      "cyan" )
          msg="\e[1;36m $2" ;;
  esac
  
  echo -e "$msg \e[0m"
}

get_distribution_type()
{
    local dtype
    # Assume unknown
    dtype="unknown"

    # First test against Fedora / RHEL / CentOS / generic Redhat derivative
    if [ -r /etc/rc.d/init.d/functions ]; then
        source /etc/rc.d/init.d/functions
        [ zz`type -t passed 2>/dev/null` == "zzfunction" ] && dtype="redhat"

    # Then test against Debian, Ubuntu and friends
    elif [ -r /lib/lsb/init-functions ]; then
        source /lib/lsb/init-functions
        [ zz`type -t log_begin_msg 2>/dev/null` == "zzfunction" ] && dtype="debian"

    fi
    echo $dtype
}

check_if_root()
{
  if [ "$(id -u)" != "0" ]; then
    print_msg "red" "This script must be run as root :-o" >&2
    exit 1
  else
    print_msg "green" "Ok"
  fi
}

update_system()
{
   #If not present install lsb_release
   if [ "$1" = "redhat" ]; then
      yum update -y 2>&1 >> $log_file

   elif [ "$1" = "debian" ]; then
      apt-get update -y 2>&1 >> $log_file
   fi
   
   print_msg "green" "Ok"
}

install_repo()
{

   if [ "$flavour" = "redhat" ]; then

    #Check if CentOS then install puppet repo
    if grep -Fxq "CentOS" /etc/redhat-release ; then

      if [ grep -q -i "release 6" /etc/redhat-release ]; then
        REPO_URL=REPO_URL_CENTOS6
      fi

      if [ grep -q -i "release 7" /etc/redhat-release ]; then
        REPO_URL=REPO_URL_CENTOS7
      fi

      #If found a REPO the install
      if [ ! -z "$REPO_URL" -a "$REPO_URL" != " " ]; then
        print_msg "cyan" "Installing CentOS repo $REPO_URL"
        rpm -i "${REPO_URL}" 2>&1 >> $log_file
      fi

     if [ "$REPO_URL" != "" ]; then
        rpm -i "${REPO_URL}"
        print_msg "green" "Ok"
     else
        print_msg "cyan" "Nothing to do"
     fi

    fi

   elif [ "$flavour" = "debian" ]; then
      . /etc/lsb-release
      REPO_URL="http://apt.puppetlabs.com/puppetlabs-release-${DISTRIB_CODENAME}.deb"
      repo_deb_path=$(mktemp)
      print_msg "cyan" "Installing Debian repo $REPO_URL"
      wget --output-document="${repo_deb_path}" "${REPO_URL}" 2>&1 >> $log_file
      dpkg -i "${repo_deb_path}" 2>&1 >> $log_file
   fi

}

install_puppet_module()
{
  print_msg "cyan" "Installing Puppet module $1"
  modules_list="$(puppet module list)"
  if [[ $modules_list != *"$1"* ]]; then
    puppet module install $1
    print_msg "green" "Ok"
  else
    print_msg "cyan" "Module already installed"
  fi
  
}


install_package()
{
   print_msg "cyan" "Installing $1..."
   if [ "$flavour" = "redhat" ]; then
      yum install -y $1 2>&1 >> $log_file

   elif [ "$flavour" = "debian" ]; then
      apt-get install -y $1 2>&1 >> $log_file
   fi
   print_msg "green" "Ok"
}


##--------------------------------------------##

#Getting Linux Flavour
flavour=$(get_distribution_type)
print_msg "cyan" "Linux flavour: $flavour"

print_msg "cyan" "Checking user rights"
check_if_root

print_msg "cyan" "Updating system"
update_system $flavour

print_msg "cyan" "Installing lsb"
if [ "$flavour" = "redhat" ]; then
  install_package "redhat-lsb"

elif [ "$flavour" = "debian" ]; then
  install_package "lsb-release"
  install_package "rpm"
fi

print_msg "cyan" "Installing Puppet repo"
install_repo

install_package "puppet"

install_puppet_module "jfryman-nginx"
install_puppet_module "jfryman-selinux"
install_puppet_module "puppetlabs-vcsrepo"
install_puppet_module "puppetlabs-git"
install_puppet_module "puppetlabs-firewall"

print_msg "cyan" "Running Puppet"

path="$(pwd)/manifests/"
print_msg "cyan" "Running Puppet using $path"

puppet apply $path 2>&1 | tee $log_file
print_msg "cyan" "Done!"