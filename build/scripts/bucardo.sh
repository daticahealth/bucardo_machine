#!/bin/bash -e

/etc/init.d/postgresql start

CHECK=0
WAIT=5
STATUS_INTERVAL=300
until /usr/lib/postgresql/9.6/bin/pg_isready; do
  COUNT=$((COUNT+1))
  if [ $COUNT -ge 5 ]; then
    print "Postgres not ready after $(($COUNT*$WAIT)) seconds. Exiting."
    exit 1
  fi
  sleep $WAIT
done

sedex=$(grep bucardo ~postgres/.pgpass |awk -F':' '{print $5}'|sed -e 's*&*\\\&*g' -e 's*\\\([1-9]\)*\\\\\1*g')
sed -i "s*dbpass = bucardo*dbpass = $sedex*g" /etc/bucardorc

bucardo start --log-destination=stdout

cat ~/.pgpass >> ~postgres/.pgpass

C=$(($STATUS_INTERVAL/$WAIT))
N=0
BPID=$(head -1 /var/run/bucardo/bucardo.mcp.pid)
while ps -p $BPID >/dev/null 2>&1; do
  if [ $N -ge $C ]; then
    echo "$(date): Bucardo running since $(stat -c %y /proc/$BPID)"
    bucardo status
    N=0
  fi
  sleep $WAIT
  N=$((N+1))
done

EXIT_CODE=$?

/etc/init.d/postgresql stop

exit $EXIT_CODE
