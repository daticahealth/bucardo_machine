#!/usr/bin/python3

import json
import os
import sys
import time
import stat

def wait_for_postgres():
    pg_ready="/usr/lib/postgresql/9.6/bin/pg_isready"
    i=0
    wait=5
    while not os.system(pg_ready):
        i += 1
        if i > 5:
            print("Postgresql not ready after {} seconds. Exiting.".format(wait*i))
            sys.exit(1)
        time.sleep(wait)

def update_config():


def start_bucardo():
    fifo = "/var/run/bucardo/log.fifo"
    if not stat.S_ISFIFO(os.stat(fifo).st_mode):
        if os.path.exists(fifo):
            os.unlink(fifo)
        os.mkfifo(fifo)
    os.system("bucardo start --log-destination={}".format(fifo))

def tail_log(command):
    process = subprocess.Popen(shlex.split(command), stdout=subprocess.PIPE)
    while True:
        output = process.stdout.readline()
        if output == '' and process.poll() is not None:
            break
        if output:
            print output.strip()
    rc = process.poll()
    return rc
