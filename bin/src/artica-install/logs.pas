unit logs;

{$mode objfpc}{$H+}

interface

uses
//depreciated oldlinux -> baseunix
Classes, SysUtils,variants,strutils, Process,IniFiles,baseunix,unix,md5,RegExpr in 'RegExpr.pas',systemlog,mysql4,dateutils;

  type
  Tlogs=class


private
     MaxlogSize:longint;
     D:boolean;

     sock : PMYSQL;
     qmysql : TMYSQL;
     //qbuf : string [160];
     rowbuf : MYSQL_ROW;
     //mquery : string;
     recbuf : PMYSQL_RES;
     alloc : PMYSQL;
     mem_mysql_port:string;

     function GetFileSizeKo(path:string):longint;
     function GET_INFO(key:string):string;
     function MaxSizeLimit:integer;
     PROCEDURE logsModule(zText:string);
     function MYSQL_PORT():string;
     function MYSQL_MYCNF_PATH:string;
     function MYSQL_SERVER_PARAMETERS_CF(key:string):string;
     function MYSQL_READ_CF(key:string;mycfpath:string):string;
     function MYSQL_EXEC_BIN_PATH():string;
     function FILE_TIME_BETWEEN_MIN(filepath:string):LongInt;
     function SearchAndReplace(sSrc, sLookFor, sReplaceWith: string ): string;
     function SYSTEM_FQDN():string;
     function ReadFileIntoString(path:string):string;
     function MYSQL_PARSE_ERROR(error:string):boolean;




public
    Enable_echo:boolean;
    Enable_echo_install:boolean;
    Debug:boolean;
    module_name:string;

    constructor Create;
    procedure Free;
    procedure logs(zText:string);
    PROCEDURE logsInstall(zText:string);
    PROCEDURE logsPostfix(zText:string);
    function GetFileSizeMo(path:string):longint;
    function MD5FromString(value:string):string;
    PROCEDURE Debuglogs(zText:string);
    PROCEDURE logsStart(zText:string);
    PROCEDURE  mysql_logs(event_id:string;event_type:string;event_text:string);
    PROCEDURE  mysql_notify(error_id:string;daemon:string;event_text:string);
    PROCEDURE  mysql_virus(daemon:string;event_text:string;zDate:string;virusname:string);
    function FormatHeure (value : Int64) : String;
    procedure DeleteLogs();
    function   GetFileBytes(path:string):longint;
    PROCEDURE logsThread(ThreadName:string;zText:string);
    PROCEDURE ERRORS(zText:string);
    PROCEDURE RemoveFilesAndDirectories(path:string;pattern:string);
    PROCEDURE INSTALL_MODULES(application_name:string;zText:string);
    PROCEDURE Syslogs(text:string);
    function COMMANDLINE_PARAMETERS(FoundWhatPattern:string):boolean;
    FUNCTION TRANSFORM_DATE_MONTH(zText:string):string;
    PROCEDURE mysql_sysev(event_type:string;daemon:string;event_text:string;zDate:string;msg_id:string);
    function getyear():string;

    function Connect():boolean;
    procedure Disconnect();

    FUNCTION QUERY_SQL(sql:Pchar;database:string):boolean;
    function QUERY_SQL_STORE(sql:string;database:string):PMYSQL_RES;
    function QUERY_SQL_PARSE_COLUMN(sql:string;database:string;ColumnNumber:integer):Tstringlist;
    function QUERY_SQL_BIN(database:string;fileName:string):boolean;
    procedure MYSQL_REPAIR_TABLE(tablename:string;database:string;error:string);
    function EXECUTE_SQL_FILE(filenname:string;database:string;defaultcharset:string=''):boolean;
    function LIST_MYSQL_DATABASES():TstringList;
    function EXECUTE_SQL_STRING(query:string):string;
    function IF_DATABASE_EXISTS(database_name:string):boolean;
    function IF_TABLE_EXISTS(table:string;database:string):boolean;
    function SYS_EVENTS_ROWNUM():integer;
    function DateTimeNowSQL():string;
    function WriteToFile(zText:string;TargetPath:string):boolean;
    procedure DeleteFile(TargetPath:string);
    function ReadFromFile(TargetPath:string):string;
    PROCEDURE Output(zText:string;icon_type:string='info');


    procedure OutputCmd(command:string;realoutput:boolean=false);
    function OutputCmdR(command:string):string;

    procedure set_INFOS(key:string;val:string);
    function FILE_TEMP():string;
    PROCEDURE nmap(zText:string);
    function TABLE_ROWNUM(tablename:string;database:string):integer;
    procedure WriteInstallLogs(text:string);
    function GetAsSQLText(MessageToTranslate:string) : string;
    procedure NOTIFICATION(subject:string;content:string;context:string);
    function DateTimeDiff(Start, Stop : TDateTime) : int64;
    function INSTALL_STATUS(APP_NAME:string;POURC:integer):string;
    procedure LogGeneric(text:string;path:string);
    function MYSQL_INFOS(val:string):string;
    function INSTALL_PROGRESS(APP_NAME:string;info:string):string;
    PROCEDURE EVENTS(subject:string;text:string;context:string;filePath:string);
    PROCEDURE BACKUP_EVENTS(text:string;localsource:string;remote_source:string;success:integer);
    function copyfile(srcfn, destfn:string):boolean;
    PROCEDURE commandlog();
    function FileTimeName():string;
end;

implementation

//-------------------------------------------------------------------------------------------------------


//##############################################################################
constructor Tlogs.Create;

begin
       forcedirectories('/etc/artica-postfix');
       Enable_echo:=false;
       MaxlogSize:=100;
       D:=COMMANDLINE_PARAMETERS('-V');
end;
//##############################################################################
PROCEDURE Tlogs.Free();
begin

end;
//##############################################################################
PROCEDURE Tlogs.EVENTS(subject:string;text:string;context:string;filePath:string);
         const
            CR = #$0d;
            LF = #$0a;
            CRLF = CR + LF;
var
   zdate:string;
   zDateSubject:string;
   ini:Tinifile;
   filename:string;
   bigtext:string;
begin
   zdate:=FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
   zDateSubject:=FormatDateTime('hh:nn:ss', Now);
   filename:='/var/log/artica-postfix/events/'+MD5FromString(context+filePath+subject);

   if FIleExists(filename) then exit;



   ForceDirectories('/var/log/artica-postfix/events');
   ini:=Tinifile.Create(filename);
   ini.WriteString('LOG','processname',ExtractFileName(ParamStr(0)));
   ini.WriteString('LOG','date',zdate);
   ini.WriteString('LOG','context',context);
   ini.WriteString('LOG','subject','['+zDateSubject+']: '+subject);
   ini.WriteString('LOG','filePath',filePath);
   ini.UpdateFile;
   ini.Free;

   bigtext:=ReadFileIntoString(filename);
   bigtext:=bigtext+CRLF+'<text>'+text+'</text>'+CRLF;
   WriteToFile(bigtext,filename);



end;
//##############################################################################



PROCEDURE Tlogs.logsInstall(zText:string);
      var
        zDate:string;
        myFile : TextFile;
        xText:string;
        TargetPath:string;
        info : stat;
        maintenant : Tsystemtime;
        processname:string;
      BEGIN
        if Enable_echo=True then writeln(zText);
        if Enable_echo_install then writeln(zText);
        TargetPath:='/var/log/artica-postfix/artica-install.log';
        processname:=ExtractFileName(ParamStr(0));
        forcedirectories('/var/log/artica-postfix');
        getlocaltime(maintenant);zDate := FormatHeure(maintenant.Year)+'-' +FormatHeure(maintenant.Month)+ '-' + FormatHeure(maintenant.Day)+ chr(32)+FormatHeure(maintenant.Hour)+':'+FormatHeure(maintenant.minute)+':'+ FormatHeure(maintenant.second);
        xText:=zDate + ' [' + processname + '] ' + zText;

        TRY
           if GetFileSizeKo(TargetPath)>MaxlogSize then begin
              ExecuteProcess('/bin/rm','-f ' +  TargetPath);
              xText:=xText + ' (log file was killed before)';
              end;
              EXCEPT
              exit;
        end;

        TRY

           AssignFile(myFile, TargetPath);
           if FileExists(TargetPath) then Append(myFile);
           if not FileExists(TargetPath) then ReWrite(myFile);
            WriteLn(myFile, xText);
           CloseFile(myFile);
        EXCEPT
             writeln(xtext + '-> error writing ' +     TargetPath);
          END;
      END;
//#############################################################################
PROCEDURE Tlogs.logsPostfix(zText:string);
      var
        zDate:string;
        myFile : TextFile;
        xText:string;
        TargetPath:string;
        processname:string;
        info : stat;
        maintenant : Tsystemtime;
      BEGIN
        if Enable_echo=True then writeln(zText);
        if Enable_echo_install then writeln(zText);
        TargetPath:='/var/log/artica-postfix/postfix.log';
        processname:=ExtractFileName(ParamStr(0));
        
        
        
        forcedirectories('/var/log/artica-postfix');
        getlocaltime(maintenant);zDate := FormatHeure(maintenant.Year)+'-' +FormatHeure(maintenant.Month)+ '-' + FormatHeure(maintenant.Day)+ chr(32)+FormatHeure(maintenant.Hour)+':'+FormatHeure(maintenant.minute)+':'+ FormatHeure(maintenant.second);
        xText:=zDate + ' ' +processname + ' ' + zText;

        

        TRY
           if GetFileSizeKo(TargetPath)>MaxlogSize then begin
              ExecuteProcess('/bin/rm','-f ' +  TargetPath);
              xText:=xText + ' (log file was killed before)';
              end;
              EXCEPT
              exit;
        end;

        TRY

           AssignFile(myFile, TargetPath);
           if FileExists(TargetPath) then Append(myFile);
           if not FileExists(TargetPath) then ReWrite(myFile);
            WriteLn(myFile, xText);
           CloseFile(myFile);
        EXCEPT
             writeln(xtext + '-> error writing ' +     TargetPath);
          END;
      END;
//#############################################################################


PROCEDURE Tlogs.ERRORS(zText:string);
      var
        zDate:string;
        myFile : TextFile;
        xText:string;
        TargetPath:string;
        info : stat;
        maintenant : Tsystemtime;
      BEGIN
        if Enable_echo=True then writeln(zText);
        if Enable_echo_install then writeln(zText);
        TargetPath:='/var/log/artica-postfix/artica-errors.log';

        forcedirectories('/var/log/artica-postfix');
        getlocaltime(maintenant);zDate := FormatHeure(maintenant.Year)+'-' +FormatHeure(maintenant.Month)+ '-' + FormatHeure(maintenant.Day)+ chr(32)+FormatHeure(maintenant.Hour)+':'+FormatHeure(maintenant.minute)+':'+ FormatHeure(maintenant.second);
        xText:=zDate + ' ' + zText;

        TRY
           if GetFileSizeKo(TargetPath)>MaxlogSize then begin
              ExecuteProcess('/bin/rm','-f ' +  TargetPath);
              xText:=xText + ' (log file was killed before)';
              end;
              EXCEPT
              exit;
        end;

        TRY

           AssignFile(myFile, TargetPath);
           if FileExists(TargetPath) then Append(myFile);
           if not FileExists(TargetPath) then ReWrite(myFile);
            WriteLn(myFile, xText);
           CloseFile(myFile);
        EXCEPT
             writeln(xtext + '-> error writing ' +     TargetPath);
          END;
      END;
//#############################################################################
PROCEDURE tlogs.BACKUP_EVENTS(text:string;localsource:string;remote_source:string;success:integer);
var sql:string;
begin
   sql:='INSERT INTO cyrus_backup_events(`zDate`,`local_ressource`, `events`,`remote_ressource` ,`success`) VALUES("'+DateTimeNowSQL()+'","'+localsource+'","'+GetAsSQLText(text)+'","'+remote_source+'","'+IntToStr(success)+'");';
   QUERY_SQL(Pchar(sql),'artica_events');
end;
//#############################################################################
PROCEDURE Tlogs.INSTALL_MODULES(application_name:string;zText:string);
      var
        zDate:string;
        myFile : TextFile;
        xText:string;
        TargetPath:string;
        info : stat;
        maintenant : Tsystemtime;

      BEGIN
        D:=COMMANDLINE_PARAMETERS('-verbose');
        if not D then D:=COMMANDLINE_PARAMETERS('setup');
        if not D then D:=COMMANDLINE_PARAMETERS('-install');
        if not D then D:=COMMANDLINE_PARAMETERS('-perl-upgrade');
        if not D then D:=COMMANDLINE_PARAMETERS('addons');
        if not D then D:=COMMANDLINE_PARAMETERS('-web-configure');
        if not D then D:=COMMANDLINE_PARAMETERS('-kav-proxy');
        if not D then D:=COMMANDLINE_PARAMETERS('-install-web-artica');
        if not D then D:=COMMANDLINE_PARAMETERS('-init-postfix');
        if not D then D:=COMMANDLINE_PARAMETERS('-init-cyrus');
        if not D then D:=COMMANDLINE_PARAMETERS('-artica-web-install');
        if not D then D:=COMMANDLINE_PARAMETERS('-php-mysql');
        if not D then D:=COMMANDLINE_PARAMETERS('-php5');
        if not D then D:=COMMANDLINE_PARAMETERS('-mysql-install');
        if not D then D:=COMMANDLINE_PARAMETERS('-mysql-reconfigure');
        if not D then D:=COMMANDLINE_PARAMETERS('-roundcube');
        if not D then D:=COMMANDLINE_PARAMETERS('-squid-install');
        if not D then D:=COMMANDLINE_PARAMETERS('-squid-configure');
        if not D then D:=COMMANDLINE_PARAMETERS('linux-net-dev');
        if not D then D:=COMMANDLINE_PARAMETERS('-squid-security');
        if not D then D:=COMMANDLINE_PARAMETERS('-pure-ftpd');
        if not D then D:=COMMANDLINE_PARAMETERS('-perl-addons');
        if not D then D:=COMMANDLINE_PARAMETERS('-curl-install');
        if not D then D:=COMMANDLINE_PARAMETERS('-perl-db-file');
        if not D then D:=COMMANDLINE_PARAMETERS('-amavis-install');
        if not D then D:=COMMANDLINE_PARAMETERS('-amavisd-install');
        if not D then D:=COMMANDLINE_PARAMETERS('-init-amavis');
        if not D then D:=COMMANDLINE_PARAMETERS('-amavis-sql-reconfigure');
        if not D then D:=COMMANDLINE_PARAMETERS('-amavis-sql-install');
        if not D then D:=COMMANDLINE_PARAMETERS('-amavis-sql-configure');
        if not D then D:=COMMANDLINE_PARAMETERS('-install-perl-cyrus');
        if not D then D:=COMMANDLINE_PARAMETERS('-mailutils-install');
        if not D then D:=COMMANDLINE_PARAMETERS('-mailfromd-install');
        if not D then D:=COMMANDLINE_PARAMETERS('-cyrus-imap-install');
        if not D then D:=COMMANDLINE_PARAMETERS('-lighttp');
        if not D then D:=COMMANDLINE_PARAMETERS('-ligphp5');
        if not D then D:=COMMANDLINE_PARAMETERS('-mhonarc-install');
        if not D then D:=COMMANDLINE_PARAMETERS('--init-from-repos');
        


        WriteInstallLogs(zText);
        logs(zText);
        logsInstall('[' + application_name + '] ' + ztext);
        TargetPath:='/var/log/artica-postfix/artica-install-' + application_name + '.log';
        logs(zText);
        Debuglogs(zText);
        if COMMANDLINE_PARAMETERS('--verbose') then begin
           writeln(ztext);
        end else begin
            if COMMANDLINE_PARAMETERS('--screen') then writeln(ztext);
        end;


        if D then writeln(zText);
        forcedirectories('/var/log/artica-postfix');
        getlocaltime(maintenant);zDate := FormatHeure(maintenant.Year)+'-' +FormatHeure(maintenant.Month)+ '-' + FormatHeure(maintenant.Day)+ chr(32)+FormatHeure(maintenant.Hour)+':'+FormatHeure(maintenant.minute)+':'+ FormatHeure(maintenant.second);
        xText:=zDate + ' ' + zText;

        TRY
           if GetFileSizeKo(TargetPath)>MaxlogSize then begin
              ExecuteProcess('/bin/rm','-f ' +  TargetPath);
              xText:=xText + ' (log file was killed before)';
              end;
              EXCEPT
              exit;
        end;

        TRY

           AssignFile(myFile, TargetPath);
           if FileExists(TargetPath) then Append(myFile);
           if not FileExists(TargetPath) then ReWrite(myFile);
            WriteLn(myFile, xText);
            CloseFile(myFile);
            xText:='';
        EXCEPT
             writeln(xtext + '-> error writing ' +     TargetPath);
          END;
      END;
//#############################################################################



//##############################################################################
function Tlogs.getyear():string;
var
   maintenant : Tsystemtime;
begin
   getlocaltime(maintenant);
   result:=FormatHeure(maintenant.Year);
end;
//##############################################################################
function Tlogs.DateTimeNowSQL():string;
begin
   result:=FormatDateTime('yyyy-mm-dd hh:nn:ss', Now)
end;
//##############################################################################
function Tlogs.FileTimeName():string;
begin

   result:=FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
   result:=AnsiReplaceText(result,' ','_');
   result:=AnsiReplaceText(result,':','-');
end;
//##############################################################################


PROCEDURE Tlogs.RemoveFilesAndDirectories(path:string;pattern:string);
var
   l:TstringList;
   i:integer;
begin

if length(path)=0 then exit;
if length(pattern)=0 then pattern:='/*';
if pattern='*' then pattern:='/*';

l:=TstringList.Create;
l.Add('/');
l.Add('/usr');
l.Add('/usr/share');
l.Add('/usr/sbin');
l.Add('/sbin');
l.Add('/usr/local');
l.Add('/home');
l.Add('/home/dtouzeau');
l.Add('/usr/share/artica-postfix');
l.add('/var');
l.add('/etc');
l.add('/var/lib');
l.add('/proc');
l.add('/bin');
l.Add('/lib');

for i:=0 to l.Count-1 do begin
    if l.Strings[i]=path then begin
       Syslogs('Security warning, could not delete Directory "' +path+'"');
       exit;
    end;

end;

l.free;
Debuglogs('Removing '+path+pattern);
Outputcmd('/bin/rm -rf '+ path+pattern);

end;
//##############################################################################





PROCEDURE Tlogs.logsThread(ThreadName:string;zText:string);
      var
        zDate:string;
        myFile : TextFile;
        xText:string;
        TargetPath:string;
        info : stat;
        maintenant : Tsystemtime;
      BEGIN

        TargetPath:='/var/log/artica-postfix/artica-thread-' + ThreadName + '.log';

        forcedirectories('/var/log/artica-postfix');
        getlocaltime(maintenant);
        zDate := DateTimeNowSQL();

        if length(module_name)>0 then logsModule(zText);
        xText:=zDate + ' ' + zText;


        if D=True then writeln(zText);


        TRY
           if GetFileSizeKo(TargetPath)>MaxlogSize then begin
              ExecuteProcess('/bin/rm','-f ' +  TargetPath);
              xText:=xText + ' (log file was killed before)';
              end;
              EXCEPT
              exit;
        end;

        TRY

           AssignFile(myFile, TargetPath);
           if FileExists(TargetPath) then Append(myFile);
           if not FileExists(TargetPath) then ReWrite(myFile);
            WriteLn(myFile, xText);
           CloseFile(myFile);
        EXCEPT
             //writeln(xtext + '-> error writing ' +     TargetPath);
          END;
      END;
//##############################################################################
PROCEDURE Tlogs.Output(zText:string;icon_type:string);
var img:string;
   begin
      if icon_type='info' then img:='icon_mini_info.gif';
      if icon_type='error' then img:='icon_mini_off.gif';
      if icon_type='ok' then img:='icon_mini_off.gif';
         writeln(ztext);

      
   
   end;
//##############################################################################
PROCEDURE Tlogs.OutputCmd(command:string;realoutput:boolean);
var
   tmp:string;
   cmd:string;
   i:Integer;
   l:TstringList;
   r:Tstringlist;
begin
   tmp:=FILE_TEMP();
   cmd:=command + ' >' + tmp + ' 2>&1';
   Debuglogs(cmd);
   fpsystem(cmd);
   if FileExists(tmp) then begin
      l:=TstringList.Create;

      try
         l.LoadFromFile(tmp);
      except
         Syslogs('OutputCmd:: FATAL error while reading '+tmp);
         exit;
      end;
      
      r:=TstringList.Create;
      for i:=0 to l.Count-1 do begin
          if length(trim(l.Strings[i]))>0 then r.Add(l.Strings[i]);
      end;
      if r.Count>0 then begin
         Debuglogs(r.Text);
         if realoutput then Output(r.Text,'info');
      end;
      r.free;
      l.free;
      DeleteFile(tmp);
   end;
end;
//##############################################################################
function Tlogs.OutputCmdR(command:string):string;
var
   tmp:string;
   cmd:string;
   i:Integer;
   l:TstringList;
   r:Tstringlist;
begin
   tmp:=FILE_TEMP();
   cmd:=command + ' >' + tmp + ' 2>&1';
   Debuglogs(cmd);
   fpsystem(cmd);
   if FileExists(tmp) then begin
      l:=TstringList.Create;
      r:=TstringList.Create;
      l.LoadFromFile(tmp);

      for i:=0 to l.Count-1 do begin
          if length(trim(l.Strings[i]))>0 then r.Add(l.Strings[i]);
      end;
      if r.Count>0 then begin
         Debuglogs(r.Text);
      end;
      r.free;
      l.free;
      result:=tmp;
   end;
end;
//##############################################################################

function Tlogs.FILE_TEMP():string;
var
   stmp:string;
begin
stmp:=MD5FromString(FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));

result:=GetTempFileName('',ExtractFileName(ParamStr(0))+'-'+stmp+'-')
end;


PROCEDURE Tlogs.logsStart(zText:string);
      var
        zDate:string;
        myFile : TextFile;
        xText:string;
        TargetPath:string;
        maintenant : Tsystemtime;
      BEGIN

        TargetPath:='/var/log/artica-postfix/start.log';

        forcedirectories('/var/log/artica-postfix');
        zDate := DateTimeNowSQL();

        if length(module_name)>0 then logsModule(zText);
        xText:=zDate + ' ' + zText;
        TRY
        EXCEPT
        writeln('unable to write /var/log/artica-postfix/start.log');
        END;

        TRY
           if GetFileSizeKo(TargetPath)>MaxlogSize then begin
              ExecuteProcess('/bin/rm','-f ' +  TargetPath);
              xText:=xText + ' (log file was killed before)';
              end;
              EXCEPT
              exit;
        end;

        TRY

           AssignFile(myFile, TargetPath);
           if FileExists(TargetPath) then Append(myFile);
           if not FileExists(TargetPath) then ReWrite(myFile);
            WriteLn(myFile, xText);
           CloseFile(myFile);
        EXCEPT
             //writeln(xtext + '-> error writing ' +     TargetPath);
          END;
      END;
//##############################################################################


PROCEDURE tlogs.Syslogs(text:string);
var
   s:string;
   LogString: array[0..1024] of char;
   LogPrefix: array[0..255] of char;
   ProcessName:string;
   facility:longint;
const
  LOG_PID       = $01;
  LOG_CONS      = $02;
  LOG_ODELAY    = $04;
  LOG_NDELAY    = $08;
  LOG_NOWAIT    = $10;
  LOG_PERROR    = $20;
  LOG_EMERG             = 0;
  LOG_ALERT             = 1;
  LOG_CRIT              = 2;
  LOG_ERR               = 3;
  LOG_WARNING           = 4;
  LOG_NOTICE            = 5;
  LOG_INFO              = 6;
  LOG_DEBUG             = 7;
   
begin
   // S := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now)
  ProcessName:= ExtractFileName(ParamStr(0));
  s:= ProcessName+'['+IntToStr(fpGetPid)+']';
  StrPCopy(LogPrefix, s);
  
  facility:=LOG_INFO;
  if ProcessName='artica-filter-smtp-out' then facility:=LOG_MAIL;
  if ProcessName='artica-mailarchive' then facility:=LOG_MAIL;
  if ProcessName='artica-bogom' then facility:=LOG_MAIL;
  if ProcessName='artica-attachments' then facility:=LOG_MAIL;
  
  OpenLog(LogPrefix, LOG_NOWAIT, facility);
  StrPCopy( LogString,text);
  SysLog(2, LogString, [0]);
  CloseLog();
  Debuglogs(text);
end;

PROCEDURE Tlogs.mysql_logs(event_id:string;event_type:string;event_text:string);
var
   zDate      :string;
   processname:string;
   l          :TstringList;
   queuefile  :string;
   maintenant : Tsystemtime;
   hostname   :string;
begin

   {
    event_id
            2 services
            3 update
            4 mailboxes
            5 OBM
            6 backup
            
    event_type
            0 error
            1 success
            2 infos
    }
    

   hostname:=SYSTEM_FQDN();
   getlocaltime(maintenant);
   zDate := FormatHeure(maintenant.Year)+'-' +FormatHeure(maintenant.Month)+ '-' + FormatHeure(maintenant.Day)+ chr(32)+FormatHeure(maintenant.Hour)+':'+FormatHeure(maintenant.minute)+':'+ FormatHeure(maintenant.second);
   processname:=ExtractFileName(ParamStr(0));
   l:=TstringList.Create;
   forcedirectories('/opt/artica/mysql/artica-queue/');
   queuefile:='/opt/artica/mysql/artica-queue/'+MD5FromString(zDate+event_id+event_type+event_text);
   
   event_text:=AnsiReplaceStr(event_text,'''','`');
   event_text:=AnsiReplaceStr(event_text,'\','\\');
   
   l:=TStringList.Create;
   l.Add('INSERT INTO `artica_events`.`events` (');
   l.Add('`ID` ,');
   l.Add('`zDate` ,');
   l.Add('`hostname` ,');
   l.Add('`event_id` ,');
   l.Add('`event_type` ,');
   l.Add('`process` ,');
   l.Add('`text`');
   l.Add(')');
   l.Add('VALUES (');
   l.Add('NULL , '''+zDate+''','''+hostname+''', '''+event_id+''', '''+event_type+''', '''+processname+''', '''+event_text+'''');
   l.Add(');');
   
   if Connect() then begin
        if QUERY_SQL(PChar(l.Text),'artica_events') then begin
           mysql_close(sock);
           l.free;
           exit;
        end;
   end;
   
   l.SaveToFile(queuefile);
   l.free;
end;


//##############################################################################
PROCEDURE Tlogs.mysql_notify(error_id:string;daemon:string;event_text:string);
var
   l          :TstringList;
   queuefile  :string;
   maintenant : Tsystemtime;
   md5f       :string;
begin



   l:=TstringList.Create;
   forcedirectories('/opt/artica/mysql/artica-queue/');
   md5f:=MD5FromString(error_id+daemon+event_text);
   queuefile:='/opt/artica/mysql/artica-queue/'+md5f;

   event_text:=AnsiReplaceStr(event_text,'''','`');
   event_text:=AnsiReplaceStr(event_text,'\','\\');

   l:=TStringList.Create;
   l.Add('INSERT INTO `artica_events`.`notify` (');
   l.Add('`daemon` ,');
   l.Add('`event_text` ,');
   l.Add('`error_id` ,');
   l.Add('`zMD5`');
   l.Add(')');
   l.Add('VALUES (');
   l.Add(''''+daemon+''','''+event_text+''', '''+error_id+''', '''+md5f+'''');
   l.Add(');');
   

   if Connect() then begin
        if QUERY_SQL(PChar(l.Text),'artica_events') then begin
           mysql_close(sock);
           l.free;
           exit;
        end;
   end;
   l.SaveToFile(queuefile);
   l.free;
end;


//##############################################################################
PROCEDURE Tlogs.mysql_sysev(event_type:string;daemon:string;event_text:string;zDate:string;msg_id:string);
var

   processname:string;
   l          :TstringList;
   queuefile  :string;
   md5f       :string;
begin



   l:=TstringList.Create;
   forcedirectories('/opt/artica/mysql/artica-queue/');
   md5f:=MD5FromString(event_type+daemon+event_text+zDate+msg_id);
   queuefile:='/opt/artica/mysql/artica-queue/'+md5f;

   event_text:=AnsiReplaceStr(event_text,'''','`');
   event_text:=AnsiReplaceStr(event_text,'\','\\');



l.Add('INSERT INTO `artica_events`.`sys_events` (');
l.Add('`md5` ,');
l.Add('`ID` ,');
l.Add('`zDate` ,');
l.Add('`type` ,');
l.Add('`event_text` ,');
l.Add('`daemon` ,');
l.Add('`msg_id`');
l.Add(')');
l.Add('VALUES (');
l.Add(''''+md5f+''', NULL , '''+zDate+''', '''+event_type+''', '''+event_text+''', '''+daemon+''', '''+msg_id+''');');


   if Connect() then begin
        if QUERY_SQL(PChar(l.Text),'artica_events') then begin
           mysql_close(sock);
           l.free;
           exit;
        end;
   end;

l.SaveToFile(queuefile);
l.free;

end;
//##############################################################################
PROCEDURE Tlogs.mysql_virus(daemon:string;event_text:string;zDate:string;virusname:string);
var
   l          :TstringList;
   queuefile  :string;
   md5f       :string;
begin



   l:=TstringList.Create;
   forcedirectories('/opt/artica/mysql/artica-queue/');
   md5f:=MD5FromString(virusname+daemon+event_text+zDate);
   queuefile:='/opt/artica/mysql/artica-queue/'+md5f;

   event_text:=AnsiReplaceStr(event_text,'''','`');
   event_text:=AnsiReplaceStr(event_text,'\','\\');



l.Add('INSERT INTO `artica_events`.`infected_count` (');
l.Add('`zMD5` ,');
l.Add('`zDate` ,');
l.Add('`event_text` ,');
l.Add('`daemon` ,');
l.Add('`virusname`');
l.Add(')');
l.Add('VALUES (');
l.Add(''''+md5f+''', '''+zDate+''', '''+event_text+''', '''+daemon+''', '''+virusname+''');');


   if Connect() then begin
        if QUERY_SQL(PChar(l.Text),'artica_events') then begin
           mysql_close(sock);
           l.free;
           exit;
        end;
   end;
l.SaveToFile(queuefile);
l.free;

end;
//##############################################################################
function Tlogs.SYSTEM_FQDN():string;
begin
    D:=COMMANDLINE_PARAMETERS('debug');
    fpsystem('/bin/hostname >/opt/artica/logs/hostname.txt');
    result:=ReadFileIntoString('/opt/artica/logs/hostname.txt');
    result:=trim(result);
    if D then writeln('hostname=',result);
end;
//##############################################################################
PROCEDURE Tlogs.logs(zText:string);
      var
        zDate:string;
        myFile : TextFile;
        xText:string;
        TargetPath:string;
        info : stat;
        maintenant : Tsystemtime;
        processname:string;
      BEGIN
        processname:=ExtractFileName(ParamStr(0));
        TargetPath:='/var/log/artica-postfix/artica-postfix.log';

        forcedirectories('/var/log/artica-postfix');
        getlocaltime(maintenant);zDate := FormatHeure(maintenant.Year)+'-' +FormatHeure(maintenant.Month)+ '-' + FormatHeure(maintenant.Day)+ chr(32)+FormatHeure(maintenant.Hour)+':'+FormatHeure(maintenant.minute)+':'+ FormatHeure(maintenant.second);

        if length(module_name)>0 then logsModule(zText);
        xText:=zDate + ' ' + processname  + ' ' + zText;

        TRY
        if Enable_echo=True then writeln(zText);
        EXCEPT
        END;
        
        TRY
           if GetFileSizeKo(TargetPath)>MaxlogSize then begin
              ExecuteProcess('/bin/rm','-f ' +  TargetPath);
              xText:=xText + ' (log file was killed before)';
              end;
              EXCEPT
              exit;
        end;

        TRY

           AssignFile(myFile, TargetPath);
           if FileExists(TargetPath) then Append(myFile);
           if not FileExists(TargetPath) then ReWrite(myFile);
            WriteLn(myFile, xText);
           CloseFile(myFile);
        EXCEPT
             //writeln(xtext + '-> error writing ' +     TargetPath);
          END;
      END;
//##############################################################################
PROCEDURE Tlogs.nmap(zText:string);
      var
        zDate:string;
        myFile : TextFile;
        xText:string;
        TargetPath:string;
        info : stat;
        maintenant : Tsystemtime;
        processname:string;
      BEGIN
        processname:=ExtractFileName(ParamStr(0));
        forceDirectories('/usr/share/artica-postfix/ressources/logs');
        TargetPath:='/usr/share/artica-postfix/ressources/logs/nmap.log';
        Debuglogs(zText);
        forcedirectories('/var/log/artica-postfix');
        getlocaltime(maintenant);zDate := FormatHeure(maintenant.Year)+'-' +FormatHeure(maintenant.Month)+ '-' + FormatHeure(maintenant.Day)+ chr(32)+FormatHeure(maintenant.Hour)+':'+FormatHeure(maintenant.minute)+':'+ FormatHeure(maintenant.second);

        if length(module_name)>0 then logsModule(zText);
        xText:=zDate + ' ' + processname  + ' ' + zText;

        TRY
        if Enable_echo=True then writeln(zText);
        EXCEPT
        END;

        TRY
           if GetFileSizeKo(TargetPath)>MaxlogSize then begin
              ExecuteProcess('/bin/rm','-f ' +  TargetPath);
              xText:=xText + ' (log file was killed before)';
              end;
              EXCEPT
              exit;
        end;

        TRY

           AssignFile(myFile, TargetPath);
           if FileExists(TargetPath) then Append(myFile);
           if not FileExists(TargetPath) then ReWrite(myFile);
            WriteLn(myFile, xText);
           CloseFile(myFile);
        EXCEPT
             //writeln(xtext + '-> error writing ' +     TargetPath);
          END;
      END;
//##############################################################################
function Tlogs.GetAsSQLText(MessageToTranslate:string) : string;
var
  escaped: pchar;
  slen: longword;
  res: longword;
  newlen: longword;
begin
  if not connect() then exit;
  result:= '';
  escaped:='';
  slen:= length(MessageToTranslate);
  newlen:=(slen*2) + 1;
  getmem(escaped, newlen); // allocate worst case scenario
  res:= mysql_real_escape_string(sock, escaped,  pchar(MessageToTranslate), slen);
  if res > newlen then Debuglogs('GetAsSQLText():: Allocated pchar in mysqlEscape too small');
  result:= string(escaped); // makes copy of pchar
  freemem(escaped);
  Disconnect();
end;
//##############################################################################
PROCEDURE Tlogs.commandlog();
      var
        zDate:string;
        myFile : TextFile;
        xText:string;
        TargetPath:string;
        MasterDirectory:string;
        info : stat;
        MyDate,s:string;
        i:integer;
      BEGIN

        MasterDirectory:='/var/log/artica-postfix';
 if ParamCount>0 then begin
     for i:=0 to ParamCount do begin
        s:=s  + ' ' +ParamStr(i);

     end;
     s:=trim(s);
 end;
        TargetPath:=MasterDirectory+'/commands.debug';
        zDate:=FormatDateTime('dd:hh:ss', Now);
        xText:=zDate + ' ' +intTostr(fpgetpid)+ ' '+ s;
        TRY
           if GetFileSizeKo(TargetPath)>MaxlogSize then begin
                 ExecuteProcess('/bin/rm','-f ' +  TargetPath);
                 xText:=xText + ' (log file was killed before)';
              end;
              EXCEPT
              exit;
        end;

        TRY

           AssignFile(myFile, TargetPath);
           if FileExists(TargetPath) then Append(myFile);
           if not FileExists(TargetPath) then ReWrite(myFile);
            try
               WriteLn(myFile, xText);
            finally
            CloseFile(myFile);
            end;
        EXCEPT
             //writeln(xtext + '-> error writing ' +     TargetPath);
          END;
      END;
//##############################################################################
PROCEDURE Tlogs.Debuglogs(zText:string);
      var
        zDate:string;
        myFile : TextFile;
        xText:string;
        TargetPath:string;
        MasterDirectory:string;
        info : stat;
        processname:string;
        RegExpr:TRegExpr;
        MyDate:string;
      BEGIN
        processname:=ExtractFileName(ParamStr(0));
        RegExpr:=TRegExpr.Create;
        MasterDirectory:='/var/log/artica-postfix';

        if processname='artica-make' then writeln(zText);
        
        if COMMANDLINE_PARAMETERS('--verbose') then writeln(ztext);

        if not COMMANDLINE_PARAMETERS('--startall') then begin
           RegExpr.Expression:='Starting[\.\s+:]+';
           if RegExpr.Exec(zText) then writeln(zText);
           RegExpr.Expression:='Stopping[\.\s+:]+';
           if RegExpr.Exec(zText) then writeln(zText);
        end;


           //logging into syslog /start/stop daemons....
           

           RegExpr.Free;

        if processname='artica-pipe-back' then MasterDirectory:='/opt/artica/mimedefang-hooks';
        if processname='artica-mimedefang-pipe' then MasterDirectory:='/opt/artica/mimedefang-hooks';
        if processname='artica-filter-smtp-out' then MasterDirectory:='/opt/artica/mimedefang-hooks';

        if processname='artica-backup' then begin
           if Paramstr(1)='--export-config' then begin
              MasterDirectory:='/usr/share/artica-postfix/ressources/logs';
              TargetPath:=MasterDirectory+'/export-config.debug';
              if not FileExists(TargetPath) then begin
                 fpsystem('/bin/touch '+TargetPath);
                 fpsystem('/bin/chmod 755 '+ TargetPath);
              end;
          end;

           if Paramstr(1)='--import-config' then begin
              MasterDirectory:='/usr/share/artica-postfix/ressources/logs';
              TargetPath:=MasterDirectory+'/export-config.debug';
              if not FileExists(TargetPath) then begin
                 fpsystem('/bin/touch '+TargetPath);
                 fpsystem('/bin/chmod 755 '+ TargetPath);
              end;
          end;


        end;


        
        
        
        forcedirectories(MasterDirectory);
        if length(TargetPath)=0 then begin
           TargetPath:=MasterDirectory+'/' + processname + '.debug';
           if processname='artica-backup' then begin
            MyDate:=FormatDateTime('yyyy-mm-dd', Now);
            TargetPath:=MasterDirectory+'/' + processname + '-'+MyDate+'.debug';
           end;

           if processname='artica-update' then begin
              MyDate:=FormatDateTime('yyyy-mm-dd-hh', Now);
              TargetPath:=MasterDirectory+'/' + processname + '-'+MyDate+'.debug';
           end;
        end;

        zDate :=DateTimeNowSQL();

        if length(module_name)>0 then logsModule(zText);                        
        xText:=zDate + ' ' +intTostr(fpgetpid)+ ' '+ zText;




        TRY
           if GetFileSizeKo(TargetPath)>MaxlogSize then begin
              if processname<>'artica-backup' then begin
                 ExecuteProcess('/bin/rm','-f ' +  TargetPath);
                 xText:=xText + ' (log file was killed before)';
                 end;
              end;
              EXCEPT
              exit;
        end;

        TRY

           AssignFile(myFile, TargetPath);
           if FileExists(TargetPath) then Append(myFile);
           if not FileExists(TargetPath) then ReWrite(myFile);
            try
               WriteLn(myFile, xText);
            finally
            CloseFile(myFile);
            end;
        EXCEPT
             //writeln(xtext + '-> error writing ' +     TargetPath);
          END;
      END;
//##############################################################################

FUNCTION Tlogs.TRANSFORM_DATE_MONTH(zText:string):string;
begin
  zText:=UpperCase(zText);
  zText:=StringReplace(zText, 'JAN', '01',[rfReplaceAll, rfIgnoreCase]);
  zText:=StringReplace(zText, 'FEB', '02',[rfReplaceAll, rfIgnoreCase]);
  zText:=StringReplace(zText, 'MAR', '03',[rfReplaceAll, rfIgnoreCase]);
  zText:=StringReplace(zText, 'APR', '04',[rfReplaceAll, rfIgnoreCase]);
  zText:=StringReplace(zText, 'MAY', '05',[rfReplaceAll, rfIgnoreCase]);
  zText:=StringReplace(zText, 'JUN', '06',[rfReplaceAll, rfIgnoreCase]);
  zText:=StringReplace(zText, 'JUL', '07',[rfReplaceAll, rfIgnoreCase]);
  zText:=StringReplace(zText, 'AUG', '08',[rfReplaceAll, rfIgnoreCase]);
  zText:=StringReplace(zText, 'SEP', '09',[rfReplaceAll, rfIgnoreCase]);
  zText:=StringReplace(zText, 'OCT', '10',[rfReplaceAll, rfIgnoreCase]);
  zText:=StringReplace(zText, 'NOV', '11',[rfReplaceAll, rfIgnoreCase]);
  zText:=StringReplace(zText, 'DEC', '12',[rfReplaceAll, rfIgnoreCase]);
  result:=zText;
end;


PROCEDURE Tlogs.logsModule(zText:string);
      var
        zDate:string;
        myFile : TextFile;
        xText:string;
        TargetPath:string;


      BEGIN
        D:=COMMANDLINE_PARAMETERS('debug');
        if D then writeln('logsmodule();');
        TargetPath:='/var/log/artica-postfix/' + module_name + '.log';
        forcedirectories('/var/log/artica-postfix');
        zDate:=DateTimeNowSQL();
        xText:=zDate + ' ' + zText;


        TRY
           if GetFileSizeKo(TargetPath)>MaxlogSize then begin
              ExecuteProcess('/bin/rm','-f ' +  TargetPath);
              xText:=xText + ' (log file was killed before)';
              end;
              EXCEPT
              exit;
        end;

        TRY

           AssignFile(myFile, TargetPath);
           if FileExists(TargetPath) then Append(myFile);
           if not FileExists(TargetPath) then ReWrite(myFile);
            WriteLn(myFile, xText);
           CloseFile(myFile);
        EXCEPT
             writeln(xtext + '-> error writing ' +     TargetPath);
          END;
      END;
//#############################################################################
procedure Tlogs.DeleteLogs();
var
        TargetPath:string;
        val_GetFileSizeKo:integer;
begin
   TargetPath:='/var/log/artica-postfix/artica-postfix.log';
  val_GetFileSizeKo:=GetFileSizeKo(TargetPath);
  if debug then logs('Tlogs.DeleteLogs() -> ' + IntToStr(val_GetFileSizeKo) + '>? -> ' + IntToStr(MaxlogSize));
  if val_GetFileSizeKo>MaxlogSize then  fpsystem('/bin/rm -f ' +  TargetPath);

end;
//##############################################################################


function Tlogs.GetFileSizeKo(path:string):longint;
Var
L : File Of byte;
size:longint;
ko:longint;

begin
if not FileExists(path) then begin
   result:=0;
   exit;
end;
   TRY
  Assign (L,path);
  Reset (L);
  size:=FileSize(L);
   Close (L);
  ko:=size div 1024;
  result:=ko;
  EXCEPT

  end;
end;
//##############################################################################
function Tlogs.GetFileBytes(path:string):longint;
Var
L : File Of byte;
size:longint;
ko:longint;

begin
if not FileExists(path) then begin
   result:=0;
   exit;
end;
   TRY
  Assign (L,path);
  Reset (L);
  size:=FileSize(L);
   Close (L);
  ko:=size;
  result:=ko;
  EXCEPT

  end;
end;
function Tlogs.MaxSizeLimit:integer;
begin
exit(100);
end;
//##############################################################################

function Tlogs.FormatHeure (value : Int64) : String;
var minus : boolean;
begin
result := '';
if value = 0 then
result := '0';
Minus := value <0;
if minus then
value := -value;
while value >0 do begin
      result := char((value mod 10) + integer('0'))+result;
      value := value div 10;
end;
 if minus then
 result := '-' + result;
 if length(result)=1 then result := '0'+result;
end;
 //##############################################################################

function Tlogs.SearchAndReplace(sSrc, sLookFor, sReplaceWith: string ): string;
var
  nPos,
  nLenLookFor : integer;
begin
  nPos        := Pos( sLookFor, sSrc );
  nLenLookFor := Length( sLookFor );
  while(nPos > 0)do
  begin
    Delete( sSrc, nPos, nLenLookFor );
    Insert( sReplaceWith, sSrc, nPos );
    nPos := Pos( sLookFor, sSrc );
  end;
  Result := sSrc;
end;

//##############################################################################
function Tlogs.COMMANDLINE_PARAMETERS(FoundWhatPattern:string):boolean;
var
   i:integer;
   s:string;
   RegExpr:TRegExpr;

begin
 s:='';
 result:=false;
 if ParamCount>0 then begin
     for i:=1 to ParamCount do begin
        s:=s  + ' ' +ParamStr(i);
     end;
 end;
   RegExpr:=TRegExpr.Create;
   RegExpr.Expression:='\s+'+FoundWhatPattern;
   if RegExpr.Exec(s) then result:=True;
   RegExpr.Free;
   s:='';

end;
//##############################################################################
function Tlogs.MD5FromString(value:string):string;
var
Digest:TMD5Digest;
begin
Digest:=MD5String(value);
exit(MD5Print(Digest));
end;
//##############################################################################
function Tlogs.ReadFileIntoString(path:string):string;
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
function Tlogs.Connect():boolean;
var
   root     :string;
   password :string;
   port     :string;
   server   :string;
   socket   :string;
   portint  :integer;
begin
  root    :=MYSQL_INFOS('database_admin') +#0;
  password:=MYSQL_INFOS('database_password') +#0;
  port    :=MYSQL_INFOS('port') +#0;
  server  :=MYSQL_INFOS('mysql_server') +#0;
  socket  :=MYSQL_SERVER_PARAMETERS_CF('socket')+#0;
  alloc   :=mysql_init(PMYSQL(@qmysql));

  if not TryStrToInt(port,portint) then portint:=3306;

  sock    :=mysql_real_connect(alloc, PChar(@server[1]), PChar(@root[1]), PChar(@password[1]), nil, portint, PChar(@socket[1]), 0);


  if sock=Nil then
    begin
      Debuglogs('Connect():: Couldn''t connect to MySQL.');
      Debuglogs('Connect():: Error was: '+ StrPas(mysql_error(@qmysql)));
      exit(false);
   end;
  exit(true);

end;
//##############################################################################
function Tlogs.MYSQL_SERVER_PARAMETERS_CF(key:string):string;
var ini:TiniFile;
begin
  result:='';
  if not FileExists(MYSQL_MYCNF_PATH()) then exit();
  ini:=TIniFile.Create(MYSQL_MYCNF_PATH());
  result:=ini.ReadString('mysqld',key,'');
  ini.free;
end;
//#############################################################################
function Tlogs.GET_INFO(key:string):string;
var
   str:string;
begin

str:='';
   if FileExists('/etc/artica-postfix/settings/Daemons/'+key) then begin
      str:=trim(ReadFileIntoString('/etc/artica-postfix/settings/Daemons/'+key));
      result:=str;
   end;

end;
//#############################################################################
function Tlogs.INSTALL_STATUS(APP_NAME:string;POURC:integer):string;
var
   ini:TiniFile;
   user:string;
begin
  result:='';

  user:=GET_INFO('LighttpdUserAndGroup');
  if length(user)=0 then user:='www-data:www-data';
  forceDirectories('/usr/share/artica-postfix/ressources/install');
  ini:=TIniFile.Create('/usr/share/artica-postfix/ressources/install/'+APP_NAME+'.ini');
  ini.WriteString('INSTALL','STATUS',IntToStr(POURC));
  ini.free;
  fpsystem('/bin/chmod 777 /usr/share/artica-postfix/ressources/install');
  fpsystem('/bin/chown -R '+user+' /usr/share/artica-postfix/ressources/install');
end;
//#############################################################################
function Tlogs.MYSQL_MYCNF_PATH:string;
begin
  if FileExists('/etc/mysql/my.cnf') then exit('/etc/mysql/my.cnf');
  if FileExists('/etc/my.cnf') then exit('/etc/my.cnf');

end;
//#############################################################################
function Tlogs.MYSQL_INFOS(val:string):string;
var ini:TIniFile;
    str:string;
begin

   if FileExists('/etc/artica-postfix/settings/Mysql/'+val) then begin
      str:=trim(ReadFileIntoString('/etc/artica-postfix/settings/Mysql/'+val));
      result:=trim(str);

      if result='' then begin
           if(val='port') then exit('3306');
      end;
     exit;
   end;

if not FileExists('/etc/artica-postfix/artica-mysql.conf') then exit();
ini:=TIniFile.Create('/etc/artica-postfix/artica-mysql.conf');
result:=ini.ReadString('MYSQL',val,'');
ini.Free;
end;
//#############################################################################
function Tlogs.MYSQL_PORT():string;
var
   mycf_path   :string;
begin
   mycf_path:=MYSQL_MYCNF_PATH();
   result:=MYSQL_READ_CF('port',mycf_path);
   if length(result)=0 then result:='3306';
end;
//#############################################################################



FUNCTION Tlogs.QUERY_SQL(sql:Pchar;database:string):boolean;
var
   sql_results:longint;
   db:Pchar;
   RegExpr     :TRegExpr;
   error:string;
begin

    RegExpr:=TRegExpr.Create;
   if not Connect() then begin
        Debuglogs('QUERY_SQL:: error while connecting');
        exit;
   end;

 if length(trim(database))>0 then begin

    db:=PChar(database+#0);
    sql_results:=mysql_select_db(sock,db);

    
    if sql_results=1 then begin
       error:=mysql_error(sock);

       RegExpr.Expression:='Unknown database';
        if RegExpr.Exec(error) then begin
        
           Debuglogs('QUERY_SQL:: mysql_select_db:: '+ mysql_error(sock) + ' EXEC -> ' + ExtractFilePath(ParamStr(0)) + 'artica-install --mysql-reconfigure-db');
           if ParamStr(1)='--mysql-reconfigure-db' then  exit(false);
           fpsystem(ExtractFilePath(ParamStr(0)) + 'artica-install --mysql-reconfigure-db');
           Disconnect();
           exit(false);
        end;
        
        RegExpr.Expression:='already exists';
        if RegExpr.Exec(error) then begin
           Disconnect();
           exit(true);
        end;

        
        Debuglogs('QUERY_SQL:: mysql_select_db::  mysql_select_db->error number : ' + IntToStr(sql_results));
        Debuglogs('QUERY_SQL:: mysql_select_db:: '+ mysql_error(sock));
        Disconnect();
        exit(false);
    end;
    
end;
    
    
    
    
    
     sql_results:=mysql_query(alloc, sql);
     error:=mysql_error(sock);
     if sql_results=1 then begin
     
     
     
      error:=mysql_error(sock);
        RegExpr.Expression:='Duplicate entry';
        if RegExpr.Exec(error) then begin
           Disconnect();
           exit(true);
        end;
        RegExpr.Expression:='Unknown database';
        if RegExpr.Exec(error) then begin
           Debuglogs('QUERY_SQL::ParamStr(1)=' + ParamStr(1));
           if ParamStr(1)='--mysql-reconfigure-db' then exit;
           fpsystem(ExtractFilePath(ParamStr(0)) + 'artica-install --mysql-reconfigure-db');
           Disconnect();
           exit(false);
        end;

        RegExpr.Expression:='already exists';
        if RegExpr.Exec(error) then begin
           Disconnect();
           exit(true);
        end;
        
        RegExpr.Expression:='Duplicate key name';
        if RegExpr.Exec(error) then begin
           Disconnect();
           exit(true);
        end;

        RegExpr.Expression:='is marked as crashed';
        if RegExpr.Exec(error) then begin
           NOTIFICATION('Warning, mysql claim database "'+database+'" crashed ',' i will try to launch repair databases...'+error,'system');
           fpsystem('/usr/share/artica-postfix/artica-backup --repair-database &');
           Disconnect();
           exit(true);
        end;
     
        Debuglogs('QUERY_SQL:: mysql_query:: mysql_query error number: ' + IntToStr(sql_results));
        Debuglogs('QUERY_SQL:: mysql_query:: mysql_query query.......: '+sql);
        Debuglogs('QUERY_SQL:: mysql_query:: Error returned..........: '+ mysql_error(sock));
        Disconnect();


        exit(false);
     end;

 RegExpr.free;
 if sql_results>0 then Debuglogs('QUERY_SQL:: RETURN TRUE with result ('+ IntToStr(sql_results)+' "'+error+'")');
 Disconnect();
 exit(true);
end;
//#############################################################################
function Tlogs.MYSQL_READ_CF(key:string;mycfpath:string):string;
var ini:TiniFile;
begin
  result:='';
  if not FileExists(mycfpath) then exit();
  ini:=TIniFile.Create(mycfpath);
  result:=ini.ReadString('mysqld',key,'');
  ini.free;
end;
//#############################################################################
procedure Tlogs.Disconnect();
begin
Try
   mysql_close(sock);
except
   Debuglogs('Disconnect() -> Failed to close');
end;
end;
//#############################################################################
function Tlogs.GetFileSizeMo(path:string):longint;
Var
L : File Of byte;
size:longint;
ko:longint;

begin
if not FileExists(path) then begin
   result:=0;
   exit;
end;
   TRY
  Assign (L,path);
  Reset (L);
  size:=FileSize(L);
   Close (L);
  ko:=size div 1024;
  ko:=ko div 1000;
  result:=ko;
  EXCEPT

  end;
end;
//##############################################################################
function Tlogs.EXECUTE_SQL_FILE(filenname:string;database:string;defaultcharset:string):boolean;
    var
    root,commandline,password,port,socket,basedir,mysqlbin,server,sql_results,defchar:string;
    tempfile:string;
begin
  root    :=MYSQL_INFOS('database_admin');
  password:=MYSQL_INFOS('database_password');
  port    :=MYSQL_SERVER_PARAMETERS_CF('port');
  server  :=MYSQL_INFOS('mysql_server');
  socket  :=MYSQL_SERVER_PARAMETERS_CF('socket');
  basedir :=MYSQL_SERVER_PARAMETERS_CF('basedir');
  mysqlbin:=MYSQL_EXEC_BIN_PATH();


  if length(password)>0 then password:=' -p'+password;
  if not fileExists(mysqlbin) then begin
     Debuglogs('EXECUTE_SQL_FILE:: Unable to locate mysql binary (usually in ' + mysqlbin + ')');
     exit(false);
  end;

  if not IF_DATABASE_EXISTS(database) then begin
   if Connect() then begin
       Debuglogs('#############CREATE DATABASE '+database+'#############');
       QUERY_SQL(pChar('CREATE DATABASE '+database+';'),'');
       Disconnect();
   end;
end;

  if not FileExists(filenname) then begin
     Debuglogs('EXECUTE_SQL_FILE:: Unable to stat ' +filenname);
     exit;
  end;

  if length(defaultcharset)>0 then defchar:=' --default-character-set="'+defaultcharset+'"';


   tempfile:=FILE_TEMP();
   commandline:=MYSQL_EXEC_BIN_PATH() + ' --port=' + port + ' --socket=' +socket+ ' --skip-column-names'+defchar+' --database=' + database + ' --silent --xml --user='+ root +password + ' <' + filenname;
   commandline:=commandline + ' >' + tempfile + ' 2>&1';
   Debuglogs(commandline);
   fpsystem(commandline);
   sql_results:=ReadFileIntoString(tempfile);
   DeleteFile(tempfile);
   Debuglogs(sql_results);
   exit(true);
   
end;
//#############################################################################
function Tlogs.EXECUTE_SQL_STRING(query:string):string;
    var
    root,commandline,password,port,socket,basedir,mysqlbin,server,sql_results:string;
    tempfile:string;
begin
  root    :=MYSQL_INFOS('database_admin');
  password:=MYSQL_INFOS('database_password');
  port    :=MYSQL_INFOS('port');
  server  :=MYSQL_INFOS('mysql_server');
  mysqlbin:=MYSQL_EXEC_BIN_PATH();
  if length(port)=0 then port:='3306';
  if length(server)=0 then server:='127.0.0.1';

  if length(password)>0 then password:=' -p'+password;
  if not fileExists(mysqlbin) then begin
     Debuglogs('EXECUTE_SQL_FILE:: Unable to locate mysql binary (usually in ' + mysqlbin + ')');
     exit();
  end;

   tempfile:=FILE_TEMP();
   commandline:=MYSQL_EXEC_BIN_PATH() + ' --host=' + server+' --port=' + port + ' --socket=' +socket+ ' --skip-column-names --silent --xml --user='+ root +password + ' -e "'+query+'"';
   commandline:=commandline + ' >' + tempfile + ' 2>&1';
   Debuglogs(commandline);
   fpsystem(commandline);
   sql_results:=ReadFileIntoString(tempfile);
   DeleteFile(tempfile);
   exit(sql_results);

end;
//#############################################################################
function Tlogs.LIST_MYSQL_DATABASES():TstringList;
var
RegExpr     :TRegExpr;
l:TstringList;
res:TstringList;
i:integer;
tempfile:string;
begin
tempfile:=FILE_TEMP();

l:=TstringList.Create;
result:=l;
l.Add(EXECUTE_SQL_STRING('SHOW DATABASES'));
try
   l.SaveToFile(tempfile);
except
  exit;
end;


l.clear;
l.LoadFromFile(tempfile);
DeleteFile(tempfile);
RegExpr:=TRegExpr.Create;
res:=TstringList.Create;
RegExpr.Expression:='<field name="Database">(.+?)</field>';
for i:=0 to l.Count-1 do begin
    if RegExpr.Exec(l.Strings[i]) then begin
       res.Add(RegExpr.Match[1]);
    end;
end;

RegExpr.free;
l.free;
result:=res;
end;
//#############################################################################


function Tlogs.IF_DATABASE_EXISTS(database_name:string):boolean;
   var sql_results:longint;
begin

   if not Connect() then begin
      Debuglogs('Tlogs.IF_DATABASE_EXISTS():: ERR: failed to connect');
      exit;
   end;
   sql_results:=mysql_select_db(sock,pChar(database_name)) ;
   
   if sql_results=1 then begin
      Debuglogs ('Tlogs.IF_DATABASE_EXISTS():: ERR Couldnt select database "'+ database_name+'"');
      Debuglogs (mysql_error(sock));
      Disconnect();
      exit(false);
   end;
Disconnect();
exit(true);

end;
//#############################################################################
function Tlogs.IF_TABLE_EXISTS(table:string;database:string):boolean;
     var res:longint;
     var sql_results:integer;
     var sqlstring:string;
     var error:string;
begin
result:=false;

  if not Connect() then begin
      Debuglogs('IF_TABLE_EXISTS -> failed to connect');
      exit;
   end;
   sql_results:=mysql_select_db(sock,pChar(database)) ;
   if sql_results=1 then begin
      Debuglogs('IF_TABLE_EXISTS:: ->results: '+IntToStr(sql_results));
      Debuglogs ('IF_TABLE_EXISTS:: Couldnt select database ->'+ database);
      Debuglogs (mysql_error(sock));
      Disconnect();
      exit(false);
   end;
   
   

           sqlstring:='SHOW TABLES LIKE ''' + table + ''';';
            sql_results:=mysql_query(alloc,Pchar(sqlstring));
            
            if sql_results=1 then begin
                error:=mysql_error(sock);
                Debuglogs ('IF_TABLE_EXISTS:: mysql_query:: ' + error+' "' + table +'" return false');
                MYSQL_PARSE_ERROR(error);
                Disconnect();
                exit(false);
            end;
            

            recbuf := mysql_store_result(alloc);
            res:=mysql_num_rows(recbuf);
            if res=0 then begin
               Debuglogs ('IF_TABLE_EXISTS:: mysql_store_result:: '+mysql_error(sock)+' "' + table +'" return false');
               Disconnect();
               exit(false);
            end;
result:=true;
Disconnect();
end;
//#############################################################################
function Tlogs.SYS_EVENTS_ROWNUM():integer;
begin
result:=TABLE_ROWNUM('syslogs','artica_events');
end;
//#############################################################################
function Tlogs.MYSQL_PARSE_ERROR(error:string):boolean;
var
   table:string;
   sql_results:integer;
   RegExpr:TRegExpr;
begin
  result:=false;
  RegExpr:=TRegExpr.Create;
  RegExpr.Expression:='Can''t read dir of ''\.\/(.+?)\/'' \(errno\: 13\)';
  if RegExpr.Exec(error) then begin
         Debuglogs ('MYSQL_PARSE_ERROR:: found system acls error on '+ RegExpr.Match[1]+' try to repair it, please restart your operation');
         fpsystem('/etc/init.d/artica-postfix restart mysql');
         RegExpr.free;
         exit(true);
  end;

end;
//#############################################################################
function Tlogs.TABLE_ROWNUM(tablename:string;database:string):integer;
var
   table:string;
   sql_results:integer;

begin
result:=0;

try
   if not Connect() then begin
      Debuglogs('TABLE_ROWNUM -> failed to connect');
      exit(0);
   end;
except
    Syslogs('TABLE_ROWNUM:: fatal error: connect() function');
    exit;
end;


sql_results:=mysql_select_db(sock,pChar(database)) ;
   if sql_results=1 then begin
      Debuglogs('TABLE_ROWNUM:: ->results: '+IntToStr(sql_results));
      Debuglogs ('TABLE_ROWNUM:: Couldnt select database ->'+database);
      Debuglogs (mysql_error(sock));
      Disconnect();
      exit(0);
   end;

   table:='SELECT count(*) as tcount FROM '+tablename;
   sql_results:=mysql_query(alloc,Pchar(table));
             if sql_results=1 then begin
                Debuglogs ('TABLE_ROWNUM:: ' + mysql_error(sock));
                Disconnect();
                exit;
            end;
    recbuf := mysql_store_result(alloc);

    if RecBuf=Nil then begin
       Debuglogs ('Query returned nil result.');
       Disconnect();
       exit(0);
    end;


    rowbuf := mysql_fetch_row(recbuf);
    if not TryStrToInt(rowbuf[0],result) then begin
       result:=0;
       exit;
    end;
    result:=StrToInt(rowbuf[0]);
   Disconnect();

end;
//#############################################################################
function Tlogs.QUERY_SQL_PARSE_COLUMN(sql:string;database:string;ColumnNumber:integer):Tstringlist;
var
   l:Tstringlist;
begin
l:=TstringList.Create;
result:=l;
recbuf:=QUERY_SQL_STORE(sql,database);

if recbuf=nil then exit;

rowbuf := mysql_fetch_row(recbuf);

 while (rowbuf <>nil) do begin
      l.Add(rowbuf[ColumnNumber]);
      rowbuf := mysql_fetch_row(recbuf);
 end;
 result:=l;
end;
//#############################################################################
function Tlogs.QUERY_SQL_STORE(sql:string;database:string):PMYSQL_RES;
var
   sql_results:integer;
   error:string;
   RegExpr:TRegExpr;
begin
result:=recbuf;

    if not Connect() then begin
      Debuglogs('QUERY_SQL_STORE -> failed to connect');
      exit;
   end;

sql_results:=mysql_select_db(sock,pChar(database)) ;
   if sql_results=1 then begin
      Debuglogs('QUERY_SQL_STORE:: ->results: '+IntToStr(sql_results));
      Debuglogs('QUERY_SQL_STORE:: Couldnt select database ->'+database);
      Debuglogs(mysql_error(sock));
      Disconnect();
      exit();
   end;


sql_results:=mysql_query(alloc,Pchar(sql));
   if sql_results=1 then begin
      error:=mysql_error(sock);
      RegExpr:=TRegExpr.Create;
      Debuglogs('QUERY_SQL_STORE::ERROR: ' + error);
      Debuglogs('QUERY_SQL_STORE:: ' + sql);
      Disconnect();
      RegExpr.Expression:='table.+?\/.+?\/(.+?)\.MYI.+?try to repair it';
      if RegExpr.Exec(error) then MYSQL_REPAIR_TABLE(RegExpr.Match[1],database,error);
      RegExpr.free;
      exit;
   end;


result:=mysql_store_result(alloc);
Disconnect();

end;
//#############################################################################
procedure Tlogs.MYSQL_REPAIR_TABLE(tablename:string;database:string;error:string);
var
   sql:string;
   checktime:string;
   sql_results:integer;
begin

 checktime:='/etc/artica-postfix/mysql.table.corrupted.error.time';

   if FileExists(checktime) then begin
      if FILE_TIME_BETWEEN_MIN(checktime)<15 then begin
         Syslogs('Mysql has reported failed, but time stamp block perform operations');
         exit;
      end;
   end;

    if not Connect() then begin
      Debuglogs('MYSQL_REPAIR_TABLE -> failed to connect');
      exit;
   end;

   sql:='REPAIR TABLE `'+tablename+'`';

   NOTIFICATION('Warning Corrupted mysql table '+tablename,'Mysql claim '+error+', Artica will try to repair it','system');

   DeleteFile(checktime);
   WriteToFile('#',checktime);

   sql_results:=mysql_select_db(sock,pChar(database)) ;
   if sql_results=1 then begin
      Debuglogs('MYSQL_REPAIR_TABLE:: ->results: '+IntToStr(sql_results));
      Debuglogs('MYSQL_REPAIR_TABLE:: Couldnt select database ->'+database);
      Debuglogs(mysql_error(sock));
      Disconnect();
      exit();
   end;

  sql_results:=mysql_query(alloc,Pchar(sql));
   if sql_results=1 then begin
      error:=mysql_error(sock);
      Debuglogs('MYSQL_REPAIR_TABLE:: ' + mysql_error(sock));
      Debuglogs('MYSQL_REPAIR_TABLE:: ' + sql);
   end;

Disconnect();
end;

//#############################################################################




function Tlogs.MYSQL_EXEC_BIN_PATH():string;
begin
   if FileExists('/usr/bin/mysql') then exit('/usr/bin/mysql');
   if FileExists('/usr/local/bin/mysql') then exit('/usr/local/bin/mysql');
end;
//#############################################################################

function Tlogs.WriteToFile(zText:string;TargetPath:string):boolean;
      var
        F : Text;
      BEGIN
      result:=true;
      Debuglogs('Tlogs.WriteToFile:: ' + IntToStr(length(zText)) + ' bytes in ' + TargetPath);
      TRY
      forcedirectories(ExtractFilePath(TargetPath));
       EXCEPT
             Debuglogs('Tlogs.WriteFile():: -> error I/O while creating directory in ' +     TargetPath);

        END;

        TRY
           Assign (F,TargetPath);
           Rewrite (F);
           Write(F,zText);
           Close(F);
          exit(true);
        EXCEPT
             Debuglogs('Tlogs.WriteFile():: -> error I/O while Writing in ' +     TargetPath);

        END;
        
exit(false);
      END;
//#############################################################################
function Tlogs.ReadFromFile(TargetPath:string):string;
         const
            CR = #$0d;
            LF = #$0a;
            CRLF = CR + LF;
var
  F:textfile;
  teststr: string;
  s:string;
begin
  if not FileExists(TargetPath) then exit;
  assignfile(F,TargetPath);
 reset(F);
          repeat
                readln(F,s);
                teststr:=teststr+s+CRLF;
          until eof(F);
 closefile(F);
 result:=teststr;
end;
//#############################################################################
procedure Tlogs.WriteInstallLogs(text:string);
var
zdate,dir,filew,mypid,CurrentInstallProduct:string;
myFile : TextFile;
begin
mypid:=intTostr(fpgetpid);

CurrentInstallProduct:=GET_INFO('CurrentInstallProduct');
if length(CurrentInstallProduct)=0 then exit;
zdate:=DateTimeNowSQL();
dir:='/usr/share/artica-postfix/ressources/logs/'+CurrentInstallProduct;
filew:=dir+'/install.log';
ForceDirectories(dir);

text:=zdate + ' ['+ mypid +']:'+text;

        TRY
           AssignFile(myFile, filew);
           if FileExists(filew) then Append(myFile);
           if not FileExists(filew) then ReWrite(myFile);
            WriteLn(myFile, text);
           CloseFile(myFile);
        EXCEPT

        END;


end;
//#############################################################################
procedure Tlogs.LogGeneric(text:string;path:string);
var
zdate,mypid:string;
myFile : TextFile;
begin
forcedirectories(ExtractFilePath(path));
mypid:=intTostr(fpgetpid);
zdate:=DateTimeNowSQL();

text:=zdate + ' ['+ mypid +']:'+text;
Debuglogs(text);

        TRY
           AssignFile(myFile, path);
           if FileExists(path) then Append(myFile);
           if not FileExists(path) then ReWrite(myFile);
            WriteLn(myFile, text);
           CloseFile(myFile);
        EXCEPT

        END;


end;
//#############################################################################

procedure Tlogs.DeleteFile(TargetPath:string);
Var F : Text;

begin
  if not FileExists(TargetPath) then exit;
  TRY
    Assign (F,TargetPath);
    Erase (f);
  EXCEPT
     Debuglogs('Delete():: -> error I/O in ' +     TargetPath);
  end;
end;
//#############################################################################
procedure Tlogs.set_INFOS(key:string;val:string);
var ini:TIniFile;
begin
try
ini:=TIniFile.Create('/etc/artica-postfix/artica-postfix.conf');
ini.WriteString('INFOS',key,val);
finally
ini.Free;
end;
end;
//#############################################################################
procedure Tlogs.NOTIFICATION(subject:string;content:string;context:string);
begin
EVENTS(subject,content,context,'');


end;
//#############################################################################
function Tlogs.DateTimeDiff(Start, Stop : TDateTime) : int64;
var TimeStamp : TTimeStamp;
begin
  TimeStamp := DateTimeToTimeStamp(Stop - Start);
  Dec(TimeStamp.Date, TTimeStamp(DateTimeToTimeStamp(0)).Date);
  Result := (TimeStamp.Date*24*60*60)+(TimeStamp.Time div 1000);
end;
//#############################################################################
function Tlogs.QUERY_SQL_BIN(database:string;fileName:string):boolean;
    var
       root,commandline,password,port,
       mysqlbin,FileTemp:string;

begin
  root    :=MYSQL_INFOS('database_admin') +#0;
  password:=MYSQL_INFOS('database_password') +#0;
  port    :=MYSQL_SERVER_PARAMETERS_CF('port') +#0;
  result:=false;
  mysqlbin:='';
  FileTemp:=FILE_TEMP();
  if length(password)>0 then password:=' -p'+password;
  if not fileExists(mysqlbin) then begin
     Debuglogs('QUERY_SQL_BIN::Unable to stat mysql client');
     exit(false);
  end;
  commandline:=mysqlbin + ' --port=' + port + ' --database=' + database;
  commandline:=commandline + ' --skip-column-names --silent --xml --user='+ root +password + ' <'+FileName;
  commandline:=commandline + ' >' + FileTemp+ ' 2>&1';

  Debuglogs('QUERY_SQL_BIN::'+commandline);
  fpsystem(commandline);
end;
//#############################################################################
function Tlogs.INSTALL_PROGRESS(APP_NAME:string;info:string):string;
var ini:TiniFile;
begin
  result:='';
  forceDirectories('/usr/share/artica-postfix/ressources/install');
  try
     ini:=TIniFile.Create('/usr/share/artica-postfix/ressources/install/'+APP_NAME+'.ini');
     ini.WriteString('INSTALL','INFO',info);
  except
   writeln('INSTALL_STATUS():: FATAL ERROR STAT /usr/share/artica-postfix/ressources/install/'+APP_NAME+'.ini');
   exit;
  end;
  ini.free;
end;
//#############################################################################
function Tlogs.FILE_TIME_BETWEEN_MIN(filepath:string):LongInt;
var
   fa   : Longint;
   S    : TDateTime;
   maint:TDateTime;
begin
if not FileExists(filepath) then exit(0);
    fa:=FileAge(filepath);
    maint:=Now;
    S:=FileDateTodateTime(fa);
    result:=MinutesBetween(maint,S);
end;
//##############################################################################

function Tlogs.copyfile(srcfn, destfn:string):boolean;
const bufs= 65536;
var buf:pointer;
    f1,f2,bytesread:longint;
begin
  result:=false;
  if not FileExists(srcfn)then exit;
  getmem(buf,bufs);
  f2:=FileCreate(destfn);
  if f2<=0 then exit;
  f1:=FileOpen(srcfn,fmOpenRead);
  if f1<=0 then begin FileClose(f2); exit end;
  repeat
    bytesread:=FileRead(f1,buf^,bufs);
    if bytesread>0 then bytesread:=FileWrite(f2,buf^,bytesread);
  until bytesread<>bufs;
  FileClose(f1); FileClose(f2);
  freemem(buf,bufs);
  result:=bytesread<>-1;
end;



end.

