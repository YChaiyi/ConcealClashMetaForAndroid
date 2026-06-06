ui_print "- Conceal CMFA Root Proxy"
ui_print "- Install the matching Conceal CMFA APK before enabling traffic rules."
ui_print "- The module starts RootProxyService at late_start service time."
ui_print "- Use the module action button to toggle rules and service."

MODPATH=${MODPATH:-/data/adb/modules_update/cmfa-root-transparent-proxy}

ui_print "- Setting script permissions in $MODPATH"
chmod 0755 "$MODPATH/service.sh" "$MODPATH/action.sh" "$MODPATH/uninstall.sh" "$MODPATH/scripts/cmfa-root.sh"
chmod 0644 "$MODPATH/config.env" "$MODPATH/module.prop"

ui_print "- Installed script permissions:"
ls -l "$MODPATH/service.sh" "$MODPATH/action.sh" "$MODPATH/uninstall.sh" "$MODPATH/scripts/cmfa-root.sh" | while read -r line; do
  ui_print "  $line"
done
