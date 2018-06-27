# exit on error
#set -e

while getopts "dg:ps:e:" opt; do
  case ${opt} in
    d ) 
      just_deploy=yes
      ;;
    e ) # process option a
      existingdb=yes
      db_name=$OPTARG
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
      echo "Usage: cmd <-g group_name> [-e db_name (use existing db)] [-s sql_passwd (create server)] [-p (create plan)] website_name"
      ;; 
  esac 
done

shift $((OPTIND -1))

if [ $# -ne 1  ] || [ -z "$group_name" ]; then
   echo "Usage: cmd <-g group_name> [-e db_name (use existing db)] [-s sql_passwd (create server)] [-p (create plan)] website_name"
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
  
  if  [ -z "${db_name}" ]; then
    db_name="${site_name}db"
    echo "Create website DB...."
    az sql db create --server ${sqlserver_name} -g ${group_name} -n ${db_name}  >/dev/null
  fi

  echo "Adding DB Connection String to webapp settings...."
  if [ -z "${sql_passwd}" ]; then
    read -s -r -p "Enter SQL Server password: " sql_passwd
  fi
  sql_connectionstring=$(az sql db show-connection-string -s ${sqlserver_name} -c jdbc -otsv | sed -e "s/<username>/${sql_username}/" -e "s/<password>/${sql_passwd}/" -e "s/<databasename>/${db_name}/")
  az webapp config appsettings set -n ${site_name} -g ${group_name} --settings JDBC_URL="${sql_connectionstring}" >/dev/null

  if [ "$create_plan" ]; then
    echo "Whitelisting the plan website IP addresses on DB firewall...."
    webapp_ips=$(az webapp show -n ${site_name} -g ${group_name} --query "outboundIpAddresses" -otsv)
    for webapp_ip in ${webapp_ips//,/ }; do
      az sql server firewall-rule create -g ${group_name} -n "${site_name}${webapp_ip}" -s ${sqlserver_name} --start-ip-address ${webapp_ip} --end-ip-address ${webapp_ip}  >/dev/null
    done
  fi
fi

echo "Deploy website ${web_name}..."
read -r -p "Have you build your apps (npm run-script build &&  ./mvnw package -Dmaven.test.skip=true) [y/N] " response
response=${response,,}    # tolower
if [[ "$response" =~ ^(yes|y)$ ]]; then
  tmp_dir=./_deploy_temp export tmp_dir
  rm -r $tmp_dir
  mkdir $tmp_dir
  cp ./springbackend/web.config  ./springbackend/target/springbackend-0.0.1-SNAPSHOT.jar $tmp_dir
  cp -r ./frontend/build/* $tmp_dir
  (
    cd $tmp_dir
    zip -r ./springbackend_deploy.zip *
  )

  az webapp deployment source config-zip -n ${site_name} -g ${group_name} --src ./$tmp_dir/springbackend_deploy.zip 

  echo "Done"
fi
