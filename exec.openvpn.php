<?php
if(posix_getuid()<>0){die("Cannot be used in web server mode\n\n");}
include_once(dirname(__FILE__) . '/ressources/class.users.menus.inc');
include_once(dirname(__FILE__) . '/ressources/class.mysql.inc');
include_once(dirname(__FILE__) . '/ressources/class.user.inc');
include_once(dirname(__FILE__) . '/ressources/class.ini.inc');
include_once(dirname(__FILE__) . '/ressources/class.openvpn.inc');
include_once(dirname(__FILE__) . '/ressources/class.mysql.inc');
include_once(dirname(__FILE__) . '/framework/class.unix.inc');
include_once(dirname(__FILE__) . '/ressources/class.system.network.inc');

$GLOBALS["server-conf"]=false;

if(is_array($argv)){
	if(preg_match("#--verbose#",implode(" ",$argv))){$GLOBALS["VERBOSE"]=true;}
}
if($GLOBALS["VERBOSE"]){echo "Debug mode TRUE for {$argv[1]}\n";}
$openvpn=new openvpn();
$GLOBALS["IPTABLES_ETH"]=$openvpn->main_array["GLOBAL"]["IPTABLES_ETH"];

if($GLOBALS["IPTABLES_ETH"]==null){$GLOBALS["IPTABLES_ETH"]=IPTABLES_ETH_FIX();}

if($argv[1]=='--server-conf'){$GLOBALS["server-conf"]=true;writelogs("Starting......: OpenVPN building settings...","main",__FILE__,__LINE__);BuildTunServer();die();}
if($argv[1]=="--iptables-server"){BuildIpTablesServer();die();}
if($argv[1]=="--iptables-delete"){iptables_delete_rules();die();}
if($argv[1]=="--client-conf"){BuildOpenVpnClients();die();}
if($argv[1]=="--client-start"){StartOPenVPNCLients();die();}
if($argv[1]=="--client-stop"){StopOpenVPNCLients();die();}
if($argv[1]=="--server-stop"){StopServer();die();}
if($argv[1]=="--default-eth"){OpenVpnClientGetDefaultethLink();die();}
if($argv[1]=="--ipof"){echo GetIpaddrOf($argv[2])."\n";die();}
if($argv[1]=="--bridges"){print_r(GetBridgeExists($argv[2]))."\n";die();}
if($argv[1]=="--fix-routes"){BuildClientRoute($argv[2])."\n";die();}





if($argv[1]=="--client-restart"){
	StopOpenVPNCLients();
	StartOPenVPNCLients();
	die();
}

writelogs("Starting......: OpenVPN Unable to understand this command-line (" .implode(" ",$argv).")","main",__FILE__,__LINE__);	
	
	

function BuildIpTablesServer(){
	iptables_delete_rules();
	$IPTABLES_ETH=$GLOBALS["IPTABLES_ETH"];
	
	if($IPTABLES_ETH==null){
		echo "Starting......: OpenVPN no prerouting set (IPTABLES_ETH)\n";
		return false;
	}
	shell_exec("/sbin/iptables -A INPUT -i tun0 -j ACCEPT -m comment --comment \"ArticaOpenVPN\"");
	shell_exec("/sbin/iptables -A FORWARD -i tun0 -j ACCEPT -m comment --comment \"ArticaOpenVPN\"");
	shell_exec("/sbin/iptables -A OUTPUT -o tun0 -j ACCEPT -m comment --comment \"ArticaOpenVPN\"");
	shell_exec("/sbin/iptables -t nat -A POSTROUTING -o $IPTABLES_ETH -j MASQUERADE -m comment --comment \"ArticaOpenVPN\"");

	shell_exec("/sbin/iptables -A INPUT -i $IPTABLES_ETH -j ACCEPT -m comment --comment \"ArticaOpenVPN\"");
	shell_exec("/sbin/iptables -A FORWARD -i $IPTABLES_ETH -j ACCEPT -m comment --comment \"ArticaOpenVPN\"");
	shell_exec("/sbin/iptables -A OUTPUT -o $IPTABLES_ETH -j ACCEPT -m comment --comment \"ArticaOpenVPN\"");
	shell_exec("/sbin/iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE -m comment --comment \"ArticaOpenVPN\"");
	
	echo "Starting......: OpenVPN prerouting success from tun0 -> $IPTABLES_ETH...\n";
	
}


function StopServer(){
	$unix=new unix();
    $openvpn=$unix->find_program("openvpn");
    $brctl=$unix->find_program("brctl");
    $ifconfig=$unix->find_program("ifconfig");
    $ip_tools=$unix->find_program("ip");	
    
	$ini=new Bs_IniHandler();
    $sock=new sockets();
    $ini->loadString($sock->GET_INFO("ArticaOpenVPNSettings"));
    $BRIDGE_ETH=$ini->_params["GLOBAL"]["BRIDGE_ETH"]; 
    echo "Stopping OpenVPN......................: stopping server bridged on=$BRIDGE_ETH\n";   
	if(preg_match("#(.+?):([0-9]+)#",$BRIDGE_ETH,$re)){$original_eth=$re[1];}
	if($original_eth<>null){
		$array_ip=BuildBridgeServer_eth_infos($BRIDGE_ETH);
		echo "Stopping OpenVPN......................: checking bridges and $original_eth\n";
		$array=GetBridgeExists("br0");
	
		if(is_array($array)){
			echo "Stopping OpenVPN......................: Bridge br0 exists\n";
			system("$ifconfig br0 down");
			while (list ($num, $ligne) = each ($array) ){
				echo "Stopping OpenVPN......................: remove $ligne from br0\n";
				system("brctl delif br0 $ligne");
			}
			
			echo "Stopping OpenVPN......................: remove br0\n";
			system("brctl delbr br0");
			system("$ifconfig $original_eth down");
			}
			
			echo "Stopping OpenVPN......................: rebuild $original_eth settings\n";
			system("$ifconfig $original_eth up");
			if(GetIpaddrOf($original_eth)==null){
				if(preg_match("#^(.+?)\.([0-9]+)$#",$array_ip["IPADDR"],$re)){$eth_broadcast="broadcast {$re[1]}.255";}
				system("$ifconfig $original_eth {$array_ip["IPADDR"]} netmask {$array_ip["NETMASK"]} $eth_broadcast");
			}
			system("$ip_tools route add default via {$array_ip["GATEWAY"]} dev $original_eth  proto static");
	}
	
	iptables_delete_rules();

}





function iptables_delete_rules(){
shell_exec("/sbin/iptables-save > /etc/artica-postfix/iptables.conf");
$data=file_get_contents("/etc/artica-postfix/iptables.conf");
$datas=explode("\n",$data);
$pattern="#.+?ArticaOpenVPN#";	
$count=0;
while (list ($num, $ligne) = each ($datas) ){
		if($ligne==null){continue;}
		if(preg_match($pattern,$ligne)){$count++;continue;}
		$conf=$conf . $ligne."\n";
		}

file_put_contents("/etc/artica-postfix/iptables.new.conf",$conf);
shell_exec("/sbin/iptables-restore < /etc/artica-postfix/iptables.new.conf");
echo "Starting......: OpenVPN cleaning iptables $count rules\n";

}

function iptables_delete_client_rules(){
shell_exec("/sbin/iptables-save > /etc/artica-postfix/iptables.conf");
$data=file_get_contents("/etc/artica-postfix/iptables.conf");
$datas=explode("\n",$data);
$pattern="#.+?ArticaVPNClient_[0-9]+#";	
$count=0;
while (list ($num, $ligne) = each ($datas) ){
		if($ligne==null){continue;}
		if(preg_match($pattern,$ligne)){$count++;continue;}
		$conf=$conf . $ligne."\n";
		}

file_put_contents("/etc/artica-postfix/iptables.new.conf",$conf);
shell_exec("/sbin/iptables-restore < /etc/artica-postfix/iptables.new.conf");
echo "Starting......: OpenVPN cleaning iptables $count rules\n";	
}

function BuildBridgeServer(){
	$unix=new unix();
    $sock=new sockets();
    $openvpn=$unix->find_program("openvpn");
    $brctl=$unix->find_program("brctl");
    $ifconfig=$unix->find_program("ifconfig");
    $ip_tools=$unix->find_program("ip");
    if($openvpn==null){
    	echo "Starting......: OpenVPN bridge unable to stat openvpn binary\n";
    	@unlink("/etc/openvpn/cmdline.conf");
    	exit;
    }
    
    if($brctl==null){
    	echo "Starting......: OpenVPN bridge unable to stat brctl binary\n";
    	@unlink("/etc/openvpn/cmdline.conf");
    	exit;
    }  

    if($ifconfig==null){
    	echo "Starting......: OpenVPN bridge unable to stat ifconfig binary\n";
    	@unlink("/etc/openvpn/cmdline.conf");
    	exit;
    }

    if($ip_tools==null){
    	echo "Starting......: OpenVPN bridge unable to stat ip binary\n";
    	@unlink("/etc/openvpn/cmdline.conf");
    	exit;
    }      
    
    $servername=$unix->hostname_g();	
  	if(preg_match("#^(.+?)\.#",$servername,$re)){$servername=$re[1];}
    $servername=strtoupper($servername);    	
    $ini=new Bs_IniHandler();
    $sock=new sockets();
    $ini->loadString($sock->GET_INFO("ArticaOpenVPNSettings"));
    $BRIDGE_ETH=$ini->_params["GLOBAL"]["BRIDGE_ETH"];
    $BRIDGE_ADDR=$ini->_params["GLOBAL"]["BRIDGE_ADDR"];
    $array_ip=BuildBridgeServer_eth_infos($BRIDGE_ETH);
    
    
   $ca='/etc/artica-postfix/openvpn/keys/allca.crt';
   $dh='/etc/artica-postfix/openvpn/keys/dh1024.pem';
   $key="/etc/artica-postfix/openvpn/keys/vpn-server.key";
   $crt="/etc/artica-postfix/openvpn/keys/vpn-server.crt";    
    
    if(preg_match("#(.+?):([0-9]+)#",$BRIDGE_ETH,$re)){$original_eth=$re[1];}
    
    if($array_ip["IPADDR"]==null){
    	echo "Starting......: OpenVPN bridge for $BRIDGE_ETH (failed to get IP informations)...\n";	
    	return;
    }
    
if(preg_match("#^(.+?)\.([0-9]+)$#",$array_ip["IPADDR"],$re)){$eth_broadcast=$re[1].".255";}
    echo "Starting......: OpenVPN bridge for tap0 -> $original_eth {$array_ip["IPADDR"]}/$eth_broadcast...\n";
    $br0_ip=GetIpaddrOf("br0");
    echo "Starting......: OpenVPN bridge for br0=$br0_ip\n";
    
    if($br0_ip==null){
    	echo "Starting......: OpenVPN bridge creating tap0\n";
    	system("$openvpn --mktun --dev tap0");
    	system("$brctl addbr br0");
    	system("$brctl addif br0 tap0");
    	system("$brctl addif br0 $original_eth");
    	system("$ifconfig $original_eth 0.0.0.0 promisc up");
    	system("$ifconfig tap0 0.0.0.0 promisc up");
    	system("$ifconfig br0 {$array_ip["IPADDR"]} netmask {$array_ip["NETMASK"]} broadcast $eth_broadcast");
		$br0_ip=GetIpaddrOf("br0");  
		if($br0_ip==null){
			   echo "Starting......: OpenVPN failed to create bridge rolling back\n";
			   StopServer();
			   return; 
		}
		system("$ip_tools route add default via {$array_ip["GATEWAY"]} dev br0 proto static");
		
    }
		
		
    $OpenVpnPasswordCert=$sock->GET_INFO("OpenVpnPasswordCert");
	if($OpenVpnPasswordCert==null){$OpenVpnPasswordCert="MyKey";}
   
   	if(is_file("/etc/artica-postfix/openvpn/keys/password")){
   		$askpass=" --askpass /etc/artica-postfix/openvpn/keys/password ";
   	}		
	
   	$routess=GetRoutes();
   	if(is_array($routess)){$routes=implode(" ",$routess);}
		
   $port=$ini->_params["GLOBAL"]["LISTEN_PORT"];
   $server_bridge="--server-bridge $BRIDGE_ADDR {$array_ip["NETMASK"]} {$ini->_params["GLOBAL"]["VPN_DHCP_FROM"]} {$ini->_params["GLOBAL"]["VPN_DHCP_TO"]}";
   $cmd=" --port $port --dev tap0 $server_bridge --comp-lzo $local --ca $ca --dh $dh --key $key --cert $crt";
   $cmd=$cmd. " --ifconfig-pool-persist /etc/artica-postfix/openvpn/ipp.txt $routes";
   $cmd=$cmd. " $askpass--client-to-client -persist-tun -verb 5 --daemon --writepid /var/run/openvpn/openvpn-server.pid --log \"/var/log/openvpn/openvpn.log\"";
   $cmd=$cmd. " --status /var/log/openvpn/openvpn-status.log 10";
   @file_put_contents("/etc/openvpn/cmdline.conf",$cmd);

   
   
    
	
}



function GetBridgeExists($br){
	$unix=new unix();
    $sock=new sockets();
    $brctl=$unix->find_program("brctl");	
	exec("$brctl showstp $br 2>&1",$results);	
	if($GLOBALS["VERBOSE"]){echo count($results)." lines for $brctl showstp $br\n";}
	
	while (list ($index, $line) = each ($results) ){
		if(preg_match("#^([a-zA-Z]+)([0-9]+)#",$line,$re)){
			
			if($re[1]=="br"){continue;}
			$array[]="{$re[1]}{$re[2]}";
		}else{
		
		}
	}

	return $array;
}


function GetIpaddrOf($eth){
	$unix=new unix();
    $sock=new sockets();
    $ip_tools=$unix->find_program("ip");	
	exec("$ip_tools -f inet  address show $eth 2>&1",$results);
	
	while (list ($index, $line) = each ($results) ){
		if(preg_match("#inet\s+([0-9\.]+)\/#",$line,$re)){
			return $re[1];
		}
	}
}

function BuildBridgeServer_eth_infos($BRIDGE_ETH){
		$eth=$BRIDGE_ETH;
		if(!preg_match("#(.+?):([0-9]+)#",$eth,$re)){return array();}
		$sql="SELECT * FROM nics_virtuals WHERE ID={$re[2]}";
		$q=new mysql();
		$ligne=mysql_fetch_array($q->QUERY_SQL($sql,"artica_backup"));	
		if(!$q->ok){
			echo "Starting......: OpenVPN mysql error $q->mysql_error (". __FUNCTION__.")\n";	
		}
		if($ligne["ipaddr"]==null){
			echo "Starting......: OpenVPN $BRIDGE_ETH (has $eth ID={$re[2]}) has no information\n";
		}
		$array_ip["IPADDR"]=$ligne["ipaddr"];
		$array_ip["NETMASK"]=$ligne["netmask"];
		$array_ip["GATEWAY"]=$ligne["gateway"];	
		return $array_ip;
}


function GetRoutes(){
	
   $ini=new Bs_IniHandler();
   $sock=new sockets();
   $ini->loadString($sock->GET_INFO("ArticaOpenVPNSettings"));
   if($ini->_params["GLOBAL"]["ENABLE_BRIDGE_MODE"]==1){
   		$BRIDGE_ETH=$ini->_params["GLOBAL"]["BRIDGE_ETH"];
   		$array_ip=BuildBridgeServer_eth_infos($BRIDGE_ETH);
   		echo "Starting......: OpenVPN binding $BRIDGE_ETH to \"{$array_ip["IPADDR"]}/{$array_ip["NETMASK"]}\"\n";
   		if(preg_match("#(.+?)\.[0-9]+$#",trim($array_ip["IPADDR"]),$re)){
   			$LOCAL_ROUTE="{$re[1]}.0 {$array_ip["NETMASK"]}";
   		    echo "Starting......: OpenVPN default Local route \"$LOCAL_ROUTE\"\n";
   			if(trim($LOCAL_ROUTE<>null)){$routess[]="--push \"route $LOCAL_ROUTE\"";}
   		}
   }

if (is_file('/etc/artica-postfix/settings/Daemons/OpenVPNRoutes')){
   $routes=(explode("\n",@file_get_contents("/etc/artica-postfix/settings/Daemons/OpenVPNRoutes")));
   while (list ($num, $ligne) = each ($routes) ){
   	if(!preg_match("#(.+?)\s+(.+)#",$ligne,$re)){continue;}
   	$re[1]=trim($re[1]);
   	$re[2]=trim($re[2]);
   	$routess[]="--push \"route {$re[1]} {$re[2]}\"";
   }
}
if(is_array($routess)){while (list ($index, $route) = each ($routess) ){$cleaned_routes[$route]=$route;}}
if(is_array($cleaned_routes)){ while (list ($a, $b) = each ($cleaned_routes) ){$c[]=$a;}}


return $c;

	
}

function BuildTunServer(){
	
   $unix=new unix();
   $sock=new sockets();
   $servername=$unix->hostname_g();	
   
 
  if(preg_match("#^(.+?)\.#",$servername,$re)){$servername=$re[1];}
   $servername=strtoupper($servername);       
   echo "Starting......: OpenVPN building settings for $servername...\n";
   
   
   
   $ini=new Bs_IniHandler();
   $sock=new sockets();
   $ini->loadString($sock->GET_INFO("ArticaOpenVPNSettings"));
   if($ini->_params["GLOBAL"]["ENABLE_BRIDGE_MODE"]==1){
   		echo "Starting......: OpenVPN building settings mode bridge enabled...\n";
   		BuildBridgeServer();
   		return;
   }
   
   
   $IPTABLES_ETH=$GLOBALS["IPTABLES_ETH"];
   $DEV_TYPE=$ini->_params["GLOBAL"]["DEV_TYPE"];
   $port=$ini->_params["GLOBAL"]["LISTEN_PORT"];
   $IP_START=$ini->_params["GLOBAL"]["IP_START"];
   $NETMASK=$ini->_params["GLOBAL"]["NETMASK"];
   $bind_addr=$ini->_params["GLOBAL"]["LOCAL_BIND"];
   
   if(trim($port)==null){$port=1194;}
   if(trim($IP_START)==null){$IP_START="10.8.0.0";}
   if(trim($NETMASK)==null){$IP_START="255.255.255.0";}
   
$nic=new networking();

while (list ($num, $ligne) = each ($nic->array_TCP) ){
	if($ligne==null){continue;}
		$eths[][$num]=$num;
		$ethi[$num]=$ligne;
	} 

if($IPTABLES_ETH<>null){
		echo "Starting......: OpenVPN linked to $IPTABLES_ETH ({$ethi[$IPTABLES_ETH]})...\n";
		$IPTABLES_ETH_ROUTE=IpCalcRoute($ethi[$IPTABLES_ETH]);
}else{
	echo "Starting......: OpenVPN no local NIC linked...\n";
}
	
   $ca='/etc/artica-postfix/openvpn/keys/allca.crt';
   $dh='/etc/artica-postfix/openvpn/keys/dh1024.pem';
   $key="/etc/artica-postfix/openvpn/keys/vpn-server.key";
   $crt="/etc/artica-postfix/openvpn/keys/vpn-server.crt";
   $route='';
   
   //$IPTABLES_ETH_IP=

if (is_file('/etc/artica-postfix/settings/Daemons/OpenVPNRoutes')){
   $routes=(explode("\n",@file_get_contents("/etc/artica-postfix/settings/Daemons/OpenVPNRoutes")));
   while (list ($num, $ligne) = each ($routes) ){
   	if(!preg_match("#(.+?)\s+(.+)#",$ligne,$re)){continue;}
   	$routess[]="--push \"route {$re[1]} {$re[2]}\"";
   }
}

$routess[]=GetRoutes();

if(count($routess)==0){
	if($IPTABLES_ETH_ROUTE<>null){
		echo "Starting......: OpenVPN IP adding default route \"$IPTABLES_ETH_ROUTE\"\n";
		$routess[]="--push \"route $IPTABLES_ETH_ROUTE\"";
	}
  }else{
  	echo "Starting......: OpenVPN IP adding ".count($routess)." routes\n";
  }
   

	
   if(trim($bind_addr)<>null){
   	$local=" --local $bind_addr";
   	echo "Starting......: OpenVPN IP bind $bind_addr\n";
   }
   
   $IP_START=FIX_IP_START($IP_START,$local);
   $ini->set("GLOBAL","IP_START",$IP_START); 	
  
   if(preg_match("#(.+?)\.([0-9]+)$#",$IP_START,$re)){
   	$calc_ip=" {$re[1]}.0";
   	$calc_ip_end="{$re[1]}.254";
   	echo "Starting......: OpenVPN IP pool from {$re[1]}.2 to {$re[1]}.254 mask:$NETMASK\n";
   	$server_ip="{$re[1]}.1";
   }

   if($NETMASK==null){
			$ip=new IP();
			$cdir=$ip->ip2cidr($calc_ip,$calc_ip_end);
			$arr=$ip->parseCIDR($cdir);
			$rang=$arr[0];
			$netbit=$arr[1];
			$ipv=new ipv4($calc_ip,$netbit);
			$NETMASK=$ipv->netmask();	   
			if($NETMASK=="255.255.255.255"){$NETMASK="255.255.255.0";}		
   			echo "Starting......: OpenVPN Netmask is null for the range $calc_ip, assume $NETMASK\n";
   			$ini->set("GLOBAL","NETMASK",$NETMASK);
   	}
   	
	$OpenVpnPasswordCert=$sock->GET_INFO("OpenVpnPasswordCert");
	if($OpenVpnPasswordCert==null){$OpenVpnPasswordCert="MyKey";}
   
   	if(is_file("/etc/artica-postfix/openvpn/keys/password")){
   		$askpass=" --askpass /etc/artica-postfix/openvpn/keys/password ";
   	}
 
   $cmd=" --port $port --dev tun --server $IP_START $NETMASK --comp-lzo $local --ca $ca --dh $dh --key $key --cert $crt";
   $cmd=$cmd. " --ifconfig-pool-persist /etc/artica-postfix/openvpn/ipp.txt " . implode(" ",$routess);
   $cmd=$cmd. " $askpass--client-to-client --persist-tun --verb 5 --daemon --writepid /var/run/openvpn/openvpn-server.pid --log \"/var/log/openvpn/openvpn.log\"";
   $cmd=$cmd. " --status /var/log/openvpn/openvpn-status.log 10";
   @file_put_contents("/etc/openvpn/cmdline.conf",$cmd);
  
   
   $sock->SaveConfigFile($ini->toString(),"ArticaOpenVPNSettings");
   echo "Starting......: OpenVPN building settings done.\n";
   if($GLOBALS["VERBOSE"]){writelogs("$cmd",__FUNCTION__,__FILE__,__LINE__);}
}

function FIX_IP_START($ip,$local){
	$original_ip=$ip;
	if(preg_match("#(.+?)\/#",$ip,$re)){$ip=$re[1];}
	
	if(preg_match("#([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)#",$ip,$re)){
		$ip=$re[1].".".$re[2].".".$re[3].".0";
		$ip_1=$re[1];
		$ip_2=$re[2];
		$ip_3=$re[3];
		
	}
	
	if(preg_match("#([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)#",$local,$re)){
		$local=$re[1].".".$re[2].".".$re[3].".0";
	}

	if($ip==$local){
		if($ip_1<255){$ip_1=$ip_1+1;}
		if($ip_2<255){$ip_2=$ip_2+1;}
		if($ip_3<255){$ip_3=$ip_3+1;}
		
		echo "Starting......: OpenVPN bad server parameters $original_ip.\n";
		echo "Starting......: OpenVPN vpn dhcp parameters ($ip) must no reflect local network ($local).\n";
		echo "Starting......: OpenVPN change automatically to $ip_1.$ip_2.$ip_3.0.\n";
		$ip="$ip_1.$ip_2.$ip_3.0";
	}
	
	if($ip=="255.255.255.0"){
		
		if("10.8.0.0"<>$local){
			echo "Starting......: OpenVPN $ip seems to be a netmask not an IP address change to 10.8.0.0\n";
			return "10.8.0.0";
		}
	}
	
	return $ip;
	
}

function IPTABLES_ETH_FIX(){
$nic=new networking();

while (list ($num, $ligne) = each ($nic->array_TCP) ){
	if($ligne==null){continue;}
		$eths[][$num]=$num;
		$ethi[$num]=$ligne;
	} 

if($IPTABLES_ETH==null){
	while (list ($num, $ligne) = each ($ethi) ){
		if(preg_match("#^eth[0-9]+#",$num)){
			if($GLOBALS["server-conf"]){echo "Starting......: OpenVPN no local NIC linked: assume $num ($ligne)...\n";}
			return $num;
		}
	}
}	
}


function IpCalcRoute($ipsingle){
	 if(!preg_match("#(.+?)\.([0-9]+)$#",$ipsingle,$re)){
	 	writelogs("Unable to match $ipsingle",__FUNCTION__,__FILE__,__LINE__);
	 	return null;
	 	}

	 $unix=new unix();
	 $tmp=$unix->FILE_TEMP();
	 
	 shell_exec("/usr/share/artica-postfix/bin/ipcalc {$re[1]}.0 >$tmp 2>&1");
	 
	 $arr=explode("\n",@file_get_contents($tmp));
	 @unlink($tmp);
	
	 
		while (list ($num, $ligne) = each ($arr) ){
			
			if(preg_match("#^Netmask:\s+(.+?)\s+#",$ligne,$ri)){
				return "{$re[1]}.0 {$ri[1]}";
			}
			 
			
		}

}


function Synchronize_clients(){
	$main_path="/etc/artica-postfix/openvpn/clients";
	$unix=new unix();
	shell_exec("sysctl -w net.ipv4.ip_forward=1");
	$tbl=$unix->dirdir($main_path);
	$q=new mysql();
	if(!is_array($tbl)){return;}
	while (list ($num, $id) = each ($tbl) ){
		$id=trim($id);
		$mustkill=false;
		$sql="SELECT ID,enabled FROM vpnclient WHERE connexion_type=2 AND ID=$id";
		$ligne=@mysql_fetch_array($q->QUERY_SQL($sql,"artica_backup"));	
		if(!$q->ok){continue;}
		if($ligne["ID"]==null){$mustkill=true;}
		if($ligne["enabled"]==0){$mustkill=true;}
		if($mustkill){
			if($unix->process_exists(vpn_client_pid($id))){
				shell_exec("/bin/kill $pid >/dev/null 2>&1");
			}
			shell_exec("/bin/rm -rf $main_path/$id >/dev/null");	
		}
		
	}	
	
}


function BuildOpenVpnClients(){
	chdir("/root");
	iptables_delete_client_rules();
	$main_path="/etc/artica-postfix/openvpn/clients";
	$sql="SELECT * FROM vpnclient WHERE connexion_type=2 and enabled=1 ORDER BY ID";
	$q=new mysql();
	$results=$q->QUERY_SQL($sql,"artica_backup");
	if(!$q->ok){echo "Starting......: OpenVPN client, mysql database error, starting from cache\n";return null;}
	@mkdir("/etc/artica-postfix/openvpn/clients",0666,true);
	while($ligne=mysql_fetch_array($results,MYSQL_ASSOC)){
		$subpath="$main_path/{$ligne["ID"]}";
		@mkdir("$subpath",0666,true);
		$password=base64_decode($ligne["keypassword"]);
		if($password==null){$password="MyKey";}
		echo "Starting......: OpenVPN client, building configuration for {$ligne["connexion_name"]}\n";
		@file_put_contents("$subpath/ca.crt",$ligne["ca_bin"]);
		@file_put_contents("$subpath/certificate.crt",$ligne["cert_bin"]);
		@file_put_contents("$subpath/master-key.key",$ligne["key_bin"]);
		@file_put_contents("$subpath/settings.ovpn",$ligne["ovpn"]);
		@file_put_contents("$subpath/ethlink",$ligne["ethlisten"]);
		@file_put_contents("$subpath/keypassword",$password);
		BuildOpenVpnClients_changeConfig($subpath,"{$ligne["ID"]}");
		}
		
}

function vpn_client_pid($id){
	
	if(is_file("/etc/artica-postfix/openvpn/clients/$id/pid")){
		return trim(@file_get_contents("/etc/artica-postfix/openvpn/clients/$id/pid"));
	}
	
	$unix=new unix();
	exec($unix->find_program("pgrep"). " -f \"openvpn.+?\/etc\/artica-postfix\/openvpn\/clients\/$id\/settings\.ovpn\" -l",$re);
	
	while (list ($num, $ligne) = each ($re) ){
		if(!preg_match("#^([0-9]+)\s+(.+)#",$ligne,$ri)){continue;}
		if(!preg_match("#pgrep -f#",$ri[2])){
			$cmdline=$ri[2];
			$pid=$ri[1];
			break;
		}
		
	}
	
	return $pid;
	
}
function vpn_client_pids($id){
	$unix=new unix();
	exec($unix->find_program("pgrep"). " -f \"openvpn.+?\/etc\/artica-postfix\/openvpn\/clients\/$id\/settings\.ovpn\"",$re);
	return $re;
	
}
function vpn_client_allpids(){
	$unix=new unix();
	exec($unix->find_program("pgrep"). " -f \"openvpn.+?\/etc\/artica-postfix\/openvpn\/clients\/[0-9]+\/settings\.ovpn\"",$re);
	while (list ($num, $pid) = each ($re) ){
		$pid=trim($pid);
		if($pid==null){continue;}
		if($pid==0){continue;}
		$rr[]=$pid;
	}
	
	return $rr;
	
}

function StartOpenVPNCLients(){
	$main_path="/etc/artica-postfix/openvpn/clients";
	Synchronize_clients();
	BuildOpenVpnClients();
	$unix=new unix();
	$tbl=$unix->dirdir($main_path);
	if(!is_array($tbl)){return null;}
	while (list ($num, $ligne) = each ($tbl) ){
		OpenVPNCLientStart($ligne);
		
	}
	
	
	
}
function StopOpenVPNCLients(){
	chdir("/root");
	$pids=vpn_client_allpids();
	if(!is_array($pids)){
		echo "Stopping OpenVPN clients..............: stopped\n"; 
		return;
	}
	
	echo "Stopping OpenVPN clients..............: ". implode(", ",$pids)."\n";
	
	while (is_array($pids)) {
		while (list ($num, $pid) = each ($pids) ){
			if($pid==null){continue;}
			if($pid==0){continue;}
			echo "Stopping OpenVPN clients..............: PID $pid\n";
			shell_exec("/bin/kill $pid >/dev/null 2>&1");
			sleep(1);
		}
		
		$pids=vpn_client_allpids();
	}
	
	BuildOpenVpnClients();
	
	
	
}
function BuildIpTablesClient($eth,$tun_id){
	
	
	
	if($eth==null){
		echo "Starting......: OpenVPN no prerouting set (IPTABLES_ETH)\n";
		return false;
	}
	
	echo "Starting......: OpenVPN tun$tun_id Enable IP Forwarding\n";
    shell_exec("sysctl -w net.ipv4.ip_forward=1");         
   
	shell_exec("/sbin/iptables -A INPUT -i tun$tun_id -j ACCEPT -m comment --comment \"ArticaVPNClient_$tun_id\"");
	shell_exec("/sbin/iptables -A FORWARD -i tun$tun_id -j ACCEPT -m comment --comment \"ArticaVPNClient_$tun_id\"");
	shell_exec("/sbin/iptables -A OUTPUT -o tun$tun_id -j ACCEPT -m comment --comment \"ArticaVPNClient_$tun_id\"");
	shell_exec("/sbin/iptables -t nat -A POSTROUTING -o $eth -j MASQUERADE -m comment --comment \"ArticaVPNClient_$tun_id\"");
	
	//iptables -t nat -A POSTROUTING -i tun8 -o eth0 -j MASQUERADE
	//iptables -t nat -A POSTROUTING -i eth0 -o tun0 -j MASQUERADE
	

	shell_exec("/sbin/iptables -A INPUT -i $eth -j ACCEPT -m comment --comment \"ArticaVPNClient_$tun_id\"");
	shell_exec("/sbin/iptables -A FORWARD -i $eth -j ACCEPT -m comment --comment \"ArticaVPNClient_$tun_id\"");
	shell_exec("/sbin/iptables -A OUTPUT -o $eth -j ACCEPT -m comment --comment \"ArticaVPNClient_$tun_id\"");
	shell_exec("/sbin/iptables -t nat -A POSTROUTING -o tun$tun_id -j MASQUERADE -m comment --comment \"ArticaVPNClient_$tun_id\"");
	
	echo "Starting......: OpenVPN prerouting success for tun$tun_id...\n";
	
}


function OpenVPNCLientStartGetDev($id){
	$main_path="/etc/artica-postfix/openvpn/clients";
	$datas=explode("\n",@file_get_contents("$main_path/$id/settings.ovpn"));
	while (list ($num, $line) = each ($datas) ){
		if(preg_match("#^dev\s+tun([0-9]+)#",$line,$re)){
			return "tun{$re[1]}";
		}
	}		
}
function OpenVPNCLientStartGetTAPDev($id){
	$main_path="/etc/artica-postfix/openvpn/clients";
	$datas=explode("\n",@file_get_contents("$main_path/$id/settings.ovpn"));
	while (list ($num, $line) = each ($datas) ){
		if(preg_match("#^dev\s+tap([0-9]+)#",$line,$re)){
			return "tap{$re[1]}";
		}
	}		
}

function OpenVPNCLientIsOnTap($id){
$main_path="/etc/artica-postfix/openvpn/clients";
	$datas=explode("\n",@file_get_contents("$main_path/$id/settings.ovpn"));
	while (list ($num, $line) = each ($datas) ){
		if(preg_match("#^dev.+?tap#",$line,$re)){
			return true;
		}
	}		
	return false;
}




function OpenVPNCLientStart($id){
	$unix=new unix();
	$sock=new sockets();
	$main_path="/etc/artica-postfix/openvpn/clients";
	chdir("/root");
	$count=0;
	if(!is_file("$main_path/$id/settings.ovpn")){
		echo "Starting......: OpenVPN client $id, unable to stat $main_path/$id/settings.ovpn\n";
		return;  
	}
	
	$pid=vpn_client_pid($id);
	if($unix->process_exists($pid)){
		echo "Starting......: OpenVPN client $id, Already running PID $pid\n";
		return;
	}
	$bridge=OpenVPNCLientIsOnTap($id);
	if(!$bridge){
		$tun=OpenVPNCLientStartGetDev($id);	
		if($tun<>null){
			if(!is_file("/dev/net/$tun")){
			echo "Starting......: OpenVPN client TUN $id,creating dev \"$tun\"\n";
			system($unix->find_program("mknod") ." /dev/net/$tun c 10 200 >/dev/null 2>&1");
			system($unix->find_program("chmod"). " 600 /dev/net/$tun >/dev/null 2>&1");
			}}
	}else{
		$tap=OpenVPNCLientStartGetTAPDev($id);
		echo "Starting......: OpenVPN client TAP $id,creating dev \"$tap\"\n";
		system("$openvpn --mktun --dev $tap");
		
		
		
	}
	
	echo "Starting......: OpenVPN client [$id] log file will be $main_path/$id/openvpn-status.log\n";
	
	shell_exec("/bin/chmod -R 600 $main_path/$id");
	$cmd="openvpn --askpass $main_path/$id/keypassword --config $main_path/$id/settings.ovpn --writepid $main_path/$id/pid --daemon --log $main_path/$id/log";
	$cmd=$cmd. " --status $main_path/$id/openvpn-status.log 10";
	shell_exec($cmd);	
	$count=0;
	$pid=vpn_client_pid($id);
	for($i=0;$i<7;$i++){
		$count++;
		echo "Starting......: OpenVPN client [$id] (pid=$pid), waiting for pid $i/7\n";
		
		if($count>5){
			echo "Starting......: OpenVPN client $id, time-out\n";
			break;
		}
		$pid=vpn_client_pid($id);
		
		if($pid==null){
			sleep(5);
			continue;
		}
		
		if($unix->process_exists($id)){
			break;
		}
		sleep(5);
	}
	
	
	$pid=vpn_client_pid($id);
	if(!$unix->process_exists($pid)){
		echo "Starting......: OpenVPN client $id, failed \"$cmd\"\n";
		return;
	}
	
	echo "Starting......: OpenVPN client $id, success running pid number $pid\n";
	if(!$bridge){
		$ethlink=trim(@file_get_contents("$main_path/$id/ethlink"));
		
		if(trim($ethlink)==null){
			$ethlink=OpenVpnClientGetDefaultethLink();
			echo "Starting......: OpenVPN client $id, no ethlink...create a default one for $ethlink\n";
			@file_put_contents("$main_path/$id/ethlink",$ethlink);
		}
		
		if($ethlink<>null){
			BuildIpTablesClient($ethlink,$id);
		}else{
			echo "Starting......: OpenVPN client $id, no ethlink...in $main_path/$id/ethlink\n";
		}
	}
	
	BuildClientRoute($id);
	
	
}


function BuildClientRoute($id){
	sleep(5);
	$unix=new unix();
	$main_path="/etc/artica-postfix/openvpn/clients";
	$ip_tool=$unix->find_program("ip");
	$bridge=OpenVPNCLientIsOnTap($id);
	if(!$bridge){
		$dev=OpenVPNCLientStartGetDev($id);
	}else{
		$dev=OpenVPNCLientStartGetTAPDev($id);		
	}
	
echo "Starting......: OpenVPN client $id, $dev\n";
exec("$ip_tool route",$results);
if($bridge){
	echo "Starting......: OpenVPN Tap $dev, cleaning bad route\n";
	
	while (list ($num, $ligne) = each ($results) ){
		if(preg_match("#^([0-9\.]+)\/([0-9]+)\s+via\s+[0-9\.]+\s+dev\s+$dev#",$ligne,$re)){
			echo "Starting......: OpenVPN Tap {$re[0]} must be cleaned\n";
			system("$ip_tool route del {$re[0]}");
		}
	}
}

	echo "Starting......: OpenVPN $dev, finding correct route\n";
	reset($results);
	while (list ($num, $ligne) = each ($results) ){
		if(preg_match("#^([0-9\.]+)\/([0-9]+)\s+dev\s+$dev\s+proto\s+kernel\s+scope\s+link\s+src\s+([0-9\.]+)#",$ligne,$re)){
			$IP_TO_ROUTE=$re[3];
			echo "Starting......: OpenVPN others routes match $dev $IP_TO_ROUTE\n";
			break;
		}
	
	}

	$routes=OpenVpnClientGetRoutes("$main_path/$id");
	$localnets=getLocalNets();
	//print_r($routes);
	//print_r($localnets);
	if(count($routes)==0){echo "Starting......: OpenVPN no routes to add\n";return;}
	while (list ($ip_start, $netmask) = each ($routes) ){
		if($localnets[$ip_start]<>null){
			echo "Starting......: OpenVPN skipping route $ip_start\n";
			continue;
		}
		echo "Starting......: OpenVPN adding route $ip_start/$netmask\n";
		$cmd="$ip_tool route add $ip_start/$netmask dev $dev proto kernel scope link src $IP_TO_ROUTE >/dev/null 2>&1";
		if($GLOBALS["VERBOSE"]){echo __FUNCTION__." $cmd\n";}
		system($cmd);
	}
	
	
}

function getLocalNets(){
	$unix=new unix();
	$main_path="/etc/artica-postfix/openvpn/clients";
	$ip_tool=$unix->find_program("ip");

	exec("$ip_tool addr show 2>&1",$results);
	while (list ($num, $ligne) = each ($results) ){
		if(preg_match("#^[0-9]+:\s+(.+?):#",$ligne,$re)){
			$eth=$re[1];
			if(preg_match("#(.+?)\.[0-9]+$#",GetIpaddrOf($eth),$ri)){
				$ipof="{$ri[1]}.0";
			}
			$array[$ipof]=$eth;
		}else{
		
		}
	}
	return $array;
}



function OpenVpnClientGetDefaultethLink(){
$nic=new networking();

while (list ($num, $ligne) = each ($nic->array_TCP) ){
	if($ligne==null){continue;}
		if(!preg_match("#^eth[0-9]+#",$num)){continue;}
		$eths[]=$num;
		$ethi[$num]=$ligne;
	} 
	

	if(is_array($eths)){return $eths[0];}
	
}

function OpenVpnClientGetRoutes($mainpath){
	$datas=file_get_contents("$mainpath/settings.ovpn");
	$f=explode("\n",$datas);
	if($GLOBALS["VERBOSE"]){echo __FUNCTION__." open $mainpath/settings.ovpn ". count($f)." lines\n";}
	while (list ($num, $ligne) = each ($f) ){
		if(preg_match("#REMOTE-SITE:\s+([0-9\.]+);([0-9\.]+)#",$ligne,$re)){
			$routes[$re[1]]=$re[2];
		}else{
			//if($GLOBALS["VERBOSE"]){echo __FUNCTION__." $ligne NO MATCH\n";}
		}
	}
	
	return $routes;
}

function BuildOpenVpnClients_changeConfig($mainpath,$ethid){
	echo "Starting......: OpenVPN client $mainpath/settings.ovpn\n";
	
	
	$datas=file_get_contents("$mainpath/settings.ovpn");
	$f=explode("\n",$datas);
	while (list ($num, $ligne) = each ($f) ){
		if(preg_match("#^dev\s+tun(.*)#",$ligne)){
			echo "Starting......: OpenVPN client tun dev=". trim($re[1])." change to tun$ethid\n";
			$f[$num]="dev tun$ethid";
		}
		
		if(preg_match("#^dev\s+tap(.*)#",$ligne)){
			echo "Starting......: OpenVPN client tap dev=". trim($re[1])." change to tap$ethid\n";
			$f[$num]="dev tap$ethid";
		}		
		
		if(preg_match("#^ca\s+#",$ligne)){
			$f[$num]="ca $mainpath/ca.crt";
		}
		
		if(preg_match("#^cert\s+#",$ligne)){
			$f[$num]="cert $mainpath/certificate.crt";
		}

		if(preg_match("#^key\s+#",$ligne)){
			$f[$num]="key $mainpath/master-key.key";
		}			
		
		
	}
	
	@file_put_contents("$mainpath/settings.ovpn",implode("\n",$f));
	
	
}





?>