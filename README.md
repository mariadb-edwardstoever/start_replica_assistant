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
* IO ERROR 1236: Switch to MASTER_USE_GTID = slave_pos (returning it to current_pos at end of script)
* SQL ERROR 1950: Set global gtid_strict_mode = OFF (returning it to ON at end of script)
* OTHER SQL ERRORS: set global sql_slave_skip_counter=(a number)

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
  --skip_multiplier=100 # How many binlog events to skip from the primary at a time, default 1.
                        # Skipping multiples will speed up the process of finding the first transaction 
                        # that does not fail. Skipping multiples can also lead to skipping transactions 
                        # that would otherwise succeed. For more details, review the file README.md.
  --milliseconds=75     # Pause between each error skipped in miliseconds. Default 50.
  --nocolor             # Do not display with color letters
  --nolog               # Do not write a logfile into directory ${TMPDIR}
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

### Taking too long to complete
The Mariadb Start Replica Assistant can skip over about 500 errors per minute on a one-by-one basis. In most cases this is fast enough to get by a problem area in the slave. The script completes _when there are no more errors to skip over_.


If the script is running and not finishing, you can quit out of the script by pressing CTRL+c. Look in the `/tmp` directory for a log of what was done up to that point.

There are two ways to make the script faster:
`--skip_multiplier=100`
This option will increase the number of sql events skipped in the binlog. The default is 1. If you increase it to 100, it will perform this option:
```SQL
set global sql_slave_skip_counter=100; start slave;
```
This will allow the script to skip 100 binlog events at a time, completing its task much faster. However, it will also skip a few transactions in the binlog that would otherwise succeed. If you don't want to lose valid transactions, do not change this option.

`--milliseconds=25`
A pause is necessary between each skipped error and the check to see if there is another error. The default is `50`. You can lower this number safely to make the script run a little faster. If it is too low, the script will exit early and provide a warning: `This script exited early. Increase milliseconds to avoid this issue.`

### Sharing Results With MariaDB Support
When the script completes, it will output the name of a logfile that you can share in a Mariadb support ticket:
```
The logfile /tmp/start_replica_assistant_0423_094947.log contains the details from running this script.
```