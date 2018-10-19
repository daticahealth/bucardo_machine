# bucardo_machine

## Overview
This project, the Bucardo Machine, was created to help Datica customers migrate from Postgresql running in CPaaS to Postgresql RDS running in a CKS VPC. The Bucardo Machine is meant to be launched into a CKS cluster, but should work in any Kubernetes cluster or Docker instance for testing. Some features, such as the ability to delete the pod and have the new pod continue replication, may not work. This tool is really intended to be used for a limited amount of time and with a fair amount of observation.

## Prerequisites
* Before you can use this tool to replicate your database you need to have your CPaaS Postgresql source database configured to use SSL. This is something that has to be done by Datica Support. You can open a ticket for this by following [these instructions](https://help.datica.com/hc/en-us/articles/360000244303-How-To-Submit-An-Authenticated-Support-Ticket).
* If you have not already gotten a VPN connection set up between your CPaaS environment and your CKS VPC, then you should include that in the ticket.
* You will need to know the proxy IP address and port for your CPaaS Postgresql database.

## Launching Bucardo machine into your CKS cluster

##### Create a bucardo namespace
```shell
kubectl create namespace bucardo-machine
```

##### Creating your pgpass secret
To connect to your source and destination, you must first create a kubernetes secret. To do this you must first create a pgpass file as you would if you wanted to use it with psql. You will need the hostname, port, database, username, and password for the database. If your source database is hosted in CPaaS you will need to use the same IP and port that you would use to connect to your database while connected to your VPN. More information is [here](https://www.postgresql.org/docs/10/static/libpq-pgpass.html)
Once you have created your pgpass file, you will need to create the Kubernetes secret for pgpass. To create the secret use the following command:

```shell
kubectl --namespace=bucardo-machine create secret generic pgpass --from-file=./pgpass
```

##### Creating the StatefulSet
You can clone this repo, but all that you really need is the kubernetes/bucardo-statefulset.yaml file. If you don't feel the need to modify that file at all you can simply run the kubectl create command and specify the url of the file.
```shell
kubectl create -f https://raw.githubusercontent.com/daticahealth/bucardo_machine/master/kubernetes/bucardo-statefulset.yaml
```
If you think you need to make changes to the file you can save it to your computer, make your changes, then run `kubectl create -f bucardo-statefulset.yaml`

## Usage

##### Getting a shell on the bucardo_machine
```shell
kubectl --namespace=bucardo-machine exec -i -t bucardo-machine-0 -- bash -l
```
Note the use of `-l` with bash. The Bucardo machine container has a keepalive function in the profile. The `-l` tells bash to act as though it had been called from a login. This will source the profile and run the keepalive. Without the keepalive, the load balancer will disconnect the session when there is no traffic. Not only is this annoying, it also leaves processes running on the container.

##### Export environment variables #####
```shell
export SOURCE_HOST=10.255.0.1 # <- provided by Datica
export SOURCE_PORT=7446 # <- provided by Datica
export SOURCE_USER=catalyze # Unless you have created another superuser
export SOURCE_DATABASE=catalyzeDB # Unless you have created another database
export DEST_HOST=mydatabase.XXXXXXXXXX.us-east-2.rds.amazonaws.com # Your RDS endpoint
export DEST_PORT=5432 # RDS endpoint port
export DEST_USER=catalyze # RDS Master User
export DEST_DATABASE=catalyzeDB # Or whatever you named it
```

##### Replicate your schema to your new database
```shell
(
  echo "SET session_replication_role = replica;" && \
  pg_dump "\
    sslmode=require \
    host=$SOURCE_HOST \
    port=$SOURCE_PORT \
    user=$SOURCE_USER \
    dbname=$SOURCE_DATABASE"\
    --schema-only
) | psql "\
  sslmode=require \
  user=$DEST_USER \
  host=$DEST_HOST \
  dbname=$DEST_DATABASE \
  port=$DEST_PORT"
```

##### Add your databases
```shell
bucardo add db MySourceDB dbname=$SOURCE_DATABASE host=$SOURCE_HOST user=$SOURCE_USER port=$SOURCE_PORT conn=sslmode=require type=postgres
bucardo add db MyDestDB dbname=$DEST_DATABASE host=$DEST_HOST user=$DEST_USER port=$DEST_PORT conn=sslmode=require type=postgres
```

##### Add your tables and sequences
```shell
bucardo add all tables db=MySourceDB relgroup=MyReplGroup
bucardo add all sequences db=MySourceDB relgroup=MyReplGroup
```

##### Create the database group
Note: Both databases are set up as a source. This doesn't have to done this way, but configuring both databases as sources will allow a fail-back to the original environment.
```shell
bucardo add dbgroup MyDBGroup MySourceDB:source MyDestDB:source
```

##### Create the database sync
This will add the bucardo sync, which means that any changes after this command is run will be queued for replication. However, the replication will not begin automatically as "autokick" is turned off.
```shell
bucardo add sync MyDBSync relgroup=MyReplGroup dbs=MyDBGroup autokick=0 analyze_after_copy=1 conflict_strategy=bucardo_latest
```

##### Copy your data to your new database - and hope nothing goes wrong
Hope nothing goes wrong because this is going to take a lot of time.
```shell
(
  echo "SET session_replication_role = replica;" && \
  pg_dump "\
    sslmode=require \
    host=$SOURCE_HOST \
    port=$SOURCE_PORT \
    user=$SOURCE_USER \
    dbname=$SOURCE_DATABASE"\
    --data-only
) | psql "\
  sslmode=require \
  user=$DEST_USER \
  host=$DEST_HOST \
  dbname=$DEST_DATABASE \
  port=$DEST_PORT"
```

##### Start the replication
```shell
bucardo update sync MyDBSync autokick=1
bucardo reload config
```

##### Monitor ongoing replication
This solution is really intended to be a short-term migration tool and is not intended to be used long-term. As such, there isn't really any monitoring for ongoing replication and you should probably check its status periodically.
```shell
bucardo status
bucardo list all
```

If the replication has stalled or stopped you should be able simply delete the current pod. Since this is a StatefulSet a new pod will be created and the same volume will be attached to it. The container will see this when starting up and will just restart replication.
```shell
kubectl --namespace=bucardo-machine delete po/bucardo-machine-0
```

## Cutting over
Every environment is different, so there is not a one-size-fits-all solution for cutting over an application to a new database. There are, however, some high-level steps that should probably be followed.
1. Your application servers, middleware, caching layer, and whatever else is required should be in place in the new environment. Remember though, both the old and the new database are treated as sources, so if you do anything that changes data in the new database those changes will get replicated to the old database. Be careful. In theory this allows you to cut over to the new stack, verify that everything is working, and cut back if things are not.
2. Make sure you have good backups. This should go without saying. You may even want to take an additional backup right before starting the cut over.
3. Quiesce your old database. Generally this means stopping anything that may generate changes on the database and then waiting for any pending changes to be processed or any queues to clear. Again, this is dependent upon the environment and may be different depending upon your architecture, data flow, or whatnot. The important thing is to make sure that no changes are being made to the data before you proceed.
4. Wait for replication to catch up.
5. Verify all changes have been replicated. The diligence with which you verify that all of the data has been replicated and is an exact duplicate of the original data really depends upon your comfort level. It wouldn't be a horrible idea to create a script that verifies data consistency on the two databases or creates checksums of the tables. There's a pretty good article on how to write a sql script to do this [here](https://www.periscopedata.com/blog/hashing-tables-to-ensure-consistency-in-postgres-redshift-and-mysql).
6. Cut over.
7. Verify things work. Like data verification this is highly dependent upon your application and your risk tolerance. In an ideal world there would be a full acceptance test suite for your application that would test every function your application may perform. This is not an ideal world and thorough automated tests are rare. Before migrating it may not be a bad idea to develop testing procedures or better yet automated acceptance tests.
8. Continue monitoring. It is a really bad idea to schedule a vacation right after a major migration. Be prepared to keep an eye on things for a while.

As was mentioned earlier, both databases were configured as sources. This means that without any intervention after cutting over replication should essentially reverse direction wherein data will be replicated from the RDS instance to your CPaaS database. If this is not something that you want to have happen then you may want to take a look at the Bucardo documentation for dbgroup options. The documentation is pretty horrible, so it may take some hunting. The best place I've found is the help function of the bucardo command itself. For instance, `bucardo help add dbgroup`. This is still pretty sparse though, so the best place to look may just be looking at the [source code](https://github.com/bucardo/bucardo).

## Additional information
* https://bucardo.org/Bucardo/
* https://wiki.postgresql.org/wiki/Bucardo
* https://justatheory.com/2013/02/bootstrap-bucardo-mulitmaster/
* https://www.endpoint.com/blog/2016/05/31/bucardo-replication-workarounds-for
* https://www.compose.com/articles/using-bucardo-5-3-to-migrate-a-live-postgresql-database/
* This article suggests looking at the AWS Database Migration Service (DMS) because it wasn't available when they did their migration. DMS was the first stop for the creator of this project and there is a reason that this project exists.  https://www.theguardian.com/info/developer-blog/2016/feb/04/migrating-postgres-to-rds-without-downtime
