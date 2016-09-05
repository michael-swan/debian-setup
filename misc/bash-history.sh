
# Bash History #
# Remove duplicate entries in shell history
export HISTCONTROL=ignoredups:erasedups

# Append to the history file instead of overwriting it
shopt -s histappend

# After each command, append to the history file and reread it
export PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}history -a; history -c; history -r"
