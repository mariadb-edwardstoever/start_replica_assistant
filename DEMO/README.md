# IMPORANT INFORMATION ABOUT THIS DEMO

The demo is used to produce a situation of typical replication errors to be handled by the Mariadb Start Replica Assistant. 
The demo should be run in a test environment only. The demo scripts will not set up replication, rather they will break existing replication! 

When using a named connection, uncomment the first line of STEP2_widget_demo_RUN_ON_SLAVE.sql and change MYCONNECTION to your connection name.

To set up the demo, run these scripts on the host indicated by the name of the script (MASTER or SLAVE):
* STEP1_widget_demo_RUN_ON_MASTER.sql
* STEP2_widget_demo_RUN_ON_SLAVE.sql 
* STEP3_widget_demo_RUN_ON_MASTER.sql

After STEPS 1 through 3 are completed, you may run the Start Replica Assistant in a typical fashion.

After the demo is completed, you may clean up the demo by running this script on the master:
* CLEANUP_after_demo_RUN_ON_MASTER.sql

