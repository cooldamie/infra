// Azure estate for damiecodes.com: the portfolio's Static Web App and the DNS zone.
// Side projects add their own modules here as they arrive (Wave 1 onward).
targetScope = 'resourceGroup'

@description('Region for the Static Web App resource. Content is served from a global edge regardless.')
@allowed(['westeurope', 'eastus2', 'centralus', 'westus2', 'eastasia'])
param location string = 'westeurope'

@description('Name of the portfolio Static Web App.')
param siteName string = 'damiecodes-portfolio'

@description('Apex domain, already registered by the owner.')
param domainName string = 'damiecodes.com'

param tags object = {
  project: 'damiecodes'
  managedBy: 'bicep'
}

resource site 'Microsoft.Web/staticSites@2022-09-01' = {
  name: siteName
  location: location
  tags: tags
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {
    // Deployed by GitHub Actions with a deployment token; no repository link needed here.
    stagingEnvironmentPolicy: 'Enabled'
    allowConfigFileUpdates: true
  }
}

resource zone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: domainName
  location: 'global'
  tags: tags
}

// Apex points at the Static Web App through an alias record, so it follows the app if it moves.
resource apex 'Microsoft.Network/dnsZones/A@2018-05-01' = {
  parent: zone
  name: '@'
  properties: {
    TTL: 3600
    targetResource: {
      id: site.id
    }
  }
}

resource www 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  parent: zone
  name: 'www'
  properties: {
    TTL: 3600
    CNAMERecord: {
      cname: site.properties.defaultHostname
    }
  }
}

output siteDefaultHostname string = site.properties.defaultHostname
output nameServers array = zone.properties.nameServers
