#!/bin/bash -e

if [ -f /var/lib/postgresql/.init_complete ]; then
  exit 0
else
  cd /
  if [ ! -d /var/lib/postgresql ]; then
    mkdir /var/lib/postgresql
  fi
  chown postgres:postgres /var/lib/postgresql
  tar xzvpf /root/var_lib_postgresql.tgz
  /etc/init.d/postgresql start
  su - postgres -c "bucardo install --batch --dbhost='<none>' --dbuser=bucardo --dbname=bucardo"
  su - postgres -c "touch /var/lib/postgresql/.init_complete"
  /etc/init.d/postgresql stop
fi
