# Mariadb Start Replica Assistant
A script to assist in restarting replication when there are errors. 

To download the start_replica_assistant script direct to your linux server, you may use git or wget:
```
git clone https://github.com/mariadb-edwardstoever/start_replica_assistant.git
```
```
wget https://github.com/mariadb-edwardstoever/start_replica_assistant/archive/refs/heads/main.zip
```

### What will the Mariadb Start Replica Assistant do?
The Start Replica Assistant will make the task of restarting the slave process for asynchronous or semi-synchronous replication much easier. It can quickly fix or skip over the most common errors and log each step that it takes. The script will handle these errors:
* __IO ERROR 1236__ - Switch to MASTER_USE_GTID = slave_pos (returning it to current_pos at end of script)
* __SQL ERROR 1950__ - Set global gtid_strict_mode = OFF (returning it to ON at end of script)
* __OTHER SQL ERRORS__ - set global sql_slave_skip_counter=(a number)

When the script completes, it will provide you with a final report of the count of each type of error that it skipped. For example:
```
 COUNT   SKIPPED ERROR
------- --------------------------
      3 1032_DELETE_ROWS_V1
      5 1032_UPDATE_ROWS_V1
      1 1062_INSERT
    290 1062_WRITE_ROWS_V1
      1 1950_BINLOG_GTID

The logfile /tmp/start_replica_assistant_0423_094947.log contains the details from running this script.

Elapsed time: 90 seconds
Binlog Events Skipped: 300
```

### Examples of running the script on the command line
```
./start_replica_assistant.sh 
./start_replica_assistant.sh --test
./start_replica_assistant.sh --help
./start_replica_assistant.sh --skip_multiplier=100
./start_replica_assistant.sh --milliseconds=25
```

### Available Options
```
This script can be run without options. Not indicating an option value will use the default.
  --conn_name=MYREPLICA # This is only required when multiple named slave connections exist.
  --skip_multiplier=100 # How many binlog events to skip from the primary at a time, default 1.
                        # Skipping multiples will speed up the process of finding the first transaction
                        # that does not fail. Skipping multiples can also lead to skipping transactions
                        # that would otherwise succeed. For more details, review the file README.md.
  --milliseconds=75     # Pause between each error skipped in miliseconds. Default 50.
  --nocolor             # Do not display with color letters
  --nolog               # Do not write a logfile into directory /tmp
  --bypass_priv_check   # Bypass the check that the database user has sufficient privileges.
  --test                # Test connect to database and display script version.
  --version             # Test connect to database and display script version.
  --help                # Display the help menu
```
  
### Connecting from the database host
The most simple method for running Mariadb Start Replica Assistant is via unix_socket as root on the database host of the replica with errors. If you want another user to connect to the database, add a user and password to the file `assistant.cnf`. Remember the configuration must be to connect to the replica.

### Connecting over the network
You can define a connection for any user and using any method that is supported by mariadb client. Edit the file `assistant.cnf`. For example, a user connecting to a remote database might look like this:
```
[start_replica_assistant]
user = admin
password = "NDQeJ0hA13zGtM2O$$f4haKDu"
host = mindapp.ha.db7.mariadb.com
port = 5305
ssl-ca = /etc/ssl/certs/mariadb_chain_2024.pem
```
* Do not define a connection through maxscale. The connections should be direct to the replica with the broken slave process.

Once the configuration in `assistant.cnf` is correct, just run the script with the desired options.

### Required Privileges
```SQL
-- GRANTS REQUIRED (option #1):
GRANT REPLICATION SLAVE ADMIN, SLAVE MONITOR on *.* to 'admin'@'%';

-- GRANTS REQUIRED (option #2):
GRANT SUPER on *.* to 'admin'@'%';
```

### Interactive Options
You will be offered 3 options when the script encounters its first error blocking replication. You can press __c__ to skip over this error and continue to the next error. You can press __a__ to auto-skip all errors like this error. You can press __e__ to skip everything which will run until there are no more errors found. Pressing any other key will exit the script. 
```
------------- CHOOSE AN OPTION -------------
Press c to continue. Slave will skip only this occurrence.
Press a to auto-skip. Slave will skip all occurrences of 1950 (BINLOG_GTID).
Press e to everything. Slave will skip every error possible.
```

### Taking too long to complete
The Mariadb Start Replica Assistant can skip over about 500 errors per minute on a one-by-one basis. In most cases this is fast enough to get by a problem area in the slave. The script completes _when there are no more errors to skip over_.


If the script is running and not finishing, you can quit out of the script by pressing CTRL+c. Look in the `/tmp` directory for a log of what was done up to that point.

There are two ways to make the script faster:
* `--skip_multiplier=100` This option will increase the number of sql events skipped at a time. The default is 1. You can increase it to any number. The higher you go, the faster it will complete by skipping that many binlog events at a time. When the script finishes by finding no more SQL errors, it will set the value back to 0. If the master has waiting transactions in the binary logs, it is likely some valid SQL events will be skipped over in the milliseconds between finding no SQL errors and finishing the script. Furthermore, the log produced by the script will only include the first error in each batch of skipped errors and no final report displaying a count of error types will be produced.


* `--milliseconds=25` A pause is necessary between each skipped error and the check to see if the next binlog even produces an error. The default is `50`. You can lower this number safely to make the script run a little faster. If it is too low, the script will exit early and provide a warning: `This script exited early. Increase milliseconds to avoid this issue.`

### Named Slave connections
If you have only one slave and it has a named connection, the Start Replica Assistant will discover the name for you. If you have multiple named slave connections, you can indicate the one that you want the script to work on using the following syntax:
```
./start_replica_assistant.sh --conn_name=MYREPLICA
```

### Divergence

The Start Replica Assistant does not test for divergence or fix divergence. It can give you an idea of whether divergence exists in the slave. General Rules for typical errors:
* __1950__ - An attempt was made to binlog GTID 0-10-1617 which would create an out-of-order sequence number. This error is often followed by more errors but does not indicate divergence by itself.
* __1062 INSERT__ - Usually occurs when row(s) were inserted on the slave first by mistake. It is not likely the slave will be divergent when this error is skipped.
* __1032 DELETE__ - Occurs when a deleted row on the master does not exist on the slave. It is not likely the slave will be divergent when this error is skipped.
* __1032 UPDATE__ - Occurs when a row that is updated on the master does not exist on the slave. This is usually a problem. The row should be there.

If you think that there is an unacceptable level of divergence on the slave, you can refresh the slave from a recent backup of the master and restart replication. This will depend on your tolerance for divergence in the tables involved.

A method for testing if a table is divergent is the [CHECKSUM TABLE](https://mariadb.com/kb/en/checksum-table/) command.

### Sharing Results With MariaDB Support
When the script completes, it will output the name of a logfile that you can share in a Mariadb support ticket:
```
The logfile /tmp/start_replica_assistant_0423_094947.log 
contains the details from running this script.
```