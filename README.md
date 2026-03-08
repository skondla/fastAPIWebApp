# flaskAPIWebApp
[![license](https://img.shields.io/github/license/mashape/apistatus.svg?maxAge=2592000)](https://github.com/skondla/flaskAPIWebApp/blob/main/LICENSE)
[![slack](https://img.shields.io/badge/slack-chat-yellow)](https://join.slack.com/t/devops-zwf1016/shared_invite/zt-1wsafgivm-iI88~ZqZBaKGzYhD8N2JsA)
[![CICD](https://github.com/skondla/flaskAPIWebApp/actions/workflows/Deploy-GKE-flaskAdminApp.yml/badge.svg?event=push)](https://github.com/skondla/flaskAPIWebApp/actions)
[![CICD](https://github.com/skondla/flaskAPIWebApp/actions/workflows/Deploy-GKE-flaskUserApp.yml/badge.svg?event=push)](https://github.com/skondla/flaskAPIWebApp/actions)
[![CICD](https://github.com/skondla/flaskAPIWebApp/actions/workflows/Deploy-EKS-ADMIN.yml/badge.svg?event=push)](https://github.com/skondla/flaskAPIWebApp/actions)
[![CICD](https://github.com/skondla/flaskAPIWebApp/actions/workflows/Deploy-EKS-USER.yml/badge.svg?event=push)](https://github.com/skondla/flaskAPIWebApp/actions)
[![Twitter Follow](https://img.shields.io/twitter/follow/skondla?style=social)](https://twitter.com/skondla)

The web interface (HTML) or CURL command can be used to request for
1. Restoring a database instance from cluster and non-cluster database instances
2. Checking the status of the restore from step 1.
3. Attaching an instances to already existing dB cluster
4. The API app is written in Python using Flask Web Frame work and blueprints with API endpoints called routes.

Request website credentials (Signup/Login):

1. Provide your email for web site sign up.
2. Sign up is only available to Admins through Admin console.
3. Apps with both Admin and User interfaces are running on dB API server(s) in a docker container mapped to different ports.
4. The web site use authentication (currently stored in Postgresql dB) can be used in two forms
5. The web site store user information for each action is performance on the web site. (user email, computer IP (real IP when available))
6. In future the web site will be added with geo location and JWT authentication


Functionality: The web interface (HTML) or CURL command can be used to request for 
1. Restoring a database instance (AWS/RDS) from cluster and non-cluster database instances
2. Checking the status of the restore from step 1.
3. Attaching an instances to already existing dB cluster 
4. The API app is written in Python using Flask Web Frame work and blueprints with API endpoints called routes.


Flask Python Curl command: (how to use)
Restore backup:


```
#!/bin/bash
#Author: skondla@me.com
#Purpose: Restore DB from a Snapshot
 
if [ $# -lt 2 ];
then
    echo "Provide snapshotname , db endpoint"
    echo "example: bash getDBRestoreStatus.sh myDB
    myDB.cluster-XXXYYYYDDDD.us-east-1.rds.amazonaws.com"
exit 1
fi
 
snapshotname=${1}
endpoint=${2}
 
EMAIL=`cat ~/.password/mySecrets2 | grep email | awk '{print $2}'`
PASSWORD=`cat ~/.password/mySecrets2 | grep password | awk '{print $2}'`
 
 
#/usr/bin/curl -k "https://ec2-54.94.x.x.compute-1.amazonaws.com:50443/login" \
/usr/bin/curl -k "https://192.168.2.15:50443/login" \
    --data-urlencode "email=${EMAIL}" \
    --data-urlencode "password=${PASSWORD}" \
    --cookie "cookies.txt" \
    --cookie-jar "cookies.txt" \
    --verbose \
    > "login_log.html"
 
#/usr/bin/curl -k "https://ec2-54.94.x.x.compute-1.amazonaws.com:50443/restore" \
/usr/bin/curl -k "https://192.168.2.15:50443/restore" \
    --data-urlencode "snapshotname=${snapshotname}" \
    --data-urlencode "endpoint=${endpoint}" \
    --cookie "cookies.txt" \
    --verbose \
    --cookie-jar "cookies.txt"; \
    echo
rm -f cookies.txt
```
Status of Restored backup:
```
#!/bin/bash
#Author: skondla@me.com
#Purpose: Status of Restore

if [ $# -lt 2 ];
then
    echo "Provide snapshotname , db endpoint"
    echo "example: bash getDBRestoreStatus.sh myDB
    myDB.cluster-XXXYYYYDDDD.us-east-1.rds.amazonaws.com"
exit 1
fi

snapshotname=${1}
endpoint=${2}

EMAIL=`cat ~/.password/mySecrets2 | grep email | awk '{print $2}'`
PASSWORD=`cat ~/.password/mySecrets2 | grep password | awk '{print $2}'`

#/usr/bin/curl -k "https://ec2-54.94.x.x.compute-1.amazonaws.com:50443/login" \
/usr/bin/curl -k "https://192.168.2.15:50443/login" \
    --data-urlencode "email=${EMAIL}" \
    --data-urlencode "password=${PASSWORD}" \
    --cookie "cookies.txt" \
    --cookie-jar "cookies.txt" \
    --verbose \
    > "login_log.html"

#/usr/bin/curl -k "https://ec2-54.94.x.x.compute-1.amazonaws.com:50443/status" \
/usr/bin/curl -k "https://192.168.2.15:50443/restore" \
    --data-urlencode "snapshotname=${snapshotname}" \
    --data-urlencode "endpoint=${endpoint}" \
    --cookie "cookies.txt" \
    --verbose \
    --cookie-jar "cookies.txt"; \
    echo
rm -f cookies.txt
```
Attach DB instance to the cluster:

```
#!/bin/bash
#Author: skondla@me.com
#Purpose: Attach dB instance to dB cluster
 
if [ $# -lt 2 ];
then
    echo "Provide db endpoint , instanceclass"
    echo "example: bash getDBRestoreStatus.sh
          myDB.cluster-XXXYYYYDDDD.us-east-1.rds.amazonaws.com
          db.t2.small"
exit 1
fi
 
endpoint=${1}
instanceclass=${2}
 
 
EMAIL=`cat ~/.password/mySecrets2 | grep email | awk '{print $2}'`
PASSWORD=`cat ~/.password/mySecrets2 | grep password | awk '{print $2}'`
 
#/usr/bin/curl -k "https://ec2-54.94.x.x.compute-1.amazonaws.com:50443/login" \
/usr/bin/curl -k "https://192.168.2.15:50443/login" \
    --data-urlencode "email=${EMAIL}" \
    --data-urlencode "password=${PASSWORD}" \
    --cookie "cookies.txt" \
    --cookie-jar "cookies.txt" \
    --verbose \
    > "login_log.html"
 
#/usr/bin/curl -k "https://ec2-54.94.x.x.compute-1.amazonaws.com:50443/attachdb" \
/usr/bin/curl -k "https://192.168.2.15:50443/attachdb" \
    --data-urlencode "endpoint=${endpoint}" \
    --data-urlencode "instanceclass=${instanceclass}" \
    --cookie "cookies.txt" \
    --verbose \
    --cookie-jar "cookies.txt"; \
    echo
 
rm -f cookies.txt
```
Python Flask Web Interface:

Sign Up page: 

![Alt text](images/signup.png)

Sign In page: 

![Alt text](images/signin.png)

RestoreDB page:

![Alt text](images/restore.png)

RestoreDB Status page:

![Alt text](images/restore_status.png)

AttachDB page1:

![Alt text](images/attachdb1.png)

AttachDB page2:

![Alt text](images/attachdb2.png)

AttachDB DB Restore Options after successful login:

![Alt text](images/db_restore_options_after_login.png)

### DevSecOps pipeline diagram

![Alt text](images/DevSecOps_with_GutHub_Actions_AKS.png)

![Alt text](images/DevSecOps_with_GutHub_Actions_EKS.png)

![Alt text](images/DevSecOps_with_GutHub_Actions_GKE.png)


###### Contact: skondla.ai@gmail.com
###### DevSecOps Blog Posts

[DevSecOps — Deploying WebApp on Google Cloud AKS cluster with Github Actions](https://kondlawork.medium.com/devsecops-deploying-webapp-on-azure-aks-cluster-with-github-actions-efc72bdc552a)


[DevSecOps — Deploying WebApp on Google Cloud EKS cluster with Github Actions](https://kondlawork.medium.com/devsecops-deploying-webapp-on-aws-eks-cluster-with-github-actions-da8865a1b27)


[DevSecOps — Deploying WebApp on Google Cloud GKE cluster with Github Actions](https://medium.com/@kondlawork/devsecops-deploying-webapp-on-google-cloud-gke-cluster-with-github-actions-1028c0630dde)