#!/bin/bash
# Set variable values
source ./.env
INSTANCE="${INSTANCE:=xxx-mongo}"
HOSTNAME="${HOSTNAME:=xxx-mongo.demo.redislabs.com}"
PROJECT="${PROJECT:=central-beach-194106}"
MACHINE_TYPE="${MACHINE_TYPE:=n1-standard-1}"
ZONE="${ZONE:=europe-west2-c}"
SUBNET="${SUBNET:=xxx-vpc}"
SERVICE_ACCOUNT="${SERVICE_ACCOUNT:=319143195410-compute@developer.gserviceaccount.com}"
MONGO_ADMIN="${MONGO_ADMIN:=myAdmin}"
PASSWORD=${PASSWORD}
DNS_ZONE="${DNS_ZONE:=demo-clusters}"
IMAGE=$(gcloud compute images list | grep ubuntu-2004-focal-v | cut -d" " -f1)

# Do not change anything below this line

ssh_check() {
  gcloud compute ssh --quiet --zone ${ZONE} ${INSTANCE} --command="true" 2>/dev/null
  return $?
}

gcloud compute instances create ${INSTANCE} \
  --hostname=${HOSTNAME} \
  --project=${PROJECT} \
  --zone=${ZONE} \
  --machine-type=${MACHINE_TYPE} \
  --network-interface=network-tier=PREMIUM,subnet=${SUBNET} \
  --metadata=enable-oslogin=true \
  --maintenance-policy=MIGRATE \
  --provisioning-model=STANDARD \
  --service-account=${SERVICE_ACCOUNT} \
  --scopes=https://www.googleapis.com/auth/devstorage.read_only,\
https://www.googleapis.com/auth/logging.write,\
https://www.googleapis.com/auth/monitoring.write,\
https://www.googleapis.com/auth/servicecontrol,\
https://www.googleapis.com/auth/service.management.readonly,\
https://www.googleapis.com/auth/trace.append \
  --tags=http-server,https-server \
  --create-disk=auto-delete=yes,\
boot=yes,\
image=projects/ubuntu-os-cloud/global/images/${IMAGE},\
mode=rw,\
size=10,\
type=projects/${PROJECT}/zones/${ZONE}/diskTypes/pd-balanced \
  --no-shielded-secure-boot \
  --shielded-vtpm \
  --shielded-integrity-monitoring \
  --labels=skip_deletion=yes \
  --reservation-affinity=any

#Substitute placeholders in configuration files
sed -e "s/<HOSTNAME>/$HOSTNAME/g" \
-e "s/<MONGO_ADMIN>/$MONGO_ADMIN/g" \
-e "s/<PASSWORD>/$PASSWORD/g" ./templates/startup-mongo.sh > ./startup-mongo.sh
chmod 755 startup-mongo.sh

sed -e "s/<HOSTNAME>/$HOSTNAME/g" ./templates/rs_initiate.mongodb > ./rs_initiate.mongodb

sed -e "s/<MONGO_ADMIN>/$MONGO_ADMIN/g" \
-e "s/<PASSWORD>/$PASSWORD/g" ./templates/create_user.mongodb > ./create_user.mongodb

echo "Configuring instance ${INSTANCE}..."
#Copy config files to new VM instance

#Need to check the VM is ready to accept ssh connections first
echo "Checking SSH connection..."
while true ; do
  if ssh_check; then
    gcloud compute scp ./startup-mongo.sh ${INSTANCE}:~ --zone=${ZONE}
    gcloud compute scp ./mongokey ${INSTANCE}:~ --zone=${ZONE}
    gcloud compute scp ./create_user.mongodb ${INSTANCE}:~ --zone=${ZONE}
    gcloud compute scp ./rs_initiate.mongodb ${INSTANCE}:~ --zone=${ZONE}
    gcloud compute scp ./mongod.conf ${INSTANCE}:~ --zone=${ZONE}
    break
  else
    printf '.'
    sleep 5
  fi
done
printf '\n'

#Install MongoDB Community Edition
gcloud compute ssh --zone ${ZONE} ${INSTANCE} -- './startup-mongo.sh'

#Get external IP of VM instance
EXT_IP=$(gcloud compute instances describe ${INSTANCE} \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

#Update DNS record
gcloud dns --project=${PROJECT} record-sets update ${HOSTNAME}. --type="A" --zone="${DNS_ZONE}" --rrdatas="${EXT_IP}" --ttl="300"
