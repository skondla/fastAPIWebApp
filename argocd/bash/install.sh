#!/bin/bash
#Author: skondla
#Reference: https://argo-cd.readthedocs.io/en/stable/getting_started/
#Reference: https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/
#Purpose: Install and Setup Argo CD and deploy a container web application


#1. Install Argo CD

kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

#2. Install Argo CD  core

#kubectl create namespace argocd
#kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/core-install.yaml

#3. Install Argo CD  on macOS
#brew install argocd

# 3. Access The Argo CD API Server¶
# By default, the Argo CD API server is not exposed with an external IP. To access the API server, choose one of the following 
#techniques to expose the Argo CD API server:

# Service Type Load Balancer¶
# Change the argocd-server service type to LoadBalancer:

kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Ingress¶
# Follow the ingress documentation on how to configure Argo CD with ingress.
# Port Forwarding¶
# Kubectl port-forwarding can also be used to connect to the API server without exposing the service.


kubectl port-forward svc/argocd-server -n argocd 8080:443


# 4. Login Using The CLI¶
# The initial password for the admin account is auto-generated and stored as clear text in the field password in a secret named argocd-initial-admin-secret
#  in your Argo CD installation namespace. You can simply retrieve this password using the argocd CLI:


argocd admin initial-password -n argocd


# Warning

# You should delete the argocd-initial-admin-secret from the Argo CD namespace once you changed the password. 
# The secret serves no other purpose than to store the initially generated password in clear and can safely be deleted at any time. 
# It will be re-created on demand by Argo CD if a new admin password must be re-generated.
# Using the username admin and the password from above, login to Argo CD's IP or hostname:


argocd login <ARGOCD_SERVER>

#Ingress Configuration
cat > ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
spec:
  ingressClassName: "nginx"
  rules:
  - host: argocd.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              name: https
EOF
kubectl apply -f ingress.yaml -n argocd

