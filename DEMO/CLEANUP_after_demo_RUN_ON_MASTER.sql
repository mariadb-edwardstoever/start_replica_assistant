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
