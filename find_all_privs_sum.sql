-- -----------------------------------------------------------------------------
--                 WWW.PETEFINNIGAN.COM LIMITED
-- -----------------------------------------------------------------------------
-- Script Name : find_all_privs_sum.sql
-- Author      : Pete Finnigan
-- Date        : July 2012
-- -----------------------------------------------------------------------------
-- Description : Use this script to find which privileges have been granted to a
--               particular user. This scripts lists ROLES, SYSTEM privileges
--               and object privileges granted to a user. If a ROLE is found
--               then it is checked recursively.
--      
--               The output can be directed to either the screen via dbms_output
--               or to a file via utl_file. The method is decided at run time 
--               by choosing either 'S' for screen or 'F' for File. If File is
--               chosen then a filename and output directory are needed. The 
--               output directory needs to be enabled via utl_file_dir prior to
--               9iR2 and a directory object after.
--
--               This version is the same as find_all_privs.sql but it prints
--               instead a summary of common roles contents so that the output
--               is smaller
-- -----------------------------------------------------------------------------
-- Maintainer  : Pete Finnigan (http://www.petefinnigan.com)
-- Copyright   : Copyright (C) 2004 PeteFinnigan.com Limited. All rights
--               reserved. All registered trademarks are the property of their
--               respective owners and are hereby acknowledged.
-- -----------------------------------------------------------------------------
--  Usage      : The script provided here is available free. You can do anything 
--               you want with it commercial or non commercial as long as the 
--               copyrights and this notice are not removed or edited in any way. 
--               The scripts cannot be posted / published / hosted or whatever 
--               anywhere else except at www.petefinnigan.com/tools.htm
-- -----------------------------------------------------------------------------
-- To Do       :
--               1 - add proxy connection authorities
--               2 - add SELECT ANY TABLE and SELECT ANY DICTIONARY access
-- -----------------------------------------------------------------------------
-- Version History
-- ===============
--
-- Who         version     Date      Description
-- ===         =======     ======    ======================
-- P.Finnigan  1.0         Jul 2012  First Issue. Created from find_all_privs.sql
--                                   This version outputs a summary of object
--                                   privileges instead of details; rest is the 
--                                   same
-- -----------------------------------------------------------------------------

--whenever sqlerror exit rollback
set feed on
set head on
set arraysize 1
set space 1
set verify off
set pages 25
set lines 80
set termout on
--clear screen
set serveroutput on size 1000000

undefine user_to_find
undefine output_method
undefine file_name
undefine output_dir

set feed off
col system_date  noprint new_value val_system_date
select to_char(sysdate,'Dy Mon dd hh24:mi:ss yyyy') system_date from sys.dual;
set feed on

prompt find_all_privs: Release 1.0.7.0.0 - Production on &val_system_date
prompt Copyright (c) 2004 PeteFinnigan.com Limited. All rights reserved. 
prompt
accept user_to_find char prompt  'NAME OF USER TO CHECK                 [ORCL]: ' default ORCL
accept output_method char prompt 'OUTPUT METHOD Screen/File                [S]: ' default S
accept file_name char prompt     'FILE NAME FOR OUTPUT              [priv.lst]: ' default priv.lst
accept output_dir char prompt    'OUTPUT DIRECTORY [DIRECTORY  or file (/tmp)]: ' default /tmp
prompt 

--spool find_all_privs.lis.&&user_to_find
declare
    --
    lv_tabs number:=0;
    lv_file_or_screen varchar2(1):='S';
    --
    procedure write_op (pv_str in varchar2) is
    begin
            dbms_output.put_line(pv_str);
    exception
        when others then
            dbms_output.put_line('ERROR (write_op) => '||sqlcode);
            dbms_output.put_line('MSG (write_op) => '||sqlerrm);

    end write_op;
    --
    procedure get_privs (pv_grantee in varchar2,lv_tabstop in out number) is
        --
        lv_tab varchar2(50):='';
        lv_loop number;
        --
        cursor c_main (cp_grantee in varchar2) is
        select  'ROLE' typ,
            grantee grantee,
            granted_role priv,
            admin_option ad,
            '--' tabnm,
            '--' colnm,
            '--' owner
        from    dba_role_privs
        where   grantee=cp_grantee
        union
        select  'SYSTEM' typ,
            grantee grantee,
            privilege priv,
            admin_option ad,
            '--' tabnm,
            '--' colnm,
            '--' owner
        from    dba_sys_privs
        where   grantee=cp_grantee
        union
	select typ,grantee,priv,ad,'Count['||to_char(count(*))||']' tabnm,colnm,owner
	from (
		select  'TABLE' typ,
		grantee grantee,
		privilege priv,
		grantable ad,
		table_name tabnm,
		'--' colnm,
		owner owner
		from    dba_tab_privs
		where   grantee=cp_grantee)
	group by typ,grantee,priv,ad,colnm,owner
        union
        select  'COLUMN' typ,
            grantee grantee,
            privilege priv,
            grantable ad,
            table_name tabnm,
            column_name colnm,
            owner owner
        from    dba_col_privs
        where   grantee=cp_grantee
        order by 1;
    begin
        lv_tabstop:=lv_tabstop+1;
        for lv_loop in 1..lv_tabstop loop
            lv_tab:=lv_tab||chr(9);
        end loop;
        for lv_main in c_main(pv_grantee) loop
            if lv_main.typ='ROLE' then
                write_op(lv_tab||'ROLE => '
                ||lv_main.priv||' which contains =>'); 
                get_privs(lv_main.priv,lv_tabstop);
            elsif lv_main.typ='SYSTEM' then
                write_op(lv_tab||'SYS PRIV => '
                    ||lv_main.priv
                    ||' grantable => '||lv_main.ad);
            elsif lv_main.typ='TABLE' then
                write_op(lv_tab||'TABLE PRIV => '
                    ||lv_main.priv
                    ||' object => '
                    ||lv_main.owner||'.'||lv_main.tabnm
                    ||' grantable => '||lv_main.ad);
            elsif lv_main.typ='COLUMN' then
                write_op(lv_tab||'COL PRIV => '
                    ||lv_main.priv
                    ||' object => '||lv_main.tabnm
                    ||' column_name => '
                    ||lv_main.owner||'.'||lv_main.colnm
                    ||' grantable => '||lv_main.ad);
            end if;
        end loop;
        lv_tabstop:=lv_tabstop-1;
        lv_tab:='';
    exception
        when others then
            dbms_output.put_line('ERROR (get_privs) => '||sqlcode);
            dbms_output.put_line('MSG (get_privs) => '||sqlerrm);
    end get_privs;
begin
    	write_op('User => '||upper('&&user_to_find')||' has been granted the following privileges');
    	write_op('====================================================================');    
	get_privs(upper('&&user_to_find'),lv_tabs);
exception
    when others then
        dbms_output.put_line('ERROR (main) => '||sqlcode);
        dbms_output.put_line('MSG (main) => '||sqlerrm);

end;
/
prompt For updates please visit http://www.petefinnigan.com/tools.htm
prompt
--spool off

whenever sqlerror continue