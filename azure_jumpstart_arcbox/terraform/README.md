Steps on how to setup the azure arc hyper v lab in your own Azure Subscription

Step 1:
create an SP  ( requires Owner rather than Contributor

```bash
export ARM_CLIENT_SECRET=<Enter Here>
export ARM_CLIENT_ID=<Enter Here>
export ARM_TENANT_ID=<Enter Here>
export ARM_SUBSCRIPTION_ID=<Enter Here>
```

```bash
az login \                                                       
    --service-principal \                                
    --tenant "$ARM_TENANT_ID" \
    --username "$ARM_CLIENT_ID" \
    --password "$ARM_CLIENT_SECRET"
```

