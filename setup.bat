@echo off
SETLOCAL EnableDelayedExpansion

REM Step 1: Create an EKS Cluster using AWS CLI directly (not eksctl)
echo Creating EKS Cluster...
aws eks create-cluster --region us-east-1 --name lsc-lab-cluster --role-arn arn:aws:iam::353343645137:role/LabRole --resources-vpc-config subnetIds=subnet-0b1ef7ff3ab9bd252,subnet-0ab8ee38e4aa05935,subnet-09b674285e0ceed02,securityGroupIds=sg-0f7aea2235adcca85

echo Waiting for cluster to become active...
aws eks wait cluster-active --region us-east-1 --name lsc-lab-cluster
echo Cluster is now active.

REM Step 2: Create nodegroup for the EKS cluster
echo Creating nodegroup for the cluster...
aws eks create-nodegroup --cluster-name lsc-lab-cluster --nodegroup-name lsc-ng --node-role arn:aws:iam::353343645137:role/LabRole --subnets subnet-0b1ef7ff3ab9bd252 subnet-0ab8ee38e4aa05935 subnet-09b674285e0ceed02 --instance-types t3.medium --scaling-config minSize=1,maxSize=2,desiredSize=1 --disk-size 20 --ami-type AL2_x86_64

echo Waiting for nodegroup to become active...
aws eks wait nodegroup-active --region us-east-1 --cluster-name lsc-lab-cluster --nodegroup-name lsc-ng
echo Nodegroup is now active.

REM Step 3: Configure kubectl to use the newly created EKS cluster
echo Configuring kubectl to use the EKS cluster...
aws eks --region us-east-1 update-kubeconfig --name lsc-lab-cluster

REM Step 4: Test kubectl connection
echo Testing kubectl connection...
kubectl get nodes

REM Step 5: Add Helm repository for NFS provisioner and install
echo Adding Helm repository for NFS provisioner...
helm repo add nfs-ganesha-server-and-external-provisioner https://kubernetes-sigs.github.io/nfs-ganesha-server-and-external-provisioner/
helm repo update
echo Installing NFS Server and Provisioner...
helm install nfs-server-provisioner nfs-ganesha-server-and-external-provisioner/nfs-server-provisioner -f ./nfs-values.yaml

REM Step 6: Apply Kubernetes configurations
echo Creating Persistent Volume Claim...
kubectl apply -f pvc.yaml
echo Deploying HTTP server...
kubectl apply -f http-server-deployment.yaml
echo Creating service for HTTP server...
kubectl apply -f http-server-service.yaml
echo Creating job to copy content...
kubectl apply -f copy-content-job.yaml

REM Step 7: Retrieve and display the external IP of the HTTP service
echo Retrieving external IP of the HTTP server...
echo This may take a few minutes as the load balancer provisions...
timeout /t 30
:check_service
kubectl get svc lsc-lab-service | findstr /C:"pending"
if %ERRORLEVEL% EQU 0 (
  echo Service still pending, waiting 15 seconds...
  timeout /t 15
  goto check_service
)
for /f "tokens=*" %%i in ('kubectl get svc lsc-lab-service -o jsonpath^="{.status.loadBalancer.ingress[0].hostname}"') do set EXTERNAL_IP=%%i

echo.
echo =====================================================
echo Access the HTTP server at http://%EXTERNAL_IP%
echo =====================================================
echo.

echo EKS cluster deployment completed.
pause