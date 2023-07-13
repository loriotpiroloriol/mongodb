#!/bin/bash

mongo_check() {
  nc -vz localhost 27017 > /dev/null 2>&1
  return $?
}

#Download and install MongoDB Community Edition
echo "Installing MongoDB..."
wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list >> ~/setup.log
sudo apt-get update >> ~/setup.log
sudo apt-get install -y mongodb-org >> ~/setup.log

#Tune system parameters for MongoDB
echo 9999999 | sudo tee /proc/sys/vm/max_map_count
echo "vm.max_map_count=9999999" | sudo tee -a /etc/sysctl.conf

#Start and enable service
sudo systemctl start mongod
sudo systemctl enable mongod

#Create admin user for replica set
echo "Configuring replica set..."
while true; do
  if mongo_check; then
    mongosh --quiet create_user.mongodb
    break
  else
    printf '.'
    sleep 1
  fi
done
printf '\n'

#Deploy config for replica set
echo "Deploying config for replica set..."
sudo mv mongokey /etc
sudo chown mongodb:mongodb /etc/mongokey
sudo chmod 400 /etc/mongokey
sudo mv mongod.conf /etc

#Restart service with new config
sudo systemctl restart mongod

#Initiate replica set
echo "Initiating replica set..."
#Need to add the hostname to /etc/hosts/, otherwise get error "No host described in new configuration 1 for replica set rs0 maps to this node"
echo "127.0.0.1	<HOSTNAME>" | sudo bash -c 'cat >> /etc/hosts'
while true; do
  if mongo_check; then
    mongosh  --authenticationDatabase admin -u <MONGO_ADMIN> --password <PASSWORD> --quiet localhost:27017/admin rs_initiate.mongodb
    break
  else
    printf '.'
    sleep 1
  fi
done

#Download and install sample data
echo "Installing sample data..."
wget https://atlas-education.s3.amazonaws.com/sampledata.archive >> ~/setup.log
mongorestore --archive=sampledata.archive --authenticationDatabase "admin" -u "<MONGO_ADMIN>" --password <PASSWORD> >> ~/setup.log

#Create alias
echo "alias mongosh='mongosh --authenticationDatabase \"admin\" -u \"<MONGO_ADMIN>\" --password <PASSWORD>'" >> ~/.bash_aliases
source ~/.bash_aliases 
