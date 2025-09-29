## Azure🪜自建

1. 通过Azure Portal 进入CLI
2. 上传：`cloud-init.yaml`和`deploy_v2ray.sh`
3. 更改权限： `chmod +x deploy_v2ray.sh`
4. 运行：`./deploy_v2ray.sh`
5. 复制命令行输出的vmess链接，也可以去文件路径看链接
6. (若未做) 设置端口inbound rules
  ```
  az network nsg rule create \
    --resource-group v2ray-rg \
    --nsg-name v2ray-nsg \
    --name AllowV2Ray15961 \
    --priority 1011 \
    --access Allow \
    --direction Inbound \
    --protocol '*' \
    --destination-port-ranges 15961 \
    --output none
  ```
7. 若使用ClashX, 则打开`vmess2clashx_index.html`，将vmess链接转为ClashX配置

参考链接：
- [Deon Chen - v2ray-on-Azure-fast-deploy](https://github.com/2012952877/v2ray-on-Azure-fast-deploy)
- [xingdawang - vmess2clashx](https://github.com/xingdawang/vmess2clashx)
