#!/system/bin/sh

SCRIPT_DIR=${0%/*}
if [ "$SCRIPT_DIR" = "$0" ]; then
  SCRIPT_DIR=.
fi
MODDIR=${MODDIR:-${SCRIPT_DIR%/scripts}}

[ -f "$MODDIR/config.env" ] && . "$MODDIR/config.env"

CMFA_PACKAGE=${CMFA_PACKAGE:-com.github.ychaiyi.conceal.clash.meta.for.android}
CMFA_SERVICE=${CMFA_SERVICE:-com.github.kr328.clash.service.RootProxyService}
CMFA_REDIR_PORT=${CMFA_REDIR_PORT:-7892}
CMFA_TPROXY_PORT=${CMFA_TPROXY_PORT:-7893}
CMFA_DNS_PORT=${CMFA_DNS_PORT:-1053}
CMFA_PROXY_MODE=${CMFA_PROXY_MODE:-auto}
CMFA_MARK=${CMFA_MARK:-0x2d0}
CMFA_ROUTE_TABLE=${CMFA_ROUTE_TABLE:-20230}
CMFA_RULE_PREF=${CMFA_RULE_PREF:-10030}
CMFA_ENABLE_IPV6=${CMFA_ENABLE_IPV6:-1}
CMFA_EXTRA_BYPASS_V4=${CMFA_EXTRA_BYPASS_V4:-}
CMFA_EXTRA_BYPASS_V6=${CMFA_EXTRA_BYPASS_V6:-}

MARKER_FILE=root-transparent-proxy.enabled
CHAIN_PRE=CMFA_PRE
CHAIN_OUT=CMFA_OUT
CHAIN_DIVERT=CMFA_DIVERT
CHAIN_DNS_OUT=CMFA_DNS_OUT
CHAIN_DNS_PRE=CMFA_DNS_PRE

BYPASS_V4="0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 240.0.0.0/4 255.255.255.255/32 $CMFA_EXTRA_BYPASS_V4"
BYPASS_V6="::/128 ::1/128 fc00::/7 fe80::/10 ff00::/8 $CMFA_EXTRA_BYPASS_V6"

log() {
  msg="[cmfa-root] $*"
  echo "$msg"
  if [ -n "$MODDIR" ] && [ -d "$MODDIR" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') $msg" >> "$MODDIR/cmfa-root.log" 2>/dev/null
  fi
}

run() {
  "$@" >/dev/null 2>&1
}

delete_rule() {
  while "$@" >/dev/null 2>&1; do
    :
  done
}

package_installed() {
  pm path "$CMFA_PACKAGE" >/dev/null 2>&1
}

data_dir() {
  if [ -d "/data/user/0/$CMFA_PACKAGE" ]; then
    echo "/data/user/0/$CMFA_PACKAGE"
    return
  fi

  dumpsys package "$CMFA_PACKAGE" 2>/dev/null \
    | sed -n 's/.*dataDir=//p' \
    | sed -n '1p'
}

app_uid() {
  dir=$(data_dir)
  [ -n "$dir" ] || return 1

  stat -c '%u' "$dir" 2>/dev/null && return
  ls -ldn "$dir" 2>/dev/null | awk '{print $3}'
}

wait_boot() {
  count=0
  while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$count" -lt 90 ]; do
    sleep 2
    count=$((count + 1))
  done
}

wait_package() {
  count=0
  until package_installed; do
    if [ "$count" -ge 60 ]; then
      log "package $CMFA_PACKAGE is not installed"
      return 1
    fi
    sleep 2
    count=$((count + 1))
  done
}

wait_data_dir_uid() {
  count=0
  while [ "$count" -lt 90 ]; do
    dir=$(data_dir)
    uid=$(app_uid)
    if [ -n "$dir" ] && [ -n "$uid" ]; then
      return 0
    fi
    sleep 2
    count=$((count + 1))
  done

  log "cannot resolve app data dir or uid"
  return 1
}

ensure_marker() {
  dir=$(data_dir)
  uid=$(app_uid)

  if [ -z "$dir" ] || [ -z "$uid" ]; then
    log "cannot resolve app data dir or uid"
    return 1
  fi

  clash_dir="$dir/files/clash"
  marker="$clash_dir/$MARKER_FILE"
  mkdir -p "$clash_dir" || return 1
  echo 1 > "$marker" || return 1
  chown "$uid:$uid" "$clash_dir" "$marker" >/dev/null 2>&1
  chmod 700 "$clash_dir" >/dev/null 2>&1
  chmod 600 "$marker" >/dev/null 2>&1
}

remove_marker() {
  dir=$(data_dir)
  [ -n "$dir" ] && rm -f "$dir/files/clash/$MARKER_FILE"
}

grant_notification() {
  pm grant "$CMFA_PACKAGE" android.permission.POST_NOTIFICATIONS >/dev/null 2>&1
}

start_app_service() {
  component="$CMFA_PACKAGE/$CMFA_SERVICE"

  am start-foreground-service -n "$component" >/dev/null 2>&1 \
    || am startservice -n "$component" >/dev/null 2>&1
}

stop_app_service() {
  run am broadcast -a "$CMFA_PACKAGE.intent.action.CLASH_REQUEST_STOP" -p "$CMFA_PACKAGE"
  run am stopservice -n "$CMFA_PACKAGE/com.github.kr328.clash.service.RootProxyService"
  run am stopservice -n "$CMFA_PACKAGE/com.github.kr328.clash.service.ClashService"
  run am stopservice -n "$CMFA_PACKAGE/com.github.kr328.clash.service.TunService"
  run am force-stop "$CMFA_PACKAGE"
}

port_listening() {
  hex=$(printf '%04X' "$1" 2>/dev/null)
  [ -n "$hex" ] || return 1

  grep -i ":$hex " /proc/net/tcp /proc/net/tcp6 2>/dev/null | grep -q ' 0A '
}

wait_listeners() {
  count=0
  while [ "$count" -lt 30 ]; do
    if [ "$CMFA_PROXY_MODE" != "redir" ] && port_listening "$CMFA_TPROXY_PORT"; then
      CMFA_RUNTIME_MODE=tproxy
      log "using tproxy listener on $CMFA_TPROXY_PORT"
      return 0
    fi
    if [ "$CMFA_PROXY_MODE" != "tproxy" ] && port_listening "$CMFA_REDIR_PORT"; then
      CMFA_RUNTIME_MODE=redir
      log "using redir listener on $CMFA_REDIR_PORT"
      return 0
    fi
    sleep 1
    count=$((count + 1))
  done

  log "proxy listener did not start (tproxy=$CMFA_TPROXY_PORT redir=$CMFA_REDIR_PORT)"
  return 1
}

cleanup_ipv4() {
  delete_rule iptables -t mangle -D PREROUTING -j "$CHAIN_PRE"
  delete_rule iptables -t mangle -D OUTPUT -j "$CHAIN_OUT"
  delete_rule iptables -t nat -D PREROUTING -j "$CHAIN_PRE"
  delete_rule iptables -t nat -D OUTPUT -j "$CHAIN_OUT"
  delete_rule iptables -t nat -D OUTPUT -j "$CHAIN_DNS_OUT"
  delete_rule iptables -t nat -D PREROUTING -j "$CHAIN_DNS_PRE"

  for chain in "$CHAIN_PRE" "$CHAIN_OUT" "$CHAIN_DIVERT"; do
    run iptables -t mangle -F "$chain"
    run iptables -t mangle -X "$chain"
  done
  for chain in "$CHAIN_DNS_OUT" "$CHAIN_DNS_PRE"; do
    run iptables -t nat -F "$chain"
    run iptables -t nat -X "$chain"
  done
  for chain in "$CHAIN_PRE" "$CHAIN_OUT"; do
    run iptables -t nat -F "$chain"
    run iptables -t nat -X "$chain"
  done

  while ip -4 rule del fwmark "$CMFA_MARK/$CMFA_MARK" table "$CMFA_ROUTE_TABLE" >/dev/null 2>&1; do
    :
  done
  run ip -4 route flush table "$CMFA_ROUTE_TABLE"
}

cleanup_ipv6() {
  delete_rule ip6tables -t mangle -D PREROUTING -j "$CHAIN_PRE"
  delete_rule ip6tables -t mangle -D OUTPUT -j "$CHAIN_OUT"
  delete_rule ip6tables -t nat -D PREROUTING -j "$CHAIN_PRE"
  delete_rule ip6tables -t nat -D OUTPUT -j "$CHAIN_OUT"
  delete_rule ip6tables -t nat -D OUTPUT -j "$CHAIN_DNS_OUT"
  delete_rule ip6tables -t nat -D PREROUTING -j "$CHAIN_DNS_PRE"

  for chain in "$CHAIN_PRE" "$CHAIN_OUT" "$CHAIN_DIVERT"; do
    run ip6tables -t mangle -F "$chain"
    run ip6tables -t mangle -X "$chain"
  done
  for chain in "$CHAIN_DNS_OUT" "$CHAIN_DNS_PRE"; do
    run ip6tables -t nat -F "$chain"
    run ip6tables -t nat -X "$chain"
  done
  for chain in "$CHAIN_PRE" "$CHAIN_OUT"; do
    run ip6tables -t nat -F "$chain"
    run ip6tables -t nat -X "$chain"
  done

  while ip -6 rule del fwmark "$CMFA_MARK/$CMFA_MARK" table "$CMFA_ROUTE_TABLE" >/dev/null 2>&1; do
    :
  done
  run ip -6 route flush table "$CMFA_ROUTE_TABLE"
}

cleanup_rules() {
  cleanup_ipv4
  [ "$CMFA_ENABLE_IPV6" = "1" ] && cleanup_ipv6
}

add_bypass_v4() {
  chain=$1
  for cidr in $BYPASS_V4; do
    run iptables -t mangle -A "$chain" -d "$cidr" -j RETURN
  done
}

add_bypass_v4_nat() {
  chain=$1
  for cidr in $BYPASS_V4; do
    run iptables -t nat -A "$chain" -d "$cidr" -j RETURN
  done
}

add_bypass_v6() {
  chain=$1
  for cidr in $BYPASS_V6; do
    run ip6tables -t mangle -A "$chain" -d "$cidr" -j RETURN
  done
}

add_bypass_v6_nat() {
  chain=$1
  for cidr in $BYPASS_V6; do
    run ip6tables -t nat -A "$chain" -d "$cidr" -j RETURN
  done
}

apply_ipv4() {
  uid=$1

  run ip -4 rule add pref "$CMFA_RULE_PREF" fwmark "$CMFA_MARK/$CMFA_MARK" table "$CMFA_ROUTE_TABLE"
  run ip -4 route add local 0.0.0.0/0 dev lo table "$CMFA_ROUTE_TABLE"

  iptables -t mangle -N "$CHAIN_DIVERT" >/dev/null 2>&1
  iptables -t mangle -A "$CHAIN_DIVERT" -j MARK --set-mark "$CMFA_MARK" >/dev/null 2>&1
  iptables -t mangle -A "$CHAIN_DIVERT" -j ACCEPT >/dev/null 2>&1

  iptables -t mangle -N "$CHAIN_PRE" >/dev/null 2>&1
  iptables -t mangle -A "$CHAIN_PRE" -p udp --dport 53 -j RETURN >/dev/null 2>&1
  iptables -t mangle -A "$CHAIN_PRE" -p tcp --dport 53 -j RETURN >/dev/null 2>&1
  iptables -t mangle -A "$CHAIN_PRE" -m addrtype --dst-type LOCAL -j RETURN >/dev/null 2>&1
  iptables -t mangle -A "$CHAIN_PRE" -m addrtype --dst-type BROADCAST -j RETURN >/dev/null 2>&1
  add_bypass_v4 "$CHAIN_PRE"
  run iptables -t mangle -A "$CHAIN_PRE" -p tcp -m socket -j "$CHAIN_DIVERT"
  run iptables -t mangle -A "$CHAIN_PRE" -p udp -m socket -j "$CHAIN_DIVERT"
  iptables -t mangle -A "$CHAIN_PRE" -p tcp -j TPROXY --on-port "$CMFA_TPROXY_PORT" --tproxy-mark "$CMFA_MARK/$CMFA_MARK" >/dev/null 2>&1
  iptables -t mangle -A "$CHAIN_PRE" -p udp -j TPROXY --on-port "$CMFA_TPROXY_PORT" --tproxy-mark "$CMFA_MARK/$CMFA_MARK" >/dev/null 2>&1
  iptables -t mangle -A PREROUTING -j "$CHAIN_PRE" >/dev/null 2>&1

  iptables -t mangle -N "$CHAIN_OUT" >/dev/null 2>&1
  iptables -t mangle -A "$CHAIN_OUT" -m mark --mark "$CMFA_MARK" -j RETURN >/dev/null 2>&1
  iptables -t mangle -A "$CHAIN_OUT" -m owner --uid-owner "$uid" -j RETURN >/dev/null 2>&1
  iptables -t mangle -A "$CHAIN_OUT" -p udp -m multiport --dports 53,123,137 -j RETURN >/dev/null 2>&1
  iptables -t mangle -A "$CHAIN_OUT" -p tcp --dport 53 -j RETURN >/dev/null 2>&1
  iptables -t mangle -A "$CHAIN_OUT" -m addrtype --dst-type LOCAL -j RETURN >/dev/null 2>&1
  iptables -t mangle -A "$CHAIN_OUT" -m addrtype --dst-type BROADCAST -j RETURN >/dev/null 2>&1
  add_bypass_v4 "$CHAIN_OUT"
  iptables -t mangle -A "$CHAIN_OUT" -p tcp -j MARK --set-mark "$CMFA_MARK" >/dev/null 2>&1
  iptables -t mangle -A "$CHAIN_OUT" -p udp -j MARK --set-mark "$CMFA_MARK" >/dev/null 2>&1
  iptables -t mangle -A OUTPUT -j "$CHAIN_OUT" >/dev/null 2>&1

  iptables -t nat -N "$CHAIN_DNS_OUT" >/dev/null 2>&1
  iptables -t nat -A "$CHAIN_DNS_OUT" -m owner --uid-owner "$uid" -j RETURN >/dev/null 2>&1
  iptables -t nat -A "$CHAIN_DNS_OUT" -p udp --dport 53 -j REDIRECT --to-ports "$CMFA_DNS_PORT" >/dev/null 2>&1
  iptables -t nat -A "$CHAIN_DNS_OUT" -p tcp --dport 53 -j REDIRECT --to-ports "$CMFA_DNS_PORT" >/dev/null 2>&1
  iptables -t nat -A OUTPUT -j "$CHAIN_DNS_OUT" >/dev/null 2>&1

  iptables -t nat -N "$CHAIN_DNS_PRE" >/dev/null 2>&1
  iptables -t nat -A "$CHAIN_DNS_PRE" -p udp --dport 53 -j REDIRECT --to-ports "$CMFA_DNS_PORT" >/dev/null 2>&1
  iptables -t nat -A "$CHAIN_DNS_PRE" -p tcp --dport 53 -j REDIRECT --to-ports "$CMFA_DNS_PORT" >/dev/null 2>&1
  iptables -t nat -A PREROUTING -j "$CHAIN_DNS_PRE" >/dev/null 2>&1
}

apply_ipv6() {
  uid=$1

  run ip -6 rule add pref "$CMFA_RULE_PREF" fwmark "$CMFA_MARK/$CMFA_MARK" table "$CMFA_ROUTE_TABLE"
  run ip -6 route add local ::/0 dev lo table "$CMFA_ROUTE_TABLE"

  ip6tables -t mangle -N "$CHAIN_DIVERT" >/dev/null 2>&1
  ip6tables -t mangle -A "$CHAIN_DIVERT" -j MARK --set-mark "$CMFA_MARK" >/dev/null 2>&1
  ip6tables -t mangle -A "$CHAIN_DIVERT" -j ACCEPT >/dev/null 2>&1

  ip6tables -t mangle -N "$CHAIN_PRE" >/dev/null 2>&1
  ip6tables -t mangle -A "$CHAIN_PRE" -p udp --dport 53 -j RETURN >/dev/null 2>&1
  ip6tables -t mangle -A "$CHAIN_PRE" -p tcp --dport 53 -j RETURN >/dev/null 2>&1
  add_bypass_v6 "$CHAIN_PRE"
  run ip6tables -t mangle -A "$CHAIN_PRE" -p tcp -m socket -j "$CHAIN_DIVERT"
  run ip6tables -t mangle -A "$CHAIN_PRE" -p udp -m socket -j "$CHAIN_DIVERT"
  ip6tables -t mangle -A "$CHAIN_PRE" -p tcp -j TPROXY --on-port "$CMFA_TPROXY_PORT" --tproxy-mark "$CMFA_MARK/$CMFA_MARK" >/dev/null 2>&1
  ip6tables -t mangle -A "$CHAIN_PRE" -p udp -j TPROXY --on-port "$CMFA_TPROXY_PORT" --tproxy-mark "$CMFA_MARK/$CMFA_MARK" >/dev/null 2>&1
  ip6tables -t mangle -A PREROUTING -j "$CHAIN_PRE" >/dev/null 2>&1

  ip6tables -t mangle -N "$CHAIN_OUT" >/dev/null 2>&1
  ip6tables -t mangle -A "$CHAIN_OUT" -m mark --mark "$CMFA_MARK" -j RETURN >/dev/null 2>&1
  ip6tables -t mangle -A "$CHAIN_OUT" -m owner --uid-owner "$uid" -j RETURN >/dev/null 2>&1
  ip6tables -t mangle -A "$CHAIN_OUT" -p udp -m multiport --dports 53,123,137 -j RETURN >/dev/null 2>&1
  ip6tables -t mangle -A "$CHAIN_OUT" -p tcp --dport 53 -j RETURN >/dev/null 2>&1
  add_bypass_v6 "$CHAIN_OUT"
  ip6tables -t mangle -A "$CHAIN_OUT" -p tcp -j MARK --set-mark "$CMFA_MARK" >/dev/null 2>&1
  ip6tables -t mangle -A "$CHAIN_OUT" -p udp -j MARK --set-mark "$CMFA_MARK" >/dev/null 2>&1
  ip6tables -t mangle -A OUTPUT -j "$CHAIN_OUT" >/dev/null 2>&1

  ip6tables -t nat -N "$CHAIN_DNS_OUT" >/dev/null 2>&1
  ip6tables -t nat -A "$CHAIN_DNS_OUT" -m owner --uid-owner "$uid" -j RETURN >/dev/null 2>&1
  ip6tables -t nat -A "$CHAIN_DNS_OUT" -p udp --dport 53 -j REDIRECT --to-ports "$CMFA_DNS_PORT" >/dev/null 2>&1
  ip6tables -t nat -A "$CHAIN_DNS_OUT" -p tcp --dport 53 -j REDIRECT --to-ports "$CMFA_DNS_PORT" >/dev/null 2>&1
  ip6tables -t nat -A OUTPUT -j "$CHAIN_DNS_OUT" >/dev/null 2>&1

  ip6tables -t nat -N "$CHAIN_DNS_PRE" >/dev/null 2>&1
  ip6tables -t nat -A "$CHAIN_DNS_PRE" -p udp --dport 53 -j REDIRECT --to-ports "$CMFA_DNS_PORT" >/dev/null 2>&1
  ip6tables -t nat -A "$CHAIN_DNS_PRE" -p tcp --dport 53 -j REDIRECT --to-ports "$CMFA_DNS_PORT" >/dev/null 2>&1
  ip6tables -t nat -A PREROUTING -j "$CHAIN_DNS_PRE" >/dev/null 2>&1
}

apply_ipv4_redir() {
  uid=$1

  iptables -t nat -N "$CHAIN_OUT" >/dev/null 2>&1
  iptables -t nat -A "$CHAIN_OUT" -m owner --uid-owner "$uid" -j RETURN >/dev/null 2>&1
  iptables -t nat -A "$CHAIN_OUT" -p udp -m multiport --dports 53,123,137 -j RETURN >/dev/null 2>&1
  iptables -t nat -A "$CHAIN_OUT" -p tcp --dport 53 -j RETURN >/dev/null 2>&1
  iptables -t nat -A "$CHAIN_OUT" -m addrtype --dst-type LOCAL -j RETURN >/dev/null 2>&1
  iptables -t nat -A "$CHAIN_OUT" -m addrtype --dst-type BROADCAST -j RETURN >/dev/null 2>&1
  add_bypass_v4_nat "$CHAIN_OUT"
  iptables -t nat -A "$CHAIN_OUT" -p tcp -j REDIRECT --to-ports "$CMFA_REDIR_PORT" >/dev/null 2>&1
  iptables -t nat -A OUTPUT -j "$CHAIN_OUT" >/dev/null 2>&1

  iptables -t nat -N "$CHAIN_PRE" >/dev/null 2>&1
  iptables -t nat -A "$CHAIN_PRE" -p udp --dport 53 -j RETURN >/dev/null 2>&1
  iptables -t nat -A "$CHAIN_PRE" -p tcp --dport 53 -j RETURN >/dev/null 2>&1
  iptables -t nat -A "$CHAIN_PRE" -m addrtype --dst-type LOCAL -j RETURN >/dev/null 2>&1
  iptables -t nat -A "$CHAIN_PRE" -m addrtype --dst-type BROADCAST -j RETURN >/dev/null 2>&1
  add_bypass_v4_nat "$CHAIN_PRE"
  iptables -t nat -A "$CHAIN_PRE" -p tcp -j REDIRECT --to-ports "$CMFA_REDIR_PORT" >/dev/null 2>&1
  iptables -t nat -A PREROUTING -j "$CHAIN_PRE" >/dev/null 2>&1

  iptables -t nat -N "$CHAIN_DNS_OUT" >/dev/null 2>&1
  iptables -t nat -A "$CHAIN_DNS_OUT" -m owner --uid-owner "$uid" -j RETURN >/dev/null 2>&1
  iptables -t nat -A "$CHAIN_DNS_OUT" -p udp --dport 53 -j REDIRECT --to-ports "$CMFA_DNS_PORT" >/dev/null 2>&1
  iptables -t nat -A "$CHAIN_DNS_OUT" -p tcp --dport 53 -j REDIRECT --to-ports "$CMFA_DNS_PORT" >/dev/null 2>&1
  iptables -t nat -A OUTPUT -j "$CHAIN_DNS_OUT" >/dev/null 2>&1

  iptables -t nat -N "$CHAIN_DNS_PRE" >/dev/null 2>&1
  iptables -t nat -A "$CHAIN_DNS_PRE" -p udp --dport 53 -j REDIRECT --to-ports "$CMFA_DNS_PORT" >/dev/null 2>&1
  iptables -t nat -A "$CHAIN_DNS_PRE" -p tcp --dport 53 -j REDIRECT --to-ports "$CMFA_DNS_PORT" >/dev/null 2>&1
  iptables -t nat -A PREROUTING -j "$CHAIN_DNS_PRE" >/dev/null 2>&1
}

apply_ipv6_redir() {
  uid=$1

  ip6tables -t nat -N "$CHAIN_OUT" >/dev/null 2>&1
  ip6tables -t nat -A "$CHAIN_OUT" -m owner --uid-owner "$uid" -j RETURN >/dev/null 2>&1
  ip6tables -t nat -A "$CHAIN_OUT" -p udp -m multiport --dports 53,123,137 -j RETURN >/dev/null 2>&1
  ip6tables -t nat -A "$CHAIN_OUT" -p tcp --dport 53 -j RETURN >/dev/null 2>&1
  add_bypass_v6_nat "$CHAIN_OUT"
  ip6tables -t nat -A "$CHAIN_OUT" -p tcp -j REDIRECT --to-ports "$CMFA_REDIR_PORT" >/dev/null 2>&1
  ip6tables -t nat -A OUTPUT -j "$CHAIN_OUT" >/dev/null 2>&1

  ip6tables -t nat -N "$CHAIN_PRE" >/dev/null 2>&1
  ip6tables -t nat -A "$CHAIN_PRE" -p udp --dport 53 -j RETURN >/dev/null 2>&1
  ip6tables -t nat -A "$CHAIN_PRE" -p tcp --dport 53 -j RETURN >/dev/null 2>&1
  add_bypass_v6_nat "$CHAIN_PRE"
  ip6tables -t nat -A "$CHAIN_PRE" -p tcp -j REDIRECT --to-ports "$CMFA_REDIR_PORT" >/dev/null 2>&1
  ip6tables -t nat -A PREROUTING -j "$CHAIN_PRE" >/dev/null 2>&1

  ip6tables -t nat -N "$CHAIN_DNS_OUT" >/dev/null 2>&1
  ip6tables -t nat -A "$CHAIN_DNS_OUT" -m owner --uid-owner "$uid" -j RETURN >/dev/null 2>&1
  ip6tables -t nat -A "$CHAIN_DNS_OUT" -p udp --dport 53 -j REDIRECT --to-ports "$CMFA_DNS_PORT" >/dev/null 2>&1
  ip6tables -t nat -A "$CHAIN_DNS_OUT" -p tcp --dport 53 -j REDIRECT --to-ports "$CMFA_DNS_PORT" >/dev/null 2>&1
  ip6tables -t nat -A OUTPUT -j "$CHAIN_DNS_OUT" >/dev/null 2>&1

  ip6tables -t nat -N "$CHAIN_DNS_PRE" >/dev/null 2>&1
  ip6tables -t nat -A "$CHAIN_DNS_PRE" -p udp --dport 53 -j REDIRECT --to-ports "$CMFA_DNS_PORT" >/dev/null 2>&1
  ip6tables -t nat -A "$CHAIN_DNS_PRE" -p tcp --dport 53 -j REDIRECT --to-ports "$CMFA_DNS_PORT" >/dev/null 2>&1
  ip6tables -t nat -A PREROUTING -j "$CHAIN_DNS_PRE" >/dev/null 2>&1
}

apply_rules() {
  uid=$(app_uid)
  if [ -z "$uid" ]; then
    log "cannot resolve app uid"
    return 1
  fi

  cleanup_rules
  case "${CMFA_RUNTIME_MODE:-tproxy}" in
    redir)
      apply_ipv4_redir "$uid"
      [ "$CMFA_ENABLE_IPV6" = "1" ] && apply_ipv6_redir "$uid"
      log "redir tcp/dns rules applied for uid $uid"
      ;;
    *)
      apply_ipv4 "$uid"
      [ "$CMFA_ENABLE_IPV6" = "1" ] && apply_ipv6 "$uid"
      log "tproxy rules applied for uid $uid"
      ;;
  esac
}

rules_active() {
  iptables -t mangle -S "$CHAIN_PRE" >/dev/null 2>&1
}

start_proxy() {
  wait_boot
  wait_package || return 1
  wait_data_dir_uid || return 1
  grant_notification
  stop_app_service
  sleep 1
  ensure_marker || return 1
  start_app_service || true
  wait_listeners || return 1
  apply_rules
}

stop_proxy() {
  cleanup_rules
  stop_app_service
  remove_marker
  log "stopped"
}

case "$1" in
  start)
    start_proxy
    ;;
  stop)
    stop_proxy
    ;;
  restart)
    stop_proxy
    start_proxy
    ;;
  toggle)
    if rules_active; then
      stop_proxy
    else
      start_proxy
    fi
    ;;
  cleanup)
    cleanup_rules
    ;;
  *)
    echo "usage: $0 {start|stop|restart|toggle|cleanup}"
    exit 2
    ;;
esac
