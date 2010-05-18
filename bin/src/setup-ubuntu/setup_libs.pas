unit setup_libs;
{$MODE DELPHI}
//{$mode objfpc}{$H+}
{$LONGSTRINGS ON}

interface

uses
  Classes, SysUtils,strutils,RegExpr in 'RegExpr.pas',unix,IniFiles,md5,DATEUTILS;
type
  TStringDynArray = array of string;
  type
  tlibs=class


private
       index_file:string;
       local_folder:string;
       CACHE_KERNEL_VERSION:string;
       DirListFiles:TstringList;
       function   GET_HTTP_PROXY:string;
       function   LOCATE_CURL():string;
       function   LOCATE_MAKE():string;
       function   LOCATE_GCC():string;
       procedure  SET_HTTP_PROXY(proxy_string:string);
       function   REMOVE_HTTP_PROXY:string;
       function   DirDir(FilePath: string):TstringList;
       function   ReadFileIntoString(path:string):string;
       function   Explode(const Separator, S: string; Limit: Integer = 0):TStringDynArray;
       function   CHECK_PERL_MODULES_SECOND(ModulesToCheck:string):boolean;
       function   FILE_TEMP():string;
       function   MD5FromString(value:string):string;
       function   DateTimeNowSQL():string;
       function   WriteToFile(zText:string;TargetPath:string):boolean;
       procedure  PASSWD_INFO();
       function   MYSQL_INFOS(val:string):string;
       function   MYSQL_EXEC_BIN_PATH():string;
       procedure  ZARAFA_INSTALL_MENU();
       procedure  ZARAFA_INSTALL_PERFORM();

public
      constructor Create();
      procedure Free;
      function WGET_DOWNLOAD_FILE(uri:string;file_path:string):boolean;
      function COMPILE_GENERIC_APPS(package_name:string):string;
      function ARTICA_VERSION():string;
      function COMMANDLINE_PARAMETERS(FoundWhatPattern:string):boolean;
      function LOCATE_PERL_BIN():string;
      function PERL_INCFolders():TstringList;
      procedure InstallArtica();
      function RPM_is_application_installed(appname:string):boolean;
      function INTRODUCTION(base:string;postfix:string;cyrus:string;samba:string;squid:string;nfs:string='';pdns:string=''):string;
      function get_LDAP(key:string):string;
      procedure set_LDAP(key:string;val:string);
      function get_LDAP_ADMIN():string;
      function get_LDAP_PASSWORD():string;
      function get_LDAP_suffix():string;
      function SLAPD_CONF_PATH():string;
      function PERL_GENERIC_INSTALL(indexWeb:string;ModulesToCheck:string;force:boolean=false;echoyes:boolean=false):boolean;
      function ReadFromFile(TargetPath:string):string;
      function COMPILE_VERSION(package_name:string):integer;
      function COMPILE_VERSION_STRING(package_name:string):string;
      function FILE_TIME_BETWEEN_MIN(filepath:string):LongInt;
      function FileSize_bytes(path:string):longint;
      function CHECK_INDEX_FILE():string;
      function CHECK_PERL_MODULES(ModulesToCheck:string):string;
      procedure PERL_GENERIC_DISABLE_TESTS(source:string);
      procedure EXPORT_PATH();
      procedure CHANGE_MAKE_CONFIG(key:string;value:string;filepath:string);
      function  EXECUTE_SQL_FILE(filenname:string;database:string;defaultcharset:string):boolean;
      function  IF_DATABASE_EXISTS(databasename:string):boolean;
      function  QUERY_SQL(sql:string;databasename:string):boolean;
      function  KERNEL_SOURCES_PATH():string;
      function  KERNEL_VERSION():string;
      function  CheckReposKernel():string;
      function  GET_FIRMWARE_PATH():string;
      function  ExtractLocalPackage(filepath:string):string;
      function  VersionToInteger(version:string):integer;
END;

implementation

constructor tlibs.Create();
begin
index_file:='http://www.artica.fr/auto.update.php';
local_folder:='';
end;
//#########################################################################################
procedure tlibs.Free();
begin

end;
//#########################################################################################


procedure tlibs.EXPORT_PATH();
var
l:TstringList;
RegExpr:TRegExpr;
found:boolean;
i:integer;
begin
found:=false;
l:=TstringList.Create;
if FileExists('/root/.profile') then begin
 RegExpr:=TRegExpr.Create;
 RegExpr.Expression:='^PATH=';
 l.LoadFromFile('/root/.profile');
 for i:=0 to l.Count-1 do begin
     if RegExpr.exec(l.Strings[i]) then begin
        found:=true;
        break;
     end;
 end;
end;

if not found then begin
   writeln('Exporting path in /root/.profile...');
   l.Add('PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/bin/X11');
   l.Add('export PATH');
   try
      l.SaveToFile('/root/.profile');
   except
     writeln('Exporting path in /root/.profile... Error while writing file..');
    exit;
    end;
end;
l.free;
RegExpr.free;
end;
//#########################################################################################

function tlibs.KERNEL_SOURCES_PATH():string;
var
   tmpstr:string;
   kernelversion:string;
begin
kernelversion:=KERNEL_VERSION();
if DirectoryExists('/usr/src/kernels/'+kernelversion+'-i686') then exit('/usr/src/kernels/'+kernelversion+'-i686');
if DirectoryExists('/usr/src/kernels/'+kernelversion+'-i586') then exit('/usr/src/kernels/'+kernelversion+'-i586');
if DirectoryExists('/usr/src/kernels/'+kernelversion+'-i386') then exit('/usr/src/kernels/'+kernelversion+'-i386');
if DirectoryExists('/usr/src/linux-headers-'+kernelversion) then exit('/usr/src/kernels/'+kernelversion);
writeln('checking /usr/src/linux-headers-'+kernelversion+' failed');
if DirectoryExists('/lib/modules/'+kernelversion+'/build') then exit('/lib/modules/'+kernelversion+'/build');
writeln('checking /lib/modules/'+kernelversion+'/build failed');
end;
//##############################################################################
function tlibs.KERNEL_VERSION():string;
var
   tmpstr:string;
   kernelversion:string;
begin
if length(CACHE_KERNEL_VERSION)>0 then exit(CACHE_KERNEL_VERSION);
tmpstr:=FILE_TEMP();
fpsystem('/bin/uname -r >'+tmpstr+' 2>&1');
kernelversion:=trim(ReadFileIntoString(tmpstr));
if FileExists(tmpstr) then fpsystem('/bin/rm '+tmpstr+' >/dev/null 2>&1');
if length(kernelversion)=0 then begin
   writeln('KERNEL_VERSION:: Unable to get kernel version');
   exit;
end;

writeln('Kernel version is '+kernelversion);
result:=kernelversion;
CACHE_KERNEL_VERSION:=kernelversion;

end;
//##############################################################################
function tlibs.CheckReposKernel():string;
var
   tmpstr:string;
   kernelversion:string;
begin

kernelversion:=KERNEL_VERSION();
writeln('Checking kernel sources for '+kernelversion);
if length(kernelversion)=0 then begin
   writeln('Unable to get kernel version');
   exit;
end;

if FIleExists('/usr/bin/yum') then begin
   fpsystem('/usr/bin/yum -y install kernel-devel-'+kernelversion);
   exit;
end;

if FIleExists('/usr/bin/apt-get') then begin
     fpsystem('DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get -o Dpkg::Options::="--force-confnew" install linux-headers-'+kernelversion);
     exit;
end;

writeln('HUGH !!! no repos ???!! :(');

end;
//##############################################################################
function tlibs.GET_FIRMWARE_PATH():string;
begin
if DirectoryExists('/lib/firmware') then exit('/lib/firmware');
if DirectoryExists('/usr/lib/hotplug/firmware') then exit('/usr/lib/hotplug/firmware');
if DirectoryExists('/lib/hotplug/firmware') then exit('/lib/hotplug/firmware');
end;

function tlibs.FILE_TIME_BETWEEN_MIN(filepath:string):LongInt;
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
procedure tlibs.CHANGE_MAKE_CONFIG(key:string;value:string;filepath:string);
var
   RegExpr:TRegExpr;
   l:Tstringlist;
   i:integer;
   found:boolean;
 begin


   RegExpr:=TRegExpr.Create;
   RegExpr.Expression:='^'+key;
   found:=false;
   l:=Tstringlist.Create;
   try
   l.LoadFromFile(filepath);
   except
   writeln('FATAL ERROR WHILE READING:'+filepath);
   exit;
   end;

   for i:=0 to l.Count-1 do begin

       if RegExpr.Exec(l.Strings[i]) then begin
          l.Strings[i]:=key+'='+value;
          found:=true;
          break;
       end;
   end;

   if found then begin
      try
         l.SaveToFile(filepath);
      except
        writeln('FATAL ERROR WHILE WRITING:'+filepath);
        exit;
      end;
   end;


   l.free;
   RegExpr.free;



 end;
//##############################################################################


function tlibs.WGET_DOWNLOAD_FILE(uri:string;file_path:string):boolean;
var
   RegExpr:TRegExpr;
   ProxyString:string;
   ProxyCommand:string;
   ProxyUser:string;
   ProxyPassword:string;
   ProxyName:string;
   commandline_artica:string;
   command_line_curl:string;
   command_line_wget:string;
   localhost:boolean;
   ssl:boolean;
 begin
   localhost:=false;
   command_line_curl:='';
   RegExpr:=TRegExpr.Create;
   ProxyString:=GET_HTTP_PROXY();
   ProxyString:=AnsiReplaceStr(ProxyString,'"','');
   ProxyString:=AnsiReplaceStr(ProxyString,'http://','');
   ProxyString:=AnsiReplaceStr(ProxyString,'https://','');

   ssl:=false;
   command_line_curl:= command_line_curl + ' --progress-bar --output ' + file_path + ' "' + uri+'"';

   RegExpr.Expression:='^https:.+';
   if RegExpr.Exec(uri) then ssl:=True;


   RegExpr.Expression:='http://127\.0\.0\.1';
   if RegExpr.Exec(uri) then localhost:=True;

 if not localhost then begin
   if length(ProxyString)>0 then begin
       RegExpr.Expression:='(.+?):(.+?)@(.+)';
       if RegExpr.Exec(ProxyString) then begin
            ProxyUser:=RegExpr.Match[1];
            ProxyPassword:=RegExpr.Match[2];
            ProxyName:=RegExpr.Match[3];
       end;
       RegExpr.Expression:='(.+?)@(.+)';
       if RegExpr.Exec(ProxyString) then begin
           ProxyUser:=RegExpr.Match[1];
           ProxyName:=RegExpr.Match[3];
       end;
   end;

   if length(ProxyName)=0 then ProxyName:=ProxyString;
 end;

   if length(ProxyName)>0 then begin
      writeln('Using HTTP proxy: "'+ ProxyName+'"');
      ProxyCommand:=' --proxy ' +  ProxyName;
      if length(ProxyUser)>0 then begin
         writeln('Proxy user: '+ ProxyUser);
         if length(ProxyPassword)>0 then begin
            writeln('Proxy password: ******');
            ProxyCommand:=' --proxy ' +  ProxyName + ' --proxy-user ' + ProxyUser + ':' + ProxyPassword;
         end else begin
            ProxyCommand:=' --proxy ' +  ProxyName + ' --proxy-user ' + ProxyUser;
         end;
      end;
     command_line_curl:=ProxyCommand + ' --progress-bar --output ' + file_path + ' "' + uri+'"';

   end;


   command_line_wget:=uri + '  -q --output-document=' + file_path;


   if FileExists(LOCATE_CURL()) then begin
         if ssl then command_line_curl:=command_line_curl+ ' --insecure';
         command_line_curl:=LOCATE_CURL() + command_line_curl;
         fpsystem(command_line_curl);
         result:=true;
         exit;
   end;



  if FileExists('/usr/bin/wget') then begin
     if length(ProxyName)>0 then begin
         SET_HTTP_PROXY(GET_HTTP_PROXY());
     end;
     command_line_wget:='/usr/bin/wget ' + command_line_wget;
     if ssl then command_line_wget:=command_line_wget + ' --no-check-certificate';
     fpsystem(command_line_wget);
     result:=true;
     exit;
  end;



     if length(ProxyName)>0 then begin
        ProxyCommand:=' --proxy=on --proxy-name=' + ProxyName;
        writeln('Proxy: '+ ProxyName);
     end;

     if length(ProxyUser)>0 then begin
        ProxyCommand:=' --proxy=on --proxy-name=' + ProxyName  + ' --proxy-user=' + ProxyUser;
         writeln('Proxy Username: '+ ProxyUser);
     end;


     if length(ProxyPassword)>0 then begin
        ProxyCommand:=' --proxy=on --proxy-name=' + ProxyName  + ' --proxy-user=' + ProxyUser + ' --proxy-passwd=' + ProxyPassword;
         writeln('Proxy Password: *******');
     end;

     commandline_artica:=ExtractFilePath(ParamStr(0)) + 'artica-get  '+ uri + ' ' + ProxyCommand + ' -q --output-document=' + file_path;
     fpsystem(commandline_artica);
     result:=true;





end;
//##############################################################################
function  tlibs.GET_HTTP_PROXY:string;
var
   l:TStringList;
   i:integer;
   RegExpr:TRegExpr;

 begin
  if not FileExists('/etc/environment') then begin
     l:=TStringList.Create;
     l.Add('LANG="en_US.UTF-8"');
     l.SaveToFile('/etc/environment');
     exit;
  end;


  l:=TStringList.Create;
  RegExpr:=TRegExpr.Create;
  RegExpr.Expression:='(http_proxy|HTTP_PROXY)=(.+)';

  l.LoadFromFile('/etc/environment');
  for i:=0 to l.Count -1 do begin
      if RegExpr.Exec(l.Strings[i]) then result:=RegExpr.Match[2];

  end;
 l.FRee;
 RegExpr.free;

end;
//##############################################################################
function tlibs.LOCATE_CURL():string;
begin
   if FileExists('/usr/local/bin/curl') then exit('/usr/local/bin/curl');
   if FileExists('/usr/bin/curl') then exit('/usr/bin/curl');
   if FileExists('/opt/artica/bin/curl') then exit('/opt/artica/bin/curl');
end;
 //#############################################################################
function tlibs.CHECK_PERL_MODULES_SECOND(ModulesToCheck:string):boolean;
var
   cmd:string;
   l:TstringList;
   RegExpr:TRegExpr;
   tmpstr:string;
begin
result:=false;
tmpstr:=FILE_TEMP();
if not FileExists(LOCATE_PERL_BIN()) then exit;
cmd:=LOCATE_PERL_BIN()+' -M'+ModulesToCheck+' -e ''print "$'+ModulesToCheck+'::VERSION\n"''';
fpsystem(cmd + ' >'+tmpstr+' 2>&1');
 l:=TstringList.Create;
 RegExpr:=TRegExpr.Create;
 if not FileExists(tmpstr) then exit;
 l.LoadFromFile(tmpstr);
 fpsystem('/bin/rm -f '+tmpstr);
 RegExpr.Expression:='([0-9\.]+)';
 if RegExpr.Exec(l.Strings[0]) then begin
    if trim(RegExpr.Match[1])='.' then begin
          writeln('Failed to check ' + ModulesToCheck);
          result:=false;
          exit;
    end;
    result:=true;
 end else begin
     writeln(cmd);
     writeln('Failed to check ' + ModulesToCheck);
 end;
 L.free;
 RegExpr.Free;
end;

//##############################################################################
function tlibs.MD5FromString(value:string):string;
var
Digest:TMD5Digest;
begin
Digest:=MD5String(value);
exit(MD5Print(Digest));
end;
//##############################################################################
function tlibs.FILE_TEMP():string;
begin
result:='/opt/artica/tmp/'+ MD5FromString(DateTimeNowSQL()+IntToStr(random(2548)));
end;
//##############################################################################
function tlibs.DateTimeNowSQL():string;
begin
   result:=FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
end;
 
 procedure  tlibs.SET_HTTP_PROXY(proxy_string:string);
var
   l:TStringList;
   i:integer;
   RegExpr:TRegExpr;
   found_proxy:boolean;

 begin
  if not FileExists('/etc/environment') then begin
     writeln('Unable to find /etc/environment');
     exit;
  end;
 REMOVE_HTTP_PROXY();

  l:=TStringList.Create;
  l.LoadFromFile('/etc/environment');
  l.Add('http_proxy="'+ proxy_string + '"');
  l.SaveToFile('/etc/environment');
  writeln('export http_proxy="'+ proxy_string + '" --> done');
  fpsystem('export http_proxy="'+ proxy_string + '"');
  writeln('env http_proxy='+ proxy_string + '" --> done');
  fpsystem('env http_proxy='+ proxy_string);


  if FileExists('/etc/wgetrc') then begin
      RegExpr:=TRegExpr.Create;
      RegExpr.Expression:='^http_proxy(.+)';
      l.LoadFromFile('/etc/wgetrc');
      For i:=0 to l.Count-1 do begin
          if RegExpr.Exec(l.Strings[i]) then begin
             found_proxy:=true;
             l.Strings[i]:='http_proxy = ' + proxy_string;
             l.SaveToFile('/etc/wgetrc');
             break;
          end;
      end;

     if found_proxy=false then begin
          l.Add('http_proxy = ' + proxy_string);
          l.SaveToFile('/etc/wgetrc');
     end;

  end;

   l.free;

end;
//##############################################################################
function  tlibs.REMOVE_HTTP_PROXY:string;
var
   l:TStringList;
   i:integer;
   RegExpr:TRegExpr;

 begin
  if not FileExists('/etc/environment') then begin
     writeln('Unable to find /etc/environment');
     exit;
  end;


  l:=TStringList.Create;
  RegExpr:=TRegExpr.Create;
  RegExpr.Expression:='(http_proxy|HTTP_PROXY)=(.+)';

  l.LoadFromFile('/etc/environment');
  for i:=0 to l.Count -1 do begin
      if RegExpr.Exec(l.Strings[i]) then begin
          l.Delete(i);
          break;
      end;
  end;
  l.SaveToFile('/etc/environment');


  if FileExists('/etc/wgetrc') then begin
      RegExpr:=TRegExpr.Create;
      RegExpr.Expression:='^http_proxy(.+)';
      l.LoadFromFile('/etc/wgetrc');
      For i:=0 to l.Count-1 do begin
          if RegExpr.Exec(l.Strings[i]) then begin
             l.Strings[i]:='#' + l.Strings[i];
             l.SaveToFile('/etc/wgetrc');
             break;
          end;
      end;
  end;


  l.free;
  RegExpr.free;
  result:='';
end;
//##############################################################################
function tlibs.ARTICA_VERSION():string;
var
   l:string;
   F:TstringList;

begin
   l:='/usr/share/artica-postfix/VERSION';
   if not FileExists(l) then exit('0.00');
   F:=TstringList.Create;
   F.LoadFromFile(l);
   result:=trim(F.Text);
   F.Free;
end;
//#############################################################################
function tlibs.COMPILE_GENERIC_APPS(package_name:string):string;
var
   gcc_path,make_path,wget_path,compile_source:string;
   auto:TiniFile;
   tmp:string;
   FILE_TEMP:TstringList;
   FILE_EXT:string;
   package_version:string;
   DECOMPRESS_OPT:string;
   www_prefix:string;
   uri_download:string;
   target_file:string;
   RegExpr:TRegExpr;
   int_version                          :integer;
   FileNamePrefix                       :string;
   local_folder                         :string;
   autoupdate_path                      :string;
   remote_uri                           :string;
   index_file                           :string;
   i                                    :integer;
   updeconf                             :TIniFile;
   label                                 myEnd;




begin
    if not FileExists('/etc/artica-postfix/artica-update.conf') then fpsystem('/bin/touch /etc/artica-postfix/artica-update.conf');
    if FileExists('/etc/artica-postfix/artica-update.conf') then begin
        updeconf:=TiniFile.Create('/etc/artica-postfix/artica-update.conf');
        index_file:=updeconf.ReadString('AUTOUPDATE','uri','http://www.artica.fr/auto.update.php');
        remote_uri:=EXtractFilePath(index_file)+'download';
     end else begin
           local_folder:='';
           remote_uri:='http://www.artica.fr/download';
           index_file:='http://www.artica.fr/auto.update.php';
     end;


     if length(trim(remote_uri))=0 then remote_uri:='http://www.artica.fr/download';
     if length(trim(index_file))=0 then index_file:='http://www.artica.fr/auto.update.php';



     updeconf.free;

    FILE_TEMP:=TStringList.Create;
    RegExpr:=TRegExpr.Create;

    fpsystem('cd ' + ExtractFilePath(ParamStr(0)));

    gcc_path:=LOCATE_GCC();
    make_path:=LOCATE_MAKE();
    wget_path:='/usr/bin/wget';
    forcedirectories('/tmp/artica/install/sources');
    if FileExists('/tmp/artica/install/sources/' + package_name) then begin
       writeln('Cleaning /tmp/artica/install/sources folder...');
       fpsystem('/bin/rm -rf /tmp/artica/install/sources/' + package_name);
    end;
    
    


    writeln('Checking required compilation tools as gcc and make');
    if length(make_path)=0 then begin
        writeln('ERROR:: unable to locate make...');
        goto MyEnd;
    end;

    if length(gcc_path)=0 then begin
        writeln('ERROR:: unable to locate gcc...');
        goto MyEnd;
    end;

    writeln('Checking last supported version of ' + package_name + ' from ' +index_file);

    if local_folder='' then begin
       autoupdate_path:=CHECK_INDEX_FILE();
    end else begin
        autoupdate_path:=local_folder + '/autoupdate.ini';
        if not FileExists(autoupdate_path) then begin
             writeln('unable to stat ' + autoupdate_path);
             exit;
        end;
    end;
    auto:=TIniFile.Create(autoupdate_path);

    FILE_EXT:=auto.ReadString('NEXT',package_name + '_ext','tar.gz');
    www_prefix:=auto.ReadString('NEXT',package_name + '_prefix','');
    FileNamePrefix:=auto.ReadString('NEXT',package_name + '_filename_prefix',package_name  + '-');



    package_version:=auto.ReadString('NEXT',package_name,'');
    target_file:=FileNamePrefix + package_version + '.' + FILE_EXT;



    auto.Free;

    if local_folder='' then begin
       uri_download:=remote_uri + '/' + target_file;
       if length(www_prefix)>0 then uri_download:=remote_uri+'/' + www_prefix + '/' + target_file;
    end else begin
       uri_download:=local_folder + '/' + target_file;
       if length(www_prefix)>0 then uri_download:=local_folder + '/' + www_prefix + '/' + target_file;
    end;

    uri_download:=AnsiReplaceText(uri_download,'/auto.update.php/','/');

    writeln('');
    writeln('');
    writeln('#################################################################################');
    writeln(chr(9)+'local_folder.........:"' +local_folder+'"');
    writeln(chr(9)+'www_prefix...........:"' +www_prefix+'"');
    writeln(chr(9)+'version..............:"' +package_version+'"');
    writeln(chr(9)+'extension............:"' +FILE_EXT+'" ');
    writeln(chr(9)+'prefix...............:"' +www_prefix+'"');
    writeln(chr(9)+'FileName Prefix......:"' +FileNamePrefix+'"');
    writeln(chr(9)+'Target file..........:"' +target_file+'"');
    writeln(chr(9)+'uri..................:"' +uri_download + '"');





    if length(package_version)=0 then begin
         writeln('http source problem [NEXT]\' + package_name +  ' is null...aborting');
         exit;
    end;

    writeln('#################################################################################');
    writeln('');
    writeln('');

    if FILE_EXT='tar.bz2' then DECOMPRESS_OPT:='xjf' else DECOMPRESS_OPT:='xzf';
    if FILE_EXT='tar' then DECOMPRESS_OPT:='xf';
    if FILE_EXT='zip' then DECOMPRESS_OPT:='';

     if DirectoryExists('/tmp/artica/install/sources/' + package_name) then fpsystem('/bin -rm -rf /tmp/artica/install/sources/' + package_name);
     writeln('Creating directory ' + '/tmp/artica/install/sources/' + package_name);
     forcedirectories('/tmp/artica/install/sources/' + package_name);

    writeln('');
    writeln('');
    writeln('Get: ' + uri_download);

    if local_folder='' then begin
       WGET_DOWNLOAD_FILE(uri_download,'/tmp/artica/install/sources/' + target_file);
    end else begin
        fpsystem('/bin/cp -fv ' + uri_download + ' ' +  '/tmp/artica/install/sources/' + target_file);
    end;
    writeln('');
    writeln('');
    if not FileExists('/tmp/artica/install/sources/' + target_file) then begin
        writeln('Unable to stat /tmp/artica/install/sources/' + target_file);
        exit;
    end;

    if FILE_EXT='zip' then begin
       writeln('Zip package, return file path...');
       result:='/tmp/artica/install/sources/' + target_file;
       exit;
    end;

    writeln('Uncompress the package...');
    writeln('tar -' + DECOMPRESS_OPT + ' /tmp/artica/install/sources/' + target_file + ' -C /tmp/artica/install/sources/' + package_name);
    fpsystem('tar -' + DECOMPRESS_OPT + ' /tmp/artica/install/sources/' + target_file + ' -C /tmp/artica/install/sources/' + package_name);
    
    fpsystem('/bin/rm ' + '/tmp/artica/install/sources/' + target_file);
    
    DirDir('/tmp/artica/install/sources/' + package_name);

    if DirListFiles.Count=0 then begin
      writeln('ERROR:: Bad repository format !!!');
       fpsystem('/bin/rm -rf /tmp/artica/install/sources/'+package_name);
       fpsystem('/bin/rm /tmp/artica/install/sources/'+target_file);
       goto myEnd;
    end;
    
    
    compile_source:='/tmp/artica/install/sources/' + package_name + '/' + DirListFiles.Strings[0];
    writeln('SUCCESS: "' + compile_source + '"');
    result:=compile_source;
 goto myEnd;

myEnd:
    FILE_TEMP.free;


end;
//#############################################################################################
function tlibs.ExtractLocalPackage(filepath:string):string;
begin

   forceDirectories('/tmp/artica/install/sources/' + ExtractFileName(filepath));
    writeln('Uncompress the package...');
    writeln('tar -xf ' + filepath + ' -C /tmp/artica/install/sources/' + ExtractFileName(filepath));
    fpsystem('tar -xf ' + filepath + ' -C /tmp/artica/install/sources/' + ExtractFileName(filepath));

DirDir('/tmp/artica/install/sources/' + ExtractFileName(filepath));
result:='/tmp/artica/install/sources/' + ExtractFileName(filepath);
 if DirListFiles.Count>0 then result:='/tmp/artica/install/sources/' + ExtractFileName(filepath) + '/' + DirListFiles.Strings[0];
end;
//#############################################################################################

function tlibs.CHECK_INDEX_FILE():string;

var
autoupdate_path:string;
fsize:integer;
auto:TiniFile;
articaversion:string;
begin
result:='';
autoupdate_path:='/tmp/artica/install/sources/autoupdate.ini';

    if FileExists(autoupdate_path) then begin
         if FileSize_bytes(autoupdate_path)>5000 then begin
              if FILE_TIME_BETWEEN_MIN(autoupdate_path)<10 then begin
                 exit(autoupdate_path);
              end;
         end;
    end;
    writeln('');
    writeln('#################################################################################');
    if local_folder='' then WGET_DOWNLOAD_FILE(index_file,autoupdate_path);

    if FileExists(autoupdate_path) then begin
        fsize:=FileSize_bytes(autoupdate_path);
        writeln('Checking ' + autoupdate_path + ' (' +IntToStr(fsize) + ' bytes length)');
        if fsize<5000 then begin
              writeln('warning ' + autoupdate_path + ' seems to be corrupted, are you using a proxy ? or is the Internet connection is available ?');
              writeln('');
              writeln('#################################################################################');
              writeln('');
              exit(autoupdate_path);
        end;

        auto:=TiniFile.Create(autoupdate_path);
        articaversion:=auto.ReadString('NEXT','artica','');
        if length(articaversion)=0 then begin
             writeln('warning No artica version in ' + autoupdate_path + ' seems to be corrupted, are you using a proxy ? or is the Internet connection is available ?');
             writeln('');
             writeln('#################################################################################');
             writeln('');
             exit(autoupdate_path);
        end;

        writeln('Repository server store artica version ' +articaversion);
        writeln('');
        writeln('#################################################################################');
        writeln('');
        exit(autoupdate_path);
    end;

end;

//#############################################################################################


function tlibs.COMPILE_VERSION_STRING(package_name:string):string;
var
   gcc_path,make_path,wget_path,compile_source:string;
   auto:TiniFile;
   tmp:string;
   FILE_TEMP:TstringList;
   FILE_EXT:string;
   package_version:string;
   DECOMPRESS_OPT:string;
   www_prefix:string;
   uri_download:string;
   target_file:string;
   RegExpr:TRegExpr;
   int_version                          :integer;
   FileNamePrefix                       :string;
   local_folder                         :string;
   autoupdate_path                      :string;
   remote_uri                           :string;
   index_file                           :string;
   i                                    :integer;
begin




    local_folder:='';
    remote_uri:='http://www.artica.fr/download';

    FILE_TEMP:=TStringList.Create;
    RegExpr:=TRegExpr.Create;

    fpsystem('cd ' + ExtractFilePath(ParamStr(0)));

    gcc_path:=LOCATE_GCC();
    make_path:=LOCATE_MAKE();
    wget_path:='/usr/bin/wget';
    forcedirectories('/tmp/artica/install/sources');
    if FileExists('/tmp/artica/install/sources/' + package_name) then begin
       writeln('Cleaning /tmp/artica/install/sources folder...');
       fpsystem('/bin/rm -rf /tmp/artica/install/sources/' + package_name);
    end;




    writeln('Checking required compilation tools as gcc and make');
    if length(make_path)=0 then begin
        writeln('ERROR:: unable to locate make...');
       exit('0');
    end;

    if length(gcc_path)=0 then begin
        writeln('ERROR:: unable to locate gcc...');
        exit('0');
    end;

   writeln('Checking last supported version of ' + package_name);




    if local_folder='' then begin
       autoupdate_path:=CHECK_INDEX_FILE();
    end else begin
        autoupdate_path:=local_folder + '/autoupdate.ini';
        if not FileExists(autoupdate_path) then begin
             writeln('unable to stat ' + autoupdate_path);
             exit;
        end;
    end;
    auto:=TIniFile.Create(autoupdate_path);

    FILE_EXT:=auto.ReadString('NEXT',package_name + '_ext','tar.gz');
    www_prefix:=auto.ReadString('NEXT',package_name + '_prefix','');
    FileNamePrefix:=auto.ReadString('NEXT',package_name + '_filename_prefix',package_name  + '-');
    package_version:=auto.ReadString('NEXT',package_name,'');
    auto.free;
    result:=package_version;
end;
//#############################################################################################
  function tlibs.FileSize_bytes(path:string):longint;
Var
L : File Of byte;
size:longint;
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
  result:=size;
  EXCEPT

  end;
end;
 //#############################################################################
function tlibs.COMPILE_VERSION(package_name:string):integer;
var
   gcc_path,make_path,wget_path,compile_source:string;
   auto:TiniFile;
   tmp:string;
   FILE_TEMP:TstringList;
   FILE_EXT:string;
   package_version:string;
   DECOMPRESS_OPT:string;
   www_prefix:string;
   uri_download:string;
   target_file:string;
   RegExpr:TRegExpr;
   int_version                          :integer;
   FileNamePrefix                       :string;
   local_folder                         :string;
   autoupdate_path                      :string;
   remote_uri                           :string;
   index_file                           :string;
   i                                    :integer;
begin



    package_name:=trim(package_name);
    local_folder:='';
    remote_uri:='http://www.artica.fr/download';
    index_file:='http://www.artica.fr/auto.update.php';
    FILE_TEMP:=TStringList.Create;
    RegExpr:=TRegExpr.Create;

    fpsystem('cd ' + ExtractFilePath(ParamStr(0)));

    gcc_path:=LOCATE_GCC();
    make_path:=LOCATE_MAKE();
    wget_path:='/usr/bin/wget';
    forcedirectories('/tmp/artica/install/sources');
    if FileExists('/tmp/artica/install/sources/' + package_name) then begin
       writeln('Cleaning /tmp/artica/install/sources folder...');
       fpsystem('/bin/rm -rf /tmp/artica/install/sources/' + package_name);
    end;




    writeln('Checking required compilation tools as gcc and make');
    if length(make_path)=0 then begin
        writeln('ERROR:: unable to locate make...');
       exit(0);
    end;

    if length(gcc_path)=0 then begin
        writeln('ERROR:: unable to locate gcc...');
        exit(0);
    end;

    writeln('Checking last supported version of ' + package_name + ' from ' +index_file);

    if local_folder='' then WGET_DOWNLOAD_FILE(index_file,'/tmp/artica/install/sources/autoupdate.ini');
    if local_folder='' then begin
       autoupdate_path:='/tmp/artica/install/sources/autoupdate.ini';
    end else begin
        autoupdate_path:=local_folder + '/autoupdate.ini';
        if not FileExists(autoupdate_path) then begin
             writeln('unable to stat ' + autoupdate_path);
             exit;
        end;
    end;
    auto:=TIniFile.Create(autoupdate_path);

    FILE_EXT:=auto.ReadString('NEXT',package_name + '_ext','tar.gz');
    www_prefix:=auto.ReadString('NEXT',package_name + '_prefix','');
    FileNamePrefix:=auto.ReadString('NEXT',package_name + '_filename_prefix',package_name  + '-');
    package_version:=auto.ReadString('NEXT',package_name,'');
    auto.free;

    writeln(package_name+': version: ' + package_version);

    result:=VersionToInteger(package_version);
end;
//#############################################################################################
function tlibs.VersionToInteger(version:string):integer;
begin
    version:=AnsiReplaceText(version,'-','');
    version:=AnsiReplaceText(version,'.','');
    version:=AnsiReplaceText(version,'_','');
    if not TryStrToInt(version,result) then result:=0;

end;

function tlibs.PERL_GENERIC_INSTALL(indexWeb:string;ModulesToCheck:string;force:boolean;echoyes:boolean):boolean;
var
   source:string;
   compile:string;

begin
    result:=false;
    ModulesToCheck:=trim(ModulesToCheck);
    indexWeb:=trim(indexWeb);
    if not force then begin
       if length(CHECK_PERL_MODULES(ModulesToCheck))>0 then begin
          exit(true);
       end;
    end;

    
    source:=COMPILE_GENERIC_APPS(indexWeb);
    if not DirectoryExists(source) then begin
        writeln('............................:failed (error extracting)');
        exit;
    end;
     PERL_GENERIC_DISABLE_TESTS(source);
     SetCurrentDir(source);
     if echoyes then begin
        fpsystem('/bin/echo y| perl ' + source + '/Makefile.PL');
     end else begin
       fpsystem('perl ' + source + '/Makefile.PL');
     end;

     compile:='make && make install';
     fpsystem(compile);
     
     if CHECK_PERL_MODULES_SECOND(ModulesToCheck) then result:=true;


end;
//#############################################################################################
procedure tlibs.PERL_GENERIC_DISABLE_TESTS(source:string);
var
  l:TstringList;
  RegExpr:TRegExpr;
  i:integer;
begin
    if not FileExists( source + '/Makefile.PL') then exit;
    
    l:=TstringList.Create;
    l.LoadFromFile( source + '/Makefile.PL');
    RegExpr:=TRegExpr.Create;

    
    for i:=0 to l.Count-1 do begin
         RegExpr.Expression:='^&set_test_data';
         if RegExpr.Exec(l.Strings[i]) then begin
            l.Strings[i]:='';
         end;

         RegExpr.Expression:='^set_test_data\(';
         if RegExpr.Exec(l.Strings[i]) then begin
            l.Strings[i]:='';
         end;
    end;
     l.SaveToFile(source + '/Makefile.PL');

end;
//#############################################################################################

function tlibs.CHECK_PERL_MODULES(ModulesToCheck:string):string;
var
   cmd:string;
   l:TstringList;
   RegExpr:TRegExpr;
begin

cmd:='perl -M'+ModulesToCheck+' -e ''print "$'+ModulesToCheck+'::VERSION\n"''';
fpsystem(cmd + ' >/tmp/checkMod 2>&1');
 l:=TstringList.Create;
 RegExpr:=TRegExpr.Create;
 l.LoadFromFile('/tmp/checkMod');
 RegExpr.Expression:='([0-9\.]+)';
 if RegExpr.Exec(l.Strings[0]) then begin
    if trim(RegExpr.Match[1])='.' then exit;
    writeln(ModulesToCheck + ' version ' + RegExpr.Match[1]);
    result:=trim(RegExpr.Match[1]);
 end else begin
 writeln(l.Strings[0]);
 end;
 L.free;
 RegExpr.Free;

end;



//##############################################################################
function tlibs.LOCATE_MAKE():string;
begin
if FileExists('/usr/bin/make') then exit('/usr/bin/make');
end;
//##############################################################################
function tlibs.LOCATE_GCC():string;
 begin
     if FileExists('/usr/bin/gcc') then exit('/usr/bin/gcc');
 end;
//##############################################################################
function tlibs.LOCATE_PERL_BIN():string;
begin
    if FileExists('/usr/local/bin/perl') then exit('/usr/local/bin/perl');
    if FileExists('/usr/bin/perl') then exit('/usr/bin/perl');
    if FileExists('/opt/artica/bin/perl') then exit('/opt/artica/bin/perl');
end;
//#################################################################################
function tlibs.DirDir(FilePath: string):TstringList;
Var Info : TSearchRec;
    D:boolean;
Begin
  DirListFiles:=TstringList.Create();
  If FindFirst (FilePath+'/*',faDirectory,Info)=0 then begin
    Repeat
      if Info.Name<>'..' then begin
         if Info.Name <>'.' then begin
           if info.Attr=48 then begin
              DirListFiles.Add(Info.Name);
           end;

         end;
      end;

    Until FindNext(info)<>0;
    end;
  FindClose(Info);
  DirDir:=DirListFiles;
  exit();
end;
//#########################################################################################
function tlibs.COMMANDLINE_PARAMETERS(FoundWhatPattern:string):boolean;
var
   i:integer;
   s:string;
   RegExpr:TRegExpr;

begin
 s:='';
 result:=false;
 if(FoundWhatPattern)='--verbose' then begin
           if ParamStr(1)='--verbose' then exit(true);
 end;
 if ParamCount>1 then begin
     for i:=0 to ParamCount do begin
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
//#########################################################################################
function tlibs.PERL_INCFolders():TstringList;
const
  CR = #$0d;
  LF = #$0a;
  CRLF = CR + LF;

var
    datas:string;
    F:TstringList;
    RegExpr:TRegExpr;
    L:TStringDynArray;
    i:integer;
begin
     fpsystem(LOCATE_PERL_BIN() + ' -V >/tmp/perl.inc 2>&1');
     datas:=ReadFileIntoString('/tmp/perl.inc');
     
     RegExpr:=TRegExpr.Create;

     RegExpr.Expression:='@INC:(.+)';
     if RegExpr.Exec(datas) then begin
        l:=Explode(CRLF,RegExpr.Match[1]);
        F:=TstringList.Create;

        For i:=0 to length(l)-1 do begin
            if length(trim(l[i]))>3 then begin
               if trim(l[i])='/etc/perl' then continue;
               F.Add(trim(l[i]));
            end;
        end;
     end;

   result:=F;
   if ParamStr(1)='@INC' then begin
        For i:=0 to F.Count -1 do begin
            writeln(F.Strings[i]);
        end;
   end;

end;

//#####################################################################################
function tlibs.ReadFileIntoString(path:string):string;
         const
            CR = #$0d;
            LF = #$0a;
            CRLF = CR + LF;
var
   Afile:text;
   datas:string;
   datas_file:string;
begin
       datas_file:='';
       if not FileExists(path) then exit;


      TRY
     assign(Afile,path);
     reset(Afile);
     while not EOF(Afile) do
           begin
           readln(Afile,datas);
           datas_file:=datas_file + datas +CRLF;
           end;

close(Afile);
             EXCEPT

           end;
result:=datas_file;


end;
//#####################################################################################
function tlibs.Explode(const Separator, S: string; Limit: Integer = 0):TStringDynArray;
var
  SepLen       : Integer;
  F, P         : PChar;
  ALen, Index  : Integer;
begin
  SetLength(Result, 0);
  if (S = '') or (Limit < 0) then
    Exit;
  if Separator = '' then
  begin
    SetLength(Result, 1);
    Result[0] := S;
    Exit;
  end;
  SepLen := Length(Separator);
  ALen := Limit;
  SetLength(Result, ALen);

  Index := 0;
  P := PChar(S);
  while P^ <> #0 do
  begin
    F := P;
    P := StrPos(P, PChar(Separator));
    if (P = nil) or ((Limit > 0) and (Index = Limit - 1)) then
      P := StrEnd(F);
    if Index >= ALen then
    begin
      Inc(ALen, 5); // mehrere auf einmal um schneller arbeiten zu können
      SetLength(Result, ALen);
    end;
    SetString(Result[Index], F, P - F);
    Inc(Index);
    if P^ <> #0 then
      Inc(P, SepLen);
  end;
  if Index < ALen then
    SetLength(Result, Index); // wirkliche Länge festlegen
end;
//#########################################################################################
procedure tlibs.InstallArtica();
var
   my:TiniFile;
   articaversion:string;

begin

writeln('Getting index file');
if fileexists('/tmp/artica.ini') then fpsystem('/bin/rm -f /tmp/artica.ini');
if not WGET_DOWNLOAD_FILE('http://www.artica.fr/auto.update.php','/tmp/artica.ini') then begin
   writeln('Failed to get artica version...');
   exit;
end;


my:=TiniFile.Create('/tmp/artica.ini');
articaversion:=my.ReadString('NEXT','artica','');
if length(articaversion)=0 then begin
   writeln('Failed to get artica version after downloading the index file...');
   exit;
end;

if ARTICA_VERSION()=articaversion then begin
   writeln('Your artica-version is already updated....');
   exit;
end;


writeln('Downloading '+articaversion + ' artica version');

if FileExists('/tmp/'+articaversion+'.tgz') then fpsystem('/bin/rm -f /tmp/'+articaversion+'.tgz');
if not WGET_DOWNLOAD_FILE('http://www.artica.fr/download/artica-'+articaversion+'.tgz','/tmp/'+articaversion+'.tgz') then begin
   writeln('Failed to get artica package...');
   exit;
end;

writeln('extracting  '+articaversion + ' artica version');
fpsystem('tar -xf /tmp/'+articaversion+'.tgz -C /usr/share');

if not FileExists('/usr/share/artica-postfix/bin/artica-install') then begin
    writeln('Failed to extract the content');
    exit;
end;

if not FileExists('/usr/lib/libmysqlclient.so.15') then begin
   writeln('Copy libmysqlclient.so.15 library /usr/lib/libmysqlclient.so.15');
   fpsystem('/bin/cp /usr/share/artica-postfix/bin/install/libmysqlclient.so.15 /usr/lib/libmysqlclient.so.15');
end;

writeln('Installing  '+articaversion + ' artica version');
fpsystem('/usr/share/artica-postfix/bin/artica-install --init-from-repos');
fpsystem('/usr/share/artica-postfix/bin/artica-install --perl-addons-repos');
fpsystem('/usr/share/artica-postfix/bin/artica-install -awstats-reconfigure');
fpsystem('/usr/share/artica-postfix/bin/artica-install -awstats generate');
fpsystem('/etc/init.d/artica-postfix stop');
fpsystem('/etc/init.d/artica-postfix start');
fpsystem('/etc/init.d/artica-postfix stop');
fpsystem('/etc/init.d/artica-postfix start');
fpsystem('/usr/share/artica-postfix/bin/artica-install --init-from-repos');
end;
//#########################################################################################
function tlibs.RPM_is_application_installed(appname:string):boolean;
var
   l:TstringList;
   RegExpr:TRegExpr;
   i:integer;
   D:boolean;
begin
    D:=false;
    result:=false;
    D:=COMMANDLINE_PARAMETERS('--verbose');
    appname:=trim(appname);
    if not FileExists('/tmp/packages.list') then begin
       writeln('Checking.............: Building package list...');
       writeln('Checking.............: waiting for rpm exporting list');
       fpsystem('/bin/rpm -qa >/tmp/packages.list');
       writeln('Checking.............: Exporting list done...');
    end;

    l:=TstringList.Create;
    if not FileExists('/tmp/packages.list') then begin
       writeln('Checking.............: something wrong export file is under 10 rows ??! restart again...');
       fpsystem('/bin/rm -rf /tmp/packages.list');
       result:=RPM_is_application_installed(appname);
       exit;
    end;

    l.LoadFromFile('/tmp/packages.list');



    if l.Count<10 then begin
       writeln('Checking.............: something wrong export file is under 10 rows ??! restart again...');
       fpsystem('/bin/rm -rf /tmp/packages.list');
       result:=RPM_is_application_installed(appname);
       exit;
    end;
    RegExpr:=TRegExpr.Create;
    appname:=AnsiReplaceText(appname,'+','\+');
    RegExpr.Expression:='^'+appname;
    if D then writeln('Search ',RegExpr.Expression);

    for i:=0 to l.Count-1 do begin
        if RegExpr.Exec(l.Strings[i]) then begin
           result:=true;
           if D then writeln(RegExpr.Expression,' ', ' match ',l.Strings[i]);
           break;
        end else begin


        end;
    end;
    if not result then if D then writeln('Search ',RegExpr.Expression,' failed');
    l.free;
    RegExpr.free;

end;

//#########################################################################################
//##############################################################################

function tlibs.ReadFromFile(TargetPath:string):string;
var
  fs: TFileStream;
  teststr: string;
  a: char;
  i: integer;
begin
  if not FileExists(TargetPath) then exit;
  a:=Char('');
  teststr := '';

  if not FileExists(TargetPath) then exit;
  fs := TFileStream.Create(TargetPath, fmOpenRead);
  try
    fs.Position := 0;
    for i := 1 to fs.size do begin
      fs.Read(a, sizeof(char));
      teststr := teststr + a;
    end;
  finally
    fs.free;
  end;

  result:=teststr;
end;
//#############################################################################
function tlibs.get_LDAP(key:string):string;
var
   value:string;
   Ini:TMemIniFile;

begin

if DirectoryExists('/etc/artica-postfix/ldap_settings') then begin
   if FileExists('/etc/artica-postfix/ldap_settings/'+key) then begin
      result:=trim(ReadFromFile('/etc/artica-postfix/ldap_settings/'+key));
      exit;
   end;
end;


Ini:=TMemIniFile.Create('/etc/artica-postfix/artica-postfix-ldap.conf');
value:=trim(Ini.ReadString('LDAP',key,''));
Ini.Free;

if length(value)=0 then begin
 if FileExists('/etc/artica-postfix/artica-postfix-ldap.bak.conf') then begin
    Ini:=TMemIniFile.Create('/etc/artica-postfix/artica-postfix-ldap.bak.conf');
    value:=Ini.ReadString('LDAP',key,'');
    Ini.Free;
    if length(value)>0 then begin
       set_LDAP(key,value);
       result:=value;
       exit;
    end;
  end;

    if key='admin' then begin
      value:=get_LDAP_ADMIN();
      if length(value)>0 then begin
         set_LDAP(key,value);
         result:=value;
         exit;
       end;
     end;

    if key='password' then begin
      value:=get_LDAP_PASSWORD();
      if length(value)>0 then begin
         set_LDAP(key,value);
         result:=value;
         exit;
       end;
     end;

    if key='suffix' then begin
      value:=get_LDAP_suffix();
      if length(value)>0 then begin
         set_LDAP(key,value);
         result:=value;
         exit;
       end;
     end;

end;

result:=value;

end;
//#############################################################################
procedure tlibs.set_LDAP(key:string;val:string);
var ini:TIniFile;
begin
forceDirectories('/etc/artica-postfix');
ini:=TIniFile.Create('/etc/artica-postfix/artica-postfix-ldap.conf');
ini.WriteString('LDAP',key,val);
ini.Free;

ini:=TIniFile.Create('/etc/artica-postfix/artica-postfix-ldap.bak.conf');
ini.WriteString('LDAP',key,val);
ini.Free;


if ForceDirectories('/etc/artica-postfix/ldap_settings') then begin
      try
         WriteToFile(val,'/etc/artica-postfix/ldap_settings/'+key);
      except
          writeln('set_LDAP unable to write file /etc/artica-postfix/ldap_settings/'+key );
      end;
end;

end;
//#############################################################################
function tlibs.WriteToFile(zText:string;TargetPath:string):boolean;
      var
        F : Text;
      BEGIN
      result:=true;

        forcedirectories(ExtractFilePath(TargetPath));


        TRY
           Assign (F,TargetPath);
           Rewrite (F);
           Write(F,zText);
           Close(F);
          exit(true);
        EXCEPT
             writeln('WriteFile():: -> error I/O in ' +     TargetPath);

        END;

exit(false);
      END;
//#############################################################################
function tlibs.get_LDAP_ADMIN():string;
var
   RegExpr:TRegExpr;
   l:TstringList;
   i:integer;

begin
  if not FileExists(SLAPD_CONF_PATH()) then exit;
  RegExpr:=TRegExpr.Create;
  l:=TstringList.Create;
  TRY
  l.LoadFromFile(SLAPD_CONF_PATH());
  RegExpr.Expression:='rootdn\s+"cn=(.+?),';
  for i:=0 to l.Count-1 do begin
      if  RegExpr.Exec(l.Strings[i]) then begin
             result:=trim(RegExpr.Match[1]);
             break;
      end;
  end;
  FINALLY
   l.free;
   RegExpr.free;
  END;
end;
//#############################################################################
function tlibs.get_LDAP_PASSWORD():string;
var
   RegExpr:TRegExpr;
   l:TstringList;
   i:integer;

begin
  if not FileExists(SLAPD_CONF_PATH()) then exit;
  RegExpr:=TRegExpr.Create;
  l:=TstringList.Create;
  TRY
  l.LoadFromFile(SLAPD_CONF_PATH());
  RegExpr.Expression:='rootpw\s+(.+)';
  for i:=0 to l.Count-1 do begin
      if  RegExpr.Exec(l.Strings[i]) then begin
             result:=trim(RegExpr.Match[1]);
             result:=AnsiReplaceText(result,'"','');
             result:=AnsiReplaceText(result,'"','');
             break;
      end;
  end;
  FINALLY
   l.free;
   RegExpr.free;
  END;
end;
//#############################################################################
function tlibs.get_LDAP_suffix():string;
var
   RegExpr:TRegExpr;
   l:TstringList;
   i:integer;

begin
  if not FileExists(SLAPD_CONF_PATH()) then exit;
  RegExpr:=TRegExpr.Create;
  l:=TstringList.Create;
  TRY
  l.LoadFromFile(SLAPD_CONF_PATH());
  RegExpr.Expression:='^suffix\s+(.+)';
  for i:=0 to l.Count-1 do begin
      if  RegExpr.Exec(l.Strings[i]) then begin
             result:=trim(RegExpr.Match[1]);
             result:=AnsiReplaceText(result,'"','');
             result:=AnsiReplaceText(result,'"','');
             break;
      end;
  end;
  FINALLY
   l.free;
   RegExpr.free;
  END;
end;
//#############################################################################
function tlibs.SLAPD_CONF_PATH():string;
begin
   if FileExists('/etc/ldap/slapd.conf') then exit('/etc/ldap/slapd.conf');
   if FileExists('/etc/openldap/slapd.conf') then exit('/etc/openldap/slapd.conf');
   if FileExists('/opt/artica/etc/openldap/slapd.conf') then exit('/opt/artica/etc/openldap/slapd.conf');
   exit('/etc/ldap/slapd.conf');

end;
//##############################################################################
function tlibs.EXECUTE_SQL_FILE(filenname:string;database:string;defaultcharset:string):boolean;
    var
    root,commandline,password,port,mysqlbin,server,sql_results,defchar:string;
    tempfile:string;
begin
  root    :=MYSQL_INFOS('database_admin');
  password:=MYSQL_INFOS('database_password');
  port    :=MYSQL_INFOS('port');
  server  :=MYSQL_INFOS('mysql_server');
  mysqlbin:=MYSQL_EXEC_BIN_PATH();
  if length(password)>0 then password:=' --password='+password;
  if length(server)>0 then server:=' --host='+server;
  if length(port)>0 then port:=' --port='+server;


  if not fileExists(mysqlbin) then begin
     writeln('tlibs.EXECUTE_SQL_FILE:: Unable to locate mysql binary (usually in ' + mysqlbin + ')');
     exit(false);
  end;

  if not IF_DATABASE_EXISTS(database) then begin
       writeln('tlibs.EXECUTE_SQL_FILE:: CREATE DATABASE '+database);
       QUERY_SQL('CREATE DATABASE '+database+';','');
   end;


  if not FileExists(filenname) then begin
     writeln('tlibs.EXECUTE_SQL_FILE:: Unable to stat ' +filenname);
     exit;
  end;

  if length(defaultcharset)>0 then defchar:=' --default-character-set="'+defaultcharset+'"';


   tempfile:=FILE_TEMP();
   commandline:=MYSQL_EXEC_BIN_PATH() +' --user='+ root+password+server+port+' --skip-column-names'+defchar+' --database=' + database + ' --silent --xml <' + filenname;
   fpsystem(commandline);
   exit(true);

end;
//#############################################################################

function tlibs.IF_DATABASE_EXISTS(databasename:string):boolean;
var
    root,commandline,password,port,mysqlbin,server,sql_results,defchar:string;
    tempfile:string;
    RegExpr:TRegExpr;
    l:Tstringlist;
    i:integer;
begin
  root    :=MYSQL_INFOS('database_admin');
  password:=MYSQL_INFOS('database_password');
  port    :=MYSQL_INFOS('port');
  server  :=MYSQL_INFOS('mysql_server');
  mysqlbin:=MYSQL_EXEC_BIN_PATH();
  tempfile:=GetTempFileName('',ExtractFileName(ParamStr(0)));
  if length(password)>0 then password:=' --password='+password;
  if length(server)>0 then server:=' --host='+server;
  if length(port)>0 then port:=' --port='+server;
 commandline:=MYSQL_EXEC_BIN_PATH() +' --user='+root+password+server+port+'  --xml --skip-column-names --execute="SHOW DATABASES;" >'+tempfile+' 2>&1';
 fpsystem(commandline);


  RegExpr:=TRegExpr.Create;
  l:=TstringList.Create;
  l.LoadFromFile(tempfile);
  fpsystem('/bin/rm '+tempfile);
  RegExpr.Expression:=databasename;
  for i:=0 to l.Count-1 do begin
        if RegExpr.Exec(l.Strings[i]) then begin
           result:=true;
        end;
  end;

  l.free;
  RegExpr.free;
end;
//#############################################################################
function tlibs.QUERY_SQL(sql:string;databasename:string):boolean;
var
    root,commandline,password,port,mysqlbin,server,sql_results,defchar:string;
    tempfile:string;
begin
  root    :=MYSQL_INFOS('database_admin');
  password:=MYSQL_INFOS('database_password');
  port    :=MYSQL_INFOS('port');
  server  :=MYSQL_INFOS('mysql_server');
  mysqlbin:=MYSQL_EXEC_BIN_PATH();
  tempfile:=GetTempFileName('',ExtractFileName(ParamStr(0)));
  if length(password)>0 then password:=' --password='+password;
  if length(server)>0 then server:=' --host='+server;
  if length(port)>0 then port:=' --port='+server;
  if length(databasename)>0 then databasename:=' --database='+databasename;
  commandline:=MYSQL_EXEC_BIN_PATH() +' --user='+root+password+server+port+databasename+' --silent --xml --skip-column-names --execute="'+sql+'"';
  fpsystem(commandline);
end;
//#############################################################################





procedure tlibs.PASSWD_INFO();
begin
     writeln('');
     writeln('#################################################################################');
     writeln('##                                                                             ##');
     writeln('## You can access to artica by typing https://yourserver:9000                  ##');
     writeln('## Use on logon section the username "' + get_LDAP('admin') + '"                                 ##');
     writeln('## Use on logon section the password "' + get_LDAP('password') + '"                                  ##');
     writeln('## You have to logon to artica web site, set yours domains and apply policies  ##');
     writeln('##                                                                             ##');
     writeln('## You can install others package by executing artica-make                     ##');
     writeln('## /usr/share/artica-postfix/bin/artica-make --help                            ##');
     writeln('##                                                                             ##');
     writeln('#################################################################################');
     writeln('');
end;

function tlibs.INTRODUCTION(base:string;postfix:string;cyrus:string;samba:string;squid:string;nfs:string;pdns:string):string;
var
   u:string;
   plist:TStringDynArray;
   plistSamba:TStringDynArray;
   plistSquid:TStringDynArray;
   plistCyrus:TStringDynArray;
   plistBase:TStringDynArray;

begin
     base:=trim(base);
      if length(base)>0 then begin
             writeln('Some dependencies will missing for next installation if you');
             writeln('continue, some packages installed will failed...');
             writeln('Press Enter key to continue or press "c" and Enter if you want to skip mandatories checking');
             readln(u);
             if u='c' then begin
                fpsystem('clear');
                writeln('checking base system skipped');
                base:='';
                u:='';
             end;
           fpsystem('clear');
      end;

   if ARTICA_VERSION()='0.00' then begin
      if length(base)=0 then begin
         writeln('Artica is ready to be installed...');
         writeln('Do you want to install artica now ? [Y]');
         readln(u);
         if length(u)=0 then u:='y';
         if LowerCase(u)='y' then begin
            InstallArtica();
            exit;
         end;
      end;
   end;
   base:=trim(base);


     writeln('');
     writeln('###########################################');
     writeln('##                                       ##');
     writeln('##  Artica-postfix modules installation  ##');
     writeln('##                                       ##');
     writeln('###########################################');
     writeln('');
     writeln('"Be sure to not install Artica on a production server already set');
     writeln('Artica will transform this system to fit it`s needs that should not encounter');
     writeln('your same parameters strategy. use a free system before installing it!"');


  if FileExists('/usr/share/artica-postfix/bin/artica-install') then begin
      PASSWD_INFO();
  end;
    writeln('Select the modules you want to install:');
    postfix:=trim(postfix);
    cyrus:=trim(cyrus);
    samba:=trim(samba);
    squid:=trim(squid);
    if length(trim(base))=0 then begin
    if length(postfix+cyrus+samba+squid)=0 then begin
       writeln('Install all modules.......:................................installed');
    end else begin
       writeln('Install all modules.......:................................[A]');
    end;
    writeln('');
    if length(base)=0 then begin
       if length(postfix)>0 then begin
        plist:=explode(',', postfix);
        writeln('SMTP MTA (include postfix and securities modules):.....[1]');
        writeln(IntToStr(length(plist))+' package(s) are not installed');
       end else begin
        writeln('SMTP MTA (include postfix and securities modules):.....Installed');
         
         if FileExists('/usr/share/artica-postfix/bin/artica-make') then begin
         if not FileExists('/usr/local/sbin/amavisd') then begin
        writeln('Amavisd-new and milter:................................[C]');
         end else begin
        writeln('Amavisd-new and milter:................................Installed');
         end;
         end;
         
       end;
    end;

  if length(trim(base))=0 then begin
   if length(postfix)=0 then begin
         ZARAFA_INSTALL_MENU();
      if length(cyrus)>0 then begin
         plistCyrus:=explode(',', cyrus);
         writeln('Mail server (include postfix and Cyrus-imap):..........[2]');
         writeln(IntToStr(length(plistCyrus))+'  package(s) are not installed');
      end else begin
          writeln('Mail server (include postfix and Cyrus-imap):..........Installed');
      end;
   end;
  end;

if length(trim(base))=0 then begin
    writeln('**********************************************************');
    if length(Samba)>0 then begin
     plistSamba:=explode(',', Samba);
    writeln('Files Sharing (include Samba and Pure-ftpd):...........[3]');
    writeln(IntToStr(length(plistSamba))+' package(s) is not installed');
    end else begin
    writeln('Files Sharing (include Samba and Pure-ftpd):...........Installed');
    end;
end;

if length(trim(base))=0 then begin
    writeln('**********************************************************');
   writeln('');
    if length(squid)>0 then begin
       writeln('Squid Proxy (include Squid and dansguardian):..........[4]');
       plistSquid:=explode(',', squid);
       writeln(IntToStr(length(plistSquid))+' package(s) are not installed');
    end else begin
        writeln('Squid Proxy (include Squid and dansguardian):..........Installed');
    end;
 end;

if length(trim(base))=0 then begin
      writeln('**********************************************************');
   writeln('');
    if length(nfs)>0 then begin
       writeln('NFS System :...........................................[6]');
       plistSquid:=explode(',', nfs);
       writeln(IntToStr(length(plistSquid))+' package(s) are not installed');
    end else begin
        writeln('NFS System :...........................................Installed');
    end;
 end;

if length(trim(pdns))=0 then begin
       writeln('**********************************************************');
   writeln('');
    if length(nfs)>0 then begin
       writeln('PowerDNS System :......................................[7]');
       plistSquid:=explode(',', pdns);
       writeln(IntToStr(length(pdns))+' package(s) are not installed');
    end else begin
         writeln('PowerDNS System :......................................Installed');
    end;
 end;


end;

if length(trim(base))>0 then begin
writeln('');
writeln('##################################################################');
writeln('##                                                              ##');
writeln('## Install mandatories dependencies..:..................[ENTER] ##');
writeln('##                                                              ##');
writeln('##################################################################');
writeln('');
plistBase:=explode(',', base);
writeln('This will install '+IntToStr(length(plistBase))+' package(s):');
end else begin

writeln('');
writeln('----------------------------');
writeln('Install/upgrade Artica-postfix:........................[5] ('+ARTICA_VERSION()+')');

if length(ARTICA_VERSION())>0 then begin
   writeln('reboot  Artica-postfix:................................[R]');
   writeln('Get SuperAdmin Infos:..................................[I]');
   
   writeln('');
end;
end;




writeln('Quit the installation program.........................:[Q]');
writeln('Type the option.......................................:');
writeln('');
readln(u);
if length(u)=0 then exit;

if lowercase(u)='q' then halt(0);

if lowercase(u)='i' then begin
       fpsystem('clear');
       PASSWD_INFO();
       writeln('');
       writeln('Type key');
       readln(u);
       fpsystem('clear');
       INTRODUCTION(base,postfix,cyrus,samba,squid);
       exit;
end;


if lowercase(u)='c' then begin
   fpsystem('/usr/share/artica-postfix/bin/artica-make APP_AMAVISD_MILTER');
   INTRODUCTION(base,postfix,cyrus,samba,squid);
   exit;
end;


if lowercase(u)='r' then begin
   fpsystem('/etc/init.d/artica-postfix restart');
   fpsystem('/etc/init.d/artica-postfix restart apache');
   INTRODUCTION(base,postfix,cyrus,samba,squid);
   exit;
end;

if lowercase(u)='z' then begin
   ZARAFA_INSTALL_PERFORM();
   INTRODUCTION(base,postfix,cyrus,samba,squid);
   exit;
end;

if u='5' then begin
   InstallArtica();
   INTRODUCTION(base,postfix,cyrus,samba,squid);
   exit;
end;
   exit(u);

end;
//#############################################################################
procedure tlibs.ZARAFA_INSTALL_MENU();
var
   prereq:boolean;

begin
   prereq:=true;
    writeln('');
    writeln('Zarafa Mail server');
   if FileExists('/usr/lib/CLucene/clucene-config.h') then begin
      writeln('Zarafa CLucene library.................................: Installed');
   end else begin
      writeln('Zarafa CLucene library.................................: Not installed');
      prereq:=false;
   end;

   if FileExists('/usr/local/lib/libvmime.so.0.7.1') then begin
      writeln('Zarafa libvmime library................................: Installed');
   end else begin
      writeln('Zarafa libvmime library................................: Not installed');
      prereq:=false;
   end;

   if FileExists('/usr/bin/pprof') then begin
      writeln('Zarafa Google perftools libraries......................: Installed');
   end else begin
      writeln('Zarafa Google perftools libraries......................: Not installed');
      prereq:=false;
   end;

   if FileExists('/usr/local/lib/libicalvcal.a') then begin
      writeln('Zarafa libicalvcal library.............................: Installed');
   end else begin
      writeln('Zarafa libicalvcal library.............................: Not installed');
      prereq:=false;
   end;

   if not prereq then begin
      writeln('Install mandatories Zarafa libraries...................: [Z]');
      writeln('');
      exit;
   end;

   if not FileExists('/usr/local/bin/zarafa-server') then begin
      writeln('Install Zarafa server..................................: [Z]');
      writeln('');
      exit;
   end;

    writeln('Zarafa server..........................................: Installed');

end;


//#############################################################################
procedure tlibs.ZARAFA_INSTALL_PERFORM();
begin
    writeln('');

   if FileExists('/usr/lib/CLucene/clucene-config.h') then begin
      writeln('Zarafa CLucene library.................................: Installed');
   end else begin
      fpsystem('/usr/share/artica-postfix/bin/artica-make APP_ZARAFA_CLUCENE');
      exit;
   end;

   if FileExists('/usr/local/lib/libvmime.so.0.7.1') then begin
      writeln('Zarafa libvmime library................................: Installed');
   end else begin
       fpsystem('/usr/share/artica-postfix/bin/artica-make APP_ZARAFA_LIBVMIME');
       exit;
   end;

   if FileExists('/usr/bin/pprof') then begin
      writeln('Zarafa Google perftools libraries......................: Installed');
   end else begin
       fpsystem('/usr/share/artica-postfix/bin/artica-make APP_ZARAFA_GOOGLE');
       exit;
   end;

   if FileExists('/usr/local/lib/libicalvcal.a') then begin
      writeln('Zarafa libicalvcal library.............................: Installed');
   end else begin
       fpsystem('/usr/share/artica-postfix/bin/artica-make APP_ZARAFA_LIBICAL');
       exit;
   end;


      writeln('Install mandatories Zarafa libraries...................: Success');
      fpsystem('/usr/share/artica-postfix/bin/artica-make APP_ZARAFA --running');
      exit;
end;
//#############################################################################

function tlibs.MYSQL_INFOS(val:string):string;
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
function tlibs.MYSQL_EXEC_BIN_PATH():string;
begin
   if FileExists('/usr/bin/mysql') then exit('/usr/bin/mysql');
   if FileExists('/usr/local/bin/mysql') then exit('/usr/local/bin/mysql');
end;
//#############################################################################


end.
