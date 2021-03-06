unit pureftpd;

{$MODE DELPHI}
{$LONGSTRINGS ON}

interface

uses
    Classes, SysUtils,variants,strutils,IniFiles, Process,logs,unix,RegExpr in 'RegExpr.pas',zsystem,openldap;

type LDAP=record
      admin:string;
      password:string;
      suffix:string;
      servername:string;
      Port:string;
  end;

  type
  tpureftpd=class


private
     LOGS:Tlogs;
     GLOBAL_INI:TiniFIle;
     SYS:TSystem;
     artica_path:string;
     ldapClass:Topenldap;
     function COMMANDLINE_PARAMETERS(FoundWhatPattern:string):boolean;
     function get_INFOS(key:string):string;
     function get_LDAP(key:string):string;
     function ReadFileIntoString(path:string):string;
     function GET_COMPILED_SWITCH(key:string):boolean;
     procedure DISABLE_INETD();
     procedure DEBIAN_LINK();
     function PURE_FTPD_WRAPPER_PATH():string;
     function PURE_FTPD_PID_PATH() :string;



public
    PureFtpdEnabled:integer;
    procedure   Free;
    constructor Create;
    function    PURE_FTPD_VERSION():string;
    function    DAEMON_BIN_PATH():string;
    function    PURE_FTPD_INITD():string;
    function    PURE_FTPD_PID() :string;
    function    PURE_FTPD_STATUS:string;
    procedure   PURE_FTPD_LDAP();
    procedure   ETC_DEFAULT();
    procedure   LDAP_CONF();
    procedure   PURE_FTPD_START();
    procedure   PURE_FTPD_STOP();
    function    pure_pw_path():string;
    function    pure_db_path():string;
    procedure   CreateDebianConfig();
    function    GET_DEFAULT_VALUES(key:string):string;
    procedure   FIX_CONFIG_ERRORS();
    procedure   REMOVE();



END;

implementation

constructor tpureftpd.Create;
begin
       forcedirectories('/etc/artica-postfix');
       LOGS:=tlogs.Create();
       SYS:=Tsystem.Create;
       PureFtpdEnabled:=0;
       ldapClass:=Topenldap.Create;
       if not TryStrToInt(SYS.GET_INFO('PureFtpdEnabled'),PureFtpdEnabled) then PureFtpdEnabled:=0;
       if not DirectoryExists('/usr/share/artica-postfix') then begin
              artica_path:=ParamStr(0);
              artica_path:=ExtractFilePath(artica_path);
              artica_path:=AnsiReplaceText(artica_path,'/bin/','');

      end else begin
          artica_path:='/usr/share/artica-postfix';
      end;
end;
//##############################################################################
procedure Tpureftpd.free();
begin
    logs.Free;
    ldapClass.free;
end;
//##############################################################################
procedure Tpureftpd.ETC_DEFAULT();
var
l:TstringList;
begin

if not FileExists('/etc/default/pure-ftpd-common') then exit;
l:=TstringList.Create;
l.Add('# Configuration for pure-ftpd');
l.Add('# (this file is sourced by /bin/sh, edit accordingly)');
l.Add('');
l.Add('# STANDALONE_OR_INETD');
l.Add('# valid values are "standalone" and "inetd".');
l.Add('# Any change here overrides the setting in debconf.');
l.Add('STANDALONE_OR_INETD=standalone');
l.Add('');
l.Add('# VIRTUALCHROOT: ');
l.Add('# whether to use binary with virtualchroot support');
l.Add('# valid values are "true" or "false"');
l.Add('# Any change here overrides the setting in debconf.');
l.Add('VIRTUALCHROOT=false');
l.Add('');
l.Add('# UPLOADSCRIPT: if this is set and the daemon is run in standalone mode,');
l.Add('# pure-uploadscript will also be run to spawn the program given below');
l.Add('# for handling uploads. see /usr/share/doc/pure-ftpd/README.gz or');
l.Add('# pure-uploadscript(8)');
l.Add('');
l.Add('# example: UPLOADSCRIPT=/usr/local/sbin/uploadhandler.pl');
l.Add('UPLOADSCRIPT=');
l.Add('');
l.Add('# if set, pure-uploadscript will spawn $UPLOADSCRIPT running as the');
l.Add('# given uid and gid');
l.Add('UPLOADUID=');
l.Add('UPLOADGID=');
l.SaveToFile('/etc/default/pure-ftpd-common');
l.free;
end;
//##############################################################################
function Tpureftpd.GET_DEFAULT_VALUES(key:string):string;
var
   l:TstringList;
   i:integer;
   RegExpr:TRegExpr;
begin
  if not FileExists('/etc/default/pure-ftpd-common') then exit;
  l:=TstringList.Create;
  l.LoadFromFile('/etc/default/pure-ftpd-common');
  RegExpr:=TRegExpr.Create;
  RegExpr.Expression:='^'+key+'=(.*)';
  for i:=0 to l.Count-1 do begin
       if RegExpr.Exec(l.Strings[i]) then begin
          result:=RegExpr.Match[1];
          break;
       end;
  end;
  
  RegExpr.Free;
  l.free;
end;
//##############################################################################
function Tpureftpd.GET_COMPILED_SWITCH(key:string):boolean;
var
   l:TstringList;
   i:integer;
   RegExpr:TRegExpr;
   ftmp:string;
begin
  ftmp:=logs.FILE_TEMP();
  result:=false;
  
  fpsystem(DAEMON_BIN_PATH() + ' -h >' + ftmp + ' 2>&1');
  if not FileExists(ftmp) then exit;
  l:=TstringList.Create;
  l.LoadFromFile(ftmp);
  RegExpr:=TRegExpr.Create;
  RegExpr.Expression:='--'+key;
  for i:=0 to l.Count-1 do begin
       if RegExpr.Exec(l.Strings[i]) then begin
          result:=true;
          break;
       end;
  end;

  RegExpr.Free;
  l.free;
end;
//##############################################################################


function Tpureftpd.DAEMON_BIN_PATH():string;
begin
    if FileExists('/usr/sbin/pure-ftpd') then exit('/usr/sbin/pure-ftpd');
    if FileExists('/usr/sbin/pure-ftpd-ldap') then exit('/usr/sbin/pure-ftpd-ldap');
    if FileExists('/opt/artica/sbin/pure-ftpd') then exit('/opt/artica/sbin/pure-ftpd');
end;
//##############################################################################
function Tpureftpd.pure_pw_path():string;
begin
    if FileExists('/usr/bin/pure-pw') then exit('/usr/bin/pure-pw');
    if FileExists('/opt/artica/bin/pure-pw') then exit('/opt/artica/bin/pure-pw');
end;
//##############################################################################
function Tpureftpd.pure_db_path():string;
begin
    if FileExists('/etc/pure-ftpd/conf/PureDB') then exit(trim(ReadFileIntoString('/etc/pure-ftpd/conf/PureDB')));
    exit('/opt/artica/var/pureftpd/pureftpd.pdb');
end;
//##############################################################################
procedure Tpureftpd.REMOVE();
begin
   PURE_FTPD_STOP();
   if FileExists(PURE_FTPD_INITD()) then logs.DeleteFile(PURE_FTPD_INITD());
   if FileExists(DAEMON_BIN_PATH()) then logs.DeleteFile(DAEMON_BIN_PATH());
   if FileExists(PURE_FTPD_WRAPPER_PATH()) then logs.DeleteFile(PURE_FTPD_WRAPPER_PATH());
   writeln('Success removing pure-ftpd');
end;
//##############################################################################
function Tpureftpd.PURE_FTPD_STATUS:string;
var
pidpath:string;
begin
SYS.MONIT_DELETE('APP_PUREFTPD');
pidpath:=logs.FILE_TEMP();
fpsystem(SYS.LOCATE_PHP5_BIN()+' /usr/share/artica-postfix/exec.status.php --pure-ftpd >'+pidpath +' 2>&1');
result:=logs.ReadFromFile(pidpath);
logs.DeleteFile(pidpath);
end;
//##############################################################################
procedure Tpureftpd.PURE_FTPD_LDAP();
var
   l:TstringList;
   openldap:topenldap;
begin
openldap:=Topenldap.Create;
l:=TstringList.Create;
l.Add('LDAPServer localhost');
l.Add('LDAPPort '+openldap.ldap_settings.Port);
l.Add('LDAPBaseDN dc=organizations,'+openldap.ldap_settings.suffix);
l.Add('LDAPBindDN cn='+openldap.ldap_settings.admin+','+openldap.ldap_settings.suffix);
l.Add('LDAPBindPW '+openldap.ldap_settings.password);
l.Add('LDAPDefaultUID 405');
l.Add('LDAPDefaultGID 100');
l.Add('LDAPVersion 3');
logs.WriteToFile(l.Text,'/etc/pure-ftpd/pureftp-ldap.conf');
//if FileExists('/etc/pure-ftpd/db/ldap.conf') then logs.WriteToFile(l.Text,'/etc/pure-ftpd/db/ldap.conf');
end;
//##############################################################################
function Tpureftpd.PURE_FTPD_VERSION():string;
var
   l:TstringList;
   i:integer;
   RegExpr:TRegExpr;
begin
    if Not Fileexists(DAEMON_BIN_PATH()) then exit;
result:=SYS.GET_CACHE_VERSION('APP_PUREFTPD');
   if length(result)>2 then exit;

    fpsystem(DAEMON_BIN_PATH()+' -h >/opt/artica/logs/pure.ftpd.h.txt');
    l:=TstringList.Create;
    l.LoadFromFile('/opt/artica/logs/pure.ftpd.h.txt');


    RegExpr:=TRegExpr.Create;
    RegExpr.Expression:='pure-ftpd v([0-9\.]+)';
    for i:=0 to l.Count-1 do begin
         if RegExpr.Exec(l.Strings[i]) then begin
            result:=RegExpr.Match[1];
            break;
         end;
    end;
 SYS.SET_CACHE_VERSION('APP_PUREFTPD',result);
l.free;
RegExpr.free;
end;
//##############################################################################
function Tpureftpd.PURE_FTPD_PID_PATH() :string;
begin
if FileExists('/var/run/pure-ftpd/pure-ftpd.pid') then exit('/var/run/pure-ftpd/pure-ftpd.pid');
if FileExists('/var/run/pure-ftpd.pid') then exit('/var/run/pure-ftpd.pid');
end;
//##############################################################################
function Tpureftpd.PURE_FTPD_PID() :string;
begin
if FileExists('/var/run/pure-ftpd/pure-ftpd.pid') then exit(SYS.GET_PID_FROM_PATH('/var/run/pure-ftpd/pure-ftpd.pid'));
if FileExists('/var/run/pure-ftpd.pid') then exit(SYS.GET_PID_FROM_PATH('/var/run/pure-ftpd.pid'));
exit(SYS.PIDOF(DAEMON_BIN_PATH()));
end;
//##############################################################################
function Tpureftpd.PURE_FTPD_INITD():string;
begin
    if FileExists('/etc/init.d/pure-ftpd') then exit('/etc/init.d/pure-ftpd');
    if FileExists('/etc/init.d/pure-ftpd-ldap') then exit('/etc/init.d/pure-ftpd-ldap');
end;
//##############################################################################
function Tpureftpd.PURE_FTPD_WRAPPER_PATH():string;
begin
if FileExists('/usr/sbin/pure-ftpd-wrapper') then exit('/usr/share/artica-postfix/bin/pure-ftpd-wrapper');
if FileExists('/usr/share/artica-postfix/bin/pure-ftpd-wrapper') then exit('/usr/share/artica-postfix/bin/pure-ftpd-wrapper');
end;
//##############################################################################
procedure tpureftpd.CreateDebianConfig();
var
   l:TstringList;
   RegExpr:TRegExpr;
   CF:TstringList;
   i:Integer;
begin
   if Not DirectoryExists('/etc/pure-ftpd/conf') then ForceDirectories('/etc/pure-ftpd/conf');
   if Not DirectoryExists('/etc/pure-ftpd/auth') then ForceDirectories('/etc/pure-ftpd/auth');

    l:=Tstringlist.Create;
    l.Add('no');
    l.SaveToFile('/etc/pure-ftpd/conf/PAMAuthentication');
    l.Clear;
    
    if not FileExists('/etc/artica-postfix/settings/Daemons/PureFtpdConf') then begin
       logs.Syslogs('Starting......: unable to stat PureFtpdConf');
       exit;
    end;


    CF:=TstringList.Create;
    CF.LoadFromFile('/etc/artica-postfix/settings/Daemons/PureFtpdConf');
    RegExpr:=TRegExpr.Create;
    RegExpr.Expression:='^([A-Za-z0-9]+)\s+(.+)';
    for i:=0 to CF.Count-1 do begin
        if RegExpr.Exec(CF.Strings[i]) then begin
           if trim(RegExpr.Match[1])<>'PureDB' then begin
              if trim(RegExpr.Match[1])<>'Umask' then begin
                 if trim(RegExpr.Match[1])<>'PIDFile' then begin
                   if trim(RegExpr.Match[1])<>'FileSystemCharset' then begin
                      l.Add(trim(RegExpr.Match[2]));
                      l.SaveToFile('/etc/pure-ftpd/conf/' + trim(RegExpr.Match[1]));
                      l.Clear;
                   end;
                 end;
              end;
           end;
        end;
    end;
    
    
    logs.DeleteFile('/etc/pure-ftpd/conf/ClientCharset');
    l:=Tstringlist.Create;
    l.Add('yes');
    l.SaveToFile('/etc/pure-ftpd/conf/CreateHomeDir');
    l.Clear;
CF.free;
RegExpr.Free;
l.free;
exit;
end;
//##############################################################################
procedure tpureftpd.LDAP_CONF();
var
   l:TstringList;
   artica_admin,artica_password,ldap_server,ldap_server_port,artica_suffix:string;
begin

    artica_admin:=ldapClass.ldap_settings.admin;
    artica_password:=ldapClass.ldap_settings.password;
    artica_suffix:=ldapClass.ldap_settings.suffix;
    ldap_server:=ldapClass.ldap_settings.servername;
    ldap_server_port:=ldapClass.ldap_settings.Port;

    if length(ldap_server)=0 then ldap_server:='127.0.0.1';
    if ldap_server='*' then ldap_server:='127.0.0.1';
    if length(ldap_server_port)=0 then ldap_server_port:='389';

    logs.DebugLogs('Starting......: pure-ftpd writing '+artica_admin+'@ldap:'+artica_suffix+'@'+ldap_server+':'+ldap_server_port);


l:=Tstringlist.Create;
l.Add('#############################################');
l.Add('#                                           #');
l.Add('# Sample Pure-FTPd LDAP configuration file. #');
l.Add('# See README.LDAP for explanations.         #');
l.Add('#                                           #');
l.Add('#############################################');
l.Add('');
l.Add('');
l.Add('LDAPServer ' + ldap_server);
l.Add('LDAPPort   ' + ldap_server_port);
l.Add('LDAPBaseDN dc=organizations,'+artica_suffix);
l.Add('LDAPBindDN cn='+artica_admin+',' + artica_suffix);
l.Add('LDAPBindPW ' + artica_password);
l.Add('LDAPAuthMethod BIND');
l.Add('# LDAPDefaultUID 500');
l.Add('# LDAPDefaultGID 100');
l.Add('LDAPFilter (&(objectClass=PureFTPdUser)(uid=\L))');
l.Add('LDAPHomeDir homeDirectory');
l.Add('LDAPVersion 3');

logs.DebugLogs('Starting......: pure-ftpd writing /etc/pure-ftpd/db/ldap.conf');
logs.WriteToFile(l.Text,'/etc/pure-ftpd/db/ldap.conf');
l.Clear;
l.Add('/etc/pure-ftpd/db/ldap.conf');
logs.DebugLogs('Starting......: pure-ftpd writing /etc/pure-ftpd/conf/LDAPConfigFile');
logs.WriteToFile(l.Text,'/etc/pure-ftpd/conf/LDAPConfigFile');
forcedirectories('/etc/pure-ftpd/auth');
logs.OutputCmd('/bin/ln -s --force /etc/pure-ftpd/conf/LDAPConfigFile /etc/pure-ftpd/auth/10pure');
l.free;
end;
//#############################################################################
function tpureftpd.get_INFOS(key:string):string;
var value:string;
begin
GLOBAL_INI:=TIniFile.Create('/etc/artica-postfix/artica-postfix.conf');
value:=GLOBAL_INI.ReadString('INFOS',key,'');
result:=value;
GLOBAL_INI.Free;
end;
//#############################################################################
function tpureftpd.get_LDAP(key:string):string;
var value:string;
begin
GLOBAL_INI:=TIniFile.Create('/etc/artica-postfix/artica-postfix-ldap.conf');
value:=GLOBAL_INI.ReadString('LDAP',key,'');
result:=value;
GLOBAL_INI.Free;
end;
//#############################################################################
function tpureftpd.COMMANDLINE_PARAMETERS(FoundWhatPattern:string):boolean;
var
   i:integer;
   s:string;
   RegExpr:TRegExpr;

begin
 result:=false;
 s:='';
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

function tpureftpd.ReadFileIntoString(path:string):string;
var
   List:TstringList;
begin

      if not FileExists(path) then begin
        exit;
      end;

      List:=Tstringlist.Create;
      List.LoadFromFile(path);
      result:=trim(List.Text);
      List.Free;
end;
//##############################################################################
procedure tpureftpd.DEBIAN_LINK();
begin
if not DirectoryExists('/etc/pure-ftpd/auth') then exit;
if FileExists('/etc/pure-ftpd/auth/50pure') then exit;
fpsystem('/bin/ln -s /etc/pure-ftpd/conf/PureDB /etc/pure-ftpd/auth/50pure');
end;
//##############################################################################
procedure tpureftpd.DISABLE_INETD();
var
   l:TstringList;
   i:integer;
   RegExpr:TRegExpr;
begin

if not FileExists('/etc/inetd.conf') then begin
   logs.Syslogs('Starting......: pure-ftpd unable to stat /etc/inetd.conf');
   exit;
end;
  l:=Tstringlist.Create;
  l.LoadFromFile('/etc/inetd.conf');
  //#ftp    stream  tcp     nowait  root    /usr/sbin/tcpd /usr/sbin/pure-ftpd-wrapper
  for i:=0 to l.Count-1 do begin
  RegExpr:=TRegExpr.Create;
  RegExpr.Expression:='^ftp\s+.+?pure-ftpd-wrapper';
  if RegExpr.Exec(l.Strings[i]) then begin
     l.Delete(i);
     l.SaveToFile('/etc/inetd.conf');
     if FileExists(SYS.LOCATE_INETD_INITD()) then fpsystem(SYS.LOCATE_INETD_INITD() + ' restart');
     break;
  end;
  end;
  l.free;
  RegExpr.free;
end;
//##############################################################################

procedure tpureftpd.PURE_FTPD_START();
 var
    count      :integer;
    pid:string;
    STANDALONE_OR_INETD:string;
begin

     if Not FileExists(DAEMON_BIN_PATH()) then begin
           logs.DebugLogs('Starting......: pure-ftpd is not installed');
           exit;
     end;

     if PureFtpdEnabled=0 then begin
           PURE_FTPD_STOP();
           exit;
     end;

     pid:=PURE_FTPD_PID();
     if SYS.PROCESS_EXIST(pid) then begin
        logs.DebugLogs('Starting......: pure-ftpd already running PID '+pid);
        exit;
     end;
     
     
     {if not FileExists('/etc/pure-ftpd/pureftpd.pdb') then begin
       logs.DebugLogs('Starting......: pure-ftpd no users set');
       FIX_CONFIG_ERRORS();
       if not SYS.IsUserExists('ftp') then SYS.AddUserToGroup('ftp','ftp','','');
       exit;
     end;
     }
     
     STANDALONE_OR_INETD:=GET_DEFAULT_VALUES('STANDALONE_OR_INETD');
     if STANDALONE_OR_INETD='inetd' then begin
        ETC_DEFAULT();
        logs.DebugLogs('Starting......: pure-ftpd is linked to inetd, disable inetd for pure-ftpd');
        DISABLE_INETD();
        FIX_CONFIG_ERRORS();
        if not SYS.IsUserExists('ftp') then SYS.AddUserToGroup('ftp','ftp','','');
        PURE_FTPD_STOP();
     end;
     
     
     logs.DebugLogs('Starting......: pure-ftpd daemon...');
     if not SYS.IsUserExists('ftp') then SYS.AddUserToGroup('ftp','ftp','','');
     LDAP_CONF();
     CreateDebianConfig();
     FIX_CONFIG_ERRORS();

     if FileExists(PURE_FTPD_WRAPPER_PATH()) then begin
        logs.DebugLogs('Starting......: pure-ftpd daemon using wrapper '+PURE_FTPD_WRAPPER_PATH());
        fpsystem(PURE_FTPD_WRAPPER_PATH()+' &');
     end;

  count:=0;
  while not SYS.PROCESS_EXIST(PURE_FTPD_PID()) do begin
        sleep(100);
        count:=count+1;
        write('.');
        if count>20 then begin
            writeln('');
            logs.DebugLogs('Starting......: pure-ftpd daemon (timeout)...');
            break;
        end;
  end;

     writeln('');
     pid:=PURE_FTPD_PID();
     if SYS.PROCESS_EXIST(pid) then begin
        logs.DebugLogs('Starting......: pure-ftpd success with new PID '+pid);
        exit;
     end;



     if FileExists(PURE_FTPD_INITD()) then begin
        logs.DebugLogs('Starting......: pure-ftpd daemon '+PURE_FTPD_INITD());
        logs.OutputCmd(PURE_FTPD_INITD() + ' start');
    end;

     pid:=PURE_FTPD_PID();
     if SYS.PROCESS_EXIST(pid) then begin
        logs.DebugLogs('Starting......: pure-ftpd with PID '+pid);
        exit;
     end;

     logs.DebugLogs('Starting......: pure-ftpd failed');

end;
//##############################################################################
procedure tpureftpd.FIX_CONFIG_ERRORS();
begin
   if FileExists('/etc/pure-ftpd/conf/ClientCharset') then begin
        if not GET_COMPILED_SWITCH('clientcharset') then begin
            logs.Syslogs('Starting......: pure-ftpd remove ClientCharset due to compilation switch missing');
            logs.DeleteFile('/etc/pure-ftpd/conf/ClientCharset');
        end;
   
   end;


end;
//##############################################################################

procedure tpureftpd.PURE_FTPD_STOP();
 var
    pid:string;
    count:integer;
    STANDALONE_OR_INETD:string;
begin
count:=0;
pid:=PURE_FTPD_PID();
if Not FileExists(DAEMON_BIN_PATH()) then exit;

  if not SYS.PROCESS_EXIST(PURE_FTPD_PID()) then begin
     writeln('Stopping pure-ftpd...........: Already stopped');
     exit;
  end;

STANDALONE_OR_INETD:=GET_DEFAULT_VALUES('STANDALONE_OR_INETD');
if STANDALONE_OR_INETD='inetd' then begin
    writeln('Stopping pure-ftpd...........: linked to inetd...');
    exit;
end;

  pid:=PURE_FTPD_PID();
  if SYS.PROCESS_EXIST(pid) then begin
   writeln('Stopping pure-ftpd...........: ' + pid + ' PID');
   fpsystem('/bin/kill ' + pid + ' >/dev/null 2>&1');
    while SYS.PROCESS_EXIST(PURE_FTPD_PID()) do begin
        sleep(100);
        inc(count);
        fpsystem('/bin/kill ' + PURE_FTPD_PID() + ' >/dev/null 2>&1');
        if count>30 then break;
    end;
  end;

  if not SYS.PROCESS_EXIST(PURE_FTPD_PID()) then begin
     writeln('Stopping pure-ftpd...........: stopped');
     exit;
  end;


if FileExists(PURE_FTPD_INITD()) then begin
        if SYS.PROCESS_EXIST(pid) then begin
           writeln('Stopping pure-ftpd...........: ' + pid + ' PID');
           fpsystem(PURE_FTPD_INITD() + ' stop');
           if SYS.PROCESS_EXIST(pid) then begin
              writeln('Stopping pure-ftpd...........: Killing '+ pid);
              fpsystem('/bin/kill -9 ' + pid + ' >/dev/null 2>&1');
              exit;
           end;
           exit;

        end else begin
            writeln('Stopping pure-ftpd...........: Already stopped');
            exit;
        end;
end;
        




end;
//##############################################################################

end.
