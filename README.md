# HyperAuth 설치 가이드

## 구성 요소 및 버전
* hyperauth
    * [tmaxcloudck/hyperauth:b1.1.0.23](https://hub.docker.com/layers/tmaxcloudck/hyperauth/b1.1.0.23/images/sha256-c2d269165872e16f82d8b300f9144caf4f7a0b382a400975088e5029a7605d12?context=repo)
* postgres
    * postgres:9.6.2-alpine
* zookeeper
    * wurstmeister/zookeeper:3.4.6
* kafka
    * wurstmeister/kafka:2.12-2.0.1
    
## SPEC (21.01.25)
### Hyperauth
cpu : 300m
memory: 300Mi

## DB (Postgresql, tibero)
cpu: 300
memory: 300Mi
Storage: 100Gi

### Kafka X 3
cpu : 100m
memory: 100Mi
Storage: 5Gi

### Zookeeper
cpu : 100m
memory: 100Mi
Storage: 5Gi

## Prerequisites
* Java binary
* openssl binary
* keytool binary
* jq binary
* Storage class
  * 아래 명령어를 통해 storage class가 설치되어 있는지 확인한다.
    * `$ kubectl get storageclass`
  * 만약 아무 storage class가 없다면 아래 링크로 이동하여 rook-ceph 설치한다. 
    * https://github.com/tmax-cloud/hypercloud-install-guide/tree/4.1/rook-ceph
  * Storage class는 있지만 default로 설정된 것이 없다면 아래 명령어를 실행한다.
    * ` $ kubectl patch storageclass csi-cephfs-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'`
  * csi-cephfs-sc는 위 링크로 rook-ceph를 설치했을 때 생성되는 storage class이며 다른 storage class를 default로 사용해도 무관하다.

## 폐쇄망 구축 가이드
1. **폐쇄망에서 설치하는 경우** 사용하는 image repository에 필요한 이미지를 push한다. 

    * 작업 디렉토리 생성 및 환경 설정
    ```bash
	$ mkdir -p ~/hyperauth-install
	
	# For Hyperauth
	$ export HYPERAUTH_HOME=~/hyperauth-install
	$ cd ${HYPERAUTH_HOME}
 	$ export POSTGRES_VERSION=9.6.2-alpine
	$ export HYPERAUTH_VERSION=<tag1>
   	$ export REGISTRY=<REGISTRY_IP_PORT>
	$ export ZOOKEEPER_VERSION=3.4.6
	$ export KAFKA_VERSION=2.12-2.0.1
	
	* <tag1>에는 설치할 hyperauth 버전 명시
		예시: $ export HYPERAUTH_VERSION=1.1.0.23
	* <REGISTRY_IP_PORT>에는 폐쇄망 Docker Registry IP:PORT명시
		예시: $ export REGISTRY=192.168.6.110:5000
    ```
    * 외부 네트워크 통신이 가능한 환경에서 필요한 이미지를 다운받는다.
    ```bash
	# postgres
	$ sudo docker pull postgres:${POSTGRES_VERSION}
	$ sudo docker save postgres:${POSTGRES_VERSION} > postgres_${POSTGRES_VERSION}.tar

	# hyperauth
	$ sudo docker pull tmaxcloudck/hyperauth:b${HYPERAUTH_VERSION}
	$ sudo docker save tmaxcloudck/hyperauth:b${HYPERAUTH_VERSION} > hyperauth_b${HYPERAUTH_VERSION}.tar
	
	# kafka, zookeeper
	$ sudo docker pull wurstmeister/zookeeper:${ZOOKEEPER_VERSION}
	$ sudo docker save wurstmeister/zookeeper:${ZOOKEEPER_VERSION} > zookeeper_${ZOOKEEPER_VERSION}.tar
	$ sudo docker pull wurstmeister/kafka:${KAFKA_VERSION}
	$ sudo docker save wurstmeister/kafka:${KAFKA_VERSION} > kafka_${KAFKA_VERSION}.tar
    ```
  
2. 위의 과정에서 생성한 tar 파일들을 `폐쇄망 환경으로 이동`시킨 뒤 사용하려는 registry에 이미지를 push한다.
	
    * 이미지 load 및 push
    ```bash
    # Load Images
	$ sudo docker load < postgres_${POSTGRES_VERSION}.tar
	$ sudo docker load < hyperauth_b${HYPERAUTH_VERSION}.tar
        $ sudo docker load < kafka_${KAFKA_VERSION}.tar
	$ sudo docker load < zookeeper_${ZOOKEEPER_VERSION}.tar

    # Change Image's Tag For Private Registry
	$ sudo docker tag postgres:${POSTGRES_VERSION} ${REGISTRY}/postgres:${POSTGRES_VERSION}
	$ sudo docker tag tmaxcloudck/hyperauth:b${HYPERAUTH_VERSION} ${REGISTRY}/hyperauth:b${HYPERAUTH_VERSION}
	$ sudo docker tag wurstmeister/kafka:${KAFKA_VERSION} ${REGISTRY}/kafka:${KAFKA_VERSION}
	$ sudo docker tag wurstmeister/zookeeper:${ZOOKEEPER_VERSION} ${REGISTRY}/zookeeper:${ZOOKEEPER_VERSION}
    
    # Push Images
	$ sudo docker push ${REGISTRY}/postgres:${POSTGRES_VERSION}
	$ sudo docker push ${REGISTRY}/hyperauth:b${HYPERAUTH_VERSION}
    	$ sudo docker push ${REGISTRY}/kafka:${KAFKA_VERSION}
	$ sudo docker push ${REGISTRY}/zookeeper:${ZOOKEEPER_VERSION}
    ```

## 설치 가이드
1. [초기화 작업](#step-1-%EC%B4%88%EA%B8%B0%ED%99%94-%EC%9E%91%EC%97%85)
2. [SSL 인증서 생성](#step-2-ssl-%EC%9D%B8%EC%A6%9D%EC%84%9C-%EC%83%9D%EC%84%B1)
3. [HyperAuth Deployment 생성](#step-3-hyperauth-deployment-%EB%B0%B0%ED%8F%AC)
4. [Kubernetes OIDC 연동](#step-4-kubernetes-oidc-%EC%97%B0%EB%8F%99)

## Step 1. 초기화 작업 및 yaml 수정
* 목적 : `HyperAuth 구축을 위한 초기화 작업, Secret생성 및 DB 구축, Yaml 버전 수정`
* 아래의 command를 수정하여 사용하고자 하는 image 버전 정보를 수정한다.
```bash
    $ export POSTGRES_VERSION=9.6.2-alpine
    $ sed -i 's/POSTGRES_VERSION/'${POSTGRES_VERSION}'/g' 1.initialization.yaml
    $ export HYPERAUTH_SERVER_VERSION=b1.1.0.23
    $ sed -i 's/HYPERAUTH_SERVER_VERSION/'${HYPERAUTH_SERVER_VERSION}'/g' 2.hyperauth_deployment.yaml
    $ export ZOOKEEPER_VERSION=3.4.6
    $ sed -i 's/ZOOKEEPER_VERSION/'${ZOOKEEPER_VERSION}'/g' 5.kafka_deployment.yaml
    $ export KAFKA_VERSION=2.12-2.0.1
    $ sed -i 's/KAFKA_VERSION/'${KAFKA_VERSION}'/g' 5.kafka_deployment.yaml
 ```
* 생성 순서 : [1.initialization.yaml](manifest/1.initialization.yaml) 실행 `ex) kubectl apply -f 1.initialization.yaml`)
* 비고 : 아래 명령어 수행 후, Postgre Admin 접속 확인
```bash
    $ kubectl exec -it $(kubectl get pods -n hyperauth | grep postgre | cut -d ' ' -f1) -n hyperauth -- bash
    $ psql -U keycloak keycloak
 ```
* Kafka를 외부(k8s cluster 외부)로 노출하는 경우 Nginx Ingress Controller를 깔아야 한다.
	* ingress-nginx-system ns에 nginx ingress controller가 안깔려있는 경우  https://github.com/tmax-cloud/install-ingress/tree/5.0 참조 설치 진행
	* 설치한 (혹은 기존에 설치 되어있던) Ingress controller의 Deployment 와 Service를 지우고 다시 생성한다. (설정 추가)  [nginx-ingress-controller-kafka.yaml](manifest/1nginx-ingress-controller-kafka.yaml) 이용해서 지웠다가 생성
```bash
    $ kubectl delete -f nginx-ingress-controller-kafka.yaml        
    $ kubectl apply -f nginx-ingress-controller-kafka.yaml
 ```
## Step 2. SSL 인증서 생성
* 목적 : `HTTPS 인증을 위한 openssl root-ca 인증서, keystore, truststore를 생성하고 secret으로 변환`
* 생성 순서 : generateCerts.sh shell을 실행하여 root-ca 인증서 생성, kafka topic 서버와의 ssl통신을 위한 keystore, truststore 생성 및 secret을 생성 (Master Node의 특정 directory 내부에서 실행 권장)
* 비고 : openssl 및 keytool을 먼저 설치 하여야 한다. ( yum install -y openssl , yum install -y java-1.8.0-openjdk-devel.x86_64, apt install openssl, apt install openjdk-8-jre-headless)
```bash
    // For Hyperauth
    $ sudo chmod +755 generateCerts.sh
    $ sudo ./generateCerts.sh -ip=$(kubectl describe service hyperauth -n hyperauth | grep 'LoadBalancer Ingress' | cut -d ' ' -f7)
    $ kubectl create secret tls hyperauth-https-secret --cert=./hyperauth.crt --key=./hyperauth.key -n hyperauth
    $ sudo cp hypercloud-root-ca.crt /etc/kubernetes/pki/hypercloud-root-ca.crt
    $ sudo cp hypercloud-root-ca.key /etc/kubernetes/pki/hypercloud-root-ca.key
    $ sudo cp hyperauth.crt /etc/kubernetes/pki/hyperauth.crt
    $ sudo cp hyperauth.key /etc/kubernetes/pki/hyperauth.key
    
    $ sudo keytool -keystore hyperauth.truststore.jks -alias ca-cert -import -file /etc/kubernetes/pki/hypercloud-root-ca.crt -storepass tmax@23 -noprompt
    $ sudo keytool -keystore hyperauth.keystore.jks -alias hyperauth -validity 3650 -genkey -keyalg RSA -dname "CN=hyperauth" -storepass tmax@23 -keypass tmax@23
    $ sudo keytool -keystore hyperauth.keystore.jks -alias hyperauth -certreq -file ca-request-hyperauth -storepass tmax@23
    $ sudo openssl x509 -req -CA /etc/kubernetes/pki/hypercloud-root-ca.crt -CAkey /etc/kubernetes/pki/hypercloud-root-ca.key -in ca-request-hyperauth -out ca-signed-hyperauth -days 3650 -CAcreateserial
    $ sudo keytool -keystore hyperauth.keystore.jks -alias ca-cert -import -file /etc/kubernetes/pki/hypercloud-root-ca.crt -storepass tmax@23 -noprompt
    $ sudo keytool -keystore hyperauth.keystore.jks -alias hyperauth -import -file ca-signed-hyperauth -storepass tmax@23 -noprompt
    $ kubectl create secret generic hyperauth-kafka-jks --from-file=./hyperauth.keystore.jks --from-file=./hyperauth.truststore.jks -n hyperauth

    // For Kafka-Brokers
    $ sudo keytool -keystore kafka.broker.truststore.jks -alias ca-cert -import -file /etc/kubernetes/pki/hypercloud-root-ca.crt -storepass tmax@23 -noprompt
    $ sudo keytool -keystore kafka.broker.keystore.jks -alias broker -validity 3650 -genkey -keyalg RSA -dname "CN=kafka" -storepass tmax@23 -keypass tmax@23
    $ sudo keytool -keystore kafka.broker.keystore.jks -alias broker -certreq -file ca-request-broker -storepass tmax@23
    
    // Kafka가 쓸 Nginx Ingress Controller가 외부로 IP로 노출되어 있는 경우 NGINX_INGRESS_CONTROLLER_EXTERNAL_IP 부분 치환, DNS로 노출되어 있는 경우 NGINX_INGRESS_CONTROLLER_EXTERNAL_DNS 부분 치환, 나머지는 지워준다, Kafka를 외부 ( k8s cluster 외부 ) 로 노출 하지 않는 경우에는 IP:{NGINX_INGRESS_CONTROLLER_EXTERNAL_IP},DNS:{NGINX_INGRESS_CONTROLLER_EXTERNAL_DNS} 둘다 필요 없음
    
    $ cat > "kafka.cnf" <<EOL
[kafka]
subjectAltName = DNS:kafka-1.hyperauth,DNS:kafka-2.hyperauth,DNS:kafka-3.hyperauth,IP:{NGINX_INGRESS_CONTROLLER_EXTERNAL_IP},DNS:{NGINX_INGRESS_CONTROLLER_EXTERNAL_DNS}
EOL
    // ex) NGINX_INGRESS_CONTROLLER_EXTERNAL_IP = 172.22.6.13, NGINX_INGRESS_CONTROLLER_EXTERNAL_DNS = 172.22.6.13.nip.io 혹은 Public DNS
    
    $ sudo openssl x509 -req -CA /etc/kubernetes/pki/hypercloud-root-ca.crt -CAkey /etc/kubernetes/pki/hypercloud-root-ca.key -in ca-request-broker -out ca-signed-broker -days 3650 -CAcreateserial -extfile "kafka.cnf" -extensions kafka -sha256
    $ sudo keytool -keystore kafka.broker.keystore.jks -alias ca-cert -import -file /etc/kubernetes/pki/hypercloud-root-ca.crt -storepass tmax@23 -noprompt
    $ sudo keytool -keystore kafka.broker.keystore.jks -alias broker -import -file ca-signed-broker -storepass tmax@23 -noprompt
    $ kubectl create secret generic kafka-jks --from-file=./kafka.broker.keystore.jks --from-file=./kafka.broker.truststore.jks -n hyperauth
```
* 비고 : 
    * Kubernetes Master가 다중화 된 경우, hypercloud-root-ca.crt, hyperauth.crt를 각 Master 노드들의 /etc/kubernetes/pki/hypercloud-root-ca.crt, /etc/kubernetes/pki/hyperauth.crt 로 cp
    * MetalLB에 의해 생성된 Loadbalancer type의 ExternalIP만 인증


## Step 3. HyperAuth Deployment 배포
* 목적 : `HyperAuth 설치`
* 생성 순서 :
    * [2.hyperauth_deployment.yaml](manifest/2.hyperauth_deployment.yaml) 실행 `ex) kubectl apply -f 2.hyperauth_deployment.yaml`
    * HyperAuth Admin Console에 접속 확인
        * `kubectl get svc hyperauth -n hyperauth` 명령어로 IP 확인
        * 계정 : admin/admin
    * [3.tmax-realm-export.json](manifest/3.tmax-realm-export.json), [tmaxRealmImport.sh](manifest/tmaxRealmImport.sh) 다운 후, 아래 명령어를 실행하여 기본 Tmax Realm 및 K8s admin 계정 생성
```bash
    $ export HYPERAUTH_SERVICE_IP=$(kubectl describe service hyperauth -n hyperauth | grep 'LoadBalancer Ingress' | cut -d ' ' -f7)
    $ echo $HYPERAUTH_SERVICE_IP
    $ export HYPERCLOUD_CONSOLE_IP=$(kubectl describe service console-lb -n console-system | grep 'LoadBalancer Ingress' | cut -d ' ' -f7)
    $ echo $HYPERCLOUD_CONSOLE_IP
    $ chmod 755 tmaxRealmImport.sh
    $ ./tmaxRealmImport.sh $HYPERAUTH_SERVICE_IP $HYPERCLOUD_CONSOLE_IP
```
* 비고 :
    * K8s admin 기본 계정 정보 : hc-admin@tmax.co.kr/Tmaxadmin1!
    * HyperAuth User 메뉴에서 비밀번호는 변경 가능, ID를 위해서는 clusterrole도 변경 필요
    
## Step 4. Kafka Topic Server 설치
* 목적 : `Hyperauth의 Event를 Subscribe 할수 있는 kafka server 설치`
* 생성 순서 :
    * [4.kafka_init.yaml](manifest/4.kafka_init.yaml) 실행 `ex) kubectl apply -f 4.kafka_init.yaml`
    * NGINX_INGRESS_CONTROLLER_EXTERNAL_IP=$(kubectl describe service ingress-nginx-system-controller -n ingress-nginx-system | grep 'LoadBalancer Ingress' | cut -d ' ' -f7)
    * [5.kafka_deployment.yaml](manifest/5.kafka_deployment.yaml) 실행 `ex) kubectl apply -f 5.kafka_deployment.yaml`
* 비고 : 
    * hyperauth 이미지 tmaxcloudck/hyperauth:b1.0.15.31 이후부터 설치 적용할 것!
    
## Step 5. Kubernetes OIDC 연동
* 목적 : `Kubernetes의 RBAC 시스템과 HyperAuth 인증 연동`
* 생성 순서 :
    * Kubernetes Cluster Master Node에 접속
    * {HYPERAUTH_SERVICE_IP} = $(kubectl describe service hyperauth -n hyperauth | grep 'LoadBalancer Ingress' | cut -d ' ' -f7)
    * `/etc/kubernetes/manifests/kube-apiserver.yaml` 의 spec.containers[0].command[] 절에 아래 command를 추가
    
    ```yaml
    --oidc-issuer-url=https://{HYPERAUTH_SERVICE_IP}/auth/realms/tmax
    --oidc-client-id=hypercloud5
    --oidc-username-claim=preferred_username
    --oidc-username-prefix=-
    --oidc-groups-claim=group
    --oidc-ca-file=/etc/kubernetes/pki/hyperauth.crt
    ```
    
* 비고 :
    * 자동으로 kube-apiserver 가 재기동 됨

## Step 6. Prometheus 연동 (Optional)
* 목적 : `Prometheus 모니터링 시스템과 HyperAuth 이벤트 metrics 연동`
* 필수 요건 
    * Prometheus 설치 : https://github.com/tmax-cloud/install-prometheus 참조
    * Admin Console (tmax realm) - Events - Config - Events Config : prometheus-metric-listener 추가
* 생성 순서 :
    * ServiceMonitor 생성
    * [6.hyperauth_service_monitor.yaml](manifest/6.hyperauth_service_monitor.yaml) 실행 `ex) kubectl apply -f 4.kafka_init.yaml`
    
* 비고 :
    * 자동으로 Prometheus가 수집을 시작함
    * grafana dashboard import
        * grafana - import - https://github.com/tmax-cloud/install-hyperauth/blob/main/manifest/hyperauth_metric.json 내용 붙여넣기


## 삭제 가이드
