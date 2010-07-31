unit samba;

{$mode objfpc}{$H+}
interface

uses
Classes, SysUtils,variants,strutils,IniFiles,unix,dateUtils,BaseUnix,
zsystem      in '/home/dtouzeau/developpement/artica-postfix/bin/src/artica-install/zsystem.pas',
logs         in '/home/dtouzeau/developpement/artica-postfix/bin/src/artica-install/logs.pas',
RegExpr      in '/home/dtouzeau/developpement/artica-postfix/bin/src/artica-install/RegExpr.pas',
openldap     in '/home/dtouzeau/developpement/artica-postfix/bin/src/artica-install/openldap.pas';

  type
  Tsamba=class


private
     LOGS:Tlogs;
     artica_path:string;
     mem_version:string;
     SYS:TSystem;
     openldap:topenldap;
     verbose:boolean;
     SambaEnableEditPosixExtension:integer;
     SambaEnabled:integer;
     EnableScannedOnly:integer;
     function COMMANDLINE_PARAMETERS(FoundWhatPattern:string):boolean;
     function ReadFileIntoString(path:string):string;
     procedure StripDiezes(filepath:string);
     function lib_pam_ldap_path():string;
     function lib_nss_ldap_path():string;
     function auth_client_config_path():string;
     procedure ETC_LDAP_CONF_SET_VALUE(key:string;value:string);
     procedure SMB_CONF_SET_VALUE(key:string;value:string);
     function AUTH_CLIENT_CONFIG_VERIF_PROFILE(profilename:string):boolean;
     function ParseUsbSharesDisconnect(dev_source:string;uuid:string;target_mount:string;time_disconnect:string):boolean;
     function UsbDisconnect(dev_source:string;uuid:string;target_mount:string):boolean;
     function UsCreateLockFile(uuid:string):boolean;
     function nss_initgroups_ignoreusers():string;
     function SMB_CONF_GET_VALUE(masterkey:string;key:string):string;
     procedure SAMBA_WINBINDD_START();



public
    procedure Free;
    constructor Create;
    procedure smbldap_conf();
    procedure libnss_conf();
    procedure pam_ldap_conf();
    procedure nsswitch_conf();
    procedure default_config();
    
    procedure SAMBA_START();
    procedure SAMBA_STOP();
    procedure NMBD_STOP();
    procedure SMBD_STOP();
    FUNCTION  SAMBA_STATUS():string;
    function  SAMBA_VERSION():string;
    function  SMBD_PATH():string;
    function  SMBD_PID():string;
    function  NMBD_PID():string;
    function  SCANNED_ONLY_PID():string;
    function  INITD_PATH():string;
    function  PBEDIT_PATH():string;
    function  smbpasswd_path():string;
    function  slappasswd_path():string;
    function  smbconf_path():string;
    function  vfs_path():string;
    FUNCTION  SAMBA_AUDIT():string;
    function  ParseSharedDirectories():TstringList;
    procedure ParseUsbShares();

    function  NMBD_BIN_PATH():string;
    function  WINBIND_PID():string;
    function  WINBIND_BIN_PATH():string;
    function  INITD_WINBIND_PATH():string;
    procedure WINBIND_START();
    procedure SAMBA_NMBD_START();
    procedure SAMBA_SMBD_START();
    procedure WINBIND_STOP();
    function  WINBIND_VERSION():string;
    procedure SCANNED_ONLY_START();
    procedure SCANNED_ONLY_STOP();


    procedure FixDirectoriesChmod();
    procedure PAM_LDAP_SECRET();
    procedure SAMBA_VFS_PLUGINS();
    procedure AUTH_CLIENT_CONFIG();
    procedure Reconfigure(restart:boolean=true);
    procedure BUILD_PROFILE(username:string);
    procedure LINKING_LIBRARY();
    procedure REMOVE();
END;

implementation

constructor Tsamba.Create;
begin


       SambaEnableEditPosixExtension:=0;
       SambaEnabled:=1;


       forcedirectories('/etc/artica-postfix');
       LOGS:=tlogs.Create();
       SYS:=Tsystem.CReate;
       if not TryStrToInt(SYS.GET_INFO('SambaEnableEditPosixExtension'),SambaEnableEditPosixExtension) then SambaEnableEditPosixExtension:=0;
       if not TryStrToInt(SYS.GET_INFO('SambaEnabled'),SambaEnabled) then SambaEnabled:=1;
       if not TryStrToInt(SYS.GET_INFO('EnableScannedOnly'),EnableScannedOnly) then EnableScannedOnly:=1;
       if SambaEnabled=0 then EnableScannedOnly:=0;



       if not DirectoryExists('/usr/share/artica-postfix') then begin
              artica_path:=ParamStr(0);
              artica_path:=ExtractFilePath(artica_path);
              artica_path:=AnsiReplaceText(artica_path,'/bin/','');

      end else begin
  artica_path:='/usr/share/artica-postfix';
  end;
  verbose:=false;
  verbose:=COMMANDLINE_PARAMETERS('--verbose');
  openldap:=Topenldap.Create;
       
end;
//##############################################################################
procedure Tsamba.free();
begin
    logs.FRee;
    

end;
//##############################################################################
procedure Tsamba.nsswitch_conf();
var
  l:TstringList;
  winbind:string;
begin

if not FileExists(lib_pam_ldap_path()) then begin
   logs.Debuglogs('nsswitch_conf:: unable to stat pam_ldap.so');
   exit;
end;

if not FileExists(lib_nss_ldap_path()) then begin
   logs.Debuglogs('nsswitch_conf:: unable to stat libnss-ldap');
   exit;
end;

if FileExists(WINBIND_BIN_PATH()) then winbind:=' winbind';


  l:=TstringList.Create;
l.Add('# /etc/nsswitch.conf');
l.Add('#');
l.Add('# Example configuration of GNU Name Service Switch functionality.');
l.Add('# If you have the `glibc-doc-reference'' and `info'' packages installed, try:');
l.Add('# `info libc "Name Service Switch"'' for information about this file.');
l.Add('bind_policy soft');
l.Add('');
l.Add('passwd:         files ldap'+winbind);
l.Add('group:          files ldap'+winbind);
l.Add('shadow:         files ldap');
l.Add('');
l.Add('hosts:          files dns');
l.Add('networks:       files');
l.Add('');
l.Add('protocols:      db files');
l.Add('services:       db files');
l.Add('ethers:         db files');
l.Add('rpc:            db files');
l.Add('');
l.Add('netgroup:       nis');
l.SaveToFile('/etc/nsswitch.conf');
l.free;
end;
//##############################################################################
function Tsamba.COMMANDLINE_PARAMETERS(FoundWhatPattern:string):boolean;
var
   i:integer;
   s:string;
   RegExpr:TRegExpr;

begin
 s:='';
 result:=false;
 if ParamCount>1 then begin
     for i:=2 to ParamCount do begin
        s:=s  + ' ' +ParamStr(i);
     end;
 end;
   RegExpr:=TRegExpr.Create;
   RegExpr.Expression:=FoundWhatPattern;
   if RegExpr.Exec(s) then begin
      RegExpr.Free;
      result:=True;
   end;


end;
//##############################################################################
function Tsamba.SMBD_PATH():string;
begin
 if FileExists('/usr/sbin/smbd') then exit('/usr/sbin/smbd');
end;
//##############################################################################
function Tsamba.WINBIND_BIN_PATH():string;
begin
 if FileExists('/usr/sbin/winbindd') then exit('/usr/sbin/winbindd');
end;
//##############################################################################
function Tsamba.NMBD_BIN_PATH():string;
begin
 if FileExists('/usr/sbin/nmbd') then exit('/usr/sbin/nmbd');
end;
//##############################################################################
procedure Tsamba.REMOVE();
begin
SAMBA_STOP();
fpsystem('/usr/share/artica-postfix/bin/setup-ubuntu --remove "samba"');
if FIleExists(NMBD_BIN_PATH()) then logs.DeleteFile(NMBD_BIN_PATH());
if FIleExists(WINBIND_BIN_PATH()) then logs.DeleteFile(WINBIND_BIN_PATH());
if FIleExists(SMBD_PATH()) then logs.DeleteFile(SMBD_PATH());
logs.DeleteFile('/etc/artica-postfix/versions.cache');
fpsystem('/usr/share/artica-postfix/bin/artica-install --write-versions');
fpsystem('/usr/share/artica-postfix/bin/process1 --force');
end;
//##############################################################################
function Tsamba.SMBD_PID():string;
var
   pid:string;
begin
if FileExists('/var/run/smbd.pid') then pid:=SYS.GET_PID_FROM_PATH('/var/run/smbd.pid');
if FileExists('/var/run/samba/smbd.pid') then pid:=SYS.GET_PID_FROM_PATH('/var/run/samba/smbd.pid');
if verbose then writeln('PID=',pid);
if not SYS.PROCESS_EXIST(pid) then begin
   if verbose then writeln('Process not exists: ',pid);
   pid:=SYS.PIDOF(SMBD_PATH());
   if verbose then writeln('PIDOF ',SMBD_PATH(),': ',pid);
   end;
result:=pid;
end;
//##############################################################################
function Tsamba.NMBD_PID():string;
begin
if FileExists('/var/run/nmbd.pid') then result:=SYS.GET_PID_FROM_PATH('/var/run/nmbd.pid');
if FileExists('/var/run/samba/nmbd.pid') then result:=SYS.GET_PID_FROM_PATH('/var/run/samba/nmbd.pid');
if not SYS.PROCESS_EXIST(result) then result:=SYS.PIDOF(NMBD_BIN_PATH());
end;
//##############################################################################
function Tsamba.SCANNED_ONLY_PID():string;
begin
if FileExists('/var/run/scannedonly.pid') then result:=SYS.GET_PID_FROM_PATH('/var/run/scannedonly.pid');
if not SYS.PROCESS_EXIST(result) then result:=SYS.PIDOF('/usr/sbin/scannedonlyd_clamav');
end;
//##############################################################################
function Tsamba.WINBIND_PID():string;
var pid:string;
begin
    if FileExists('/var/run/samba/winbindd.pid') then begin
       pid:=SYS.GET_PID_FROM_PATH('/var/run/samba/winbindd.pid');
    end;

    if length(trim(pid))=0 then pid:=SYS.PIDOF(WINBIND_BIN_PATH());
    result:=pid;
end;
//##############################################################################
function Tsamba.INITD_PATH():string;
begin
 if FileExists('/etc/init.d/samba') then exit('/etc/init.d/samba');
 if FileExists('/etc/init.d/smb') then exit('/etc/init.d/smb');
end;
//##############################################################################
function Tsamba.INITD_WINBIND_PATH():string;
begin
 if FileExists('/etc/init.d/samba') then exit('/etc/init.d/samba');
 if FileExists('/etc/init.d/smb') then exit('/etc/init.d/smb');
end;
//##############################################################################
function Tsamba.PBEDIT_PATH():string;
begin
    if FileExists('/usr/bin/pdbedit') then exit('/usr/bin/pdbedit');
end;
//#########################################################################################
function Tsamba.smbpasswd_path():string;
begin
 if FileExists('/usr/bin/smbpasswd') then exit('/usr/bin/smbpasswd');
end;
//##############################################################################
function Tsamba.smbconf_path():string;
begin
 if FileExists('/etc/samba/smb.conf') then exit('/etc/samba/smb.conf');
end;
//##############################################################################
function Tsamba.slappasswd_path():string;
begin
if FileExists('/usr/sbin/slappasswd') then exit('/usr/sbin/slappasswd');
end;
//##############################################################################
function Tsamba.vfs_path():string;
begin
if DirectoryExists('/usr/lib/samba/vfs') then exit('/usr/lib/samba/vfs');
end;
//##############################################################################
procedure Tsamba.SAMBA_VFS_PLUGINS();
begin

if not DirectoryExists(vfs_path()) then begin
       logs.Debuglogs('SAMBA_VFS_PLUGINS:: unable to stat vfs samba path');
       exit;
end;

if not FileExists(vfs_path()+'/mysql_audit.so') then begin
    if FileExists(artica_path +'/bin/install/vfs/mysql_audit.so') then begin
       logs.OutputCmd('/bin/ln -s '+artica_path +'/bin/install/vfs/mysql_audit.so '+vfs_path()+'/mysql_audit.so');
    end;
end;
end;
//##############################################################################

procedure Tsamba.LINKING_LIBRARY();
var
l:TstringList;
i:integer;
begin
l:=TstringList.Create;
l.add('libnetapi.so');
l.add('libsmbclient.a');
l.add('libsmbclient.so.0');
l.add('libsmbsharemodes.so');
l.add('libtalloc.a');
l.add('libtalloc.so.1');
l.add('libtdb.so');
l.add('libwbclient.so');
l.add('libnetapi.a');
l.add('libnetapi.so.0');
l.add('libsmbclient.so');
l.add('libsmbsharemodes.a');
l.add('libsmbsharemodes.so.0');
l.add('libtalloc.so');
l.add('libtdb.a');
l.add('libtdb.so.1');
l.add('libwbclient.so.0');

for i:=0 to l.Count-1 do begin
     if FileExists('/etc/samba/'+ l.Strings[i]) then begin
        if not FileExists('/usr/lib/'+ l.Strings[i]) then begin
           logs.Debuglogs('Starting......: samba installing ' + l.Strings[i] + ' into /usr/lib');
           logs.OutputCmd('/bin/cp /etc/samba/'+ l.Strings[i] +' /usr/lib/'+ l.Strings[i] );
        end;
     end;
end;

end;
//##############################################################################

procedure Tsamba.SAMBA_START();
var
   pid:string;
   err:string;
   count:integer;
   i:integer;
begin

    logs.Debuglogs('Starting......: Samba enabled='+IntTostr(SambaEnabled));
    if SambaEnabled=0 then begin
           logs.Debuglogs('Starting......: Samba is disabled by artica');
           SAMBA_STOP();
           exit;
    end;

    SAMBA_SMBD_START();
    SAMBA_NMBD_START();
    SAMBA_WINBINDD_START();
    SCANNED_ONLY_START();
end;
//##############################################################################

procedure Tsamba.SAMBA_SMBD_START();
var
   pid:string;
   err:string;
   count:integer;
   i:integer;
begin

if not FileExists(SMBD_PATH()) then exit;
if not FileExists(smbpasswd_path()) then exit;

   logs.Debuglogs('###################### SAMBA ######################');

pid:=SMBD_PID();

if SYS.PROCESS_EXIST(pid) then begin
   logs.Debuglogs('Starting......: SMBD Already running PID ' + pid);
   if SambaEnabled=0 then SMBD_STOP();
   exit;
end;


  if SambaEnabled=0  then begin
      logs.Debuglogs('Starting......: SMBD is disabled..');
      exit;
   end;


   logs.DebugLogs('Starting......: Smbd set password to secrets.tdb');
   LINKING_LIBRARY();
   logs.OutputCmd(smbpasswd_path()+' -w ' + openldap.ldap_settings.password);
   logs.OutputCmd('/usr/bin/pdbedit -i smbpasswd -e tdbsam');

   if not FileExists('/etc/artica-postfix/samba.check.time') then Reconfigure(false);

   if SambaEnableEditPosixExtension=1 then begin
          logs.DebugLogs('Starting......: Smbd Editposix/Trusted Ldapsam extension enabled');
          logs.OutputCmd('/usr/bin/net sam provision');
   end;


   forceDirectories('/home/export/profile');
   logs.OutputCmd('/bin/chmod o+rw /home/export');
   logs.OutputCmd('/bin/chmod o+rw /home/export/profile');
   if DirectoryExists('/var/cache/samba') then logs.OutputCmd('/bin/chown -R root:root /var/cache/samba');
   sys.DirDir('/home/export/profile');
   for i:=0 to sys.DirListFiles.Count-1 do begin
       fpchmod('/home/export/profile/'+sys.DirListFiles.Strings[i],&757);
   end;

   SYS.THREAD_COMMAND_SET(SYS.LOCATE_PHP5_BIN()+' /usr/share/artica-postfix/exec.samba.php --homes');



   fpsystem(SMBD_PATH() + ' --daemon');
   pid:=SMBD_PID();
   count:=0;

 while not SYS.PROCESS_EXIST(SMBD_PID()) do begin
        sleep(100);
        inc(count);
        if count>20 then begin
           logs.DebugLogs('Starting......: Smbd (time-out)');
           break;
        end;
  end;



     if not SYS.PROCESS_EXIST(SMBD_PID()) then begin
        logs.Debuglogs('SAMBA_START:: Failed to start samba with error ' + err);
        exit;
     end;
     
  logs.Debuglogs('Starting......: SMBD success running with PID ' + pid);
end;
//##############################################################################
procedure Tsamba.SAMBA_WINBINDD_START();
var
   pid:string;
   err:string;
   count:integer;
begin

   if not FileExists(WINBIND_BIN_PATH()) then begin
      logs.Debuglogs('Starting......: WINBIND not installed..');
      exit;
   end;



pid:=WINBIND_PID();

if SYS.PROCESS_EXIST(pid) then begin
   logs.Debuglogs('Starting......: WINBIND Already running PID ' + pid);
   if SambaEnabled=0 then WINBIND_STOP();
   exit;
end;


   if SambaEnabled=0  then begin
      logs.Debuglogs('Starting......: WINBIND is disabled..');
      exit;
   end;


if DirectoryExists('/var/cache/samba') then logs.OutputCmd('/bin/chown -R root:root /var/cache/samba');
logs.OutputCmd(WINBIND_BIN_PATH()+' -D');

   pid:=WINBIND_PID();
   count:=0;

 while not SYS.PROCESS_EXIST(pid) do begin
        sleep(100);
        inc(count);
        if count>20 then begin
           logs.DebugLogs('Starting......: WINBIND (time-out)');
           break;
        end;
        pid:=WINBIND_PID();
  end;



     pid:=WINBIND_PID();
     if not SYS.PROCESS_EXIST(pid) then begin
        logs.Debuglogs('Starting......: Failed to start WINBIND');
        exit;
     end;

  logs.Debuglogs('Starting......: WINBIND success running with PID ' + pid);

end;
//##############################################################################
procedure Tsamba.SAMBA_NMBD_START();
var
   pid:string;
   err:string;
   count:integer;
begin

   if not FileExists(NMBD_BIN_PATH()) then begin
      logs.Debuglogs('Starting......: NMBD not installed..');
      exit;
   end;



pid:=NMBD_PID();

if SYS.PROCESS_EXIST(pid) then begin
   logs.Debuglogs('Starting......: NMBD Already running PID ' + pid);
   if SambaEnabled=0 then NMBD_STOP();
   exit;
end;

   if SambaEnabled=0  then begin
      logs.Debuglogs('Starting......: NMBD is disabled..');
      exit;
   end;

logs.OutputCmd(NMBD_BIN_PATH()+' -D');

   pid:=NMBD_PID();
   count:=0;

 while not SYS.PROCESS_EXIST(pid) do begin
        sleep(100);
        inc(count);
        if count>20 then begin
           logs.DebugLogs('Starting......: NMBD (time-out)');
           break;
        end;
        pid:=NMBD_PID();
  end;


      pid:=NMBD_PID();
     if not SYS.PROCESS_EXIST(pid) then begin
        logs.Debuglogs('Starting......: Failed to start NMBD');
        exit;
     end;

  logs.Debuglogs('Starting......: NMBD success running with PID ' + pid);

end;
//##############################################################################
procedure Tsamba.Reconfigure(restart:boolean);
begin

if SYS.COMMANDLINE_PARAMETERS('--force') then logs.DeleteFile('/etc/artica-postfix/samba.check.time');

if FileExists('/etc/artica-postfix/samba.check.time') then begin
   if SYS.FILE_TIME_BETWEEN_MIN('/etc/artica-postfix/samba.check.time')<10 then begin
      logs.Debuglogs('Cannot set configuration for SAMBA and PAM_LDAP under 10 minutes interval');
      exit;
   end;
end;

   if SambaEnabled=0  then begin
      logs.Debuglogs('Starting......: Samba is disabled, skipping reconfigure');
      exit;
   end;


   logs.Debuglogs('Reconfigure:: Integrate system to ldap');

   logs.OutputCmd(smbpasswd_path()+' -w ' + openldap.ldap_settings.password);
   SYS.THREAD_COMMAND_SET(artica_path+'/bin/artica-ldap --homes &');

   PAM_LDAP_SECRET();
   libnss_conf();
   pam_ldap_conf();
   nsswitch_conf();
   smbldap_conf();
   default_config();
   AUTH_CLIENT_CONFIG();
   FixDirectoriesChmod();
   SAMBA_VFS_PLUGINS();
   SAMBA_AUDIT();
   SYS.THREAD_COMMAND_SET(SYS.LOCATE_PHP5_BIN()+' /usr/share/artica-postfix/exec.samba.php --homes');
   if restart then begin
      SAMBA_STOP();
      SAMBA_START();
   end;
   logs.DeleteFile('/etc/artica-postfix/samba.check.time');
   logs.WriteToFile('#','/etc/artica-postfix/samba.check.time');
end;
//##############################################################################



procedure Tsamba.PAM_LDAP_SECRET();
var
   l:TstringList;
begin

l:=TstringList.Create;
l.Add(openldap.ldap_settings.password);
logs.Debuglogs('PAM_LDAP_SECRET:: Save /etc/pam_ldap.secret');
l.SaveToFile('/etc/pam_ldap.secret');
logs.OutputCmd('/bin/chmod 600 /etc/pam_ldap.secret');
if not FileExists('/etc/nss_ldap.secret') then fpsystem('/bin/ln -s /etc/ldap.secret /etc/nss_ldap.secret');

l.free;
end;
//##############################################################################
procedure Tsamba.SAMBA_STOP();
begin
WINBIND_STOP();
NMBD_STOP();
SMBD_STOP();
SCANNED_ONLY_STOP();
end;
//##############################################################################
procedure Tsamba.WINBIND_STOP();
var
   pid:string;
   count:Integer;
begin

if not FileExists(WINBIND_BIN_PATH()) then exit;


pid:=WINBIND_PID();



if not SYS.PROCESS_EXIST(pid) then begin
   writeln('Stopping WINBIND.............: Already stopped');
   exit;
end;

     writeln('Stopping WINBIND.............: ' + pid + ' PID');
     fpsystem('/bin/kill ' + pid);
     pid:=WINBIND_PID();
     count:=0;

 while SYS.PROCESS_EXIST(pid) do begin
        sleep(500);
        inc(count);
        if SYS.PROCESS_EXIST(pid) then fpsystem('/bin/kill ' + pid);
        if count>50 then begin
               writeln('Stopping WINBIND.............: ' + pid + ' PID time-out');
               fpsystem('/bin/kill -9 ' + pid);
              break;
        end;
        pid:=WINBIND_PID();
  end;


pid:=WINBIND_PID();
if not SYS.PROCESS_EXIST(pid) then begin
    writeln('Stopping WINBIND.............: stopped');
end;
end;
//##############################################################################
procedure Tsamba.NMBD_STOP();
var
   pid:string;
   count:Integer;
begin

if not FileExists(NMBD_BIN_PATH()) then exit;


pid:=NMBD_PID();



if not SYS.PROCESS_EXIST(pid) then begin
   writeln('Stopping NMBD................: Already stopped');
   exit;
end;

     writeln('Stopping NMBD................: ' + pid + ' PID');

     fpsystem('/bin/kill ' + pid);
     pid:=NMBD_PID();
     count:=0;

 while SYS.PROCESS_EXIST(pid) do begin
        sleep(500);
        inc(count);
        if SYS.PROCESS_EXIST(pid) then fpsystem('/bin/kill ' + pid);
        if count>50 then begin
               writeln('Stopping NMBD................: ' + pid + ' PID time-out');
               fpsystem('/bin/kill -9 ' + pid);
              break;
        end;
        pid:=NMBD_PID();
  end;


pid:=NMBD_PID();
if not SYS.PROCESS_EXIST(pid) then begin
    writeln('Stopping NMBD................: stopped');
end;
end;
//##############################################################################
procedure Tsamba.SMBD_STOP();
var
   pid:string;
   count:Integer;
begin
if not FileExists(SMBD_PATH()) then exit;


pid:=SMBD_PID();



if not SYS.PROCESS_EXIST(pid) then begin
   writeln('Stopping SMBD................: Already stopped');
   exit;
end;

     writeln('Stopping SMBD................: ' + pid + ' PID');

     fpsystem('/bin/kill ' + pid);
     pid:=SMBD_PID();
     count:=0;

 while SYS.PROCESS_EXIST(pid) do begin
        sleep(500);
        inc(count);
        fpsystem('/bin/kill ' + pid);
        if count>50 then begin
               writeln('Stopping SMBD................: ' + pid + ' PID time-out');
               fpsystem('/bin/kill -9 ' + pid);
              break;
        end;
        pid:=SMBD_PID();
  end;


pid:=SMBD_PID();
if not SYS.PROCESS_EXIST(pid) then begin
    writeln('Stopping SMBD................: stopped');
end;
end;
//##############################################################################
function Tsamba.SAMBA_VERSION():string;
var
   RegExpr:TRegExpr;
   x:string;
begin

if length(mem_version)>0 then exit(mem_version);

result:=SYS.GET_CACHE_VERSION('APP_SAMBA');
if length(result)>0 then begin
   mem_version:=result;
   exit;
end;
forcedirectories('/opt/artica/logs');
fpsystem(SMBD_PATH() + ' -V >/opt/artica/logs/samba.version');
x:=ReadFileIntoString('/opt/artica/logs/samba.version');
RegExpr:=TRegExpr.Create;
RegExpr.Expression:='Version\s+([0-9a-z\.]+)';
if RegExpr.Exec(x) then result:=trim(RegExpr.Match[1]);
SYS.SET_CACHE_VERSION('APP_SAMBA',result);
mem_version:=result;
end;
//##############################################################################
function Tsamba.WINBIND_VERSION():string;
var
   RegExpr:TRegExpr;
   x:string;
begin
forcedirectories('/opt/artica/logs');
fpsystem(WINBIND_BIN_PATH() + ' -V >/opt/artica/logs/samba.version');
x:=ReadFileIntoString('/opt/artica/logs/samba.version');
RegExpr:=TRegExpr.Create;
RegExpr.Expression:='Version\s+([0-9a-z\.]+)';
if RegExpr.Exec(x) then result:=trim(RegExpr.Match[1]);
end;
//##############################################################################
FUNCTION Tsamba.SAMBA_AUDIT():string;
var
   l:TstringList;
begin
result:='';
if not FileExists(artica_path+'/smb-audit/config/config.php') then begin
   logs.Debuglogs('SAMBA_AUDIT: Unable to stat '+artica_path+'/smb-audit/config/config.php');
   exit;
end;
   l:=TstringList.Create;
l.Add('<?');
l.Add('//Setup language from lang dir');
l.Add('//available english russian ukrainian');
l.Add('$lang="english";');
l.Add('//$lang="russian";');
l.Add('//$lang="ukrainian";');
l.Add('');
l.Add('//Database connection Setup');
l.Add('$db_type = "mysql";     // mysql or pgsql');
l.Add('$db_host = "'+SYS.MYSQL_INFOS('mysql_server')+':' + SYS.MYSQL_INFOS('port')+'";');
l.Add('$db_user = "'+SYS.MYSQL_INFOS('database_admin')+'";');
l.Add('$db_pass = "'+SYS.MYSQL_INFOS('database_password')+'";');
l.Add('$db_name = "artica_events";');
l.Add('?>');

l.SaveToFile(artica_path+'/smb-audit/config/config.php')
end;
//##############################################################################

FUNCTION Tsamba.SAMBA_STATUS():string;
var pidpath:string;
begin
pidpath:=logs.FILE_TEMP();
fpsystem(SYS.LOCATE_PHP5_BIN()+' /usr/share/artica-postfix/exec.status.php --samba >'+pidpath +' 2>&1');
result:=logs.ReadFromFile(pidpath);
logs.DeleteFile(pidpath);
end;
//#########################################################################################
procedure Tsamba.WINBIND_START();
var pid:string;
begin
    if not FileExists(WINBIND_BIN_PATH()) then exit;
    if not FileExists(INITD_WINBIND_PATH()) then exit;
    pid:=WINBIND_PID();
    
 if SYS.PROCESS_EXIST(pid) then begin
   logs.Debuglogs('WINBIND_START:: WINBIND running PID ' + pid);
   exit;
end;
  fpsystem(WINBIND_BIN_PATH()+' -D');
    
 pid:=WINBIND_PID();

     if not SYS.PROCESS_EXIST(pid) then begin
        logs.Debuglogs('WINBIND_START:: Failed to start winbind with error ' + ReadFileIntoString('/opt/artica/logs/samba.start'));
        exit;
     end;

  logs.Debuglogs('WINBIND_START:: WINBIND running PID ' + pid);

end;
//##############################################################################
procedure Tsamba.SCANNED_ONLY_START();
var
   pid:string;
   count:integer;
begin
if not FileExists('/usr/sbin/scannedonlyd_clamav') then begin
   logs.Debuglogs('Starting......: scannedonly not installed');
   exit;
end;
  pid:=SCANNED_ONLY_PID();

 if SYS.PROCESS_EXIST(pid) then begin
   if EnableScannedOnly=0 then begin
         SCANNED_ONLY_STOP();
         exit;
   end;
   logs.Debuglogs('Starting......: scannedonly already using pid '+pid);
   exit;
end;


if EnableScannedOnly=0 then begin
   logs.Debuglogs('Starting......: scannedonly is disabled');
   exit;
end;

forceDirectories('/home/samba-virus');
fpsystem('/usr/sbin/scannedonlyd_clamav --socket /var/run/scannedonly.sock --pidfile /var/run/scannedonly.pid --quarantainedir /home/samba-virus');
pid:=SCANNED_ONLY_PID();

 while not SYS.PROCESS_EXIST(pid) do begin
        sleep(100);
        inc(count);
        if count>20 then begin
           logs.DebugLogs('Starting......: scannedonly (time-out)');
           break;
        end;
 pid:=SCANNED_ONLY_PID();
  end;

     pid:=SCANNED_ONLY_PID();
     if not SYS.PROCESS_EXIST(pid) then begin
        logs.Debuglogs('Starting......: Failed to start scannedonly');
        exit;
     end;

  logs.Debuglogs('Starting......: scannedonly success running with PID ' + pid);
end;
//##############################################################################
procedure Tsamba.SCANNED_ONLY_STOP();
var
   pid:string;
   count:Integer;
begin

if not FileExists('/usr/sbin/scannedonlyd_clamav') then exit;


pid:=SCANNED_ONLY_PID();



if not SYS.PROCESS_EXIST(pid) then begin
   writeln('Stopping scannedonly.........: Already stopped');
   exit;
end;

     writeln('Stopping scannedonly.........: ' + pid + ' PID');
     fpsystem('/bin/kill ' + pid);
     pid:=SCANNED_ONLY_PID();
     count:=0;

 while SYS.PROCESS_EXIST(pid) do begin
        sleep(500);
        inc(count);
        if SYS.PROCESS_EXIST(pid) then fpsystem('/bin/kill ' + pid);
        if count>50 then begin
               writeln('Stopping scannedonly.........: ' + pid + ' PID time-out');
               fpsystem('/bin/kill -9 ' + pid);
              break;
        end;
        pid:=SCANNED_ONLY_PID();
  end;


pid:=SCANNED_ONLY_PID();
if not SYS.PROCESS_EXIST(pid) then begin
    writeln('Stopping scannedonly.........: stopped');
end;
end;
//##############################################################################


procedure Tsamba.libnss_conf();
var
  l:TstringList;
  server,port,admin,password:string; 
begin

if not FileExists(lib_pam_ldap_path()) then begin
   logs.Debuglogs('libnss_conf:: unable to stat pam_ldap.so');
   exit;
end;

if not FileExists(lib_nss_ldap_path()) then begin
   logs.Debuglogs('libnss_conf:: unable to stat libnss-ldap');
   exit;
end;
fpsystem('/bin/ln -s --force /etc/ldap.conf /etc/libnss-ldap.conf');
fpsystem('/bin/ln -s --force /etc/ldap.secret /etc/libnss-ldap.secret');
if FileExists('/usr/share/libnss-ldap/ldap.conf') then fpsystem('/bin/ln -s --force /etc/ldap.conf /usr/share/libnss-ldap/ldap.conf');

end;

//##############################################################################
function Tsamba.lib_pam_ldap_path():string;
begin
if FileExists('/lib/security/pam_ldap.so') then exit('/lib/security/pam_ldap.so');
end;
//##############################################################################
function Tsamba.lib_nss_ldap_path():string;
begin
  if FIleExists('/etc/init.d/libnss-ldap') then exit('/etc/init.d/libnss-ldap');
  if FileExists('/usr/lib/libnss_ldap.so') then exit('/usr/lib/libnss_ldap.so');
end;
//##############################################################################
function Tsamba.auth_client_config_path():string;
begin
  if FIleExists('/usr/sbin/auth-client-config') then exit('/usr/sbin/auth-client-config');
end;
//##############################################################################
procedure Tsamba.AUTH_CLIENT_CONFIG();
var
l:TstringList;

begin
   if not Fileexists(auth_client_config_path()) then begin
     logs.Debuglogs('AUTH_CLIENT_CONFIG:: auth-client-config does not exists... Aborting, i think it is not Ubuntu...not a problem');
     exit;
   end;
   
   if FileExists('/etc/auth-client-config/profile.d/open_ldap') then begin
        if AUTH_CLIENT_CONFIG_VERIF_PROFILE('open_ldap') then exit;
   end;

   
 l:=TstringList.Create;
l.Add('[open_ldap]');
l.Add('nss_passwd=passwd: files ldap');
l.Add('nss_group=group: files ldap');
l.Add('nss_shadow=shadow: files ldap');
l.Add('pam_auth=auth       required     pam_env.so');
l.Add(' auth       sufficient   pam_unix.so likeauth nullok');
l.Add(' auth       sufficient   pam_ldap.so use_first_pass');
l.Add(' auth       required     pam_deny.so');
l.Add('pam_account=account    sufficient   pam_unix.so');
l.Add(' account    sufficient   pam_ldap.so');
l.Add(' account    required     pam_deny.so');
l.Add('pam_password=password   sufficient   pam_unix.so nullok md5 shadow use_authtok');
l.Add(' password   sufficient   pam_ldap.so use_first_pass');
l.Add(' password   required     pam_deny.so');
l.Add('pam_session=session    required     pam_limits.so');
l.Add(' session    required     pam_mkhomedir.so skel=/etc/skel/');
l.Add(' session    required     pam_unix.so');
l.Add(' session    optional     pam_ldap.so');
l.SaveToFile('/etc/auth-client-config/profile.d/open_ldap');
l.free;
logs.OutputCmd(auth_client_config_path()+' -a -p open_ldap');
end;
//##############################################################################
function Tsamba.AUTH_CLIENT_CONFIG_VERIF_PROFILE(profilename:string):boolean;
var
l:TstringList;
i:integer;
line:string;
RegExpr:TRegExpr;
begin
result:=false;
line:=logs.FILE_TEMP();
fpsystem(auth_client_config_path() + ' -l > ' + line + ' 2>&1');
if not Fileexists(line) then begin
   logs.Debuglogs('AUTH_CLIENT_CONFIG_VERIF_PROFILE:: Unable to stat ' + line);
   exit;
end;

 RegExpr:=TRegExpr.Create;
 RegExpr.Expression:=profilename;
 l:=TStringList.Create;
 l.LoadFromFile(line);
 For i:=0 to l.Count-1 do begin
   if RegExpr.Exec(l.Strings[i]) then begin
      logs.Debuglogs('AUTH_CLIENT_CONFIG_VERIF_PROFILE:: ' + profilename + ' exists');
      result:=true;
      break;
   end;
 end;

   l.free;
   RegExpr.free;


END;
//##############################################################################


//##############################################################################
function Tsamba.nss_initgroups_ignoreusers():string;
var
l:TstringList;
RegExpr:TRegExpr;
r:string;
i:integer;
begin

l:=TstringList.create;
RegExpr:=TRegExpr.create;
RegExpr.Expression:='^(.+?):';
try
   l.LoadFromFile('/etc/passwd');
except
   logs.Syslogs('nss_initgroups_ignoreusers:: fatal error !');
   exit;
end;


for i:=0 to l.Count-1 do begin
    if RegExpr.Exec(l.Strings[i]) then begin
          r:=r+ RegExpr.Match[1]+',';
    end;
end;


l.free;
RegExpr.free;
if Copy(r,length(r),1)=',' then r:=Copy(r,0,length(r)-1);
result:=r;
end;
//##############################################################################

procedure Tsamba.pam_ldap_conf();
var
  l:TstringList;
  server,port,admin,password:string;
  initgroups_ignoreusers:string;
begin
if not FileExists(lib_pam_ldap_path()) then begin
   logs.Debuglogs('pam_ldap_conf:: unable to stat pam_ldap.so');
   exit;
end;

if not FileExists(lib_nss_ldap_path()) then begin
   logs.Debuglogs('pam_ldap_conf:: unable to stat libnss-ldap');
   exit;
end;

  l:=TstringList.Create;
  server:=openldap.ldap_settings.servername;
  port:=openldap.ldap_settings.Port;
  admin:='cn='+openldap.ldap_settings.admin+','+openldap.ldap_settings.suffix;
  password:=openldap.ldap_settings.password;
  
  forcedirectories('/etc/pam.d');

  
  
  ETC_LDAP_CONF_SET_VALUE('host',server);
  ETC_LDAP_CONF_SET_VALUE('port',port);
  ETC_LDAP_CONF_SET_VALUE('uri','ldap://'+server+':'+port);
  ETC_LDAP_CONF_SET_VALUE('ldap_version','3');
  ETC_LDAP_CONF_SET_VALUE('binddn',admin);
  ETC_LDAP_CONF_SET_VALUE('rootbinddn',admin);
  ETC_LDAP_CONF_SET_VALUE('bindpw',openldap.ldap_settings.password);
  ETC_LDAP_CONF_SET_VALUE('bind_policy','soft');
  ETC_LDAP_CONF_SET_VALUE('scope','sub');
  ETC_LDAP_CONF_SET_VALUE('base','dc=organizations,'+openldap.ldap_settings.suffix);
  ETC_LDAP_CONF_SET_VALUE('pam_password','clear');
//  ETC_LDAP_CONF_SET_VALUE('nss_reconnect_tries','2');
  //nss_connect_policy oneshot

  initgroups_ignoreusers:=nss_initgroups_ignoreusers();
  if length(initgroups_ignoreusers)>0 then ETC_LDAP_CONF_SET_VALUE('nss_initgroups_ignoreusers',initgroups_ignoreusers);

  SMB_CONF_SET_VALUE('ldap suffix',openldap.ldap_settings.suffix);
  SMB_CONF_SET_VALUE('ldap admin dn',admin);

  
  // /etc/pam_ldap.conf -------------------------------------------------------
  fpsystem('/bin/ln -s --force /etc/ldap.conf /etc/pam_ldap.conf');
  fpsystem('/bin/ln -s --force /etc/ldap.secret /etc/pam_ldap.secret');

  logs.OutputCmd('/bin/ln -s /etc/ldap.conf /etc/nss_ldap.conf');
  logs.OutputCmd('/bin/ln -s /etc/ldap.secret /etc/nss_ldap.secret');
  if FileExists('/etc/ldap/ldap.conf') then fpsystem('/bin/ln -s --force /etc/ldap.conf /etc/ldap/ldap.conf');
  logs.Debuglogs('pam_ldap_conf:: saving /etc/pam_ldap.conf');
  l.Clear;
  //----------------------------------------------------------------------------




  
  l.Add('@include common-auth');
  l.Add('@include common-account');
  l.Add('@include common-session');
  logs.Debuglogs('pam_ldap_conf:: saving /etc/pam.d/samba');
  l.SaveToFile('/etc/pam.d/samba');
  l.Clear;



   l.Add('#');
   l.Add('# /etc/pam.d/common-account - authorization settings common to all services');
   l.Add('#');
   l.Add('# This file is included from other service-specific PAM config files,');
   l.Add('# and should contain a list of the authorization modules that define');
   l.Add('# the central access policy for use on the system.  The default is to');
   l.Add('# only deny service to users whose accounts are expired in /etc/shadow.');
   l.Add('#');
   l.Add('account sufficient pam_ldap.so');
   l.Add('account required   pam_unix.so try_first_pass');
   logs.Debuglogs('pam_ldap_conf:: saving /etc/pam.d/common-account');
   l.SaveToFile('/etc/pam.d/common-account');
   l.Clear;



   l.Add('#');
   l.Add('# /etc/pam.d/common-auth - authentication settings common to all services');
   l.Add('#');
   l.Add('# This file is included from other service-specific PAM config files,');
   l.Add('# and should contain a list of the authentication modules that define');
   l.Add('# the central authentication scheme for use on the system');
   l.Add('# (e.g., /etc/shadow, LDAP, Kerberos, etc.).  The default is to use the');
   l.Add('# traditional Unix authentication mechanisms.');
   l.Add('#');
   l.Add('auth sufficient pam_ldap.so');
   l.Add('auth	requisite	pam_unix.so nullok_secure try_first_pass');
   l.Add('auth	optional	pam_smbpass.so migrate');
   logs.Debuglogs('pam_ldap_conf:: saving /etc/pam.d/common-auth');
   l.SaveToFile('/etc/pam.d/common-auth');
   l.Clear;

   l.Add('#%PAM-1.0');
   l.Add('');
   l.Add('#@include common-auth');
   l.Add('#@include common-account');
   l.Add('auth    sufficient      pam_unix.so ');
   l.Add('auth    required        pam_unix.so');
   l.Add('session required pam_permit.so');
   l.Add('session required pam_limits.so');
   l.SaveToFile('/etc/pam.d/sudo');
   l.Clear;


   l.Add('#');
   l.Add('# /etc/pam.d/common-password - password-related modules common to all services');
   l.Add('#');
   l.Add('# This file is included from other service-specific PAM config files,');
   l.Add('# and should contain a list of modules that define the services to be');
   l.Add('# used to change user passwords.  The default is pam_unix.');
   l.Add('');
   l.Add('# Explanation of pam_unix options:');
   l.Add('#');
   l.Add('# The "nullok" option allows users to change an empty password, else');
   l.Add('# empty passwords are treated as locked accounts.');
   l.Add('#');
   l.Add('# The "md5" option enables MD5 passwords.  Without this option, the');
   l.Add('# default is Unix crypt.');
   l.Add('#');
   l.Add('# The "obscure" option replaces the old `OBSCURE_CHECKS_ENAB'' option in');
   l.Add('# login.defs.');
   l.Add('#');
   l.Add('# You can also use the "min" option to enforce the length of the new');
   l.Add('# password.');
   l.Add('#');
   l.Add('# See the pam_unix manpage for other options.');
   l.Add('');
   l.Add('password   sufficient  pam_ldap.so');
   l.Add('password   requisite   pam_unix.so nullok obscure md5 try_first_pass');
   l.Add('');
   l.Add('# Alternate strength checking for password. Note that this');
   l.Add('# requires the libpam-cracklib package to be installed.');
   l.Add('# You will need to comment out the password line above and');
   l.Add('# uncomment the next two in order to use this.');
   l.Add('# (Replaces the `OBSCURE_CHECKS_ENAB'', `CRACKLIB_DICTPATH'')');
   l.Add('#');
   l.Add('# password required	  pam_cracklib.so retry=3 minlen=6 difok=3');
   l.Add('# password required	  pam_unix.so use_authtok nullok md5 try_first_pass');
   l.Add('');
   l.Add('# minimally-intrusive inclusion of smbpass in the stack for');
   l.Add('# synchronization.  If the module is absent or the passwords don''t');
   l.Add('# match, this module will be ignored without prompting; and if the ');
   l.Add('# passwords do match, the NTLM hash for the user will be updated');
   l.Add('# automatically.');
   l.Add('password   optional   pam_smbpass.so nullok use_authtok use_first_pass');
   l.SaveToFile('/etc/pam.d/common-password');
   l.Clear;

  l.free;
end;
//##############################################################################
procedure Tsamba.default_config();
var
  m:TiniFile;
  configfile:string;
  tmpstr:string;
  server,port,admin:string;
begin
if FileExists('/etc/samba/smb.conf') then configfile:='/etc/samba/smb.conf';
  StripDiezes(configfile);
  admin:='cn='+openldap.ldap_settings.admin+','+openldap.ldap_settings.suffix;
  server:=openldap.ldap_settings.servername;
  port:=openldap.ldap_settings.Port;
  if server='*' then server:='127.0.0.1';
  if length(port)=0 then port:='389';

m:=TiniFile.Create('/etc/samba/smb.conf');
tmpstr:=m.ReadString('global','ldap suffix','');
if length(tmpstr)>0 then exit;
  m.WriteString('global','ldap passwd sync','Yes');
  m.WriteString('global','passdb backend','ldapsam:ldap://' + server + ':' + port+'/');
  m.WriteString('global','ldap admin dn',admin);
  m.WriteString('global','ldap suffix',openldap.ldap_settings.suffix);
  m.WriteString('global','socket options','TCP_NODELAY SO_RCVBUF=8192 SO_SNDBUF=8192');
  m.UpdateFile;
  m.FRee;
end;
//##############################################################################
procedure Tsamba.StripDiezes(filepath:string);
var
list,list2:TstringList;
i,n:integer;
line:string;
RegExpr:TRegExpr;
begin
 RegExpr:=TRegExpr.create;
 RegExpr.expression:='#';
    if not FileExists(filepath) then exit;
    list:=TstringList.Create();
    list2:=TstringList.Create();
    list.LoadFromFile(filepath);
    n:=-1;
    For i:=0 to  list.Count-1 do begin
        n:=n+1;
         line:=list.Strings[i];
         if length(line)>0 then begin

            if not RegExpr.Exec(list.Strings[i])  then begin
               list2.Add(list.Strings[i]);
            end;
         end;
    end;


     list2.SaveToFile(filepath);

    RegExpr.Free;
    list2.Free;
    list.Free;
end;
 //##############################################################################



procedure Tsamba.smbldap_conf();
var
  l:TstringList;
  server,port:string;
begin
 forcedirectories('/etc/smbldap-tools');
 
l:=TstringList.Create;


l.Add('slaveDN="cn='+openldap.ldap_settings.admin+','+openldap.ldap_settings.suffix+'"');
l.Add('slavePw='+openldap.ldap_settings.password);
l.Add('masterDN="cn='+openldap.ldap_settings.admin+','+openldap.ldap_settings.suffix+'"');
l.Add('masterPw='+openldap.ldap_settings.password);
l.SaveToFile('/etc/smbldap-tools/smbldap_bind.conf');
l.Clear;

  server:=openldap.ldap_settings.servername;
  port:=openldap.ldap_settings.port;

  
  
l.Add('slaveLDAP="'+server+'"');
l.Add('slavePort="'+port+'"');
l.Add('masterLDAP="'+server+'"');
l.Add('masterPort="'+port+'"');
l.Add('ldapTLS="0"');
l.Add('verify="require"');
l.Add('suffix="'+openldap.ldap_settings.suffix+'"');
l.Add('usersdn="ou=users,dc=samba,${suffix}"');
l.Add('computersdn="ou=computers,dc=samba,${suffix}"');
l.Add('groupsdn="ou=groups,dc=samba,${suffix}"');
l.Add('idmapdn="ou=Idimap,dc=samba,${suffix}"');
l.Add('sambaUnixIdPooldn="cn=NextFreeUnixId,${suffix}"');
l.Add('scope="sub"');
l.Add('hash_encrypt="CLEARTEXT"');
l.Add('crypt_salt_format="%s"');
l.Add('');
l.Add('userLoginShell="/bin/bash"');
l.Add('userHome="/home/%U"');
l.Add('userHomeDirectoryMode="700"');
l.Add('userGecos="User"');
l.Add('defaultUserGid="513"');
l.Add('defaultComputerGid="515"');
l.Add('skeletonDir="/etc/skel"');
l.Add('defaultMaxPasswordAge="3650"');
l.Add('');
l.Add('with_smbpasswd="0"');
l.Add('smbpasswd="'+smbpasswd_path()+'"');
l.Add('');
l.Add('with_slappasswd="0"');
l.Add('slappasswd="' + slappasswd_path() + '"');

l.SaveToFile('/etc/smbldap-tools/smbldap.conf');
l.free;

end;
//#############################################################################
function Tsamba.ReadFileIntoString(path:string):string;
var
   List:TstringList;
begin

      if not FileExists(path) then begin
        exit;
      end;

      List:=Tstringlist.Create;
      List.LoadFromFile(path);
      result:=List.Text;
      List.Free;
end;
//##############################################################################
procedure Tsamba.ETC_LDAP_CONF_SET_VALUE(key:string;value:string);
var
   RegExpr:TRegExpr;
   list:TstringList;
   i:Integer;
   found:boolean;
begin
    found:=false;
    list:=TstringList.Create();
    RegExpr:=TRegExpr.Create;
    if FileExists('/etc/ldap.conf') then list.LoadFromFile('/etc/ldap.conf');
    RegExpr.Expression:='^'+key+'\s+(.+)';
    for i:=0 to list.Count-1 do begin
          if RegExpr.Exec(list.Strings[i]) then begin
              logs.Debuglogs('ETC_LDAP_CONF_SET_VALUE:: (modify) key ' + key+'="'+value+'"');
              list.Strings[i]:=key + ' ' + value;
              found:=true;
              break;
          end;
    
    end;
    if not found then begin
     list.Add(key + ' ' + value);
     logs.Debuglogs('ETC_LDAP_CONF_SET_VALUE:: (Add new) key' + key+'="'+value+'"');
    end;
    list.SaveToFile('/etc/ldap.conf');

    list.Free;
    RegExpr.free;
end;
//##############################################################################
procedure Tsamba.SMB_CONF_SET_VALUE(key:string;value:string);
var

   list:TIniFile;
   path:string;
begin
     path:=smbconf_path();
     list:=TiniFile.Create(path);
     list.WriteString('global',key,value);
     logs.Debuglogs('SMB_CONF_SET_VALUE:: [global]' + key+'="'+value+'" (' + path+')');
     list.UpdateFile;
     list.Free;
end;
//##############################################################################
function Tsamba.SMB_CONF_GET_VALUE(masterkey:string;key:string):string;
var
   value:string;
   list:TIniFile;
   path:string;
begin
     path:=smbconf_path();
     list:=TiniFile.Create(path);
     value:=list.ReadString(masterkey,key,'');
     logs.Debuglogs('SMB_CONF_GET_VALUE:: ['+masterkey+']' + key+'="'+value+'" (' + path+')');
     result:=value;
     list.Free;
end;
//##############################################################################
procedure Tsamba.BUILD_PROFILE(username:string);
var
 path:string;
begin
     path:=trim(SMB_CONF_GET_VALUE('profile','path'));
     if length(path)=0 then begin
        logs.Debuglogs('BUILD_PROFILE:: ' + username+ ' [profile] & "path" is not set');
        exit;
     end;

     forceDirectories(path+'/'+username);
     logs.OutputCmd('/bin/chown '+username+' '+path+'/'+username);
     logs.OutputCmd('/bin/chmod -R 755 '+path);
     logs.OutputCmd('/bin/chmod 755 '+path);


end;
//##############################################################################


procedure Tsamba.FixDirectoriesChmod();
var

   list:TIniFile;
   sections:TstringList;
   path:string;
   i:Integer;
begin
    forceDirectories('/home/.infected');
    logs.OutputCmd('/bin/chmod 777 /home/.infected');

     path:=smbconf_path();
     sections:=TstringList.Create;
     if not FileExists(path) then exit;
     list:=TiniFile.Create(path);
     list.ReadSections(sections);
     for i:=0 to sections.Count-1 do begin
         path:=list.ReadString(sections.Strings[i],'path','');
         if length(path)>0 then begin
            logs.Debuglogs('FixDirectoriesChmod:: '+path);
            if not DirectoryExists(path) then ForceDirectories(path);
            fpsystem('/bin/chmod 0777 ' + path + ' >/dev/null 2>&1');
         end;
         path:=list.ReadString(sections.Strings[i],'recycle:repository','');
         if length(path)>0 then begin
            logs.Debuglogs('FixDirectoriesChmod:: '+path);
           // if not DirectoryExists(path) then ForceDirectories(path);
            //fpsystem('/bin/chmod 0777 ' + path + ' >/dev/null 2>&1');
         end;
         
         
         
     end;

    sections.free;
    list.Free;
end;
//##############################################################################
function Tsamba.ParseSharedDirectories():TstringList;
var

   list:TIniFile;
   sections:TstringList;
   res:TstringList;
   path:string;
   i:Integer;
begin
     res:=TstringList.Create;
     result:=res;
     path:=smbconf_path();
     sections:=TstringList.Create;
     if not FileExists(path) then exit;
     list:=TiniFile.Create(path);
     list.ReadSections(sections);
     for i:=0 to sections.Count-1 do begin
         path:=list.ReadString(sections.Strings[i],'path','');
         if length(path)>0 then begin
            if DirectoryExists(path) then res.Add(path);
         end;
     end;

    sections.free;
    list.Free;
    result:=res;
end;
//##############################################################################
procedure Tsamba.ParseUsbShares();
var
   l:TstringList;
   RegExpr:TRegExpr;
   i:integer;
   uuid:string;
   target_mount:string;
   dev_source:string;
   name,time_disconnect:string;
   cmd:string;
   ftmp:string;
begin
   if not FileExists('/etc/artica-postfix/samba.usb.conf') then exit;
   if not FileExists(SMBD_PATH()) then exit;
   if not FileExists(SYS.LOCATE_MOUNT()) then exit;
   l:=TstringList.Create;
   l.LoadFromFile('/etc/artica-postfix/samba.usb.conf');
   RegExpr:=TRegExpr.Create;
   RegExpr.Expression:='<uuid>(.+?)</uuid><name>(.+?)</name><umounttime>([0-9\:]+)</umounttime>';
   for i:=0 to l.Count-1 do begin
       if RegExpr.Exec(l.Strings[i]) then begin
           uuid:=RegExpr.Match[1];
           name:=RegExpr.Match[2];
           time_disconnect:=RegExpr.Match[3];
           logs.Debuglogs('Tsamba.ParseUsbShares(): scanning device '+uuid+'...');

           if not SYS.DISK_USB_EXISTS(uuid) then continue;

            target_mount:='/opt/artica/usb_mount/'+ uuid;
            dev_source:=SYS.DISK_USB_DEV_SOURCE(uuid);

           if SYS.DISK_USB_IS_MOUNTED(dev_source,target_mount) then begin
               logs.Debuglogs('Tsamba.ParseUsbShares(): device '+uuid+' is already mounted on '+target_mount + ' test disconnection..');
               ParseUsbSharesDisconnect(dev_source,uuid,target_mount,time_disconnect);
               continue;
           end;
           
           if ParseUsbSharesDisconnect(dev_source,uuid,target_mount,time_disconnect) then begin
              logs.Debuglogs('Tsamba.ParseUsbShares(): device stay unmounted... continue');
              continue;
           end;
           
           fpsystem('/bin/rmdir -f '+target_mount);
           forceDirectories(target_mount);
           
           logs.Debuglogs('Tsamba.ParseUsbShares(): mount device '+uuid+' on '+target_mount);
           ftmp:=LOGS.FILE_TEMP();
           cmd:=SYS.LOCATE_MOUNT() +' -t auto ' + dev_source + ' ' + target_mount + ' >' + ftmp + ' 2>&1';
           logs.Debuglogs(cmd);
           fpsystem(cmd);
           if SYS.DISK_USB_IS_MOUNTED(dev_source,target_mount) then begin
              if fileExists(target_mount+'/disconnect') then logs.DeleteFile(target_mount+'/disconnect');
              logs.NOTIFICATION('[ARTICA]: ('+SYS.HOSTNAME_g()+') Success mount USB device name "'+name+'"','This device is Shared on the computer, you can browse it by the local network:'+logs.ReadFromFile(ftmp),'system');
           end else begin
               logs.Debuglogs('Tsamba.ParseUsbShares(): failed mount device '+uuid+ ' ' + logs.ReadFromFile(ftmp));
               logs.NOTIFICATION('[ARTICA]: ('+SYS.HOSTNAME_g()+') Failed mount USB device name "'+name+'"','This device is plugged, but failed to mount it...'+logs.ReadFromFile(ftmp),'system');
           
           end;
       
       end;
   
   end;
   


end;
//##############################################################################

function Tsamba.ParseUsbSharesDisconnect(dev_source:string;uuid:string;target_mount:string;time_disconnect:string):boolean;
var
lockfile:string;
tmpdate:string;
T1,T2:TDateTime;
minutes:integer;
minutes_now:integer;
RegExpr:TRegExpr;
begin
result:=false;
lockfile:='/etc/artica-postfix/SharedFolers/smb_sub_tmp/'+uuid;
minutes_now:=0;
minutes:=0;


if FileExists(lockfile) then begin
   logs.Debuglogs('Tsamba.ParseUsbSharesDisconnect(): '+lockfile+'='+intTosTR(SYS.FILE_TIME_BETWEEN_MIN(lockfile)));
   if SYS.FILE_TIME_BETWEEN_MIN(lockfile)>10 then begin
        logs.Debuglogs('Tsamba.ParseUsbSharesDisconnect(): '+dev_source + ' stay disconnected for 10mn');
        exit(true);
   end;
end;


  if fileExists(target_mount+'/disconnect') then begin
     if not UsbDisconnect(dev_source,uuid,target_mount) then begin
           logs.NOTIFICATION('[ARTICA]: ('+SYS.HOSTNAME_g()+') unable to disconnect USB device shared "'+target_mount+'"','','system');
           exit;
        end;
     UsCreateLockFile(uuid);
     exit;
  end;
  
  if length(time_disconnect)=0 then begin
     logs.Debuglogs('Tsamba.ParseUsbSharesDisconnect(): No disconnect time..');
     exit(false);
  end;
  
  
  if time_disconnect='0' then begin
     logs.Debuglogs('Tsamba.ParseUsbSharesDisconnect(): Disconnect time disabled..');
     exit(false);
  end;


T1 := Now;

RegExpr:=TRegExpr.Create;
RegExpr.Expression:='([0-9]+):([0-9]+)';
RegExpr.Exec(time_disconnect);

if not TryStrToInt(RegExpr.Match[2],minutes) then begin
    logs.syslogs('FATAL Error while calculate the end time of '+RegExpr.Match[2]);
    exit(false);
end;


if not TryStrToInt(FormatDateTime('nn', T1),minutes_now) then begin
    logs.syslogs('FATAL Error while calculate the now time "mn" of '+uuid);
    exit(false);
end;



tmpdate:=FormatDateTime('dd-mm-yyyy',T1) + ' ' + time_disconnect + ':'+FormatDateTime('ss', T1);
logs.Debuglogs('Tsamba.ParseUsbSharesDisconnect(): '+FormatDateTime('dd-mm-yyyy hh:nn:ss', T1) + '<>' + tmpdate);


if not TryStrToDateTime(tmpdate,T2) then begin
       logs.Debuglogs('Tsamba.ParseUsbSharesDisconnect(): unable to format ' + tmpdate);
       exit;
end;

  logs.Debuglogs('Tsamba.ParseUsbSharesDisconnect(): ' + intToStr(HoursBetween(T1,T2)) + 'h and '+ intToStr(MinutesBetween(T1,T2))+'mn between');

  if HoursBetween(T1,T2)=0 then begin
     if minutes_now>minutes then begin
        logs.Debuglogs('Tsamba.ParseUsbSharesDisconnect() it is now time off..');
        if not UsbDisconnect(dev_source,uuid,target_mount) then begin
           logs.NOTIFICATION('[ARTICA]: ('+SYS.HOSTNAME_g()+') unable to disconnect USB device shared "'+target_mount+'"','','system');
           exit;
        end;
        UsCreateLockFile(uuid);
        exit(true);
     end;
  end;



  

  
end;
//##############################################################################
function Tsamba.UsbDisconnect(dev_source:string;uuid:string;target_mount:string):boolean;
var
cmd:string;

begin

result:=false;

  if not SYS.DISK_USB_IS_MOUNTED(dev_source,target_mount) then begin
      logs.Debuglogs('Tsamba.UsbDisconnect() '+ uuid + ' already disconnected from ' + target_mount);
      exit(true);
  end;
  
  logs.Debuglogs('Tsamba.UsbDisconnect() disconnect '+ uuid + ' mounted on ' + target_mount);
  cmd:='/bin/umount ' + target_mount;
  logs.Debuglogs(cmd);
  fpsystem(cmd);
  
  if SYS.DISK_USB_IS_MOUNTED(dev_source,target_mount) then begin
     logs.Debuglogs('Tsamba.UsbDisconnect() '+ uuid + ' always mounted on ' + target_mount+' Force umount');
     fpsystem('/bin/umount -f ' + target_mount);
  end;
  
  
 if SYS.DISK_USB_IS_MOUNTED(dev_source,target_mount) then begin
      logs.Debuglogs('Tsamba.UsbDisconnect() '+ uuid + ' always mounted on ' + target_mount+' aborting');
      exit(false);
 end;

exit(true);
end;
//##############################################################################
function Tsamba.UsCreateLockFile(uuid:string):boolean;
var
   lockfile:string;

begin
result:=true;
  lockfile:='/etc/artica-postfix/SharedFolers/smb_sub_tmp/'+uuid;
  ForceDirectories('/etc/artica-postfix/SharedFolers/smb_sub_tmp');
  if FileExists(lockfile) then logs.DeleteFile(lockfile);
  fpsystem('/bin/touch ' + lockfile);
end;
//##############################################################################


end.
