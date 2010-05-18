unit compile;

{$mode objfpc}{$H+}

interface

uses
//depreciated oldlinux -> baseunix
Classes, SysUtils,variants, Process,IniFiles,unix,RegExpr in 'RegExpr.pas',global_conf,Zsystem,logs;

  type
  TCompile=class


private
     VERSION:string;
     D:boolean;
     BasePath:string;
     DestPath:string;
     BackupPath:string;
     TargetSpecFile:string;
     CurrentUser:string;
     logs:tLogs;
     GLOBAL_INI:myconf;
     function COMMANDLINE_PARAMETERS(FoundWhatPattern:string):boolean;
     procedure Execute(cmd:string);
     function GET_BASEPATH():string;
     function GET_DESTPATH():string;
     function TEMP_DATE():string;
     Function GET_CONTROL_VERSION(path:string):string;
     function GET_curUSER():string;
     Function GET_CONTROL_PACKAGE_NAME(path:string):string;
public
    constructor Create;
    procedure Free;
    function COMPILE_GEN_VERSION():string;
    procedure SET_FOLDER(path:string);
    procedure SET_DEST_PATH(path:string);
    procedure SET_CurUser(path:string);
    procedure COMPILE;
    function  PATCHING_SPECFILE(path:string):boolean;
    function  OPENSECURITY():boolean;
    procedure SAVE_CDROM_HOOKS(xVERSION:string;xDestPath:string);
    procedure SAVE_CDROM_INIT_D(xVERSION:string;xDestPath:string);
    function COMMANDLINE_EXTRACT_PARAMETERS(pattern:string):string;
    procedure SyncUSerBackup();

end;

implementation

//-------------------------------------------------------------------------------------------------------

//##############################################################################
constructor TCompile.Create;

begin
D:=COMMANDLINE_PARAMETERS('-V');
GLOBAL_INI:=myconf.Create;
VERSION:=COMPILE_GEN_VERSION();
BasePath:=GET_BASEPATH();
DestPath:=GET_DESTPATH();
BackupPath:=DestPath + '/back';
CurrentUser:=GET_curUSER() + ':' + GET_curUSER();
    writeln('Compilation start on...: ',BasePath);
    writeln('Compilation defined to.: ',DestPath);
    writeln('Backup to..............: ',BackupPath);
    writeln('Current user...........: ',CurrentUser);


end;
//##############################################################################
PROCEDURE TCompile.Free();
begin
GLOBAL_INI.Free;

end;
//##############################################################################
function TCompile.COMPILE_GEN_VERSION():string;
var
   txt:string;
   J:TstringList;
begin

fpsystem('date +%m%d%H >/tmp/date.txt');
J:=TStringList.Create;
J.LoadFromFile('/tmp/date.txt');
txt:=trim(J.Strings[0]);
result:='1.4.'+txt;

end;
//##############################################################################
function TCompile.TEMP_DATE():string;
var
   txt:string;
   J:TstringList;
begin

fpsystem('date +%Y%m%d >/tmp/date.txt');
J:=TStringList.Create;
J.LoadFromFile('/tmp/date.txt');

txt:=trim(J.Strings[0]);
result:=txt;

end;



//##############################################################################
procedure Tcompile.SET_FOLDER(path:string);
var
   f:TiniFile;
begin
    forceDirectories('/etc/artica-compile');
    f:=TiniFile.Create('/etc/artica-compile/compile.conf');
    f.WriteString('INFOS','BasePath',path);
    f.UpdateFile;
    f.Free;

end;
//##############################################################################
procedure Tcompile.SET_CurUser(path:string);
var
   f:TiniFile;
begin
    forceDirectories('/etc/artica-compile');
    f:=TiniFile.Create('/etc/artica-compile/compile.conf');
    f.WriteString('INFOS','CurUser',path);
    f.UpdateFile;
    f.Free;

end;
//##############################################################################
procedure Tcompile.SET_DEST_PATH(path:string);
var
   f:TiniFile;
begin
    forceDirectories('/etc/artica-compile');
    f:=TiniFile.Create('/etc/artica-compile/compile.conf');
    f.WriteString('INFOS','DestPath',path);
    f.UpdateFile;
    f.Free;

end;
//##############################################################################
function Tcompile.GET_BASEPATH():string;
var
   f:TiniFile;
begin
    forceDirectories('/etc/artica-compile');
    f:=TiniFile.Create('/etc/artica-compile/compile.conf');
  result:=f.ReadString('INFOS','BasePath','/home/dtouzeau/developpement/artica-postfix');

end;
//##############################################################################
function Tcompile.GET_curUSER():string;
var
   f:TiniFile;
begin
    forceDirectories('/etc/artica-compile');
    f:=TiniFile.Create('/etc/artica-compile/compile.conf');
  result:=f.ReadString('INFOS','CurUser','dtouzeau');

end;
//##############################################################################
function Tcompile.GET_DESTPATH():string;
var
   f:TiniFile;
begin
    forceDirectories('/etc/artica-compile');
    f:=TiniFile.Create('/etc/artica-compile/compile.conf');
  result:=f.ReadString('INFOS','DestPath','/home/dtouzeau/Bureau/artica-compile');

end;
//##############################################################################
procedure Tcompile.COMPILE;
var
tempdate:string;
cmd:string;
tempver,SourcePath,verrr,patchfile,patchedDir,generic_path,package_name,control_path:string;
begin
    writeln();
    writeln();
    VERSION:=trim(VERSION);
    SourcePath:=DestPath;
    DestPath:=DestPath + '/' + VERSION;
    BackupPath:=DestPath + '/backup';
    tempdate:=TEMP_DATE();
    GLOBAl_INI:=myconf.Create;
    
    

    writeln('New version on ',VERSION);
    writeln('');
    writeln('');
    
    if not FileExists(BasePath) then begin
     Writeln('Unable to stat BasePath');
     halt(0);
    end;
    
    if length(BasePath)=0 then halt(0);
    
    
     if COMMANDLINE_PARAMETERS('--postfix') then begin
        forcedirectories(DestPath);
        cmd:='dpkg-deb -b /home/dtouzeau/source-export/bogo ';
        cmd:=cmd + DestPath + '/artica-postfix-smtp-relay-' + GET_CONTROL_VERSION('/home/dtouzeau/source-export/bogo/DEBIAN/control')+'.deb';
        Execute(cmd);
        cmd:='cd ' + DestPath + ' && alien -r --scripts '+ DestPath + '/artica-postfix-smtp-relay-' + GET_CONTROL_VERSION('/home/dtouzeau/source-export/bogo/DEBIAN/control')+'.deb';
        Execute(cmd);
     end;
    
     if COMMANDLINE_PARAMETERS('--generic') then begin
        generic_path:=COMMANDLINE_EXTRACT_PARAMETERS('--path=(.+)');
        if not DirectoryExists(generic_path) then begin
           writeln('Unable to stat '+ generic_path);
           halt(0);
        end;
        writeln('Compiling using source....:' +  generic_path);
        control_path:=generic_path+'/DEBIAN/control';
        if not FileExists(control_path) then begin
             writeln('Unable to stat '+ control_path);
        end;
        package_name:=GET_CONTROL_PACKAGE_NAME(control_path)+'_'+GET_CONTROL_VERSION(control_path);
        writeln('Package name will be......:' +  package_name);
        

        
        forcedirectories(SourcePath);
        cmd:='dpkg-deb -b '+generic_path;
        cmd:=cmd + ' ' + SourcePath + '/'+package_name+'.deb';
        Execute(cmd);
        cmd:='cd ' + SourcePath + ' && alien -r --scripts '+ SourcePath + '/'+package_name+'.deb';
        Execute(cmd);
        fpsystem('/bin/chown -R dtouzeau:dtouzeau '+SourcePath);
        halt(0);
     end;

    
    if COMMANDLINE_PARAMETERS('--cyrus') then begin
       forcedirectories(DestPath);
       cmd:='dpkg-deb -b /home/dtouzeau/source-export/cyrus-imapd';
       cmd:=cmd+' /home/dtouzeau/Bureau/artica-compile/artica-postfix-mailbox-' + GET_CONTROL_VERSION('/home/dtouzeau/source-export/cyrus-imapd/DEBIAN/control')+'.deb';
       Execute(cmd);
       cmd:='cd ' + DestPath + ' && alien -r --scripts '+ SourcePath + '/artica-postfix-mailbox-' + GET_CONTROL_VERSION('/home/dtouzeau/source-export/cyrus-imapd/DEBIAN/control')+'.deb';
       Execute(cmd);
    end;
    

    if COMMANDLINE_PARAMETERS('--monitorix') then begin
       forcedirectories(DestPath);
       cmd:='dpkg-deb -b /home/dtouzeau/developpement/artica-postfix/bin/install/monitorix/monitorix.deb';
       cmd:=cmd+' /home/dtouzeau/developpement/artica-postfix/bin/install/monitorix.deb';
       Execute(cmd);
      // cmd:='cd ' + DestPath + ' && alien -r --scripts '+ SourcePath + '/artica-postfix-security-1.0.deb';
      // Execute(cmd);
       halt(0);
    end;
    
    
    if COMMANDLINE_PARAMETERS('--kas') then begin
       forcedirectories(DestPath);
       cmd:='dpkg-deb -b /home/dtouzeau/source-export/security';
       cmd:=cmd+' /home/dtouzeau/Bureau/artica-compile/artica-postfix-security-1.0.deb';
       Execute(cmd);
       cmd:='cd ' + DestPath + ' && alien -r --scripts '+ SourcePath + '/artica-postfix-security-1.0.deb';
       Execute(cmd);
       halt(0);
    end;
    
    if COMMANDLINE_PARAMETERS('--ksquid') then begin
       forcedirectories(DestPath);
       cmd:='dpkg-deb -b /home/dtouzeau/source-export/kaspersky-squid';
       cmd:=cmd+' /home/dtouzeau/Bureau/artica-compile/artica-squid-security-'+GET_CONTROL_VERSION('/home/dtouzeau/source-export/kaspersky-squid/DEBIAN/control')+'.deb';
       Execute(cmd);
       cmd:='cd ' + DestPath + ' && alien -r --scripts '+ SourcePath + '/artica-squid-security-'+ GET_CONTROL_VERSION('/home/dtouzeau/source-export/kaspersky-squid/DEBIAN/control')+'.deb';
       Execute(cmd);
       halt(0);
    end;
    
    if COMMANDLINE_PARAMETERS('--ksamba') then begin
       forcedirectories(DestPath);
       cmd:='dpkg-deb -b /home/dtouzeau/source-export/kavsamba';
       cmd:=cmd+' /home/dtouzeau/Bureau/artica-compile/artica-samba-security-1.0.deb';
       Execute(cmd);
       cmd:='cd ' + DestPath + ' && alien -r --scripts '+ SourcePath + '/artica-samba-security-1.0.deb';
       Execute(cmd);
       halt(0);
    end;
    
    if COMMANDLINE_PARAMETERS('--dansguardian') then begin
       forcedirectories(DestPath);
       cmd:='dpkg-deb -b /home/dtouzeau/source-export/dansguardian';
       cmd:=cmd+' /home/dtouzeau/Bureau/artica-compile/dansguardian-'+GET_CONTROL_VERSION('/home/dtouzeau/source-export/dansguardian/DEBIAN/control')+'.deb';
       Execute(cmd);
       //cmd:='cd ' + DestPath + ' && alien -r --scripts '+ SourcePath + '/artica-samba-security-1.0.deb';
       //Execute(cmd);
       halt(0);
    end;
    
    

    
    if COMMANDLINE_PARAMETERS('--webmail') then begin
       forcedirectories(SourcePath);
       verrr:=GET_CONTROL_VERSION('/home/dtouzeau/source-export/artica-webmail/DEBIAN/control');
       patchedDir:=SourcePath + '/artica-postfix-webmail-' + verrr;
       cmd:='dpkg-deb -b /home/dtouzeau/source-export/artica-webmail';
       cmd:=cmd + ' /home/dtouzeau/Bureau/artica-compile/artica-postfix-webmail-' + verrr + '.deb';
       Execute(cmd);
       if FileExists(patchedDir) then fpsystem('/bin/rm -rf ' + patchedDir);
       Execute('cd '+ SourcePath +' && alien -r -g --scripts '+ SourcePath + '/artica-postfix-webmail-' + verrr + '.deb');
       


       patchfile:=patchedDir+'/artica-postfix-webmail-' + verrr+'-2.spec';
       writeln(patchfile);
       
       if directoryExists(patchedDir) then begin
             if PATCHING_SPECFILE(patchedDir) then begin
                Execute('cd ' + patchedDir + ' && rpmbuild -bb '+ patchfile);
             end else begin
               writeln('unable to patch !!! ' +patchedDir);
             end;
       end else begin
           writeln('unable to stat ' +patchedDir);
       end;
       fpsystem('/bin/rm -rf ' + patchedDir);
    end;
    
    
    
    fpsystem('/bin/chown -R dtouzeau:dtouzeau '+SourcePath);
    
    if COMMANDLINE_PARAMETERS('--no-artica') then exit;
    
    
    
// Setup Family --------------------------------------------------------------------------------------------------------
ForceDirectories(DestPath);
ForceDirectories(BackupPath);
ForceDirectories(DestPath + '/setup-web');
Execute('strip -s ' + BasePath + '/bin/setup-ubuntu');
Writeln('STRIP artica-postfix/bin/setup-ubuntu');
Execute('rm -f ' + BasePath+'/bin/setup-suse');
Execute('rm -f ' + BasePath+'/bin/setup-fedora');
Execute('rm -f ' + BasePath+'/bin/setup-debian');
Execute('rm -f ' + BasePath+'/bin/setup-centos');
Execute('rm -f ' + BasePath+'/bin/setup-mandrake');

Execute('cp ' + BasePath+'/bin/setup-ubuntu '+BasePath+'/bin/setup-suse');
Execute('cp ' + BasePath+'/bin/setup-ubuntu '+BasePath+'/bin/setup-fedora');
Execute('cp ' + BasePath+'/bin/setup-ubuntu '+BasePath+'/bin/setup-debian');
Execute('cp ' + BasePath+'/bin/setup-ubuntu '+BasePath+'/bin/setup-centos');
Execute('cp ' + BasePath+'/bin/setup-ubuntu '+BasePath+'/bin/setup-mandrake');

Execute('cd ' + ExtractFilePath(BasePath) + 'artica-postfix/bin && tar -czf '+ DestPath+'/setup-ubuntu-' + VERSION + '.tgz setup-ubuntu');

Execute('cd ' + ExtractFilePath(BasePath) + 'artica-postfix/bin && tar -czf '+ DestPath + '/setup-web/setup-ubuntu.tgz setup-ubuntu');

Execute('cd ' + ExtractFilePath(BasePath) + 'artica-postfix/bin && tar -czf '+ DestPath+'/setup-suse-' + VERSION + '.tgz setup-suse');
Execute('cd ' + ExtractFilePath(BasePath) + 'artica-postfix/bin && tar -czf '+ DestPath + '/setup-web/setup-suse.tgz setup-suse');

Execute('cd ' + ExtractFilePath(BasePath) + 'artica-postfix/bin && tar -czf '+ DestPath+'/setup-fedora-' + VERSION + '.tgz setup-fedora');
Execute('cd ' + ExtractFilePath(BasePath) + 'artica-postfix/bin && tar -czf '+ DestPath + '/setup-web/setup-fedora.tgz setup-fedora');

Execute('cd ' + ExtractFilePath(BasePath) + 'artica-postfix/bin && tar -czf '+ DestPath+'/setup-debian-' + VERSION + '.tgz setup-debian');
Execute('cd ' + ExtractFilePath(BasePath) + 'artica-postfix/bin && tar -czf '+ DestPath + '/setup-web/setup-debian.tgz setup-debian');

Execute('cd ' + ExtractFilePath(BasePath) + 'artica-postfix/bin && tar -czf '+ DestPath+'/setup-centos-' + VERSION + '.tgz setup-centos');
Execute('cd ' + ExtractFilePath(BasePath) + 'artica-postfix/bin && tar -czf '+ DestPath + '/setup-web/setup-centos.tgz setup-centos');
Execute('cd ' + ExtractFilePath(BasePath) + 'artica-postfix/bin && tar -czf '+ DestPath + '/setup-web/setup-centos.tar.gz setup-centos');

Execute('cd ' + ExtractFilePath(BasePath) + 'artica-postfix/bin && tar -czf '+ DestPath + '/setup-web/setup-mandrake.tgz setup-mandrake');
Execute('cd ' + ExtractFilePath(BasePath) + 'artica-postfix/bin && tar -czf '+ DestPath+'/setup-mandrake-' + VERSION + '.tgz setup-mandrake');

fpsystem('/bin/chown -R dtouzeau:dtouzeau '+DestPath);
if COMMANDLINE_PARAMETERS('--setup') then exit;
// Setup Family --------------------------------------------------------------------------------------------------------
    
    
Execute('chown -R ' + CurrentUser + '  ' + BasePath);
Execute('rm -rf ' + BasePath + '/ressources/backup');
Execute('rm -rf ' + BasePath + '/ressources/conf/*');
Execute('rm -rf ' + BasePath + '/ressources/logs/*');
Execute('rm -rf ' + BasePath + '/ressources/userdb/*');
Execute('rm -rf ' + BasePath + '/ressources/settings.inc');
Execute('rm -rf ' + BasePath + '/ressources/install/*');
Execute('rm -rf ' + BasePath + '/ressources/databases/*.cache');
Execute('rm -rf ' + BasePath + '/ressources/isoqlog');
ForceDirectories(BackupPath + '/artica-src');
ForceDirectories(BackupPath + '/artica-src/'+ tempdate);

    
Execute('cp -rf ' +BasePath + '/bin/src ' + BackupPath + '/artica-src/'+ tempdate);

writeln('Compress source code....');
Execute('cd ' + BackupPath + '/artica-src && tar -czf '+DestPath+ '/artica-' + tempdate + '-fpc.tgz ' + tempdate);

Execute ('chown -R ' + CurrentUser + '  ' + DestPath);

if COMMANDLINE_PARAMETERS('--sources') then exit;


logs:=tlogs.Create;
VERSION:=trim(VERSION);
writeln('Writing new version '+VERSION +' ->'+BasePath + '/VERSION' );
logs.WriteToFile(trim(VERSION),BasePath + '/VERSION');
writeln('Writing new version '+VERSION +' ->'+BasePath + '/ressources/VERSION' );
logs.WriteToFile(trim(VERSION),BasePath + '/ressources/VERSION');

if trim(logs.ReadFromFile(BasePath + '/VERSION'))<>VERSION then begin
    writeln('WARNING VERSION !!! local version : '+trim(logs.ReadFromFile(BasePath + '/VERSION'))+' is different than new version '+VERSION);
    exit;
end;


Execute ('/etc/init.d/artica-postfix stop watchdog');
Execute ('/etc/init.d/artica-postfix stop');

writeln('Remove compiled source code....');
Execute ('rm -rf ' + BasePath + '/bin/*.ppu');
Execute ('rm -rf ' + BasePath + '/bin/*.o');
Execute ('rm -rf ' + BasePath + '/bin/src/*.compiled');
Execute ('rm -f ' + BasePath + '/bin/setup-centos.tar.gz');
Execute ('rm -f ' + BasePath + '/bin/st4Czo31');
Execute ('rm -f ' + BasePath + '/bin/st4skT5C');
Execute ('rm -f ' + BasePath + '/bin/stANVwuK');
Execute ('rm -f ' + BasePath + '/bin/stApAicl');
Execute ('rm -f ' + BasePath + '/bin/stGzrbwf');
Execute ('rm -f ' + BasePath + '/bin/stk8VPJq');
Execute ('rm -f ' + BasePath + '/bin/stkPQQSb');
Execute ('rm -f ' + BasePath + '/bin/stpLqWwo');
Execute ('rm -f ' + BasePath + '/bin/stq74yeJ');
Execute ('rm -f ' + BasePath + '/bin/stQGqqBv');
Execute ('rm -f ' + BasePath + '/bin/stS7fSvN');
Execute ('rm -f ' + BasePath + '/bin/stuheP33');
Execute ('rm -f ' + BasePath + '/bin/stWmx0VR');
Execute ('rm -f ' + BasePath + '/bin/st1UEWR6');
Execute ('rm -f ' + BasePath + '/bin/st2ts1lW');
Execute ('rm -f ' + BasePath + '/bin/st2YCULj');
Execute ('rm -f ' + BasePath + '/bin/st3ZcYk5');
Execute ('rm -f ' + BasePath + '/bin/st4rHMfp');
Execute ('rm -f ' + BasePath + '/bin/st4zKJCw');
Execute ('rm -f ' + BasePath + '/bin/st54SLK4');
Execute ('rm -f ' + BasePath + '/bin/st60evAY');
Execute ('rm -f ' + BasePath + '/bin/st6WaasS');
Execute ('rm -f ' + BasePath + '/bin/st6x6R6P');
Execute ('rm -f ' + BasePath + '/bin/st8uk6KS');
Execute ('rm -f ' + BasePath + '/bin/st9Dh1bJ');
Execute ('rm -f ' + BasePath + '/bin/stAG8dV2');
Execute ('rm -f ' + BasePath + '/bin/stAgiYhj');
Execute ('rm -f ' + BasePath + '/bin/stAODD4S');
Execute ('rm -f ' + BasePath + '/bin/stbFFo9B');
Execute ('rm -f ' + BasePath + '/bin/stbNDJIY');
Execute ('rm -f ' + BasePath + '/bin/stBrpD86');
Execute ('rm -f ' + BasePath + '/bin/stc6k2Jg');
Execute ('rm -f ' + BasePath + '/bin/stcGspbL');
Execute ('rm -f ' + BasePath + '/bin/stckXrjb');
Execute ('rm -f ' + BasePath + '/bin/stcmsVQe');
Execute ('rm -f ' + BasePath + '/bin/stdc1mcN');
Execute ('rm -f ' + BasePath + '/bin/stdt4NMi');
Execute ('rm -f ' + BasePath + '/bin/stdt6yf4');
Execute ('rm -f ' + BasePath + '/bin/ste5w3qt');
Execute ('rm -f ' + BasePath + '/bin/steD3uK8');
Execute ('rm -f ' + BasePath + '/bin/stEsftqU');
Execute ('rm -f ' + BasePath + '/bin/stEYYHoB');
Execute ('rm -f ' + BasePath + '/bin/stFdWyse');
Execute ('rm -f ' + BasePath + '/bin/stfQgMrV');
Execute ('rm -f ' + BasePath + '/bin/stg1xC2m');
Execute ('rm -f ' + BasePath + '/bin/stGbsK89');
Execute ('rm -f ' + BasePath + '/bin/stgfFnLn');
Execute ('rm -f ' + BasePath + '/bin/sthijxla');
Execute ('rm -f ' + BasePath + '/bin/stI5Uii9');
Execute ('rm -f ' + BasePath + '/bin/stIFOQ6A');
Execute ('rm -f ' + BasePath + '/bin/stiWMsO0');
Execute ('rm -f ' + BasePath + '/bin/stjcbo70');
Execute ('rm -f ' + BasePath + '/bin/stjPhO7Y');
Execute ('rm -f ' + BasePath + '/bin/stk1I07D');
Execute ('rm -f ' + BasePath + '/bin/stk2NNK6');
Execute ('rm -f ' + BasePath + '/bin/stkHOh0b');
Execute ('rm -f ' + BasePath + '/bin/stkk4uf1');
Execute ('rm -f ' + BasePath + '/bin/stKSMU4T');
Execute ('rm -f ' + BasePath + '/bin/stLefdsD');
Execute ('rm -f ' + BasePath + '/bin/stlQ2Cfy');
Execute ('rm -f ' + BasePath + '/bin/stlqjrgi');
Execute ('rm -f ' + BasePath + '/bin/stLV0DNb');
Execute ('rm -f ' + BasePath + '/bin/stLwyPuU');
Execute ('rm -f ' + BasePath + '/bin/stLzSKJQ');
Execute ('rm -f ' + BasePath + '/bin/stmAcBmt');
Execute ('rm -f ' + BasePath + '/bin/stmGUDH3');
Execute ('rm -f ' + BasePath + '/bin/stMMvXcI');
Execute ('rm -f ' + BasePath + '/bin/stMSOCis');
Execute ('rm -f ' + BasePath + '/bin/stN1BEmy');
Execute ('rm -f ' + BasePath + '/bin/stN4X7xl');
Execute ('rm -f ' + BasePath + '/bin/stnAZzMp');
Execute ('rm -f ' + BasePath + '/bin/stNDlpso');
Execute ('rm -f ' + BasePath + '/bin/stnJww2A');
Execute ('rm -f ' + BasePath + '/bin/stnvtIlh');
Execute ('rm -f ' + BasePath + '/bin/stO7Fgay');
Execute ('rm -f ' + BasePath + '/bin/stOJu8AF');
Execute ('rm -f ' + BasePath + '/bin/stol4Eyg');
Execute ('rm -f ' + BasePath + '/bin/stoqf1tD');
Execute ('rm -f ' + BasePath + '/bin/stOv5zjc');
Execute ('rm -f ' + BasePath + '/bin/stP25bp7');
Execute ('rm -f ' + BasePath + '/bin/stpeAzKY');
Execute ('rm -f ' + BasePath + '/bin/stprCi3e');
Execute ('rm -f ' + BasePath + '/bin/stPUBfPs');
Execute ('rm -f ' + BasePath + '/bin/stpvSGAd');
Execute ('rm -f ' + BasePath + '/bin/stQ9tLKh');
Execute ('rm -f ' + BasePath + '/bin/stQaZGZW');
Execute ('rm -f ' + BasePath + '/bin/stQbl2Lv');
Execute ('rm -f ' + BasePath + '/bin/stqCFLrG');
Execute ('rm -f ' + BasePath + '/bin/stQGHRfr');
Execute ('rm -f ' + BasePath + '/bin/stQGZmti');
Execute ('rm -f ' + BasePath + '/bin/stqSRAIw');
Execute ('rm -f ' + BasePath + '/bin/strBdNFw');
Execute ('rm -f ' + BasePath + '/bin/strDIKTV');
Execute ('rm -f ' + BasePath + '/bin/stRPa1bg');
Execute ('rm -f ' + BasePath + '/bin/strPjuCQ');
Execute ('rm -f ' + BasePath + '/bin/stsxvwI5');
Execute ('rm -f ' + BasePath + '/bin/stt3klvz');
Execute ('rm -f ' + BasePath + '/bin/sttHMity');
Execute ('rm -f ' + BasePath + '/bin/stTNiekA');
Execute ('rm -f ' + BasePath + '/bin/stTXrcU7');
Execute ('rm -f ' + BasePath + '/bin/stuXdvtB');
Execute ('rm -f ' + BasePath + '/bin/stUyQowO');
Execute ('rm -f ' + BasePath + '/bin/stVDy6HD');
Execute ('rm -f ' + BasePath + '/bin/stvljZrB');
Execute ('rm -f ' + BasePath + '/bin/stvMTs1y');
Execute ('rm -f ' + BasePath + '/bin/stVqGLSa');
Execute ('rm -f ' + BasePath + '/bin/stwgjPn3');
Execute ('rm -f ' + BasePath + '/bin/stWiIcnO');
Execute ('rm -f ' + BasePath + '/bin/stx95o4r');
Execute ('rm -f ' + BasePath + '/bin/stXtNnq7');
Execute ('rm -f ' + BasePath + '/bin/stxUDRZp');
Execute ('rm -f ' + BasePath + '/bin/sty1r4iG');
Execute ('rm -f ' + BasePath + '/bin/stY9lLjl');
Execute ('rm -f ' + BasePath + '/bin/stYAAlAZ');
Execute ('rm -f ' + BasePath + '/bin/styisaBY');
Execute ('rm -f ' + BasePath + '/bin/stypqcFj');
Execute ('rm -f ' + BasePath + '/bin/stz5lH2H');
Execute ('rm -f ' + BasePath + '/bin/stZbUs94');
Execute('strip -s ' + BasePath + '/bin/artica-install');
Writeln('STRIP artica-postfix/bin/artica-install');
Execute('strip -s ' + BasePath + '/bin/install-sql');
Writeln('STRIP artica-postfix/bin/install-sql');
Execute('strip -s ' + BasePath + '/bin/articacgi');
Writeln('STRIP artica-postfix/bin/articacgi');
Execute('strip -s ' + BasePath + '/bin/artica-filter');
Writeln('STRIP artica-postfix/bin/artica-filter');
Execute('strip -s ' + BasePath + '/bin/artica-mime');
Writeln('STRIP artica-postfix/bin/artica-mime');
Execute('strip -s ' + BasePath + '/bin/artica-sql');
Writeln('STRIP artica-postfix/bin/artica-sql');
Execute('strip -s ' + BasePath + '/bin/artica-sql-cron');
Writeln('STRIP artica-postfix/bin/artica-sql-cron');
Execute('strip -s ' + BasePath + '/bin/process1');
Writeln('STRIP artica-postfix/bin/process1');
Execute('strip -s ' + BasePath + '/bin/process2');
Writeln('STRIP artica-postfix/bin/process2');
Execute('strip -s ' + BasePath + '/bin/process3');
Writeln('STRIP artica-postfix/bin/process3');
Execute('strip -s ' + BasePath + '/bin/artica-dbf');
Writeln('STRIP artica-postfix/bin/artica-dbf');
Execute('strip -s ' + BasePath + '/bin/artica-quarantine');
Writeln('STRIP artica-postfix/bin/artica-quarantine');
Execute('strip -s ' + BasePath + '/bin/artica-get');
Writeln('STRIP artica-postfix/bin/artica-get');
Execute('strip -s ' + BasePath + '/bin/artica-ldap');
Writeln('STRIP artica-postfix/bin/artica-ldap');
Execute('strip -s ' + BasePath + '/bin/artica-kavmilterd');
Writeln('STRIP artica-postfix/bin/artica-kavmilterd');
Execute('strip -s ' + BasePath + '/bin/artica-compile');
Writeln('STRIP artica-postfix/bin/artica-compile');
Execute('strip -s ' + BasePath + '/bin/artica-update');
Writeln('STRIP artica-postfix/bin/artica-update');
Execute('strip -s ' + BasePath + '/bin/artica-tail');
Writeln('STRIP artica-postfix/bin/artica-tail');
Execute('strip -s ' + BasePath + '/bin/artica-mimedefang-pipe');
Writeln('STRIP artica-postfix/bin/artica-mimedefang-pipe');
Execute('strip -s ' + BasePath + '/bin/artica-sharedfolders');
Writeln('STRIP artica-postfix/bin/artica-sharedfolders');
Execute('strip -s ' + BasePath + '/bin/artica-resend');
Writeln('STRIP artica-postfix/bin/artica-resend');
Execute('strip -s ' + BasePath + '/bin/artica-thread-back');
Writeln('STRIP artica-postfix/bin/artica-thread-back');
Execute('strip -s ' + BasePath + '/bin/artica-tail-syslog');
Writeln('STRIP artica-postfix/bin/artica-tail-syslog');
Execute('strip -s ' + BasePath + '/bin/artica-mailgraph');
Writeln('STRIP artica-postfix/bin/artica-mailgraph');
Execute('strip -s ' + BasePath + '/bin/artica-interface');
Writeln('STRIP artica-postfix/bin/artica-interface');
Execute('strip -s ' + BasePath + '/bin/artica-ad');
Writeln('STRIP artica-postfix/bin/artica-ad');
Execute('strip -s ' + BasePath + '/bin/index.cgi');
Writeln('STRIP artica-postfix/bin/index.cgi');
Execute('strip -s ' + BasePath + '/bin/artica-apt');
Writeln('STRIP artica-postfix/bin/artica-apt');
Execute('strip -s ' + BasePath + '/bin/artica-backup');
Writeln('STRIP artica-postfix/bin/artica-backup');
Execute('strip -s ' + BasePath + '/bin/artica-backup-share');
Writeln('STRIP artica-postfix/bin/artica-backup-share');
Execute('strip -s ' + BasePath + '/bin/artica-iso');
Writeln('STRIP artica-postfix/bin/artica-iso');
Execute('strip -s ' + BasePath + '/bin/artica-notif');
Writeln('STRIP artica-postfix/bin/artica-notif');
Execute('strip -s ' + BasePath + '/bin/artica-mailarchive');
Writeln('STRIP artica-postfix/bin/artica-mailarchive');

Execute('strip -s ' + BasePath + '/bin/artica-roundcube');
Writeln('STRIP artica-postfix/bin/artica-roundcube');

Execute('strip -s ' + BasePath + '/bin/artica-bogom');
Writeln('STRIP artica-postfix/bin/artica-bogom');

Execute('strip -s ' + BasePath + '/bin/setup-ubuntu');
Writeln('STRIP artica-postfix/bin/setup-ubuntu');

Execute('strip -s ' + BasePath + '/bin/artica-orders');
Writeln('STRIP artica-postfix/bin/artica-orders');

Execute('strip -s ' + BasePath + '/bin/artica-make');
Writeln('STRIP artica-postfix/bin/artica-make');

Execute('strip -s ' + BasePath + '/bin/artica-attachments');
Writeln('STRIP artica-postfix/bin/artica-attachments');

Execute('strip -s ' + BasePath + '/bin/artica-learn');
Writeln('STRIP artica-postfix/bin/artica-learn');

Execute('strip -s ' + BasePath + '/bin/artica-mysqlpost');
Writeln('STRIP artica-postfix/bin/artica-mysqlpost');

Execute('strip -s ' + BasePath + '/bin/artica-whitelist');
Writeln('STRIP artica-postfix/bin/artica-whitelist');



if FileExists(BasePath + '/bin/artica-filter-smtp-out') then begin
   Execute('strip -s ' + BasePath + '/bin/artica-filter-smtp-out');
   Writeln('STRIP artica-postfix/bin/artica-filter-smtp-out');
end;

if FileExists(BasePath + '/bin/artica-logon') then begin
   Execute('strip -s ' + BasePath + '/bin/artica-logon');
   Writeln('STRIP artica-postfix/bin/artica-logon');
end;


if FileExists(BasePath + '/bin/artica-dansguardian-stats') then begin
   Execute('strip -s ' + BasePath + '/bin/artica-dansguardian-stats');
   Writeln('STRIP artica-postfix/bin/artica-dansguardian-stats');
end;



fpsystem('/bin/cp /usr/share/artica-postfix/bin/artica-msmtp.bk /usr/share/artica-postfix/bin/artica-msmtp');

SyncUSerBackup();

Execute('rm ' + BasePath+'/bin/*.gz');
Execute('rm ' + BasePath+'/*.gz');
Execute('rm -f ' + BasePath+'/ressources/settings.inc');
Execute('rm -f ' + BasePath+'/ressources/settings.new.inc');
Execute('rm -f ' + BasePath+'/PATCH');
Execute('rm -f ' + BasePath+'/PATCHS_HISTORY');
Execute('rm -rf ' + BasePath+'/ressources/logs/*');
Execute('rm -rf ' + BasePath+'/ressources/dar_collection');
Execute('rm -rf ' + BasePath+'/artica-install');
Execute('rm -f ' + BasePath+'/class.templates.inc');
Execute('rm -rf ' + BasePath+'/user-backup/ressources/profiles/icons/*.*');
Execute('rm -rf ' + BasePath+'/user-backup/ressources/conf/upload/*.*');
Execute('php5 /usr/share/artica-postfix/exec.shm.php --compile-lang');





cmd:='cd ' + ExtractFilePath(BasePath) + ' && tar -czf '+ DestPath+'/artica-' + VERSION + '.tgz artica-postfix';
cmd:=cmd + ' --exclude artica-postfix/bin/src';
cmd:=cmd + ' --exclude artica-postfix/bin/install/kas-linux-install';
cmd:=cmd + ' --exclude artica-postfix/bin/install/kav4mailservers-linux-install';
cmd:=cmd + ' --exclude artica-postfix/bin/install/roundcubemail';
cmd:=cmd + ' --exclude artica-postfix/bin/install/kas-linux-mp1';
cmd:=cmd + ' --exclude artica-postfix/LocalDatabases';
cmd:=cmd + ' --exclude artica-postfix/bin/oldlibs';
cmd:=cmd + ' --exclude artica-postfix/ressources/profiles';
cmd:=cmd + ' --exclude artica-postfix/ressources/ldap-back';
cmd:=cmd + ' --exclude artica-postfix/webmail';
cmd:=cmd + ' --exclude artica-postfix/amavis';
cmd:=cmd + ' --exclude artica-postfix/ldap';
cmd:=cmd + ' --exclude artica-postfix/mysql';
cmd:=cmd + ' --exclude artica-postfix/certs';
cmd:=cmd + ' --exclude artica-postfix/sql';
cmd:=cmd + ' --exclude artica-postfix/roundcube';
cmd:=cmd + ' --exclude artica-postfix/oma';
cmd:=cmd + ' --exclude artica-postfix/etc';
cmd:=cmd + ' --exclude artica-postfix/groupware';
cmd:=cmd + ' --exclude artica-postfix/groupware';
cmd:=cmd + ' --exclude artica-postfix/certs';
cmd:=cmd + ' --exclude artica-postfix/bin/artica-compile';
cmd:=cmd + ' --exclude artica-postfix/bin/setup-centos';
cmd:=cmd + ' --exclude artica-postfix/bin/setup-mandrake';
cmd:=cmd + ' --exclude artica-postfix/bin/setup-fedora';
cmd:=cmd + ' --exclude artica-postfix/bin/setup-debian';
cmd:=cmd + ' --exclude artica-postfix/bin/setup-suse';
cmd:=cmd + ' --exclude artica-postfix/bin/artica-bogom';
cmd:=cmd + ' --exclude artica-postfix/bin/clear';
cmd:=cmd + ' --exclude artica-postfix/bin/artica-mimedefang-pipe';
cmd:=cmd + ' --exclude artica-postfix/ressources/sessions/SessionData';
cmd:=cmd + ' --exclude artica-postfix/ressources/isoqlog';
cmd:=cmd + ' --exclude artica-postfix/ressources/psps.inc';
cmd:=cmd + ' --exclude artica-postfix/ressources/scan.printers.drivers.inc';
cmd:=cmd + ' --exclude artica-postfix/ressources/processes.inc';
cmd:=cmd + ' --exclude artica-postfix/ressources/logs/';
cmd:=cmd + ' --exclude artica-postfix/ressources/language/en';
cmd:=cmd + ' --exclude artica-postfix/ressources/language/fr';
cmd:=cmd + ' --exclude artica-postfix/ressources/language/it';
cmd:=cmd + ' --exclude artica-postfix/ressources/language/po';
cmd:=cmd + ' --exclude artica-postfix/ressources/language/de';
cmd:=cmd + ' --exclude artica-postfix/ressources/language/es';
cmd:=cmd + ' --exclude artica-postfix/artica-install';
cmd:=cmd + ' --exclude artica-postfix/user-backup/.cache';
cmd:=cmd + ' --exclude artica-postfix/user-backup/.settings';
cmd:=cmd + ' --exclude artica-postfix/user-backup/php_logs';
cmd:=cmd + ' --exclude artica-postfix/.settings';
cmd:=cmd + ' --exclude artica-postfix/ressources/ldap-back';
cmd:=cmd + ' --exclude artica-postfix/ressources/sock';
cmd:=cmd + ' --exclude artica-postfix/zabbix';

Execute(cmd);

if COMMANDLINE_PARAMETERS('--single-tgz') then exit;


if COMMANDLINE_PARAMETERS('--old-cd') then begin
   forceDirectories(DestPath + '/CD-ROM/compile');
   forceDirectories(DestPath + '/CD-ROM/files/home/artica/artica-' + VERSION + '.tgz');
   forceDirectories(DestPath + '/CD-ROM/files/home/artica/artica-' + VERSION + '-core.tgz');
   forceDirectories(DestPath + '/CD-ROM/files/etc/init.d/artica-cd');
   forceDirectories(DestPath + '/CD-ROM/hooks');

   cmd:='cp ' + DestPath+'/artica-' + VERSION + '.tgz  ' + DestPath + '/CD-ROM/files/home/artica/artica-' + VERSION + '.tgz/DEFAULT';
   Execute(cmd);

   cmd:='cp -rf /home/dtouzeau/source-export/bogo/* '+ DestPath+'/CD-ROM/compile/';
   Execute(cmd);
   cmd:='cp -rf /home/dtouzeau/source-export/artica-deb/* '+ DestPath+'/CD-ROM/compile/';
   Execute(cmd);
   cmd:='cp -rf /home/dtouzeau/source-export/security/* '+ DestPath+'/CD-ROM/compile/';
   Execute(cmd);
   cmd:='/bin/rm -rf '+ DestPath+'/CD-ROM/compile/usr/share/artica-postfix';
   Execute(cmd);
   cmd:='/bin/rm -rf '+ DestPath+'/CD-ROM/compile/usr/share/artica-postfix';
   Execute(cmd);
   cmd:='cd ' + DestPath + '/CD-ROM/compile &&  tar -czf '+ DestPath+'/artica-core-cdrom.tgz *';
   Execute(cmd);
   cmd:='mv '+ DestPath+'/artica-core-cdrom.tgz ' + DestPath + '/CD-ROM/files/home/artica/artica-' + VERSION + '-core.tgz/DEFAULT';
   Execute(cmd);
   cmd:='/bin/rm -rf '+ DestPath+'/CD-ROM/compile';
   Execute(cmd);
   Execute ('chown -R ' + CurrentUser + '  ' + DestPath);
   SAVE_CDROM_HOOKS(VERSION,DestPath);
   SAVE_CDROM_INIT_D(VERSION,DestPath);
   if COMMANDLINE_PARAMETERS('--cdrom') then exit;
end;


Execute('rm -rf /home/dtouzeau/source-export/artica-deb/usr/share');
ForceDirectories('/home/dtouzeau/source-export/artica-deb/usr/share');
Execute('cp -rf '+ BasePath +' /home/dtouzeau/source-export/artica-deb/usr/share/');
Execute('rm -rf /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/userdb');
Execute('rm -rf /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/bin/mailgraph');
Execute('rm -rf /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/bin/oldlibs');
Execute('rm -rf /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/bin/yorhel-rrd');
Execute('rm -rf /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/bin/process3');
Execute('rm -rf /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/ldap');
Execute('rm -rf /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/mysql');
Execute('rm -rf /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/bin/oldlib');
Execute('rm -rf /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/bin/src');
Execute('rm -rf /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/phpldapadmin');
Execute('rm -rf /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/LocalDatabases');
Execute('rm -rf /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/webmail');
Execute('rm -rf /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/ldap');
Execute('rm -rf /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/mysql');
Execute('rm -rf /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/david.touzeau@klf.fr');
Execute('rm -rf /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/roundcube');
Execute('rm -rf /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/oma');
Execute('rm -rf /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/groupware');
Execute('rm -rf /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/ressources/profile');
Execute('rm -rf /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/ressources/ldap-back/*');
Execute('rm -rf /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/ressources/logs/*');
Execute('rm -rf /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/ressources/psps.inc');
Execute('rm -rf /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/ressources/scan.printers.drivers.inc');
Execute('rm -rf /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/certs/*');
Execute('rm -f  /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/bin/install/parse_avstat.pl');
Execute('rm -f  /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/bin/install/kavgroup/kas-compile-artica.pl');
Execute('rm -f  /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/bin/*.gz');
Execute('rm -f  /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/bin/artica-compile');
Execute('rm -f  /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/bin/setup-centos');
Execute('rm -f  /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/bin/setup-mandrake');
Execute('rm -f  /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/bin/setup-fedora');
Execute('rm -f  /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/bin/setup-debian');
Execute('rm -f  /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/bin/setup-suse');
Execute('rm -f  /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/bin/artica-mimedefang-pipe');
Execute('rm -r  /home/dtouzeau/source-export/artica-deb/usr/share/artica-postfix/ressources/sessions/SessionData/*');

Execute('rm -rf /home/dtouzeau/source-export/artica2/usr/share');
Execute('/bin/cp -rf /home/dtouzeau/source-export/artica-deb/usr /home/dtouzeau/source-export/artica2/');
if DirectoryExists('/home/dtouzeau/source-export/artica2/usr/share/artica-postfix/david.touzeau@klf.fr') then begin
   Execute('rm -rf /home/dtouzeau/source-export/artica2/usr/share/artica-postfix/david.touzeau@klf.fr');
end;

Execute('rm -rf /home/dtouzeau/source-export/artica2/usr/share/artica-postfix/roundcube');
Execute('rm -rf /home/dtouzeau/source-export/artica2/usr/share/artica-postfix/oma');

GLOBAL_INI.BuildDeb('/home/dtouzeau/source-export/artica2/DEBIAN/control',VERSION);
Execute('dpkg-deb -b /home/dtouzeau/source-export/artica2 '+DestPath + '/artica-postfix-' + VERSION + '.deb');
Execute('chown -R ' + CurrentUser + '  ' + DestPath);



writeln('Creating RPM File');
Execute('cd '+ DestPath +' && alien -r -g --scripts '+ DestPath + '/artica-postfix-' + VERSION + '.deb');

if DirectoryExists(DestPath + '/artica-postfix-' + VERSION) then begin

end else begin
    writeln('Unable to stat ' + DestPath + '/artica-postfix-' + VERSION);
    readln();
    halt(0);
end;

    if not PATCHING_SPECFILE(DestPath + '/artica-postfix-' + VERSION) then begin
      writeln('Unable to patch spec file !!!');
      readln();
      halt(0);
    end;

     Execute('cd ' + DestPath + '/artica-postfix-' + VERSION + ' && rpmbuild -bb '+ DestPath + '/artica-postfix-' + VERSION + '/' + TargetSpecFile);
     fpsystem('rm -rf ' + DestPath + '/artica-postfix-' + VERSION);
     Execute('chown -R ' + CurrentUser + '  ' + DestPath);



     Execute('chown -R ' + CurrentUser + '  ' + DestPath);
exit;
     
     
     fpsystem('/opt/artica/bin/curl -T ' +DestPath + '/artica-'+VERSION+'.tgz ftp://sys_artica:0enZA9KV2u@imu144.infomaniak.ch/tmpf/');
     fpsystem('/opt/artica/bin/curl -T ' +DestPath + '/artica-php-src.tgz ftp://sys_artica:0enZA9KV2u@imu144.infomaniak.ch/tmpf/');
     fpsystem('/opt/artica/bin/curl -T ' +DestPath + '/artica-postfix-'+VERSION+'.deb ftp://sys_artica:0enZA9KV2u@imu144.infomaniak.ch/tmpf/');
     fpsystem('/opt/artica/bin/curl -T ' +DestPath + '/artica-postfix-'+VERSION+'-2.i386.rpm ftp://sys_artica:0enZA9KV2u@imu144.infomaniak.ch/tmpf/');
     

    fpsystem('/opt/artica/bin/curl -T ' +DestPath + '/artica-'+VERSION+'.tgz ftp://upload.sourceforge.net/incoming/');
    fpsystem('/opt/artica/bin/curl -T ' +DestPath + '/artica-postfix-'+VERSION+'.deb ftp://upload.sourceforge.net/incoming/');
    fpsystem('/opt/artica/bin/curl -T ' +DestPath + '/artica-postfix-'+VERSION+'-2.i386.rpm ftp://upload.sourceforge.net/incoming/');

end;
//##############################################################################
procedure tcompile.SyncUSerBackup();
begin
Execute('cp -f /usr/share/artica-postfix/ressources/class.cron.inc /usr/share/artica-postfix/user-backup/ressources/class.cron.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.amavis.inc /usr/share/artica-postfix/user-backup/ressources/class.amavis.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.sockets.inc /usr/share/artica-postfix/user-backup/ressources/class.sockets.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.ldap.inc /usr/share/artica-postfix/user-backup/ressources/class.ldap.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.html.pages.inc /usr/share/artica-postfix/user-backup/ressources/class.html.pages.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.main_cf.inc /usr/share/artica-postfix/user-backup/ressources/class.main_cf.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.ini.inc /usr/share/artica-postfix/user-backup/ressources/class.ini.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.system.network.inc /usr/share/artica-postfix/user-backup/ressources/class.system.network.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.cyrus.inc /usr/share/artica-postfix/user-backup/ressources/class.cyrus.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.status.inc /usr/share/artica-postfix/user-backup/ressources/class.status.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.ssl.certificate.inc /usr/share/artica-postfix/user-backup/ressources/class.ssl.certificate.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.artica.inc /usr/share/artica-postfix/user-backup/ressources/class.artica.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.mimedefang.inc /usr/share/artica-postfix/user-backup/ressources/class.mimedefang.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.tcpip.inc /usr/share/artica-postfix/user-backup/ressources/class.tcpip.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.dnsmasq.inc /usr/share/artica-postfix/user-backup/ressources/class.dnsmasq.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.obm.inc /usr/share/artica-postfix/user-backup/ressources/class.obm.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.sqlgrey.inc /usr/share/artica-postfix/user-backup/ressources/class.sqlgrey.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.milter.greylist.inc /usr/share/artica-postfix/user-backup/ressources/class.milter.greylist.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.kavmilterd.inc /usr/share/artica-postfix/user-backup/ressources/class.kavmilterd.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.users.menus.inc /usr/share/artica-postfix/user-backup/ressources/class.users.menus.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.samba.inc /usr/share/artica-postfix/user-backup/ressources/class.samba.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.spamassassin.inc /usr/share/artica-postfix/user-backup/ressources/class.spamassassin.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.kavmilterd.inc /usr/share/artica-postfix/user-backup/ressources/class.kavmilterd.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.images.inc /usr/share/artica-postfix/user-backup/ressources/class.images.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.user.inc /usr/share/artica-postfix/user-backup/ressources/class.user.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.fetchmail.inc /usr/share/artica-postfix/user-backup/ressources/class.fetchmail.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.cyrus-admin.inc /usr/share/artica-postfix/user-backup/ressources/class.cyrus-admin.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.apache.inc /usr/share/artica-postfix/user-backup/ressources/class.apache.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.openvpn.inc /usr/share/artica-postfix/user-backup/ressources/class.openvpn.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.pdns.inc /usr/share/artica-postfix/user-backup/ressources/class.pdns.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.domains.diclaimers.inc /usr/share/artica-postfix/user-backup/ressources/class.domains.diclaimers.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.computers.inc /usr/share/artica-postfix/user-backup/ressources/class.computers.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.ocs.inc  /usr/share/artica-postfix/user-backup/ressources/class.ocs.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.dhcpd.inc /usr/share/artica-postfix/user-backup/ressources/class.dhcpd.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.crypt.php /usr/share/artica-postfix/user-backup/ressources/class.crypt.php');
Execute('cp -f /usr/share/artica-postfix/ressources/class.bind9.inc /usr/share/artica-postfix/user-backup/ressources/class.bind9.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.xapian.inc /usr/share/artica-postfix/user-backup/ressources/class.xapian.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.langages.inc /usr/share/artica-postfix/user-backup/ressources/class.langages.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.dansguardian.inc /usr/share/artica-postfix/user-backup/ressources/class.dansguardian.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.squid.inc /usr/share/artica-postfix/user-backup/ressources/class.squid.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.semaphores.php /usr/share/artica-postfix/user-backup/ressources/class.semaphores.php');


Execute('cp -f /usr/share/artica-postfix/ressources/xapian.php /usr/share/artica-postfix/user-backup/ressources/xapian.php');
Execute('cp -f /usr/share/artica-postfix/computer.infos.php /usr/share/artica-postfix/user-backup/computer.infos.php');
Execute('cp -f /usr/share/artica-postfix/tree.php /usr/share/artica-postfix/user-backup/tree.php');

Execute('cp -f /usr/share/artica-postfix/ressources/class.kav4samba.inc /usr/share/artica-postfix/user-backup/ressources/class.kav4samba.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.lvm.org.inc /usr/share/artica-postfix/user-backup/ressources/class.lvm.org.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.os.system.inc /usr/share/artica-postfix/user-backup/ressources/class.os.system.inc');
Execute('cp -f /usr/share/artica-postfix/ressources/class.nfs.inc /usr/share/artica-postfix/user-backup/ressources/class.nfs.inc');
Execute('cp -f /usr/share/artica-postfix/js/samba.js /usr/share/artica-postfix/user-backup/js/samba.js');
Execute('cp -f /usr/share/artica-postfix/domains.edit.hd.php /usr/share/artica-postfix/user-backup/domains.edit.hd.php');
Execute('cp -f /usr/share/artica-postfix/SambaBrowse.php /usr/share/artica-postfix/user-backup/SambaBrowse.php');
Execute('cp -f /usr/share/artica-postfix/samba.index.php /usr/share/artica-postfix/user-backup/samba.index.php');
Execute('cp -f /usr/share/artica-postfix/dansguardian.index.php /usr/share/artica-postfix/user-backup/dansguardian.index.php');
Execute('cp -f /usr/share/artica-postfix/dansguardian.weight-phrases.php /usr/share/artica-postfix/user-backup/dansguardian.weight-phrases.php');
Execute('cp -f /usr/share/artica-postfix/dansguardian.categories.php  /usr/share/artica-postfix/user-backup/dansguardian.categories.php');
Execute('cp -f /usr/share/artica-postfix/dansguardian.banned-phrases.php  /usr/share/artica-postfix/user-backup/dansguardian.banned-phrases.php');
Execute('cp -f /usr/share/artica-postfix/dansguardian.banned-regex-purlist.php  /usr/share/artica-postfix/user-backup/dansguardian.banned-regex-purlist.php');
Execute('cp -f /usr/share/artica-postfix/dansguardian.exception.sites.php  /usr/share/artica-postfix/user-backup/dansguardian.exception.sites.php');
Execute('cp -f /usr/share/artica-postfix/dansguardian.banned-extensions.php  /usr/share/artica-postfix/user-backup/dansguardian.banned-extensions.php');
Execute('cp -f /usr/share/artica-postfix/dansguardian.banned-mime.php  /usr/share/artica-postfix/user-backup/dansguardian.banned-mime.php');
Execute('cp -f /usr/share/artica-postfix/dansguardian.exception.filesite.php  /usr/share/artica-postfix/user-backup/dansguardian.exception.filesite.php');
Execute('cp -f /usr/share/artica-postfix/dansguardian.categories.personnal.php    /usr/share/artica-postfix/user-backup/dansguardian.categories.personnal.php');

Execute('cp -f /usr/share/artica-postfix/css/rounded.css /usr/share/artica-postfix/user-backup/css/rounded.css');
Execute('cp -f /usr/share/artica-postfix/framework/class.unix.inc /usr/share/artica-postfix/user-backup/framework/class.unix.inc');
Execute('cp -rf /usr/share/artica-postfix/img/ext/* /usr/share/artica-postfix/user-backup/img/ext/');
Execute('rm -rf /usr/share/artica-postfix/user-backup/ressources/logs/*');

end;



function Tcompile.OPENSECURITY():boolean;
var
cmd:string;

begin
cmd:='dpkg-deb -b /home/dtouzeau/source-export/artica-amavis ';
cmd:=cmd + DestPath + '/artica-opensecurity-smtp-' + GET_CONTROL_VERSION('/home/dtouzeau/source-export/artica-amavis/DEBIAN/control')+'.deb';
Execute(cmd);

cmd:='cd ' + DestPath;
cmd:=cmd + ' && alien -r --scripts ' + DestPath+ '/artica-opensecurity-smtp-' + GET_CONTROL_VERSION('/home/dtouzeau/source-export/artica-amavis/DEBIAN/control') + '.deb';
Execute(cmd);

end;
//##############################################################################
function Tcompile.PATCHING_SPECFILE(path:string):boolean;
var
SYS:TSystem;
TargetFile:string;
i:integer;
s:TstringList;
RegExpr:TRegExpr;

begin
 result:=False;
SYS:=TSystem.Create;
SYS.DirFiles(path,'*.spec');

if SYS.DirListFiles.count=0 then exit;
TargetFile:=SYS.DirListFiles.Strings[0];
TargetSpecFile:=TargetFile;
writeln('Patching ' + TargetFile);

RegExpr:=TRegExpr.Create;
RegExpr.Expression:='%define';
s:=TstringList.Create;
s.LoadFromFile(path + '/' + TargetFile);
for i:=0 to s.Count do begin
    if RegExpr.Exec(s.Strings[i]) then begin
        writeln('Found line ',i,'%define _use_internal_dependency_generator 0');
        s.Insert(i,'%define _use_internal_dependency_generator 0');
         writeln('Found line ',i,'AutoReq: 0');
        s.Insert(i,'AutoReq: 0');
        s.SaveToFile(path + '/' + TargetFile);
        s.free;
        RegExpr.free;
        result:=true;
        
       //
        break;
    end;

end;
end;





Function Tcompile.GET_CONTROL_VERSION(path:string):string;
var
   i:integer;
   s:TstringList;
   RegExpr:TRegExpr;
begin
    s:=TstringList.Create;
    RegExpr:=TRegExpr.Create;
    RegExpr.Expression:='Version:(.+)';
    s.LoadFromFile(path);
    For i:=0 to s.Count-1 do begin
        if RegExpr.Exec(s.Strings[i]) then begin
           result:=trim(RegExpr.Match[1]);
           break;
        end;
    end;
    s.free;
    RegExpr.Free;
end;
//##############################################################################
Function Tcompile.GET_CONTROL_PACKAGE_NAME(path:string):string;
var
   i:integer;
   s:TstringList;
   RegExpr:TRegExpr;
begin
    s:=TstringList.Create;
    RegExpr:=TRegExpr.Create;
    RegExpr.Expression:='Package:(.+)';
    s.LoadFromFile(path);
    For i:=0 to s.Count-1 do begin
        if RegExpr.Exec(s.Strings[i]) then begin
           result:=trim(RegExpr.Match[1]);
           break;
        end;
    end;
    s.free;
    RegExpr.Free;
end;
//##############################################################################
function TCompile.COMMANDLINE_PARAMETERS(FoundWhatPattern:string):boolean;
var
   i:integer;
   s:string;
   RegExpr:TRegExpr;

begin
 result:=false;
 s:='';
 if ParamCount>0 then begin
     for i:=1 to ParamCount do begin
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
procedure TCompile.Execute(cmd:string);
begin
    writeln(cmd);
    fpsystem(cmd);

end;

procedure TCompile.SAVE_CDROM_HOOKS(xVERSION:string;xDestPath:string);
var
l:TstringList;
begin
l:=TstringList.Create;
l.Add('#! /bin/bash');
l.Add('');
l.Add('[ -s $target/etc/kernel-img.conf ] || fcopy -Bi /etc/kernel-img.conf');
l.Add('$ROOTCMD mkdir /home/artica');
l.Add('$ROOTCMD echo ""');
l.Add('$ROOTCMD echo "       ################################################"');
l.Add('$ROOTCMD echo "       ##                                            ##"');
l.Add('$ROOTCMD echo "       ##                   ARTICA                   ##"');
l.Add('$ROOTCMD echo "       ##                '+xVERSION+'                  ##"');
l.Add('$ROOTCMD echo "       ##                                            ##"');
l.Add('$ROOTCMD echo "       ################################################"');
l.Add('$ROOTCMD echo ""');
l.Add('$ROOTCMD echo "Waiting please... installing artica core package....."');
l.Add('fcopy -Bi /home/artica/artica-' + xVERSION + '-core.tgz');
l.Add('$ROOTCMD echo "Waiting please... installing artica daemons....."');
l.Add('fcopy -Bi /home/artica/artica-' + xVERSION + '.tgz');
l.Add('$ROOTCMD echo "Waiting please... Creating startup scripts....."');
l.Add('fcopy -Bi /etc/init.d/artica-cd');
l.Add('fcopy -Bi /home/artica/init-kav');
l.Add('$ROOTCMD chmod 777 /etc/init.d/artica-cd');
l.Add('$ROOTCMD update-rc.d artica-cd defaults 99');
l.SaveToFile(xDestPath + '/CD-ROM/hooks/instsoft.FAIBASE');
fpsystem('/bin/chmod 777 ' + xDestPath + '/CD-ROM/hooks/instsoft.FAIBASE');
end;


procedure TCompile.SAVE_CDROM_INIT_D(xVERSION:string;xDestPath:string);
var
l:TstringList;
begin
l:=TstringList.Create;
l.Add('#! /bin/sh');
l.Add('#Begin /etc/init.d/artica-cd');
l.Add('');
l.Add('case "$1" in');
l.Add(' start)');
l.Add('    echo "artica-cd... Extracting base..."');
l.Add('    /bin/tar -xf /home/artica/artica-' + xVERSION + '.tgz -C /usr/share/');
l.Add('    echo "artica-cd... Extracting Core..."');
l.Add('    /bin/tar -xf /home/artica/artica-' + xVERSION + '-core.tgz -C /');
l.Add('    echo "artica-cd... Running installation scripts..."');
l.Add('    /usr/share/artica-postfix/bin/artica-install --fromcdkav');
l.Add('    ;;');
l.Add('');
l.Add('  stop)');
l.Add('    ');
l.Add('    ;;');
l.Add('');
l.Add(' restart)');
l.Add('    ;;');
l.Add('');
l.Add('  *)');
l.Add('    echo "Usage: $0 {start|stop|}"');
l.Add('    exit 1');
l.Add('    ;;');
l.Add('esac');
l.Add('exit 0');
l.Add('');
l.Add('');
l.SaveToFile(xDestPath + '/CD-ROM/files/etc/init.d/artica-cd/DEFAULT');
end;
//##############################################################################
function TCompile.COMMANDLINE_EXTRACT_PARAMETERS(pattern:string):string;
var
   i:integer;
   s:string;
   RegExpr:TRegExpr;

begin
s:='';
 result:='';
 if ParamCount>0 then begin
     for i:=0 to ParamCount do begin
        s:=s  + ' ' +ParamStr(i);
     end;
 end;

         RegExpr:=TRegExpr.Create;
         RegExpr.Expression:=pattern;
         RegExpr.Exec(s);
         Result:=RegExpr.Match[1];
         RegExpr.Free;
end;
//##############################################################################

end.
