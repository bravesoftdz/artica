program artica_iso;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils,debian_class,unix
  { you can add units after this };

  var deb:tdebian;
begin



if not FileExists('/etc/artica-postfix/FROM_ISO') then halt(0);
deb:=tdebian.Create;
deb.ARTICA_CD_SOURCES_LIST();
deb.remove_bip();
deb.linuxlogo();

if FileExists('/etc/artica-postfix/artica-iso-first-reboot') then begin
       if not FileExists('/etc/artica-postfix/artica-iso-make-launched') then begin
          fpsystem('/bin/touch /etc/artica-postfix/artica-iso-setup-launched');
          //fpsystem('/usr/share/artica-postfix/bin/setup-ubuntu --check-base-system >/dev/null');
       end;
end;


if FileExists('/etc/artica-postfix/KASPER_INSTALL') then begin
     fpsystem('/usr/share/artica-postfix/bin/artica-make APP_KAS3');
     fpsystem('/usr/share/artica-postfix/bin/artica-make APP_KAVMILTER');
     fpsystem('/bin/rm -f /etc/artica-postfix/KASPER_INSTALL');
end;

 // TextColor(White);
 // TextBackground(Black);

if not FileExists('/etc/artica-postfix/artica-iso-first-reboot') then begin
    fpsystem('/bin/touch /etc/artica-postfix/artica-iso-first-reboot');
    fpsystem('/etc/init.d/artica-postfix stop');
    fpsystem('/etc/init.d/artica-postfix start');
    fpsystem('/usr/share/artica-postfix/bin/artica-install -awstats generate --verbose');
    fpsystem('echo "artica-cd... restart artica"');
    fpsystem('/bin/rm -rf /usr/share/artica-postfix/ressources/settings.inc');
    fpsystem('/etc/init.d/artica-postfix stop');
    fpsystem('/etc/init.d/artica-postfix start');
    fpsystem('/usr/share/artica-postfix/bin/process1 --verbose --yes');
    fpsystem('echo "artica-cd... remove init boot"');
    fpsystem('update-rc.d -f artica-cd remove');
    fpsystem('/bin/rm -f /etc/init.d/artica-cd');
    fpsystem('reboot');
end else begin
     if FileExists('/etc/init.d/artica-cd') then begin
        fpsystem('update-rc.d -f artica-cd remove');
        fpsystem('/bin/rm -f /etc/init.d/artica-cd');
    end;

end;

halt(0);


end.

