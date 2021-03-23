#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HYPERAUTH_INSTALL_HOME=$SCRIPTDIR/install-hyperauth

pushd $HYPERAUTH_INSTALL_HOME/manifests
  # step1 1.initialization.yaml
  kubectl apply -f 1.initialization.yaml

  sleep 60

  # step2 Generate Certs for hyperauth & kafka
  chmod +755 generateCerts.sh
  ./generateCerts.sh -ip=$(kubectl describe service hyperauth -n hyperauth | grep 'LoadBalancer Ingress' | cut -d ' ' -f7)
  kubectl create secret tls hyperauth-https-secret --cert=./hyperauth.crt --key=./hyperauth.key -n hyperauth
  cp hypercloud-root-ca.crt /etc/kubernetes/pki/hypercloud-root-ca.crt
  cp hypercloud-root-ca.key /etc/kubernetes/pki/hypercloud-root-ca.key
    
  keytool -keystore hyperauth.truststore.jks -alias ca-cert -import -file /etc/kubernetes/pki/hypercloud-root-ca.crt -storepass tmax@23 -noprompt
  keytool -keystore hyperauth.keystore.jks -alias hyperauth -validity 3650 -genkey -keyalg RSA -ext SAN=dns:hyperauth.hyperauth -dname "CN=hyperauth.hyperauth" -storepass tmax@23 -keypass tmax@23
  keytool -keystore hyperauth.keystore.jks -alias hyperauth -certreq -file ca-request-hyperauth -storepass tmax@23
  openssl x509 -req -CA /etc/kubernetes/pki/hypercloud-root-ca.crt -CAkey /etc/kubernetes/pki/hypercloud-root-ca.key -in ca-request-hyperauth -out ca-signed-hyperauth -days 3650 -CAcreateserial
  keytool -keystore hyperauth.keystore.jks -alias ca-cert -import -file /etc/kubernetes/pki/hypercloud-root-ca.crt -storepass tmax@23 -noprompt
  keytool -keystore hyperauth.keystore.jks -alias hyperauth -import -file ca-signed-hyperauth -storepass tmax@23 -noprompt
  rm ca-*
  kubectl create secret generic hyperauth-kafka-jks --from-file=./hyperauth.keystore.jks --from-file=./hyperauth.truststore.jks -n hyperauth
   
  ##For Kafka-Brokers
  keytool -keystore kafka.broker1.truststore.jks -alias ca-cert -import -file /etc/kubernetes/pki/hypercloud-root-ca.crt -storepass tmax@23 -noprompt
  keytool -keystore kafka.broker1.keystore.jks -alias broker1 -validity 3650 -genkey -keyalg RSA -ext SAN=dns:kafka-1.hyperauth,dns:kafka-2.hyperauth,dns:kafka-3.hyperauth -dname "CN=kafka-1.hyperauth" -storepass tmax@23 -keypass tmax@23
  keytool -keystore kafka.broker1.keystore.jks -alias broker1 -certreq -file ca-request-broker1 -storepass tmax@23
  openssl x509 -req -CA /etc/kubernetes/pki/hypercloud-root-ca.crt -CAkey /etc/kubernetes/pki/hypercloud-root-ca.key -in ca-request-broker1 -out ca-signed-broker1 -days 3650 -CAcreateserial
  keytool -keystore kafka.broker1.keystore.jks -alias ca-cert -import -file /etc/kubernetes/pki/hypercloud-root-ca.crt -storepass tmax@23 -noprompt
  keytool -keystore kafka.broker1.keystore.jks -alias broker1 -import -file ca-signed-broker1 -storepass tmax@23 -noprompt
  rm ca-*
    
  keytool -keystore kafka.broker2.truststore.jks -alias ca-cert -import -file /etc/kubernetes/pki/hypercloud-root-ca.crt -storepass tmax@23 -noprompt
  keytool -keystore kafka.broker2.keystore.jks -alias broker2 -validity 3650 -genkey -keyalg RSA -ext SAN=dns:kafka-1.hyperauth,dns:kafka-2.hyperauth,dns:kafka-3.hyperauth -dname "CN=kafka-2.hyperauth" -storepass tmax@23 -keypass tmax@23
  keytool -keystore kafka.broker2.keystore.jks -alias broker2 -certreq -file ca-request-broker2 -storepass tmax@23
  openssl x509 -req -CA /etc/kubernetes/pki/hypercloud-root-ca.crt -CAkey /etc/kubernetes/pki/hypercloud-root-ca.key -in ca-request-broker2 -out ca-signed-broker2 -days 3650 -CAcreateserial
  keytool -keystore kafka.broker2.keystore.jks -alias ca-cert -import -file /etc/kubernetes/pki/hypercloud-root-ca.crt -storepass tmax@23 -noprompt
  keytool -keystore kafka.broker2.keystore.jks -alias broker2 -import -file ca-signed-broker2 -storepass tmax@23 -noprompt
  rm ca-*
    
  keytool -keystore kafka.broker3.truststore.jks -alias ca-cert -import -file /etc/kubernetes/pki/hypercloud-root-ca.crt -storepass tmax@23 -noprompt
  keytool -keystore kafka.broker3.keystore.jks -alias broker3 -validity 3650 -genkey -keyalg RSA -ext SAN=dns:kafka-1.hyperauth,dns:kafka-2.hyperauth,dns:kafka-3.hyperauth -dname "CN=kafka-3.hyperauth" -storepass tmax@23 -keypass tmax@23
  keytool -keystore kafka.broker3.keystore.jks -alias broker3 -certreq -file ca-request-broker3 -storepass tmax@23
  openssl x509 -req -CA /etc/kubernetes/pki/hypercloud-root-ca.crt -CAkey /etc/kubernetes/pki/hypercloud-root-ca.key -in ca-request-broker3 -out ca-signed-broker3 -days 3650 -CAcreateserial
  keytool -keystore kafka.broker3.keystore.jks -alias ca-cert -import -file /etc/kubernetes/pki/hypercloud-root-ca.crt -storepass tmax@23 -noprompt
  keytool -keystore kafka.broker3.keystore.jks -alias broker3 -import -file ca-signed-broker3 -storepass tmax@23 -noprompt
  rm ca-*
    
  kubectl create secret generic kafka-jks --from-file=./kafka.broker1.keystore.jks --from-file=./kafka.broker1.truststore.jks --from-file=./kafka.broker2.keystore.jks --from-file=./kafka.broker2.truststore.jks --from-file=./kafka.broker3.keystore.jks --from-file=./kafka.broker3.truststore.jks -n hyperauth

  ## 다중화
  IFS=' ' read -r -a masters <<< $(kubectl get nodes --selector=node-role.kubernetes.io/master -o jsonpath='{$.items[*].status.addresses[?(@.type=="InternalIP")].address}')
  for master in "${masters[@]}"
  do
  	if [ $master == $MAIN_MASTER_IP ]; then
      continue
  	fi
  	sshpass -p "$MASTER_NODE_ROOT_PASSWORD" scp hypercloud-root-ca.crt ${MASTER_NODE_ROOT_USER}@"$master":/etc/kubernetes/pki/hypercloud-root-ca.crt
  done	

  # step3 Hyperauth Deploymennt

  ## DB IP Sed 해야 할지 아직 판단이 안섬
  kubectl apply -f 2.hyperauth_deployment.yaml

  # step4 Kafka Deployment
  kubectl apply -f 4.kafka_all.yaml

  # step5 Hyperauth Log Collector
  kubectl apply -f 5.hyperauth_log_collector.yaml

popd



