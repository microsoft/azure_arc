targetScope = 'subscription'

resource VirtualMachines 'Microsoft.Security/pricings@2022-03-01' = {
  name: 'VirtualMachines'
  properties: {
    pricingTier: 'Standard'
    subPlan: 'P2'
  }
}
