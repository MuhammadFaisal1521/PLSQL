-- -----------------------------------------------------------------------------
--                 WWW.PETEFINNIGAN.COM LIMITED
-- -----------------------------------------------------------------------------
-- Script Name : check_parameter.sql
-- Author      : Pete Finnigan
-- Date        : June 2004
-- -----------------------------------------------------------------------------
-- Description : Use this script to find the value of an Oracle initialisation
--               parameter. It handles undocument ("_" underscore) parameters
--               as well as normal ones. You can also pass in the value that the
--               parameter should have and the procedure indicates if the setting
--               violates this or not.
--      
--               The output can be directed to either the screen via dbms_output
--               or to a file via utl_file. The method is decided at run time 
--               by choosing either 'S' for screen or 'F' for File. If File is
--               chosen then a filename and output directory are needed. The 
--               output directory needs to be enabled via utl_file_dir prior to
--               9iR2 and a directory object after.
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
-- Version History
-- ===============
--
-- Who         version     Date      Description
-- ===         =======     ======    ======================
-- P.Finnigan  1.0         Jun 2004  First Issue.
-- P.Finnigan  1.1         Apr 2005  Added whenever sqlerror continue to stop 
--                                   subsequent errors barfing SQL*Plus. Thanks
--                                   to Norman Dunbar for the update.
-- P.Finnigan  1.2         Apr 2005  Corrected spelling mistake in the output.
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
clear screen
set serveroutput on size 1000000

spool check_parameter.lis

undefine param_to_check
undefine param_val
undefine output_method
undefine file_name
undefine output_dir

set feed off
col system_date  noprint new_value val_system_date
select to_char(sysdate,'Dy Mon dd hh24:mi:ss yyyy') system_date from sys.dual;
set feed on

prompt check_parameter: Release 1.0.2.0.0 - Production on &val_system_date
prompt Copyright (c) 2004 PeteFinnigan.com Limited. All rights reserved. 
prompt 
accept param_to_check char prompt 'PARAMETER TO CHECK            [utl_file_dir]: ' default utl_file_dir
accept param_val char prompt      'CORRECT VALUE                         [null]: ' default null
accept output_method char prompt  'OUTPUT METHOD Screen/File                [S]: ' default S
accept file_name char prompt      'FILE NAME FOR OUTPUT              [priv.lst]: ' default priv.lst
accept output_dir char prompt     'OUTPUT DIRECTORY [DIRECTORY  or file (/tmp)]: ' default /tmp
prompt 

declare
    --
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
    procedure get_param (pv_param in varchar2, pv_val in varchar2) is
        --
        cursor c_main (cp_param in varchar2) is
	select	x.ksppinm  name,
		y.ksppstvl  value,
		decode(ksppity,1,'BOOLEAN',2,'STRING',3,'INTEGER',
			4,'PARAMETER FILE',5,'RESERVED',6,'BIG INTEGER','UNKNOWN') typ,
		decode(ksppstdf,'TRUE','DEFAULT VALUE','FALSE','***SPECIFIED IN INIT.ORA') isdefault,  
		decode(bitand(ksppiflg/256,1),1,'***CAN BE CHANGED WITH ALTER SESSION','FALSE') isses_modifiable,  
		decode(bitand(ksppiflg/65536,3),1,'CAN BE CHANGED IMMEDIATELY WITH ALTER SYSTEM',
			2,'***CAN BE CHANGED WITH ALTER SYSTEM, CHANGES TAKE EFFECT IN SUBSEQUENT SESSIONS',
			3,'***CAN BE CHANGED IMMEDIATELY WITH ALTER SYSTEM','FALSE') issys_modifiable,
		decode(bitand(ksppstvf,7),1,'WAS MODIFIED WITH ALTER SESSION',
			4,'***WAS MODIFIED WITH ALTER SYSTEM','FALSE') is_modified,  
		decode(bitand(ksppstvf,2),2,'***ORACLE CHANGED THE VALUE ON STARTUP','FALSE') is_adjusted,  
		ksppdesc description, 
		ksppstcmnt  update_comment	  	
	from 	x$ksppi x, 
	  	x$ksppcv y 
	where 	x.inst_id = userenv('Instance') 
	and	y.inst_id = userenv('Instance') 
	and	x.indx = y.indx 
	and     x.ksppinm = cp_param;
	lv_main c_main%rowtype;
        --
    begin
        open c_main(pv_param);
        fetch c_main into lv_main;
        if c_main%found then
        	write_op('Name                  : '||lv_main.name);
        	write_op('Value                 : '||lv_main.value);
        	write_op('Type                  : '||lv_main.typ);
        	write_op('Is Default            : '||lv_main.isdefault);
        	write_op('Is Session modifiable : '||lv_main.isses_modifiable);
        	write_op('Is System modifiable  : '||lv_main.issys_modifiable);
        	write_op('Is Modified           : '||lv_main.is_modified);
        	write_op('Is Adjusted           : '||lv_main.is_adjusted);
        	write_op('Description           : '||lv_main.description);
        	write_op('Update Comment        : '||lv_main.update_comment);
        	write_op('-------------------------------------------------------------------------');
       		if to_char(lv_main.value) <> nvl(pv_val,'NULL') then
       			write_op('value ***'||lv_main.value||'*** is incorrect');
       		else
       			write_op('value is correct');
       		end if;
        	
        else
        	write_op('ERROR: PARAMETER '||pv_param||' NOT FOUND');
        end if;
    exception
        when others then
            dbms_output.put_line('ERROR (get_param) => '||sqlcode);
            dbms_output.put_line('MSG (get_param) => '||sqlerrm);
    end get_param;
begin
	lv_file_or_screen:= upper('&&output_method');
	if lv_file_or_screen='F' then
        	open_file('&&file_name','&&output_dir');
	end if;
    	write_op('Investigating parameter => '||'&&param_to_check');
    	write_op('====================================================================');
	get_param('&&param_to_check','&&param_val');
	if lv_file_or_screen='F' then
        	close_file;
	end if;
exception
    when others then
        dbms_output.put_line('ERROR (main) => '||sqlcode);
        dbms_output.put_line('MSG (main) => '||sqlerrm);

end;
/
prompt For updates please visit http://www.petefinnigan.com/tools.htm
prompt
spool off

undefine param_to_check
undefine param_val
undefine output_method
undefine file_name
undefine output_dir

whenever sqlerror continue