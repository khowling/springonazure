# exit on error
#set -e

while getopts "dg:ps:" opt; do
  case ${opt} in
    d ) 
      just_deploy=yes
      ;;
    s ) # process option a
      create_sqlserver=yes
      sql_passwd=$OPTARG
      ;;
    p ) # process option a
      create_plan=yes
      ;;
    g ) # process option a
      group_name=$OPTARG
      ;;
    \? )
      echo "Unknown arg"
      echo "Usage: cmd <-g group_name> [-s sql_passwd] [-p (create plan)] website_name"
      ;; 
  esac 
done

shift $((OPTIND -1))

if [ $# -ne 1  ] || [ -z "$group_name" ]; then
   echo "Usage: cmd <-g group_name> [-s sql_passwd] [-p (create plan)] website_name"
   exit
fi

site_name=$1; shift

if [ ! "$just_deploy" ]; then

  echo "Create group ${group_name}..."
  az  group create -n $group_name >/dev/null

  plan_name="WinJavaS1"
  if [ "$create_plan" ]; then
    echo "Create Plan ${plan_name}..."
    # --is-linux 
    az appservice plan create -g ${group_name} -n ${plan_name}  --number-of-workers 1 --sku S1 >/dev/null
  fi

  sql_username="dbuser"
  sqlserver_name=${group_name,,}-sql
  if [ "$create_sqlserver" ]; then
    echo "Create SQL DB server ${sqlserver_name}..."
    az sql server create -g ${group_name} -n ${sqlserver_name}  --admin-user ${sql_username} --admin-password  ${sql_passwd} >/dev/null
    az sql server firewall-rule create -g ${group_name} -n "myip" -s ${sqlserver_name} --start-ip-address $(curl ipinfo.io/ip 2>/dev/null) --end-ip-address $(curl ipinfo.io/ip 2>/dev/null)  >/dev/null
  fi

  echo "Create website ${web_name}..."
  az webapp create -n ${site_name} -g ${group_name} --plan ${plan_name} >/dev/null
  echo "Setting Java version..."
  az webapp config set -n ${site_name} -g ${group_name} --java-version "1.8" --java-container "Tomcat" --java-container-version "8.5" >/dev/null
  echo "Create website DB...."
  az sql db create --server ${sqlserver_name} -g ${group_name} -n ${site_name}  >/dev/null
  echo "Adding DB Connection String to webapp settings...."
  sql_connectionstring=$(az sql db show-connection-string -s ${sqlserver_name} -c jdbc -otsv | sed -e "s/<username>/${sql_username}/" -e "s/<password>/${sql_passwd}/" -e "s/<databasename>/${site_name}/")
  az webapp config appsettings set -n ${site_name} -g ${group_name} --settings JDBC_URL="${sql_connectionstring}"

  echo "Whitelisting website IP addresses on DB firewall...."
  webapp_ips=$(az webapp show -n ${site_name} -g ${group_name} --query "outboundIpAddresses" -otsv)
  for webapp_ip in ${webapp_ips//,/ }; do
    az sql server firewall-rule create -g ${group_name} -n "${site_name}${webapp_ip}" -s ${sqlserver_name} --start-ip-address ${webapp_ip} --end-ip-address ${webapp_ip}  >/dev/null
  done

fi

echo "Deploy website ${web_name}..."
(
    cd springbackend
    zip ../springbackend_deploy.zip ./web.config  ./target/springbackend-0.0.1-SNAPSHOT.jar
)
az webapp deployment source config-zip -n ${site_name} -g ${group_name} --src ./springbackend_deploy.zip >/dev/null

echo "Done"


