
keepalive () {
  P=$1
  while sleep 150 ; do
    if [ $(( $(date +%s) - $(date +%s -r /var/log/console.$P) )) -ge 300 ]; then
      echo -ne "\000"
    fi
  done
}

export -f keepalive

export P=$$
export SHELL=/bin/bash
keepalive $P &
shopt -s checkwinsize
exec /usr/bin/script /var/log/console.$P --flush
