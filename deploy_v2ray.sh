#!/bin/bash
set -e

### ==== 可按需修改 ==== ###
RESOURCE_GROUP="v2ray-rg"
LOCATION="southeastasia"
VM_NAME="v2ray-vm"
PIP_NAME="v2ray-pip"
NIC_NAME="v2ray-nic"
NSG_NAME="v2ray-nsg"
VNET_NAME="v2ray-vnet"
SUBNET_NAME="v2ray-subnet"
IMAGE="Ubuntu2204"
ADMIN_USER="azureuser"
VM_SIZE="Standard_B2s"
PORT_RANGE="20000-65515"
CLOUD_INIT_FILE="cloud-init.yaml"
### ===================== ###

echo "==> 1. 创建资源组 $RESOURCE_GROUP ($LOCATION) ..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none

echo "==> 2. 检查并创建公网 IP $PIP_NAME ..."
if ! az network public-ip show --resource-group "$RESOURCE_GROUP" --name "$PIP_NAME" &>/dev/null; then
  az network public-ip create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$PIP_NAME" \
    --sku Standard \
    --allocation-method Static \
    --location "$LOCATION" \
    --output none

  echo "    等待公网 IP $PIP_NAME 就绪 ..."
  az network public-ip wait --resource-group "$RESOURCE_GROUP" --name "$PIP_NAME" --created
else
  echo "    公网 IP $PIP_NAME 已存在，跳过创建。"
fi

echo "==> 3. 创建 VNet $VNET_NAME / Subnet $SUBNET_NAME ..."
az network vnet create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VNET_NAME" \
  --address-prefix 10.0.0.0/16 \
  --subnet-name "$SUBNET_NAME" \
  --subnet-prefix 10.0.0.0/24 \
  --location "$LOCATION" \
  --output none

echo "    等待 VNet $VNET_NAME 就绪 ..."
az network vnet wait --resource-group "$RESOURCE_GROUP" --name "$VNET_NAME" --created

echo "==> 4. 创建 NSG $NSG_NAME ..."
az network nsg create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$NSG_NAME" \
  --location "$LOCATION" \
  --output none

echo "    等待 NSG $NSG_NAME 就绪 ..."
az network nsg wait --resource-group "$RESOURCE_GROUP" --name "$NSG_NAME" --created

echo "==> 5. 配置 NSG 规则 ..."
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "$NSG_NAME" \
  --name AllowSSH \
  --priority 1000 \
  --access Allow \
  --direction Inbound \
  --protocol Tcp \
  --destination-port-ranges 22 \
  --output none

az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "$NSG_NAME" \
  --name AllowV2Ray \
  --priority 1010 \
  --access Allow \
  --direction Inbound \
  --protocol '*' \
  --destination-port-ranges "$PORT_RANGE" \
  --output none

echo "==> 6. 创建 NIC $NIC_NAME ..."
az network nic create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$NIC_NAME" \
  --vnet-name "$VNET_NAME" \
  --subnet "$SUBNET_NAME" \
  --network-security-group "$NSG_NAME" \
  --public-ip-address "$PIP_NAME" \
  --location "$LOCATION" \
  --output none

echo "    等待 NIC $NIC_NAME 就绪 ..."
az network nic wait --resource-group "$RESOURCE_GROUP" --name "$NIC_NAME" --created

echo "==> 7. 创建 VM $VM_NAME ..."
az vm create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --nics "$NIC_NAME" \
  --image "$IMAGE" \
  --admin-username "$ADMIN_USER" \
  --generate-ssh-keys \
  --size "$VM_SIZE" \
  --custom-data "$CLOUD_INIT_FILE" \
  --authentication-type ssh \
  --location "$LOCATION" \
  --output table

echo "    等待 VM $VM_NAME 成功启动 ..."
az vm wait --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" --created

echo "==> 8. 获取公网 IP ..."
PUBLIC_IP=$(az network public-ip show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$PIP_NAME" \
  --query ipAddress -o tsv)

echo -e "\n✅ 部署完成！公网 IP: $PUBLIC_IP"

echo "==> 9. 获取 VMess 链接 …"
VMESS_URL=$(az vm run-command invoke \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --command-id RunShellScript \
  --scripts "cat /var/lib/cloud/instance/v2ray-url.txt || echo '未找到链接'" \
  --query 'value[0].message' -o tsv)

echo -n -e "\n🔗 VMess 链接:\n"
echo "$VMESS_URL" | sed '/^$/d'

echo -e "\n📌 如有需要，你可以通过 SSH 登录服务器查看完整配置或链接："
echo "    ssh $ADMIN_USER@$PUBLIC_IP"
echo "    文件路径：/var/lib/cloud/instance/v2ray-url.txt"
