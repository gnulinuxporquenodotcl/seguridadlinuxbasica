#!/bin/sh 
#
#  This is automatically generated file. DO NOT MODIFY !
#
#  Firewall Builder  fwb_ipt v5.1.0.3599
#
#  Generated Tue Oct 16 04:55:35 2012 CLST by ed00m
#
# files: * soloweb.fw /etc/fw/soloweb.fw
#
# Compiled for iptables (any version)
#
# This template is intended for a simple server with one interface. "Assume firewall is part of any"
# option is off, IP forwarding is off.




FWBDEBUG=""

PATH="/sbin:/usr/sbin:/bin:/usr/bin:${PATH}"
export PATH



LSMOD="/sbin/lsmod"
MODPROBE="/sbin/modprobe"
IPTABLES="/sbin/iptables"
IP6TABLES="/sbin/ip6tables"
IPTABLES_RESTORE="/sbin/iptables-restore"
IP6TABLES_RESTORE="/sbin/ip6tables-restore"
IP="/sbin/ip"
IFCONFIG="/sbin/ifconfig"
VCONFIG="/sbin/vconfig"
BRCTL="/sbin/brctl"
IFENSLAVE="/sbin/ifenslave"
IPSET="/usr/sbin/ipset"
LOGGER="/usr/bin/logger"

log() {
    echo "$1"
    which "$LOGGER" >/dev/null 2>&1 && $LOGGER -p info "$1"
}

getInterfaceVarName() {
    echo $1 | sed 's/\./_/'
}

getaddr_internal() {
    dev=$1
    name=$2
    af=$3
    L=$($IP $af addr show dev $dev |  sed -n '/inet/{s!.*inet6* !!;s!/.*!!p}' | sed 's/peer.*//')
    test -z "$L" && { 
        eval "$name=''"
        return
    }
    eval "${name}_list=\"$L\"" 
}

getnet_internal() {
    dev=$1
    name=$2
    af=$3
    L=$($IP route list proto kernel | grep $dev | grep -v default |  sed 's! .*$!!')
    test -z "$L" && { 
        eval "$name=''"
        return
    }
    eval "${name}_list=\"$L\"" 
}


getaddr() {
    getaddr_internal $1 $2 "-4"
}

getaddr6() {
    getaddr_internal $1 $2 "-6"
}

getnet() {
    getnet_internal $1 $2 "-4"
}

getnet6() {
    getnet_internal $1 $2 "-6"
}

# function getinterfaces is used to process wildcard interfaces
getinterfaces() {
    NAME=$1
    $IP link show | grep ": $NAME" | while read L; do
        OIFS=$IFS
        IFS=" :"
        set $L
        IFS=$OIFS
        echo $2
    done
}

diff_intf() {
    func=$1
    list1=$2
    list2=$3
    cmd=$4
    for intf in $list1
    do
        echo $list2 | grep -q $intf || {
        # $vlan is absent in list 2
            $func $intf $cmd
        }
    done
}

find_program() {
  PGM=$1
  which $PGM >/dev/null 2>&1 || {
    echo "\"$PGM\" not found"
    exit 1
  }
}
check_tools() {
  find_program which
  find_program $IPTABLES 
  find_program $MODPROBE 
  find_program $IP 
}
reset_iptables_v4() {
  $IPTABLES -P OUTPUT  DROP
  $IPTABLES -P INPUT   DROP
  $IPTABLES -P FORWARD DROP

cat /proc/net/ip_tables_names | while read table; do
  $IPTABLES -t $table -L -n | while read c chain rest; do
      if test "X$c" = "XChain" ; then
        $IPTABLES -t $table -F $chain
      fi
  done
  $IPTABLES -t $table -X
done
}

reset_iptables_v6() {
  $IP6TABLES -P OUTPUT  DROP
  $IP6TABLES -P INPUT   DROP
  $IP6TABLES -P FORWARD DROP

cat /proc/net/ip6_tables_names | while read table; do
  $IP6TABLES -t $table -L -n | while read c chain rest; do
      if test "X$c" = "XChain" ; then
        $IP6TABLES -t $table -F $chain
      fi
  done
  $IP6TABLES -t $table -X
done
}


P2P_INTERFACE_WARNING=""

missing_address() {
    address=$1
    cmd=$2

    oldIFS=$IFS
    IFS="@"
    set $address
    addr=$1
    interface=$2
    IFS=$oldIFS



    $IP addr show dev $interface | grep -q POINTOPOINT && {
        test -z "$P2P_INTERFACE_WARNING" && echo "Warning: Can not update address of interface $interface. fwbuilder can not manage addresses of point-to-point interfaces yet"
        P2P_INTERFACE_WARNING="yes"
        return
    }

    test "$cmd" = "add" && {
      echo "# Adding ip address: $interface $addr"
      echo $addr | grep -q ':' && {
          $FWBDEBUG $IP addr $cmd $addr dev $interface
      } || {
          $FWBDEBUG $IP addr $cmd $addr broadcast + dev $interface
      }
    }

    test "$cmd" = "del" && {
      echo "# Removing ip address: $interface $addr"
      $FWBDEBUG $IP addr $cmd $addr dev $interface || exit 1
    }

    $FWBDEBUG $IP link set $interface up
}

list_addresses_by_scope() {
    interface=$1
    scope=$2
    ignore_list=$3
    $IP addr ls dev $interface | \
      awk -v IGNORED="$ignore_list" -v SCOPE="$scope" \
        'BEGIN {
           split(IGNORED,ignored_arr);
           for (a in ignored_arr) {ignored_dict[ignored_arr[a]]=1;}
         }
         (/inet |inet6 / && $0 ~ SCOPE && !($2 in ignored_dict)) {print $2;}' | \
        while read addr; do
          echo "${addr}@$interface"
	done | sort
}


update_addresses_of_interface() {
    ignore_list=$2
    set $1 
    interface=$1 
    shift

    FWB_ADDRS=$(
      for addr in $*; do
        echo "${addr}@$interface"
      done | sort
    )

    CURRENT_ADDRS_ALL_SCOPES=""
    CURRENT_ADDRS_GLOBAL_SCOPE=""

    $IP link show dev $interface >/dev/null 2>&1 && {
      CURRENT_ADDRS_ALL_SCOPES=$(list_addresses_by_scope $interface 'scope .*' "$ignore_list")
      CURRENT_ADDRS_GLOBAL_SCOPE=$(list_addresses_by_scope $interface 'scope global' "$ignore_list")
    } || {
      echo "# Interface $interface does not exist"
      # Stop the script if we are not in test mode
      test -z "$FWBDEBUG" && exit 1
    }

    diff_intf missing_address "$FWB_ADDRS" "$CURRENT_ADDRS_ALL_SCOPES" add
    diff_intf missing_address "$CURRENT_ADDRS_GLOBAL_SCOPE" "$FWB_ADDRS" del
}

clear_addresses_except_known_interfaces() {
    $IP link show | sed 's/://g' | awk -v IGNORED="$*" \
        'BEGIN {
           split(IGNORED,ignored_arr);
           for (a in ignored_arr) {ignored_dict[ignored_arr[a]]=1;}
         }
         (/state/ && !($2 in ignored_dict)) {print $2;}' | \
         while read intf; do
            echo "# Removing addresses not configured in fwbuilder from interface $intf"
            $FWBDEBUG $IP addr flush dev $intf scope global
            $FWBDEBUG $IP link set $intf down
         done
}

check_file() {
    test -r "$2" || {
        echo "Can not find file $2 referenced by address table object $1"
        exit 1
    }
}

check_run_time_address_table_files() {
    :
    
}

load_modules() {
    :
    OPTS=$1
    MODULES_DIR="/lib/modules/`uname -r`/kernel/net/"
    MODULES=$(find $MODULES_DIR -name '*conntrack*' \! -name '*ipv6*'|sed  -e 's/^.*\///' -e 's/\([^\.]\)\..*/\1/')
    echo $OPTS | grep -q nat && {
        MODULES="$MODULES $(find $MODULES_DIR -name '*nat*'|sed  -e 's/^.*\///' -e 's/\([^\.]\)\..*/\1/')"
    }
    echo $OPTS | grep -q ipv6 && {
        MODULES="$MODULES $(find $MODULES_DIR -name nf_conntrack_ipv6|sed  -e 's/^.*\///' -e 's/\([^\.]\)\..*/\1/')"
    }
    for module in $MODULES; do 
        if $LSMOD | grep ${module} >/dev/null; then continue; fi
        $MODPROBE ${module} ||  exit 1 
    done
}

verify_interfaces() {
    :
    echo "Verifying interfaces: eth3 lo"
    for i in eth3 lo ; do
        $IP link show "$i" > /dev/null 2>&1 || {
            log "Interface $i does not exist"
            exit 1
        }
    done
}

prolog_commands() {
    echo "Running prolog script"
    
}

epilog_commands() {
    echo "Running epilog script"
    
}

run_epilog_and_exit() {
    epilog_commands
    exit $1
}

configure_interfaces() {
    :
    # Configure interfaces
    update_addresses_of_interface "eth3 192.168.0.144/24" ""
    update_addresses_of_interface "lo 127.0.0.1/8" ""
}

script_body() {
    # ================ IPv4


    # ================ Table 'filter', automatic rules
    # accept established sessions
    $IPTABLES -A INPUT   -m state --state ESTABLISHED,RELATED -j ACCEPT 
    $IPTABLES -A OUTPUT  -m state --state ESTABLISHED,RELATED -j ACCEPT 
    $IPTABLES -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT






    # ================ Table 'filter', rule set Policy
    # 
    # Rule 0 (eth3)
    # 
    echo "Rule 0 (eth3)"
    # 
    $IPTABLES -N Cid17236X32552.0
    $IPTABLES -A INPUT -i eth3   -s 127.0.0.1   -j Cid17236X32552.0
    $IPTABLES -A INPUT -i eth3   -s 192.168.0.144   -j Cid17236X32552.0
    $IPTABLES -N In_RULE_0
    $IPTABLES -A Cid17236X32552.0  -d 127.0.0.1   -j In_RULE_0
    $IPTABLES -A Cid17236X32552.0  -d 192.168.0.144   -j In_RULE_0
    $IPTABLES -A In_RULE_0  -j LOG  --log-level info --log-prefix "RULE 0 -- DENY "
    $IPTABLES -A In_RULE_0  -j DROP
    # 
    # Rule 1 (lo)
    # 
    echo "Rule 1 (lo)"
    # 
    $IPTABLES -A INPUT -i lo   -j ACCEPT
    $IPTABLES -A OUTPUT -o lo   -j ACCEPT
    # 
    # Rule 2 (global)
    # 
    echo "Rule 2 (global)"
    # 
    $IPTABLES -A INPUT -p icmp  -m icmp  --icmp-type 3  -m state --state NEW  -j ACCEPT
    $IPTABLES -A INPUT -p icmp  -m icmp  --icmp-type 0/0   -m state --state NEW  -j ACCEPT
    $IPTABLES -A INPUT -p icmp  -m icmp  --icmp-type 11/0   -m state --state NEW  -j ACCEPT
    $IPTABLES -A INPUT -p icmp  -m icmp  --icmp-type 11/1   -m state --state NEW  -j ACCEPT
    $IPTABLES -A INPUT -p tcp -m tcp  -m multiport  --dports 80,22  -m state --state NEW  -j ACCEPT
    # 
    # Rule 3 (global)
    # 
    echo "Rule 3 (global)"
    # 
    # this rejects auth (ident) queries that remote
    # mail relays may send to this server when it
    # tries to send email out.
    $IPTABLES -A INPUT -p tcp -m tcp  --dport 113  -j REJECT
    # 
    # Rule 4 (global)
    # 
    echo "Rule 4 (global)"
    # 
    $IPTABLES -N RULE_4
    $IPTABLES -A INPUT  -j RULE_4
    $IPTABLES -A RULE_4  -j LOG  --log-level info --log-prefix "RULE 4 -- DENY "
    $IPTABLES -A RULE_4  -j DROP
}

ip_forward() {
    :
    echo 0 > /proc/sys/net/ipv4/ip_forward
}

reset_all() {
    :
    reset_iptables_v4
}

block_action() {
    reset_all
}

stop_action() {
    reset_all
    $IPTABLES -P OUTPUT  ACCEPT
    $IPTABLES -P INPUT   ACCEPT
    $IPTABLES -P FORWARD ACCEPT
}

check_iptables() {
    IP_TABLES="$1"
    [ ! -e $IP_TABLES ] && return 151
    NF_TABLES=$(cat $IP_TABLES 2>/dev/null)
    [ -z "$NF_TABLES" ] && return 152
    return 0
}
status_action() {
    check_iptables "/proc/net/ip_tables_names"
    ret_ipv4=$?
    check_iptables "/proc/net/ip6_tables_names"
    ret_ipv6=$?
    [ $ret_ipv4 -eq 0 -o $ret_ipv6 -eq 0 ] && return 0
    [ $ret_ipv4 -eq 151 -o $ret_ipv6 -eq 151 ] && {
        echo "iptables modules are not loaded"
    }
    [ $ret_ipv4 -eq 152 -o $ret_ipv6 -eq 152 ] && {
        echo "Firewall is not configured"
    }
    exit 3
}

# See how we were called.
# For backwards compatibility missing argument is equivalent to 'start'

cmd=$1
test -z "$cmd" && {
    cmd="start"
}

case "$cmd" in
    start)
        log "Activating firewall script generated Tue Oct 16 04:55:35 2012 by ed00m"
        check_tools
         prolog_commands 
        check_run_time_address_table_files
        
        load_modules " "
        configure_interfaces
        verify_interfaces
        
         reset_all 
        
        script_body
        ip_forward
        epilog_commands
        RETVAL=$?
        ;;

    stop)
        stop_action
        RETVAL=$?
        ;;

    status)
        status_action
        RETVAL=$?
        ;;

    block)
        block_action
        RETVAL=$?
        ;;

    reload)
        $0 stop
        $0 start
        RETVAL=$?
        ;;

    interfaces)
        configure_interfaces
        RETVAL=$?
        ;;

    test_interfaces)
        FWBDEBUG="echo"
        configure_interfaces
        RETVAL=$?
        ;;



    *)
        echo "Usage $0 [start|stop|status|block|reload|interfaces|test_interfaces]"
        ;;

esac

exit $RETVAL