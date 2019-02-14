RED_COLOR='\033[0;31m'
GREEN_COLOR='\033[0;32m'
NO_COLOR='\033[0m'

# Encryption
ciphers=(
  aes-128-cfb
  aes-192-cfb
  aes-256-cfb
  chacha20
  salsa20
  rc4-md5
  aes-128-ctr
  aes-192-ctr
  aes-256-ctr
  aes-256-gcm
  aes-192-gcm
  aes-128-gcm
  camellia-128-cfb
  camellia-192-cfb
  camellia-256-cfb
  chacha20-ietf
  bf-cfb
)
# current/working directory
CUR_DIR=`pwd`

init_release(){
  if [ -f /etc/os-release ]; then
      # freedesktop.org and systemd
      . /etc/os-release
      OS=$NAME
  elif type lsb_release >/dev/null 2>&1; then
      # linuxbase.org
      OS=$(lsb_release -si)
  elif [ -f /etc/lsb-release ]; then
      # For some versions of Debian/Ubuntu without lsb_release command
      . /etc/lsb-release
      OS=$DISTRIB_ID
  elif [ -f /etc/debian_version ]; then
      # Older Debian/Ubuntu/etc.
      OS=Debian
  elif [ -f /etc/SuSe-release ]; then
      # Older SuSE/etc.
      ...
  elif [ -f /etc/redhat-release ]; then
      # Older Red Hat, CentOS, etc.
      ...
  else
      # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
      OS=$(uname -s)
  fi

  # convert string to lower case
  OS=`echo "$OS" | tr '[:upper:]' '[:lower:]'`

  if [[ $OS = *'ubuntu'* || $OS = *'debian'* ]]; then
    PM='apt'
  elif [[ $OS = *'centos'* ]]; then
    PM='yum'
  else
    exit 1
  fi
}

# script introduction
intro() {
  clear
  echo
  echo "******************************************************"
  echo "* OS     : Debian Ubuntu CentOS                      *"
  echo "* Desc   : auto install shadowsocks on CentOS server *"
  echo "* Author : https://github.com/shellhub               *"
  echo "******************************************************"
  echo
}

isRoot() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "false"
  else
    echo "true"
  fi
}

get_unused_port()
{
  if [ $# -eq 0 ]
    then
      $1=3333
  fi
  for UNUSED_PORT in $(seq $1 65000); do
    echo -ne "\035" | telnet 127.0.0.1 $UNUSED_PORT > /dev/null 2>&1
    [ $? -eq 1 ] && break
  done
}

config(){

  # config encryption password
  read -p "Password used for encryption (Default: w3cub.service):" sspwd
  if [[ -z "${sspwd}" ]]; then
    sspwd="w3cub.service"
  fi
  echo -e "encryption password: ${GREEN_COLOR}${sspwd}${NO_COLOR}"

  # config server port
  while [[ true ]]; do
    get_unused_port $(shuf -i 2000-65000 -n 1)
    local port=${UNUSED_PORT}
    read -p "Server port(1-65535) (Default: ${port}):" server_port
    if [[ -z "${server_port}" ]]; then
      server_port=${port}
    fi

    # make sure port is number
    expr ${server_port} + 1 &> /dev/null
    if [[ $? -eq 0 ]]; then
      # make sure port in range(1-65535)
      if [ ${server_port} -ge 1 ] && [ ${server_port} -le 65535 ]; then
        #make sure port is free
        lsof -i:${server_port} &> /dev/null
        if [[ $? -ne 0 ]]; then
          echo -e "server port: ${GREEN_COLOR}${server_port}${NO_COLOR}"
          break
        else
          echo -e "${RED_COLOR}${server_port}${NO_COLOR} is occupied"
          continue
        fi
      fi
    fi
    echo -e "${RED_COLOR}Invalid${NO_COLOR} port:${server_port}"
  done

  # config encryption method
  while [[ true ]]; do
    for (( i = 0; i < ${#ciphers[@]}; i++ )); do
      echo -e "${GREEN_COLOR}`expr ${i} + 1`${NO_COLOR}:\t${ciphers[${i}]}"
    done
    read -p "Select encryption method (Default: aes-256-cfb):" pick
    if [[ -z ${pick} ]]; then
      # default is aes-256-cfb
      pick=3
    fi
    expr ${pick} + 1 &> /dev/null
    if [[ $? -ne 0 ]]; then
      echo -e "${RED_COLOR}Invalid${NO_COLOR} number ${pick},try again"
      continue
    elif [ ${pick} -lt 1 ] || [ ${pick} -gt ${#ciphers[@]} ]; then
      echo -e "${RED_COLOR}Invalid${NO_COLOR} number ${pick},should be is(1-${#ciphers[@]})"
      continue
    else
      encryption_method=${ciphers[${pick}-1]}
      echo -e "encryption method: ${GREEN_COLOR}${encryption_method}${NO_COLOR}"
      break
    fi
  done
  # add shadowsocks config file
  cat <<EOT > /etc/shadowsocks-libev/config.json
{
  "server":"0.0.0.0",
  "server_port":${server_port},
  "local_address": "127.0.0.1",
  "local_port":1080,
  "password":"${sspwd}",
  "timeout":300,
  "method":"${encryption_method}",
  "fast_open": false
}
EOT
}

containsIgnoreCase(){
  # convert arg1 to lower case
  str=`echo "$1" | tr '[:upper:]' '[:lower:]'`
  # convert arg2 to lower case
  searchStr=`echo "$2" | tr '[:upper:]' '[:lower:]'`
  echo ${1}
  echo ${2}
  if [[ ${str} = *${searchStr}* ]]; then
    echo "true"
  else
    echo "false"
  fi
}

addTcpPort(){
  tcpPort=${server_port}
  cat /etc/*elease | grep -q VERSION_ID=\"7\"
  if [[ $? = 0 ]]; then
    firewall-cmd --zone=public --add-port=${tcpPort}/tcp --permanent
    firewall-cmd --reload
  else
    # iptables -I INPUT -p tcp -m tcp --dport ${tcpPort} -j ACCEPT
    iptables -4 -A INPUT -p tcp --dport ${tcpPort} -m  -j ACCEPT
    service iptables save
  fi
}

# show install success information
successInfo(){
  IP_ADDRESS=$(dig +short myip.opendns.com @resolver1.opendns.com)
  clear
  echo
  echo "Install completed"
  echo -e "ip_address:\t${GREEN_COLOR}${IP_ADDRESS}${NO_COLOR}"
  echo -e "server_port:\t${GREEN_COLOR}${server_port}${NO_COLOR}"
  echo -e "encryption:\t${GREEN_COLOR}${encryption_method}${NO_COLOR}"
  echo -e "password:\t${GREEN_COLOR}${sspwd}${NO_COLOR}"
  ss_link=$(echo ${encryption_method}:${sspwd}@${IP_ADDRESS}:${server_port} | base64)
  ss_link="ss://${ss_link}"
  echo -e "ss_link:\t${GREEN_COLOR}${ss_link}${NO_COLOR}"
  pip install qrcode >/dev/null
  echo -n "ss://"`echo -n ${encryption_method}:${sspwd}@${IP_ADDRESS}:${server_port} | base64` | qr
  echo -e "visit:\t\t${GREEN_COLOR}https://www.github.com/shellhub/shellhub${NO_COLOR}"
  echo
}

# install shadowsocks
install_shadowsocks(){
  # init package manager
  init_release
  #statements
  if [[ ${PM} = "apt" ]]; then
    apt-get install dnsutils -y
    apt install net-tools -y
    apt-get install python-pip -y
  elif [[ ${PM} = "yum" ]]; then
    yum install bind-utils -y
    yum install net-tools -y
    yum install python-setuptools -y && easy_install pip
  fi
  # pip install shadowsocks
  apt install shadowsocks-libev -y
}

# stop firewall
stop_firewall(){
  if [[ ${PM} = "apt" ]]; then
    ufw disable 2>&1 >/dev/null
  elif [[ ${PM} = "yum" ]]; then
    #statements
    systemctl stop firewalld 2>&1 >/dev/null
    systemctl disable firewalld 2>&1 >/dev/null
  fi
}

optimize_ss() {
  cat <<EOT > /etc/sysctl.d/local.conf
# max open files
fs.file-max = 51200
# max read buffer
net.core.rmem_max = 67108864
# max write buffer
net.core.wmem_max = 67108864
# default read buffer
net.core.rmem_default = 65536
# default write buffer
net.core.wmem_default = 65536
# max processor input queue
net.core.netdev_max_backlog = 4096
# max backlog
net.core.somaxconn = 4096
# resist SYN flood attacks
net.ipv4.tcp_syncookies = 1
# reuse timewait sockets when safe
net.ipv4.tcp_tw_reuse = 1
# turn off fast timewait sockets recycling
net.ipv4.tcp_tw_recycle = 0
# short FIN timeout
net.ipv4.tcp_fin_timeout = 30
# short keepalive time
net.ipv4.tcp_keepalive_time = 1200
# outbound port range
net.ipv4.ip_local_port_range = 10000 65000
# max SYN backlog
net.ipv4.tcp_max_syn_backlog = 4096
# max timewait sockets held by system simultaneously
net.ipv4.tcp_max_tw_buckets = 5000
# turn on TCP Fast Open on both client and server side
net.ipv4.tcp_fastopen = 3
# TCP receive buffer
net.ipv4.tcp_rmem = 4096 87380 67108864
# TCP write buffer
net.ipv4.tcp_wmem = 4096 65536 67108864
# turn on path MTU discovery
net.ipv4.tcp_mtu_probing = 1
# for high-latency network
net.ipv4.tcp_congestion_control = hybla
# for low-latency network, use cubic instead
net.ipv4.tcp_congestion_control = cubic
EOT
sysctl --system

}


start_service(){
  systemctl daemon-reload
  systemctl enable shadowsocks-libev
  systemctl start shadowsocks-libev
}

stop_service(){
  systemctl stop shadowsocks-libev
}


main(){
  #check root permission
  isRoot=$( isRoot )
  if [[ "${isRoot}" != "true" ]]; then
    echo -e "${RED_COLOR}error:${NO_COLOR}Please run this script as as root"
    exit 1
  else
    intro
    config
    install_shadowsocks
    addTcpPort
    # stop_firewall
    start_service
    successInfo
  fi
}

main
