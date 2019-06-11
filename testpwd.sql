-- -----------------------------------------------------------------------------
--                 WWW.PETEFINNIGAN.COM LIMITED
-- -----------------------------------------------------------------------------
-- Script Name : testpwd.sql
-- Author      : Pete Finnigan
-- Date        : May 2009
-- -----------------------------------------------------------------------------
-- Description : This script can be used to test users passwords in databases 
--               of versions 7 - 10gR2
-- -----------------------------------------------------------------------------
-- Maintainer  : Pete Finnigan (http://www.petefinnigan.com)
-- Copyright   : Copyright (C) 2008, 2009, PeteFinnigan.com Limited. All rights
--               reserved. All registered trademarks are the property of their
--               respective owners and are hereby acknowledged.
-- -----------------------------------------------------------------------------
-- License     : This software is free software BUT it is not in the public
--               domain. This means that you can use it for personal or 
--               commercial work but you cannot remove this notice or copyright
--               notices or the banner output by the program or edit them in any
--               way at all. You also cannot host/distribute/copy or in anyway 
--               make this script available through any means either in original
--               form or any derivitive work based on it. The script is 
--               only available from its own webpage 
--               http://www.petefinnigan.com/testpwd.sql or any other page that
--               PeteFinnigan.com Limited hosts it from.
--               This script cannot be incorporated into any other free or 
--               commercial tools without permission from PeteFinnigan.com 
--               Limited.
--
--               In simple terms use it for free but dont make it available in
--               any way or build it into any other tools. 
-- -----------------------------------------------------------------------------
-- Version History
-- ===============
--
-- Who         version     Date      Description
-- ===         =======     ======    ======================
-- P.Finnigan  1.0         May 2009  First Issue.
-- P.Finnigan  1.1         May 2009  Added calls to upper for username/password
--                                   Thanks to Kennie Nybo Pontoppidan.
--
-- -----------------------------------------------------------------------------

create or replace function testpwd(username in varchar2, password in varchar2)
return char
authid current_user
is
	--
	raw_key raw(128):= hextoraw('0123456789ABCDEF');
	--
	raw_ip raw(128);
	pwd_hash varchar2(16);
	--
	cursor c_user (cp_name in varchar2) is
	select 	password
	from sys.user$
	where password is not null
	and name=cp_name;
	--
	procedure unicode_str(userpwd in varchar2, unistr out raw)
	is
		enc_str varchar2(124):='';
		tot_len number;
		curr_char char(1);
		padd_len number;
		ch char(1);
		mod_len number;
		debugp varchar2(256);
	begin
		tot_len:=length(userpwd);
		for i in 1..tot_len loop
			curr_char:=substr(userpwd,i,1);
			enc_str:=enc_str||chr(0)||curr_char;
		end loop;
		mod_len:= mod((tot_len*2),8);
		if (mod_len = 0) then
			padd_len:= 0;
		else
			padd_len:=8 - mod_len;
		end if;
		for i in 1..padd_len loop
			enc_str:=enc_str||chr(0);
		end loop;
		unistr:=utl_raw.cast_to_raw(enc_str);
	end;
	--
	function crack (userpwd in raw) return varchar2 
	is
		enc_raw raw(2048);
		--
		raw_key2 raw(128);
		pwd_hash raw(2048);
		--
		hexstr varchar2(2048);
		len number;
		password_hash varchar2(16);	
	begin
		dbms_obfuscation_toolkit.DESEncrypt(input => userpwd, 
		       key => raw_key, encrypted_data => enc_raw );
		hexstr:=rawtohex(enc_raw);
		len:=length(hexstr);
		raw_key2:=hextoraw(substr(hexstr,(len-16+1),16));
		dbms_obfuscation_toolkit.DESEncrypt(input => userpwd, 
		       key => raw_key2, encrypted_data => pwd_hash );
		hexstr:=hextoraw(pwd_hash);
		len:=length(hexstr);
		password_hash:=substr(hexstr,(len-16+1),16);
		return(password_hash);
	end;
begin
	open c_user(upper(username));
	fetch c_user into pwd_hash;
	close c_user;
	unicode_str(upper(username)||upper(password),raw_ip);
	if( pwd_hash = crack(raw_ip)) then
		return ('Y');
	else
		return ('N');
	end if;
end;
/