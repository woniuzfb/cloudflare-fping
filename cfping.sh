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
usage: $_this -c [-l] [-p 2000] [-s 5] [-g 1] [-m 500]
        -c     ping [fping] all cloudflare ips to find the best ip
        -p <x> sets the time in milliseconds that fping waits between successive 
               packets to an individual target (default is 2000, minimum is 10)
        -s <x> set the number of request packets to send to each target (default is 5)
        -g <x> the minimum amount of time (in milliseconds) between sending a 
               ping packet to any target (default is 1, minimum is 1)
        -l     show cloudflare ip location
        -m     you may want to use this according to system resources limit 
               larger number faster result (default is 500)

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
      p)
        var="period"
        ;;
      s)
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
  local _version="0.1.1"

  local cf=0
  local period=2000
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

  while getopts "f:i:n:t:p:s:g:m:?hvcl" opt; do
    case ${opt} in
      f | i | n | t | p | s | g | m)
        cfping:set "$opt" "$OPTARG"
        ;;
      c | l)
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

    if fping -q -i"$interval" -c"$packets" -p"$period" -x1 < ip_checked > ip_result 2>&1 
    then
      awk '{split($5,a,"/");split($8,b,"/"); if($8) print $1,"\r\033[18Cpackets received: "a[2],"\033[3Cping: "b[2]| "sort -n -k4,4r -k6,6" }' ip_result > ip_sorted
      if [[ $location -eq 1 ]] 
      then
        ip_sorted=$(awk 'FNR==NR{a[$1]=$2;next}{ if($1 in a) print $0,"\r\033[55Clocation: "a[$1]}' ip_location ip_sorted)
        echo "$ip_sorted" > ip_sorted
      fi

      best_ips=$(awk 'NR < 11 {print $0}' ip_sorted)
      Println "$info Best 10 IPs:\n\n$best_ips\n"
      Println "more IPs in file ip_sorted\n"
    else
      Println "$error no ip found, connection problem ?\n"
    fi
    # echo -ne "$ips" | xargs -I {} -P"$parallel" sh -c "ping -c${packets} -q -W2 '{}' > '{}'.out 2>&1"
  else
    cfping:printip "$@"
  fi
}

if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
  cfping -t "$(basename "$0")" "$@"
fi