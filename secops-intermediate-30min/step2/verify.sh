#!/bin/bash
. /usr/local/lib/secops-lab/lib.sh
step_begin 2
cmds() { sudo -l -U deploy 2>&1 | sed -n '/following commands/,$p' | tail -n +2 | sed -E 's/^[[:space:]]*\([^)]*\)[[:space:]]*//; s/^NOPASSWD:[[:space:]]*//; s/^[[:alpha:]_]+:[[:space:]]*//'; }
c1() { ! cmds | grep -Eq '(^|[ /,])(vim?|vi|less|more|nano|ed|man|bash|sh|dash|find|awk|python3?|env|ALL)([ ,]|$)|\*'; }
c2() { c1 && sudo -l -U deploy /usr/bin/systemctl restart inventory >/dev/null 2>&1 && id sysadmin >/dev/null 2>&1; }
chk "deploy ne peut plus obtenir un shell root" c1
chk "deploy peut toujours redémarrer inventory" c2
step_end
