-- CLEANUP AFTER DEMO RUN ON MASTER WHEN REPLICATION IS WORKING
SET SESSION BINLOG_FORMAT=STATEMENT;
DELIMITER //
BEGIN NOT ATOMIC
 SET @MSG='NONE';
 SELECT 'DROPPING SCHEMA widget_demo.'  into @MSG from information_schema.SCHEMATA where SCHEMA_NAME='widget_demo';

if @MSG != 'NONE' then
  select @MSG as MESSAGE;
  drop schema if exists widget_demo;
end if;
end;
//
DELIMITER ;

-- DROP USERS:
SET SESSION BINLOG_FORMAT=STATEMENT;
DELIMITER //
BEGIN NOT ATOMIC
 SET @MSG='NONE';
  SELECT 'DROPPING demo USERS.'  into @MSG from mysql.user where `user` like 'demo%' and host='199.99.199.199' limit 1;
if @MSG != 'NONE' then
  select @MSG as MESSAGE;
  drop user if  exists `demo1`@`199.99.199.199`;
  drop user if  exists `demo2`@`199.99.199.199`;
  drop user if  exists `demo3`@`199.99.199.199`;
  drop user if  exists `demo4`@`199.99.199.199`;
  drop user if  exists `demo5`@`199.99.199.199`;
end if;
end;
//
