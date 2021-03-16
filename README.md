# HyperAuth 설치 가이드

## 구성 요소 및 버전
* hyperauth
    * [tmaxcloudck/hyperauth:b1.0.14.41](https://hub.docker.com/layers/tmaxcloudck/hyperauth/b1.0.14.41/images/sha256-026d600546d2131de0d33ff80f338b657633a3afb67c7a3adf40f0f7661354f3?context=explore)

## Prerequisites
openssl binary

HyperCloud Console

## 폐쇄망 구축 가이드
1. **폐쇄망에서 설치하는 경우** 사용하는 image repository에 필요한 이미지를 push한다. 

    * 작업 디렉토리 생성 및 환경 설정
    ```bash
	$ mkdir -p ~/hyperauth-install
	$ export HYPERAUTH_HOME=~/hyperauth-install
   $ export POSTGRES_VERSION=9.6.2-alpine
	$ export HYPERAUTH_VERSION=<tag1>
	$ cd ${HYPERAUTH_HOME}

	* <tag1>에는 설치할 hyperauth 버전 명시
		예시: $ export HYPERAUTH_VERSION=1.0.5.6
    ```
    * 외부 네트워크 통신이 가능한 환경에서 필요한 이미지를 다운받는다.
    ```bash
	# postgres
	$ sudo docker pull postgres:${POSTGRES_VERSION}
	$ sudo docker save postgres:${POSTGRES_VERSION} > postgres_${POSTGRES_VERSION}.tar

	# hyperauth
	$ sudo docker pull tmaxcloudck/hyperauth:b${HYPERAUTH_VERSION}
	$ sudo docker save tmaxcloudck/hyperauth:b${HYPERAUTH_VERSION} > hyperauth_b${HYPERAUTH_VERSION}.tar
    ```
  
2. 위의 과정에서 생성한 tar 파일들을 `폐쇄망 환경으로 이동`시킨 뒤 사용하려는 registry에 이미지를 push한다.
	* 작업 디렉토리 생성 및 환경 설정
    ```bash
	$ mkdir -p ~/hyperauth-install
	$ export HYPERAUTH_HOME=~/hyperauth-install
   $ export POSTGRES_VERSION=9.6.2-alpine
	$ export HYPERAUTH_VERSION=<tag1>
   $ export REGISTRY=<REGISTRY_IP_PORT>
	$ cd ${HYPERAUTH_HOME}

	* <tag1>에는 설치할 hypercloud-operator 버전 명시
		예시: $ export HYPERAUTH_VERSION=1.0.5.6
	* <REGISTRY_IP_PORT>에는 폐쇄망 Docker Registry IP:PORT명시
		예시: $ export REGISTRY=192.168.6.110:5000
	```
    * 이미지 load 및 push
    ```bash
    # Load Images
   $ sudo docker load < postgres_${POSTGRES_VERSION}.tar
   $ sudo docker load < hyperauth_b${HYPERAUTH_VERSION}.tar
    
    # Change Image's Tag For Private Registry
   $ sudo docker tag postgres:${POSTGRES_VERSION} ${REGISTRY}/postgres:${POSTGRES_VERSION}
	$ sudo docker tag tmaxcloudck/hyperauth:b${HYPERAUTH_VERSION} ${REGISTRY}/tmaxcloudck/hyperauth:b${HYPERAUTH_VERSION}
    
    # Push Images
	$ sudo docker push ${REGISTRY}/postgres:${POSTGRES_VERSION}
	$ sudo docker push ${REGISTRY}/tmaxcloudck/hyperauth:b${HYPERAUTH_VERSION}
    ```

## 설치 가이드
1. [초기화 작업](#step-1-%EC%B4%88%EA%B8%B0%ED%99%94-%EC%9E%91%EC%97%85)
2. [SSL 인증서 생성](#step-2-ssl-%EC%9D%B8%EC%A6%9D%EC%84%9C-%EC%83%9D%EC%84%B1)
3. [HyperAuth Deployment 생성](#step-3-hyperauth-deployment-%EB%B0%B0%ED%8F%AC)
4. [Kubernetes OIDC 연동]()

## Step 1. 초기화 작업
* 목적 : `HyperAuth 구축을 위한 초기화 작업 및 DB 구축`
* 생성 순서 : [1.initialization.yaml](manifest/1.initialization.yaml) 실행 `ex) kubectl apply -f 1.initialization.yaml`)
* 비고 : 아래 명령어 수행 후, Postgre Admin 접속 확인
```bash
    $ kubectl exec -it $(kubectl get pods -n hyperauth | grep postgre | cut -d ' ' -f1) -n hyperauth -- bash
    $ psql -U keycloak keycloak
 ```

## Step 2. SSL 인증서 생성
* 목적 : `HTTPS 인증을 위한 openssl 인증서를 생성하고 secret으로 변환`
* 생성 순서 : 아래 명령어를 실행하여 인증서 생성 및 secret을 생성 (Master Node의 특정 directory 내부에서 실행 권장)
```bash
    $ openssl req -newkey rsa:4096 -nodes -sha256 -keyout hyperauth.key -x509 -subj "/C=KR/ST=Seoul/O=tmax/CN=$(kubectl describe service hyperauth -n hyperauth | grep 'LoadBalancer Ingress' | cut -d ' ' -f7)" -days 365 -config <(cat /etc/ssl/openssl.cnf <(printf "[v3_ca]\nsubjectAltName=IP:$(kubectl describe service hyperauth -n hyperauth | grep 'LoadBalancer Ingress' | cut -d ' ' -f7)")) -out hyperauth.crt
    $ CentOS의 경우 : openssl req -newkey rsa:4096 -nodes -sha256 -keyout hyperauth.key -x509 -subj "/C=KR/ST=Seoul/O=tmax/CN=(kubectl describe service hyperauth -n hyperauth | grep 'LoadBalancer Ingress' | cut -d ' ' -f7)" -days 365 -config <(cat /etc/pki/tls/openssl.cnf <(printf "[v3_ca]\nsubjectAltName=IP:$(kubectl describe service hyperauth -n hyperauth | grep 'LoadBalancer Ingress' | cut -d ' ' -f7)")) -out hyperauth.crt
    $ kubectl create secret tls hyperauth-https-secret --cert=./hyperauth.crt --key=./hyperauth.key -n hyperauth
    $ cp hyperauth.crt /etc/kubernetes/pki/hyperauth.crt
```
* 비고 : 
    * Kubernetes Master가 다중화 된 경우, hyperauth.crt를 각 Master 노드들의 /etc/kubernetes/pki/hyperauth.crt 로 cp
    * MetalLB에 의해 생성된 Loadbalancer type의 ServiceIP만 인증


## Step 3. HyperAuth Deployment 배포
* 목적 : `HyperAuth 설치`
* 생성 순서 :
    * [2.hyperauth_deployment.yaml](manifest/2.hyperauth_deployment.yaml) 실행 `ex) kubectl apply -f 2.hyperauth_deployment.yaml`
    * HyperAuth Admin Console에 접속 확인
        * `kubectl get svc hyperauth -n hyperauth` 명령어로 IP 확인
        * 계정 : admin/admin
    * Realm Import의 경우 Hypercloud console설치 후에 진행한다. 
    * [3.tmax-realm-export.json](manifest/3.tmax-realm-export.json), [tmaxRealmImport](manifest/tmaxRealmImport) 다운 후, 아래 명령어를 실행하여 기본 Tmax Realm 및 K8s admin 계정 생성
```bash
    $ export HYPERAUTH_SERVICE_IP = $(kubectl describe service hyperauth -n hyperauth | grep 'LoadBalancer Ingress' | cut -d ' ' -f7)
    $ export HYPERCLOUD-CONSOLE_IP = $(kubectl describe service console-lb -n console-system | grep 'LoadBalancer Ingress' | cut -d
    $ ./tmaxRealmImport.sh $HYPERAUTH_SERVICE_IP $HYPERCLOUD-CONSOLE_IP
```
* 비고 :
    * K8s admin 기본 계정 정보 : admin@tmax.co.kr/Tmaxadmin1!
    * HyperAuth User 메뉴에서 비밀번호는 변경 가능, ID를 위해서는 clusterrole도 변경 필요

## Step 4. Kubernetes OIDC 연동
* 목적 : `Kubernetes의 RBAC 시스템과 HyperAuth 인증 연동`
* 생성 순서 :
    * Kubernetes Cluster Master Node에 접속
    * {HYPERAUTH_SERVICE_IP} = $(kubectl describe service hyperauth -n hyperauth | grep 'LoadBalancer Ingress' | cut -d ' ' -f7)
    * `/etc/kubernetes/manifests/kube-apiserver.yaml` 의 spec.containers[0].command[] 절에 아래 command를 추가
    
    ```yaml
    --oidc-issuer-url=https://{HYPERAUTH_SERVICE_IP}/auth/realms/tmax
    --oidc-client-id=hypercloud4
    --oidc-username-claim=preferred_username
    --oidc-username-prefix=-
    --oidc-groups-claim=group
    --oidc-ca-file=/etc/kubernetes/pki/hyperauth.crt
    ```
    
* 비고 :
    * 자동으로 kube-apiserver 가 재기동 됨

## 삭제 가이드
