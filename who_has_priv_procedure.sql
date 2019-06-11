-- -----------------------------------------------------------------------------
--                 WWW.PETEFINNIGAN.COM LIMITED
-- -----------------------------------------------------------------------------
-- Script Name : who_has_priv_procedure.sql
-- Author      : Pete Finnigan
-- Date        : March 2009
-- -----------------------------------------------------------------------------
-- Description : Use this procedure to find which users have been granted the 
--               privilege passed in. The script checks hierarchically for each
--               user granted the privileges via a role.
--      
--               The output can be directed to either the screen via dbms_output
--               or to a file via utl_file. The method is decided at run time 
--               by choosing either 'S' for screen or 'F' for File. If File is
--               chosen then a filename and output directory are needed. The 
--               output directory needs to be enabled via utl_file_dir prior to
--               9iR2 and a directory object after.
-- -----------------------------------------------------------------------------
-- Maintainer  : Pete Finnigan (http://www.petefinnigan.com)
-- Copyright   : Copyright (C) 2009 PeteFinnigan.com Limited. All rights
--               reserved. All registered trademarks are the property of their
--               respective owners and are hereby acknowledged.
-- -----------------------------------------------------------------------------
--  Usage      : The script provided here is available free. You can do anything 
--               you want with it commercial or non commercial as long as the 
--               copyrights and this notice are not removed or edited in any way. 
--               The scripts cannot be posted / published / hosted or whatever 
--               anywhere else except at www.petefinnigan.com/tools.htm
-- -----------------------------------------------------------------------------
-- Version History
-- ===============
--
-- Who         version     Date      Description
-- ===         =======     ======    ======================
-- P.Finnigan  1.0         Mar 2009  First Issue. Based on who_has_priv.sql
-- -----------------------------------------------------------------------------
whenever sqlerror exit rollback
set feed on
set head on
set arraysize 1
set space 1
set verify off
set pages 25
set lines 80
set termout on
set serveroutput on size 1000000

spool who_has_priv_procedure.lis

create or replace procedure who_has_priv(
		pv_priv_to_find in varchar2,
		pv_out_meth in varchar2 default 'S',
		pv_file_name in varchar2 default NULL,
		pv_directory in varchar2 default NULL)
authid current_user is
    --
    lg_sys_date varchar2(100);
    lg_fptr utl_file.file_type;
    lv_file_or_screen varchar2(1):='S';
    --
    procedure open_file (pv_file_name in varchar2,
            pv_dir_name in varchar2) is 
    begin
        lg_fptr:=utl_file.fopen(pv_dir_name,pv_file_name,'A');
    exception
        when utl_file.invalid_path  then
            dbms_output.put_line('invalid path');
        when utl_file.invalid_mode  then
            dbms_output.put_line('invalid mode');
        when utl_file.invalid_filehandle  then
            dbms_output.put_line('invalid filehandle');
        when utl_file.invalid_operation  then
            dbms_output.put_line('invalid operation');
        when utl_file.read_error  then
            dbms_output.put_line('read error');
        when utl_file.write_error  then
            dbms_output.put_line('write error');
        when utl_file.internal_error  then
            dbms_output.put_line('internal error');
        when others then
            dbms_output.put_line('ERROR (open_file) => '||sqlcode);
            dbms_output.put_line('MSG (open_file) => '||sqlerrm);

    end open_file;
    --
    procedure close_file is
    begin
        utl_file.fclose(lg_fptr);
    exception
        when utl_file.invalid_path  then
            dbms_output.put_line('invalid path');
        when utl_file.invalid_mode  then
            dbms_output.put_line('invalid mode');
        when utl_file.invalid_filehandle  then
            dbms_output.put_line('invalid filehandle');
        when utl_file.invalid_operation  then
            dbms_output.put_line('invalid operation');
        when utl_file.read_error  then
            dbms_output.put_line('read error');
        when utl_file.write_error  then
            dbms_output.put_line('write error');
        when utl_file.internal_error  then
            dbms_output.put_line('internal error');
        when others then
            dbms_output.put_line('ERROR (close_file) => '||sqlcode);
            dbms_output.put_line('MSG (close_file) => '||sqlerrm);

    end close_file;
    --
    procedure write_op (pv_str in varchar2) is
    begin
        if lv_file_or_screen='S' then
            dbms_output.put_line(pv_str);
        else
            utl_file.put_line(lg_fptr,pv_str);
        end if;
    exception
        when utl_file.invalid_path  then
            dbms_output.put_line('invalid path');
        when utl_file.invalid_mode  then
            dbms_output.put_line('invalid mode');
        when utl_file.invalid_filehandle  then
            dbms_output.put_line('invalid filehandle');
        when utl_file.invalid_operation  then
            dbms_output.put_line('invalid operation');
        when utl_file.read_error  then
            dbms_output.put_line('read error');
        when utl_file.write_error  then
            dbms_output.put_line('write error');
        when utl_file.internal_error  then
            dbms_output.put_line('internal error');
        when others then
            dbms_output.put_line('ERROR (write_op) => '||sqlcode);
            dbms_output.put_line('MSG (write_op) => '||sqlerrm);

    end write_op;
    --
    function user_or_role(pv_grantee in dba_users.username%type) 
    return varchar2 is
        --
        cursor c_use (cp_grantee in dba_users.username%type) is
        select  'USER' userrole 
        from    dba_users u 
        where   u.username=cp_grantee 
        union 
        select  'ROLE' userrole 
        from    dba_roles r 
        where   r.role=cp_grantee;
        --
        lv_use c_use%rowtype;
    begin
        open c_use(pv_grantee);
        fetch c_use into lv_use;
        close c_use;
        return lv_use.userrole;
    exception
        when others then
            dbms_output.put_line('ERROR (user_or_role) => '||sqlcode);
            dbms_output.put_line('MSG (user_or_role) => '||sqlerrm);
    end user_or_role;
    --
    procedure get_priv (pv_privilege in varchar2) is
        --
        cursor c_main (cp_privilege in varchar2) is
	select	p.grantee,
		p.admin_option
	from	dba_sys_privs p
	where	p.privilege=cp_privilege;
        --
        lv_userrole dba_users.username%type;
        lv_tabstop number;
        --
        procedure get_users(pv_grantee in dba_roles.role%type,pv_tabstop in out number) is
            --
            lv_tab varchar2(50):='';
            lv_loop number;
            lv_user_or_role dba_users.username%type;
            --
            cursor c_user (cp_username in dba_role_privs.grantee%type) is
            select  r.grantee,
                    r.admin_option
            from    dba_role_privs r
            where   r.granted_role=cp_username;
            --
        begin
            pv_tabstop:=pv_tabstop+1;
            for lv_loop in 1..pv_tabstop loop
                lv_tab:=lv_tab||chr(9);
            end loop;
            
            for lv_user in c_user(pv_grantee) loop
                lv_user_or_role:=user_or_role(lv_user.grantee);
                if lv_user_or_role = 'ROLE' then
	            if lv_user.grantee = 'PUBLIC' then
       			write_op(lv_tab||'Role => '||lv_user.grantee
       				||' (ADM = '||lv_user.admin_option||')');
            	    else
       			write_op(lv_tab||'Role => '||lv_user.grantee
       				||' (ADM = '||lv_user.admin_option||')'
       				||' which is granted to =>');
            	    end if;
                    get_users(lv_user.grantee,pv_tabstop);
                else
               	    write_op(lv_tab||'User => '||lv_user.grantee
                		||' (ADM = '||lv_user.admin_option||')');
                end if;
            end loop;
            pv_tabstop:=pv_tabstop-1;
            lv_tab:='';
        exception
            when others then
                dbms_output.put_line('ERROR (get_users) => '||sqlcode);
                dbms_output.put_line('MSG (get_users) => '||sqlerrm);        
        end get_users;
        --
    begin
        lv_tabstop:=1;
        for lv_main in c_main(pv_privilege) loop	
		lv_userrole:=user_or_role(lv_main.grantee);
		if lv_userrole='USER' then
                	write_op(chr(9)||'User => '||lv_main.grantee
                		||' (ADM = '||lv_main.admin_option||')');
		else
            		if lv_main.grantee='PUBLIC' then
            			write_op(chr(9)||'Role => '||lv_main.grantee
            				||' (ADM = '||lv_main.admin_option||')');
            		else
            			write_op(chr(9)||'Role => '||lv_main.grantee
            				||' (ADM = '||lv_main.admin_option||')'
            				||' which is granted to =>');
            		end if;
                	get_users(lv_main.grantee,lv_tabstop);
		end if;
	end loop;
    exception
        when others then
            dbms_output.put_line('ERROR (get_priv) => '||sqlcode);
            dbms_output.put_line('MSG (get_priv) => '||sqlerrm);
    end get_priv;
begin
	lv_file_or_screen:= upper(pv_out_meth);
	if lv_file_or_screen='F' then
        	open_file(pv_file_name,pv_directory);
	end if;
	select to_char(sysdate,'Dy Mon dd hh24:mi:ss yyyy') system_date 
	into lg_sys_date
	from sys.dual;

	write_op('who_has_priv: Release 1.0.1.0.0 - Production on '||lg_sys_date);
	write_op('Copyright (c) 2009 PeteFinnigan.com Limited. All rights reserved.');
    	write_op('Privilege => '||upper(pv_priv_to_find)||' has been granted to =>');
    	write_op('====================================================================');
	get_priv(upper(pv_priv_to_find));
	if lv_file_or_screen='F' then
        	close_file;
	end if;
	write_op('For updates please visit http://www.petefinnigan.com/tools.htm');
	write_op(chr(10));
exception
    when others then
        dbms_output.put_line('ERROR (main) => '||sqlcode);
        dbms_output.put_line('MSG (main) => '||sqlerrm);

end;
/

spool off