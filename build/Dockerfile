FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get -y update && apt-get -y install \
    ca-certificates \
    gnupg \
    lsb-release \
    pwgen \
    wget \
  && rm -rf /var/lib/apt/lists/*

RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
  && echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
  && apt-get -y update && apt-get -y install \
    bucardo \
    postgresql-client-10 \
    mysql-client \
  && rm -rf /var/lib/apt/lists/*

COPY files/pg_hba.conf /etc/postgresql/9.6/main/pg_hba.conf
COPY files/keep_alive.sh /etc/profile.d/keep_alive.sh
COPY scripts /scripts

RUN mkdir /var/run/bucardo \
  && usermod -a -G bucardo postgres \
  && chown postgres /etc/postgresql/9.6/main/pg_hba.conf /etc/bucardorc /var/log/bucardo/ /var/run/bucardo \
  && cd / \
  && tar czvpf /root/var_lib_postgresql.tgz /var/lib/postgresql \
  && rm -rf /var/lib/postgresql/* \
  && chmod +x /scripts/* /etc/profile.d/*

CMD ["bash", "-c", "/scripts/init.sh && /scripts/bucardo.sh"]
