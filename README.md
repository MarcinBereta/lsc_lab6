## 📋 Kroki

### 🔹 Krok 1: Tworzenie klastra EKS
Tworzymy nowy klaster EKS o nazwie `lsc-lab-cluster`, wskazując odpowiednią rolę IAM oraz konfigurację VPC (subnety i grupa zabezpieczeń).

```{bash}
aws eks create-cluster --region us-east-1 --name lsc-lab-cluster \
  --role-arn arn:aws:iam::353343645137:role/LabRole \
  --resources-vpc-config subnetIds=subnet-0b1ef7ff3ab9bd252,subnet-0ab8ee38e4aa05935,subnet-09b674285e0ceed02,securityGroupIds=sg-0f7aea2235adcca85
```

### 🔹 Krok 1: Tworzenie klastra EKS

```{bash}
aws eks create-cluster --region us-east-1 --name lsc-lab-cluster \
  --role-arn arn:aws:iam::353343645137:role/LabRole \
  --resources-vpc-config subnetIds=subnet-0b1ef7ff3ab9bd252,subnet-0ab8ee38e4aa05935,subnet-09b674285e0ceed02,securityGroupIds=sg-0f7aea2235adcca85
```
Czekamy aż klaster stanie się aktywny:

```{bash}
aws eks wait cluster-active --region us-east-1 --name lsc-lab-cluster
```

### 🔹 Krok 2: Tworzenie grupy węzłów (Nodegroup)
Dodajemy do klastra grupę węzłów roboczych z odpowiednią konfiguracją (rozmiar dysku, typ instancji, liczba replik, itd.).
```{bash}
aws eks create-nodegroup --cluster-name lsc-lab-cluster --nodegroup-name lsc-ng \
  --node-role arn:aws:iam::353343645137:role/LabRole \
  --subnets subnet-0b1ef7ff3ab9bd252 subnet-0ab8ee38e4aa05935 subnet-09b674285e0ceed02 \
  --instance-types t3.medium \
  --scaling-config minSize=1,maxSize=2,desiredSize=1 \
  --disk-size 20 \
  --ami-type AL2_x86_64
```

```{bash}
aws eks wait nodegroup-active --region us-east-1 --cluster-name lsc-lab-cluster --nodegroup-name lsc-ng
```

### 🔹 Krok 3: Konfiguracja kubectl
Konfigurujemy lokalne narzędzie kubectl, by mogło komunikować się z naszym klastrem EKS.
```{bash}
aws eks --region us-east-1 update-kubeconfig --name lsc-lab-cluster

```
### 🔹 Krok 4: Test połączenia
Sprawdzamy, czy połączenie z klastrem działa oraz czy węzły są dostępne.

```{bash}
kubectl get nodes
```

###🔹  Krok 5: Instalacja NFS Provisionera
Dodajemy repozytorium Helm i instalujemy provisioner NFS, który umożliwi dynamiczne przydzielanie zasobów persistent volume w Kubernetes.

```{bash}
helm repo add nfs-ganesha-server-and-external-provisioner https://kubernetes-sigs.github.io/nfs-ganesha-server-and-external-provisioner/
helm repo update
helm install nfs-server-provisioner nfs-ganesha-server-and-external-provisioner/nfs-server-provisioner -f ./nfs-values.yaml
```

###🔹  Krok 6: Tworzenie zasobów Kubernetes
Wdrażamy aplikację HTTP oraz konfigurujemy zasoby takie jak Persistent Volume Claim i Job kopiujący dane.

```{bash}
kubectl apply -f pvc.yaml
kubectl apply -f http-server-deployment.yaml
kubectl apply -f http-server-service.yaml
kubectl apply -f copy-content-job.yaml
```
###🔹 Krok 7: Uzyskanie adresu HTTP serwera
Pętla sprawdzająca, czy usługa LoadBalancer otrzymała zewnętrzny adres. Po przydzieleniu pobieramy hostname.

```{bash}
:check_service
kubectl get svc lsc-lab-service | findstr /C:"pending"
if %ERRORLEVEL% EQU 0 (
  echo Service still pending, waiting 15 seconds...
  timeout /t 15
  goto check_service
)
for /f "tokens=*" %%i in ('kubectl get svc lsc-lab-service -o jsonpath^="{.status.loadBalancer.ingress[0].hostname}"') do set EXTERNAL_IP=%%i

echo Dostęp do HTTP serwera: http://%EXTERNAL_IP%
```
