if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

alias ll='ls -al'
alias debug='tmuxinator start voltron'

alias killopenocd='sudo kill -9 `ps -ef | grep openocd | grep sudo | grep -v grep | awk '"'"'{ print $2 }'"'"'`'
