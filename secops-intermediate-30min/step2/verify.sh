#!/bin/bash
. /usr/local/lib/secops-lab/lib.sh
step_begin 2
S=/usr/local/bin/restart-inventory.sh
cmds() { sudo -l -U deploy 2>&1 | sed -n '/following commands/,$p' | tail -n +2 | sed -E 's/^[[:space:]]*\([^)]*\)[[:space:]]*//; s/^NOPASSWD:[[:space:]]*//; s/^[[:alpha:]_]+:[[:space:]]*//'; }
c1() {
  ! cmds | grep -Eq '(^|[ /,])(vim?|vi|less|more|nano|ed|man|bash|sh|dash|find|awk|python3?|env|ALL)([ ,]|$)|\*' || return 1
  if sudo -l -U deploy "$S" >/dev/null 2>&1; then ! runuser -u deploy -- test -w "$S"; fi
}
c2() {
  c1 || return 1
  id sysadmin >/dev/null 2>&1 || return 1
  { [ -x "$S" ] && grep -q 'systemctl restart inventory' "$S" && sudo -l -U deploy "$S"; } >/dev/null 2>&1 \
    || sudo -l -U deploy /usr/bin/systemctl restart inventory >/dev/null 2>&1
}
chk "deploy ne peut plus obtenir un shell root" c1
chk "deploy peut toujours redémarrer inventory" c2
step_end
