# Create a GCP Virtual Machine for MongoDB
This script will create a GCP VM with a single-node MongoDB Cluster (6.0.8 Community edition) with one replica set, suitable for testing with Redis Data Integration.

## Prerequisites
* GCP account
* VPC configured on GCP
* GCP Cloud DNS A record for target VM
* GCP firwall rule to open TCP port 27017
* Command shell, e.g. Terminal on MacOS or WSL on Microsoft Windows
* *gcloud* installed and configured on local workstation
  
## Steps to run
* Clone the repository:
  ```
  git clone https://github.com/loriotpiroloriol/mongodb.git
  ```
* `cd mongodb`
* `cp .env.sample .env`
* Edit `.env` to supply variable values matching your environment/GCP account settings

  **Notes**:
  * `MACHINE_TYPE` can be very small - `n1-standard-1` is sufficient
  * `DNS_ZONE` must match the zone you used for setting up the Cloud DNS A record
  * `IMAGE` is set in the main script and is hard-coded for Ubuntu 20.04 Focal. Don't change this, as there's a dependency on the MongoDB installer.

* `./create-mongo.sh`

## Connect to MongoDB
The easiest way to connect to the MongoDB cluster is through [Compass](https://www.mongodb.com/docs/compass/master/install/).
The connection string is
```
mongodb://<MONGO_ADMIN>:<PASSWORD>@<HOSTNAME>:27017/?authSource=admin&replicaSet=rs0&readPreference=primary
```
Note that the setup script also installs the sample databases:

<img width="1028" alt="image" src="https://github.com/loriotpiroloriol/mongodb/assets/116373419/8ec1fd96-02c8-422a-91d5-c3a0d81045d6">
