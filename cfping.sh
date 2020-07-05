#!/usr/bin/env bash
set -e

green="\033[32m"
red="\033[31m"
plain="\033[0m"
info="${green}[Info]$plain"
error="${red}[Error]$plain"

Println()
{
    printf '%b' "\n$1\n"
}

cfping() {
  cfping:help() {
    cat << EOF 1>&2
usage: $_this -c [-l] [-s 2000] [-p 5] [-g 1] [-m 500]
        -c     ping [fping] all cloudflare ips to find the best ip
        -s <x> set the time in milliseconds that fping waits between successive 
               packets to an individual target (default is 2000, minimum is 10)
        -p <x> set the number of request packets to send to each target (default is 5)
        -g <x> the minimum amount of time (in milliseconds) between sending a 
               ping packet to any target (default is 1, minimum is 1)
        -l     show cloudflare ip location
        -m <x> you may want to use this according to system resources limit 
               larger number faster result (default is 500)

        ---

usage: $_this -d [-L https://domain.com/xxx] [-N 100] [-P 10] [-I ip]
        -d     speed test (default testing best 100 IPs unless -I used)
        -L <x> set the file link to test (default is a cloudflare worker linking to a file on www.apple.com)
               the domain of this link must have cname record on cloudflare
        -N <x> set the number of IPs to test (default is 100)
        -P <x> set the parallel number of speed test (default is 10)
        -I <x> specify an ip to test

        ---

usage: $_this [options] <start> <end>
        -n <x> set the number of addresses to print (<end> must not be set)
        -f <x> set the format of addresses (hex, dec, or dot)
        -i <x> set the increment to 'x'
        -h     display this help message and exit
        -v     display the version number and exit
EOF
    exit 1
  }

  cfping:error() {
    local code=1

    case ${1} in
      -[0-9]*)
       code=${1#-}
       shift
       ;;
    esac

    echo "$_this: $*" 1>&2
    exit "$code"
  }

  cfping:aton() {
    local ip=$1
    local ipnum=0

    for (( i=0; i<4; ++i )); do
      ((ipnum+=${ip%%.*}*$((256**$((3-i))))))
      ip=${ip#*.}
    done

    echo $ipnum
  }

  cfping:ntoa() {
    echo $(($(($(($((${1}/256))/256))/256))%256)).$(($(($((${1}/256))/256))%256)).$(($((${1}/256))%256)).$((${1}%256))
  }

  cfping:isint() {
    (( $1 > 0 )) 2>/dev/null
  }

  cfping:isip() {
    [[ $1 =~ ^[0-9]+(\.[0-9]+){3}$ ]]
  }

  cfping:printip() {
    cfping:set start "$1"
    cfping:set end "${2:-}" "$(( start + (increment * count) - 1 ))"

    [[ $end -lt $start ]] && \
      cfping:error "start address must be smaller than end address"

    if [[ $cf -eq 1 ]] 
    then
      oldstart=$start
      start=$((start+RANDOM%256))
    fi

    while [[ $start -le $end ]]; do
      if [[ $cf -eq 1 ]] 
      then
        cfping:ntoa "$start"
        oldstart=$(( oldstart + 256 ))
        start=$((oldstart+RANDOM%256))
      else
        case ${format} in
          dec)
            echo "$start"
            ;;
          hex)
            printf '%X\n' "$start"
            ;;
          *)
            cfping:ntoa "$start"
            ;;
        esac
        start=$(( start + increment ))
      fi
    done
  }

  cfping:set() {
    local var=$1
    local val=${2:-$3}

    case ${var} in
      c)
        var="cf"
        args=0
        ;;
      d)
        var="st"
        args=0
        ;;
      L)
        var="st_link"
        ;;
      N)
        var="st_num"
        ;;
      P)
        var="st_parallel"
        ;;
      I)
        var="st_ip"
        ;;
      s)
        var="mseconds"
        ;;
      p)
        var="packets"
        ;;
      g)
        var="interval"
        ;;
      m)
        var="parallel"
        ;;
      l)
        var="location"
        ;;
      f)
        var="format"

        ! echo "${_formats[@]}" | grep -qw "$val" && \
          cfping:error "invalid format '$val'"
        ;;
      i)
        var="increment"

        ! cfping:isint "$val" && \
          cfping:error "$var must be a positive integer"
        ;;
      n)
        var="count"

        ! cfping:isint "$val" && \
          cfping:error "$var must be a positive integer"

        args=1
        ;;
      t)
        var="_this"
        ;;
      start | end)
        if cfping:isip "$val" 
        then
          val=$(cfping:aton "$val")
          [[ $cf -eq 1 ]] && val=$((val+1))
        fi

        [[ $cf -eq 1 ]] && val=$((val+1))

        ! cfping:isint "$val" && \
          cfping:error "bad IP address"
        ;;
    esac

    read -r ${var?} <<< "$val"
  }

  local _formats=("dec" "dot" "hex")
  local _this="cfping"
  local _version="0.1.3"

  local cf=0
  local st=0
  local st_num=100
  local st_link="https://www-apple-com.mtimer.workers.dev/105/media/us/iphone-11-pro/2019/3bd902e4-0752-4ac1-95f8-6225c32aec6d/films/product/iphone-11-pro-product-tpl-cc-us-2019_1280x720h.mp4"
  local st_parallel=10
  local st_ip=""
  local mseconds=2000
  local packets=5
  local interval=1
  local parallel=500
  local location=0
  local args=2
  local count=0
  local increment=1
  local format="dot"
  local start
  local end

  while getopts "f:i:n:t:p:s:g:m:L:N:P:I:?hvcld" opt; do
    case ${opt} in
      f | i | n | t | p | s | g | m | L | N | P | I)
        cfping:set "$opt" "$OPTARG"
        ;;
      c | l | d)
        cfping:set "$opt" 1
        ;;
      v)
        cfping:error -0 "v$_version"
        ;;
      h | \? | :)
        cfping:help
        ;;
    esac
  done
  shift $((OPTIND -1))

  if [ $# -ne $args ]; then
    cfping:help
  fi

  if [[ $cf -eq 1 ]] 
  then
    if [[ ! -x $(command -v fping) ]] 
    then
      Println "$error please install fping first:\n\nMac: brew install fping\n\nCentOS: yum install fping\n\nUbuntu/Debian: apt install fping\n\nFedora 22+: dnf install fping\n\nArch Linux: pacman -S fping\n"
      exit 1
    fi
    Println "$info generating cloudflare IPs ..."
    ips=""
    while IFS= read -r line 
    do
      if [[ -n $line ]] 
      then
        # fping -q -i1 -c5 -p2000 -g 192.168.1.0/24
        ip=${line%/*}
        cidr=${line#*/}
        count=$((2**(32-cidr)-2))
        ips="$ips$(cfping:printip $ip)\n"
      fi
    done < <(wget --timeout=10 --tries=3 --no-check-certificate "https://www.cloudflare.com/ips-v4" -qO-)
    echo -ne "$ips" > ip

    echo > ip_checked
    echo > ip_location

    if [[ $location -eq 1 ]] 
    then
      Println "$info testing IPs, 2 mins ..."
      awk '{print}' ip | xargs -L1 -P"$parallel" sh -c 'colo=$(curl -m 2 -s $0/cdn-cgi/trace | sed -n "s/colo=\(.*\)/\1/p"); if [ -n "$colo" ] ; then echo $0 $colo >> ip_location; fi'
      awk '{print $1}' ip_location > ip_checked
    else
      Println "$info testing IPs ..."
      if [[ $(uname) == "Darwin" ]] 
      then
        awk '{print}' ip | xargs -L1 -P"$((parallel*2))" sh -c 'if nc -z -w 2 -G 2 $0 80 2> /dev/null; then echo $0 >> ip_checked; fi'
      else
        awk '{print}' ip | xargs -L1 -P"$((parallel*2))" sh -c 'if nc -z -w 2 $0 80 2> /dev/null; then echo $0 >> ip_checked; fi'
      fi
    fi

    Println "$info pinging cloudflare IPs, 1 min ..."

    fping -q -i"$interval" -c"$packets" -p"$mseconds" -x1 < ip_checked > ip_result 2>&1 || exit_code=$?

    if [[ ${exit_code:-0} -eq 1 ]] || [[ ${exit_code:-0} -eq 3 ]] || [[ ${exit_code:-0} -eq 4 ]]
    then
      if [[ $EUID -ne 0 ]] && [[ $interval -lt 10 ]]
      then
        interval=10
      fi

      exit_code=0
      fping -q -i"$interval" -c"$packets" -p"$mseconds" < ip_checked > ip_result 2>&1 || exit_code=$?

      if [[ $exit_code -ne 1 ]] && [[ $exit_code -ne 0 ]]
      then
        Println "$error fping error, fping version too old or connection problem ?\n"
        exit 1
      fi
    fi

    awk '{split($5,a,"/");split($8,b,"/"); if($8) printf "%s packets received: %s ping: %s\n",$1,a[2],b[2] | "sort -k4,4rn -k6,6n" }' ip_result > ip_sorted
    if [[ $location -eq 1 ]] 
    then
      ip_sorted=$(awk 'NR==FNR{a[$1]=$2;next}{printf "%s location: %s\n",$0,a[$1]}' ip_location ip_sorted)
      echo "$ip_sorted" > ip_sorted
      best_ips=$(awk 'NR < 11 {printf "%s\r\033[18Cpackets received: %s\033[3Cping: %s\033[3Clocation: %s\n",$1,$4,$6,$8}' ip_sorted)
    else
      best_ips=$(awk 'NR < 11 {printf "%s\r\033[18Cpackets received: %s\033[3Cping: %s\n",$1,$4,$6}' ip_sorted)
    fi
    Println "$info 10 BEST IPs:\n\n$best_ips\n\nmore IPs in file ip_sorted\n"

    # echo -ne "$ips" | xargs -I {} -P"$parallel" sh -c "ping -c${packets} -q -W2 '{}' > '{}'.out 2>&1"
  elif [[ $st -eq 1 ]] 
  then
    if [ ! -s "ip_sorted" ] 
    then
      Println "$error no IPs found, run $_this -c\n"
      exit 1
    fi
    if [[ ${st_link:0:5} == "https" ]] 
    then
      st_port=443
    else
      st_port=80
    fi
    st_domain=${st_link#*http://}
    st_domain=${st_domain%%/*}
    st_domain=${st_domain%:*}
    if cfping:isip "$st_domain" 
    then
      Println "$error wrong file link, use domain\n"
      exit 1
    fi
    if [ -n "$st_ip" ] 
    then
      Println "$info testing IP $st_ip ..."
      curl --resolve "$st_domain:$st_port:$st_ip" "$st_link" -o "$st_ip" -s --connect-timeout 2 --max-time 10 || true
      if [ ! -s "$st_ip" ]
      then
        Println "$error the domain of the file link must have cname record on cloudflare or try again\n"
        exit 1
      fi
      if [[ $(uname) == "Darwin" ]] 
      then
        stat -f '%N %z' $st_ip | awk '{printf "\n%s\r\033[18Cspeed: %.2f MB/10s\n\n",$1,$2/1024/1024}'
      else
        find $st_ip -type f -printf '%p %s\n' | awk '{printf "\n%s\r\033[18Cspeed: %.2f MB/10s\n\n",$1,$2/1024/1024}'
      fi
      rm -f ${st_ip:-notfound}
      exit 0
    fi
    Println "$info speed testing, 2 mins ...\n"
    mkdir -p cf_speed_test
    awk 'NR <= '"$st_num"' {print $1}' ip_sorted | xargs -L1 -P"$st_parallel" sh -c 'curl --resolve '"$st_domain:$st_port"':$0 "'"$st_link"'" -o cf_speed_test/$0 -s --connect-timeout 2 --max-time 10 || true'
    cd cf_speed_test
    if [[ $(uname) == "Darwin" ]] 
    then
      ip_speed_test=$(find -- * -type f -print0 | xargs -0 stat -f '%N %z' | sort -k2,2rn | awk '{printf "%s %.2f MB\n",$1,$2/1024/1024}')
      # rm -- *
    else
      ip_speed_test=$(find -- * -type f -printf '%p %s\n' | sort -k2,2rn | awk '{printf "%s %.2f MB\n",$1,$2/1024/1024}')
    fi
    cd ..
    rm -rf cf_speed_test
    echo "$ip_speed_test" > ip_speed_test
    ip_speed_test=$(awk 'NR==FNR{a[$1]=$0;next}{printf "%s speed: %s MB/10s\n",a[$1],$2}' ip_sorted ip_speed_test)
    echo "$ip_speed_test" > ip_speed_test
    awk '{if($10) printf "%s\r\033[18Cpackets received: %s\033[3Cping: %s\033[3Clocation: %s\033[3Cspeed: %s MB/10s\n",$1,$4,$6,$8,$10; else printf "%s\r\033[18Cpackets received: %s\033[3Cping: %s\033[3Cspeed: %s MB/10s\n",$1,$4,$6,$8}' ip_speed_test
    Println "$info Done.\n"
  else
    cfping:printip "$@"
  fi
}

if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
  cfping -t "$(basename "$0")" "$@"
fi