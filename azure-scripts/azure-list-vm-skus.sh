#!/bin/bash

az vm list-skus -l westeurope --output table \
  --query "[?resourceType=='virtualMachines' && capabilities[?name=='AcceleratedNetworkingEnabled' && value=='True'] && capabilities[?name=='EncryptionAtHostSupported' && value=='True'] && capabilities[?name=='PremiumIO' && value=='True']].{Name:name,vCPUs:capabilities[?name=='vCPUs'].value|[0],MemoryGB:capabilities[?name=='MemoryGB'].value|[0]}"
  