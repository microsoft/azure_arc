@description('The friendly name for the workbook that is used in the Gallery or Saved List.  This name must be unique within a resource group.')
param workbookDisplayName string = 'Azure Arc-enabled servers OS Performance'
@description('The gallery that the workbook will been shown under. Supported values include workbook, tsg, etc. Usually, this is \'workbook\'')
param workbookType string = 'workbook'
@description('The id of resource instance to which the workbook will be associated')
param workbookSourceId string = 'azure monitor'
@description('The unique guid for this workbook instance')
param workbookId string = guid('OSPerformance')
@description('The location to deploy the workbook to')
param location string = resourceGroup().location
@description('Workbook content')
var workbookContent = {
  version: 'Notebook/1.0'
  items: [
    {
      type: 1
      content: {
        json: '# Operating System - Performance and capacity'
      }
      name: 'text - 0'
    }
    {
      type: 9
      content: {
        version: 'KqlParameterItem/1.0'
        crossComponentResources: [
          '{Workspace}'
        ]
        parameters: [
          {
            id: 'b82b64ff-f991-4f44-ac88-aee7c086cc48'
            version: 'KqlParameterItem/1.0'
            name: 'TimeRange'
            type: 4
            isRequired: true
            value: {
              durationMs: 86400000
            }
            typeSettings: {
              selectableValues: [
                {
                  durationMs: 3600000
                }
                {
                  durationMs: 43200000
                }
                {
                  durationMs: 86400000
                }
                {
                  durationMs: 259200000
                }
                {
                  durationMs: 604800000
                }
                {
                  durationMs: 1209600000
                }
                {
                  durationMs: 2592000000
                }
              ]
              allowCustom: true
            }
          }
          {
            id: '23e3bd37-240d-492a-99c1-5b4f3d79d75e'
            version: 'KqlParameterItem/1.0'
            name: 'Subscription'
            type: 6
            isRequired: true
            multiSelect: true
            quote: '\''
            delimiter: ','
            value: [
              '/subscriptions/00000000-0000-0000-0000-000000000000'
            ]
            query: 'where type =~ \'microsoft.compute/virtualmachines\' or type =~ \'microsoft.hybridcompute/machines\' \r\n| summarize Count = count() by subscriptionId\r\n\t| order by Count desc\r\n\t| extend Rank = row_number()\r\n\t| project value = subscriptionId, label = subscriptionId, selected = Rank == 1'
            crossComponentResources: [
              'value::all'
            ]
            typeSettings: {
              limitSelectTo: 100
              additionalResourceOptions: [
                'value::all'
              ]
              showDefault: false
            }
            queryType: 1
            resourceType: 'microsoft.resourcegraph/resources'
          }
          {
            id: 'e1ecac91-1691-4f48-b4c0-803e39e00f43'
            version: 'KqlParameterItem/1.0'
            name: 'Workspace'
            type: 5
            isRequired: true
            multiSelect: true
            quote: '\''
            delimiter: ','
            query: 'where type =~ \'microsoft.operationalinsights/workspaces\'\r\n| summarize by id, name\r\n'
            crossComponentResources: [
              '{Subscription}'
            ]
            typeSettings: {
              additionalResourceOptions: []
              showDefault: false
            }
            timeContext: {
              durationMs: 0
            }
            timeContextFromParameter: 'TimeRange'
            queryType: 1
            resourceType: 'microsoft.resourcegraph/resources'
            value: [
              'value::all'
            ]
          }
          {
            id: '98c624e3-84f5-43e2-8be3-56b84c75bbb2'
            version: 'KqlParameterItem/1.0'
            name: 'ResourceGroup'
            type: 2
            isRequired: true
            multiSelect: true
            quote: '\''
            delimiter: ','
            query: 'Heartbeat\r\n| distinct RGName = tolower(ResourceGroup)'
            crossComponentResources: [
              '{Workspace}'
            ]
            typeSettings: {
              limitSelectTo: 500
              additionalResourceOptions: [
                'value::all'
              ]
              showDefault: false
            }
            timeContext: {
              durationMs: 0
            }
            timeContextFromParameter: 'TimeRange'
            queryType: 0
            resourceType: 'microsoft.operationalinsights/workspaces'
            value: [
              'value::all'
            ]
          }
        ]
        style: 'pills'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
      }
      name: 'parameters - 1'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'let trend = (Heartbeat\r\n    | extend RGName = tolower(split(_ResourceId, "/")[4])\r\n    | where RGName in ({ResourceGroup})\r\n    | make-series InternalTrend=iff(count() > 0, 1, 0) default = 0 on TimeGenerated from ago(3d) to now() step 15m by _ResourceId\r\n    | extend Trend=array_slice(InternalTrend, array_length(InternalTrend) - 30, array_length(InternalTrend) - 1)); \r\nlet PerfCPU = (InsightsMetrics\r\n    | where Origin == "vm.azm.ms"\r\n    | extend RGName = tolower(split(_ResourceId, "/")[4])\r\n    | where RGName in ({ResourceGroup})\r\n    | where Namespace == "Processor" and Name == "UtilizationPercentage"\r\n    | summarize AvgCPU=round(avg(Val), 2), MaxCPU=round(max(Val), 2) by _ResourceId\r\n    | extend StatusCPU = case (\r\n                             AvgCPU > 80,\r\n                             2,\r\n                             AvgCPU > 50,\r\n                             1,\r\n                             AvgCPU <= 50,\r\n                             0,\r\n                             -1\r\n                         )\r\n    );\r\nlet PerfMemory = (InsightsMetrics\r\n    | where Origin == "vm.azm.ms"\r\n    | extend RGName = tolower(split(_ResourceId, "/")[4])\r\n    | where RGName in ({ResourceGroup})\r\n    | where Namespace == "Memory" and Name == "AvailableMB"\r\n    | summarize AvgMEM=round(avg(Val), 2), MaxMEM=round(max(Val), 2) by _ResourceId\r\n    | extend StatusMEM = case (\r\n                             AvgMEM > 4,\r\n                             0,\r\n                             AvgMEM >= 1,\r\n                             1,\r\n                             AvgMEM < 1,\r\n                             2,\r\n                             -1\r\n                         )\r\n    );\r\nlet PerfDisk = (InsightsMetrics\r\n    | where Origin == "vm.azm.ms"\r\n    | extend RGName = tolower(split(_ResourceId, "/")[4])\r\n    | where RGName in ({ResourceGroup})\r\n    | where Namespace == "LogicalDisk" and Name == "FreeSpaceMB"\r\n    | extend Disk=tostring(todynamic(Tags)["vm.azm.ms/mountId"])\r\n    | where (Disk =~ "C:" or Disk == "/")\r\n    | summarize\r\n        AvgDisk=round(avg(Val), 2),\r\n        (TimeGenerated, LastDisk)=arg_max(TimeGenerated, round(Val, 2))\r\n        by _ResourceId\r\n    | extend StatusDisk = case (\r\n                              AvgDisk < 5000,\r\n                              2,\r\n                              AvgDisk < 30000,\r\n                              1,\r\n                              AvgDisk >= 30000,\r\n                              0,\r\n                              -1\r\n                          )\r\n    | project _ResourceId, AvgDisk, LastDisk, StatusDisk\r\n    );\r\nPerfCPU\r\n| join (PerfMemory) on _ResourceId\r\n| join (PerfDisk) on _ResourceId\r\n| join (trend) on _ResourceId\r\n| project\r\n    _ResourceId,\r\n    StatusCPU,\r\n    AvgCPU,\r\n    MaxCPU,\r\n    StatusMEM,\r\n    AvgMEM,\r\n    MaxMEM,\r\n    StatusDisk,\r\n    AvgDisk,\r\n    LastDisk,\r\n    ["Heartbeat Trend"] = Trend\r\n| sort by StatusCPU,StatusDisk desc'
        size: 0
        showAnalytics: true
        title: 'Top servers (data aggregated based on TimeRange)'
        timeContextFromParameter: 'TimeRange'
        exportFieldName: '_ResourceId'
        exportParameterName: '_ResourceId'
        exportDefaultValue: 'All'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        crossComponentResources: [
          '{Workspace}'
        ]
        gridSettings: {
          formatters: [
            {
              columnMatch: 'StatusCPU'
              formatter: 18
              formatOptions: {
                thresholdsOptions: 'icons'
                thresholdsGrid: [
                  {
                    operator: '=='
                    thresholdValue: '0'
                    representation: 'success'
                    text: '{1}'
                  }
                  {
                    operator: '=='
                    thresholdValue: '1'
                    representation: '2'
                    text: '{1}'
                  }
                  {
                    operator: '=='
                    thresholdValue: '2'
                    representation: '4'
                    text: '{1}'
                  }
                  {
                    operator: 'Default'
                    thresholdValue: null
                    representation: 'Unknown'
                    text: '{1}'
                  }
                ]
              }
            }
            {
              columnMatch: 'AvgCPU'
              formatter: 0
              numberFormat: {
                unit: 1
                options: {
                  style: 'decimal'
                }
              }
            }
            {
              columnMatch: 'MaxCPU'
              formatter: 0
              numberFormat: {
                unit: 1
                options: {
                  style: 'decimal'
                }
              }
            }
            {
              columnMatch: 'StatusMEM'
              formatter: 18
              formatOptions: {
                thresholdsOptions: 'icons'
                thresholdsGrid: [
                  {
                    operator: '=='
                    thresholdValue: '0'
                    representation: 'success'
                    text: '{1}'
                  }
                  {
                    operator: '=='
                    thresholdValue: '1'
                    representation: '2'
                    text: '{1}'
                  }
                  {
                    operator: '=='
                    thresholdValue: '2'
                    representation: 'critical'
                    text: '{1}'
                  }
                  {
                    operator: 'Default'
                    thresholdValue: null
                    representation: 'unknown'
                    text: '{1}'
                  }
                ]
              }
            }
            {
              columnMatch: 'AvgMEM'
              formatter: 0
              numberFormat: {
                unit: 38
                options: {
                  style: 'decimal'
                  maximumFractionDigits: 2
                }
              }
            }
            {
              columnMatch: 'MaxMEM'
              formatter: 0
              numberFormat: {
                unit: 38
                options: {
                  style: 'decimal'
                  maximumFractionDigits: 2
                }
              }
            }
            {
              columnMatch: 'StatusDisk'
              formatter: 18
              formatOptions: {
                thresholdsOptions: 'icons'
                thresholdsGrid: [
                  {
                    operator: '=='
                    thresholdValue: '0'
                    representation: 'success'
                    text: '{1}'
                  }
                  {
                    operator: '=='
                    thresholdValue: '1'
                    representation: '2'
                    text: '{1}'
                  }
                  {
                    operator: '=='
                    thresholdValue: '2'
                    representation: '4'
                    text: '{1}'
                  }
                  {
                    operator: 'Default'
                    thresholdValue: null
                    representation: 'success'
                    text: '{1}'
                  }
                ]
              }
            }
            {
              columnMatch: 'AvgDisk'
              formatter: 0
              numberFormat: {
                unit: 38
                options: {
                  style: 'decimal'
                  maximumFractionDigits: 2
                }
              }
            }
            {
              columnMatch: 'LastDisk'
              formatter: 0
              numberFormat: {
                unit: 4
                options: {
                  style: 'decimal'
                  maximumFractionDigits: 2
                }
              }
            }
            {
              columnMatch: 'Trend'
              formatter: 10
              formatOptions: {
                palette: 'blue'
              }
            }
            {
              columnMatch: 'Max'
              formatter: 0
              numberFormat: {
                unit: 0
                options: {
                  style: 'decimal'
                }
              }
            }
            {
              columnMatch: 'Average'
              formatter: 8
              formatOptions: {
                palette: 'yellowOrangeRed'
              }
              numberFormat: {
                unit: 0
                options: {
                  style: 'decimal'
                  useGrouping: false
                }
              }
            }
            {
              columnMatch: 'Min'
              formatter: 8
              formatOptions: {
                palette: 'yellowOrangeRed'
                aggregation: 'Min'
              }
              numberFormat: {
                unit: 0
                options: {
                  style: 'decimal'
                }
              }
            }
          ]
          filter: true
          labelSettings: [
            {
              columnId: '_ResourceId'
              label: 'Computer'
            }
          ]
        }
        sortBy: []
      }
      showPin: true
      name: 'query - 2'
      styleSettings: {
        showBorder: true
      }
    }
    {
      type: 1
      content: {
        json: '# Top Performance'
      }
      name: 'text - 8'
    }
    {
      type: 1
      content: {
        json: '## Processor(_Total)\\% Processor Time'
      }
      name: 'text - 10'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'let TopComputers = InsightsMetrics \r\n| where Origin == "vm.azm.ms"\r\n| extend RGName = tolower(split(_ResourceId, "/")[4])\r\n| where RGName in ({ResourceGroup})\r\n| where _ResourceId contains "{_ResourceId}" or "{_ResourceId}"=="All"\r\n| where Namespace == "Processor" and Name == "UtilizationPercentage"\r\n| summarize AvgCPU = avg(Val) by Computer \r\n| top 10 by AvgCPU desc\r\n| project Computer; \r\nInsightsMetrics \r\n| where Origin == "vm.azm.ms"\r\n| where Computer in (TopComputers) \r\n| where Namespace == "Processor" and Name == "UtilizationPercentage"\r\n| summarize Used_CPU = round(avg(Val),1) by Computer, bin(TimeGenerated, ({TimeRange:end} - {TimeRange:start})/100)\r\n| render timechart'
        size: 0
        aggregation: 3
        showAnalytics: true
        title: '% Processor Time - Top 10 Computers'
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        crossComponentResources: [
          '{Workspace}'
        ]
        chartSettings: {
          showLegend: true
        }
      }
      customWidth: '50'
      name: 'query - 4'
      styleSettings: {
        showBorder: true
      }
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'let trend = \r\nInsightsMetrics\r\n| where Origin == "vm.azm.ms"          \r\n| extend RGName = tolower(split(_ResourceId, "/")[4])\r\n| where _ResourceId contains "{_ResourceId}" or "{_ResourceId}"=="All"\r\n| where RGName in ({ResourceGroup})\r\n| where Namespace == "Processor" and Name == "UtilizationPercentage"\r\n| make-series Average = round(avg(Val), 3) default = 0 on TimeGenerated from {TimeRange:start} to {TimeRange:end} step totimespan(\'00:30:00\') by _ResourceId     \r\n| project _ResourceId, [\'Trend\'] = Average; \r\n\r\nInsightsMetrics\r\n| where Origin == "vm.azm.ms"\r\n| extend RGName = tolower(split(_ResourceId, "/")[4])\r\n| where RGName in ({ResourceGroup})\r\n| where _ResourceId contains "{_ResourceId}" or "{_ResourceId}"=="All"\r\n| where Namespace == "Processor" and Name == "UtilizationPercentage"\r\n| summarize Average=round(avg(Val),3) by _ResourceId\r\n| join (trend) on _ResourceId\r\n| extend Status = case (\r\n                  Average > 80, "Critical",\r\n                  Average > 50, "Warning",\r\n                  Average <= 50, "Healthy", "Unknown"\r\n)\r\n\r\n| project Status, _ResourceId, Average, Trend\r\n| sort by Status desc'
        size: 0
        showAnalytics: true
        title: 'Thresholds (Warning=50; Critical=80) - All Computers'
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        crossComponentResources: [
          '{Workspace}'
        ]
        gridSettings: {
          formatters: [
            {
              columnMatch: 'Status'
              formatter: 18
              formatOptions: {
                thresholdsOptions: 'icons'
                thresholdsGrid: [
                  {
                    operator: '=='
                    thresholdValue: 'Healthy'
                    representation: 'success'
                    text: '{1}'
                  }
                  {
                    operator: '=='
                    thresholdValue: 'Warning'
                    representation: '2'
                    text: '{1}'
                  }
                  {
                    operator: '=='
                    thresholdValue: 'Critical'
                    representation: 'critical'
                    text: '{1}'
                  }
                  {
                    operator: 'Default'
                    thresholdValue: null
                    representation: 'unknown'
                    text: '{1}'
                  }
                ]
              }
            }
            {
              columnMatch: 'Average'
              formatter: 8
              formatOptions: {
                min: 0
                max: 100
                palette: 'greenRed'
              }
            }
            {
              columnMatch: 'Trend'
              formatter: 21
              formatOptions: {
                palette: 'green'
              }
            }
          ]
          filter: true
          sortBy: [
            {
              itemKey: '$gen_link__ResourceId_1'
              sortOrder: 2
            }
          ]
          labelSettings: [
            {
              columnId: 'Status'
              label: 'Status'
            }
            {
              columnId: '_ResourceId'
              label: 'Computer'
            }
          ]
        }
        sortBy: [
          {
            itemKey: '$gen_link__ResourceId_1'
            sortOrder: 2
          }
        ]
      }
      customWidth: '50'
      name: 'query - 9'
      styleSettings: {
        showBorder: true
      }
    }
    {
      type: 1
      content: {
        json: '## Memory: _Available MBytes_ and _% Committed Bytes in Use_'
      }
      name: 'text - 11'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'let TopComputers = InsightsMetrics \r\n| where Origin == "vm.azm.ms"\r\n| extend RGName = tolower(split(_ResourceId, "/")[4])\r\n| where RGName in ({ResourceGroup})\r\n| where _ResourceId contains "{_ResourceId}" or "{_ResourceId}"=="All"\r\n| where Namespace == "Memory" and Name == "AvailableMB"\r\n| summarize AvailableGBytes = round(avg(Val)/1024,2) by Computer\r\n| top 10 by AvailableGBytes asc\r\n| project Computer; \r\nInsightsMetrics \r\n| where Origin == "vm.azm.ms"\r\n| where Computer in (TopComputers) \r\n| where Namespace == "Memory" and Name == "AvailableMB"\r\n| summarize AvailableGBytes = round(avg(Val)/1024,2) by Computer, bin(TimeGenerated, ({TimeRange:end} - {TimeRange:start})/100)\r\n| render timechart'
        size: 0
        aggregation: 3
        showAnalytics: true
        title: 'Available MBytes - Top 10 Computers'
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        crossComponentResources: [
          '{Workspace}'
        ]
        visualization: 'timechart'
        gridSettings: {
          formatters: [
            {
              columnMatch: 'AvailableMBytes'
              formatter: 0
              formatOptions: {
                showIcon: true
              }
              numberFormat: {
                unit: 4
                options: {
                  style: 'decimal'
                  useGrouping: false
                }
              }
            }
          ]
        }
        chartSettings: {
          createOtherGroup: 0
          showLegend: true
          ySettings: {
            unit: 5
            min: null
            max: null
          }
        }
      }
      customWidth: '50'
      name: 'query - 5'
      styleSettings: {
        showBorder: true
      }
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'let trend = \r\nInsightsMetrics\r\n| where Origin == "vm.azm.ms"           \r\n| extend RGName = tolower(split(_ResourceId, "/")[4])\r\n| where RGName in ({ResourceGroup})\r\n| where _ResourceId contains "{_ResourceId}" or "{_ResourceId}"=="All"\r\n| where Namespace == "Memory" and Name == "AvailableMB"\r\n| make-series Average = round(avg(Val), 3) default = 0 on TimeGenerated from {TimeRange:start} to {TimeRange:end} step totimespan(\'00:30:00\') by _ResourceId     \r\n| project _ResourceId, [\'Trend\'] = Average; \r\n\r\nInsightsMetrics\r\n| where Origin == "vm.azm.ms"\r\n| extend RGName = tolower(split(_ResourceId, "/")[4])\r\n| where RGName in ({ResourceGroup})\r\n| where _ResourceId contains "{_ResourceId}" or "{_ResourceId}"=="All"\r\n| where Namespace == "Memory" and Name == "AvailableMB"\r\n| summarize ["Available GBytes"]=round(avg(Val)/1024,2) by _ResourceId\r\n| join (trend) on _ResourceId\r\n| extend Status = case (\r\n                  ["Available GBytes"] > 4, "Healthy",\r\n                  ["Available GBytes"] >= 1, "Warning",\r\n                  ["Available GBytes"] < 1, "Critical", "Unknown"\r\n)\r\n| project Status, _ResourceId, ["Available GBytes"], Trend\r\n| sort by ["Available GBytes"] asc'
        size: 0
        showAnalytics: true
        title: 'Thresholds (Warning < 4 GB; Critical < 1 GB) - All Computers'
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        crossComponentResources: [
          '{Workspace}'
        ]
        gridSettings: {
          formatters: [
            {
              columnMatch: 'Status'
              formatter: 18
              formatOptions: {
                thresholdsOptions: 'icons'
                thresholdsGrid: [
                  {
                    operator: '=='
                    thresholdValue: 'Healthy'
                    representation: 'success'
                    text: '{1}'
                  }
                  {
                    operator: '=='
                    thresholdValue: 'Warning'
                    representation: '2'
                    text: '{1}'
                  }
                  {
                    operator: '=='
                    thresholdValue: 'Critical'
                    representation: 'critical'
                    text: '{1}'
                  }
                  {
                    operator: 'Default'
                    thresholdValue: null
                    representation: 'Unknown'
                    text: '{1}'
                  }
                ]
              }
            }
            {
              columnMatch: 'Available GBytes'
              formatter: 8
              formatOptions: {
                min: 0
                max: 20
                palette: 'redGreen'
              }
            }
            {
              columnMatch: 'Trend'
              formatter: 21
              formatOptions: {
                palette: 'green'
              }
            }
          ]
          filter: true
          sortBy: [
            {
              itemKey: '$gen_link__ResourceId_1'
              sortOrder: 2
            }
          ]
          labelSettings: [
            {
              columnId: 'Status'
              label: 'Status'
            }
            {
              columnId: '_ResourceId'
              label: 'Computer'
            }
          ]
        }
        sortBy: [
          {
            itemKey: '$gen_link__ResourceId_1'
            sortOrder: 2
          }
        ]
      }
      customWidth: '50'
      name: 'query - 9 - Copy'
      styleSettings: {
        showBorder: true
      }
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'let TopComputers = InsightsMetrics \r\n| where Origin == "vm.azm.ms"\r\n| extend RGName = tolower(split(_ResourceId, "/")[4])\r\n| where RGName in ({ResourceGroup})\r\n| where _ResourceId contains "{_ResourceId}" or "{_ResourceId}"=="All"\r\n| where Namespace == "Memory" and Name == "AvailableMB"\r\n| extend TotalMemory = toreal(todynamic(Tags)["vm.azm.ms/memorySizeMB"]) \r\n| extend CommittedMemoryPercentage = 100-((toreal(Val) / TotalMemory) * 100.0)\r\n| summarize PctCommittedBytes = round(avg(CommittedMemoryPercentage),2) by Computer\r\n| top 10 by PctCommittedBytes desc\r\n| project Computer; \r\nInsightsMetrics \r\n| where Origin == "vm.azm.ms"\r\n| where Computer in (TopComputers) \r\n| where Namespace == "Memory" and Name == "AvailableMB"\r\n| extend TotalMemory = toreal(todynamic(Tags)["vm.azm.ms/memorySizeMB"]) \r\n| extend CommittedMemoryPercentage = 100-((toreal(Val) / TotalMemory) * 100.0)\r\n| summarize PctCommittedBytes = round(avg(CommittedMemoryPercentage),2) by Computer, bin(TimeGenerated, ({TimeRange:end} - {TimeRange:start})/100)\r\n| render timechart'
        size: 0
        aggregation: 3
        showAnalytics: true
        title: '% Committed Bytes In Use - Top 10 Computers'
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        crossComponentResources: [
          '{Workspace}'
        ]
        chartSettings: {
          group: 'Computer'
          createOtherGroup: 0
          showLegend: true
          ySettings: {
            unit: 1
            min: 0
            max: 100
          }
        }
      }
      customWidth: '50'
      name: 'query - 9'
      styleSettings: {
        showBorder: true
      }
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'let trend = \r\nInsightsMetrics   \r\n| where Origin == "vm.azm.ms"        \r\n| extend RGName = tolower(split(_ResourceId, "/")[4])\r\n| where RGName in ({ResourceGroup})\r\n| where _ResourceId contains "{_ResourceId}" or "{_ResourceId}"=="All"\r\n| where Namespace == "Memory" and Name == "AvailableMB"\r\n| extend TotalMemory = toreal(todynamic(Tags)["vm.azm.ms/memorySizeMB"]) \r\n| extend CommittedMemoryPercentage = 100-((toreal(Val) / TotalMemory) * 100.0)\r\n| make-series Average = round(avg(CommittedMemoryPercentage), 3) default = 0 on TimeGenerated from {TimeRange:start} to {TimeRange:end} step totimespan(\'00:30:00\') by _ResourceId     \r\n| project _ResourceId, [\'Trend\'] = Average; \r\n\r\nInsightsMetrics\r\n| where Origin == "vm.azm.ms"\r\n| extend RGName = tolower(split(_ResourceId, "/")[4])\r\n| where RGName in ({ResourceGroup})\r\n| where _ResourceId contains "{_ResourceId}" or "{_ResourceId}"=="All"\r\n| where Namespace == "Memory" and Name == "AvailableMB"\r\n| extend TotalMemory = toreal(todynamic(Tags)["vm.azm.ms/memorySizeMB"]) \r\n| extend CommittedMemoryPercentage = 100-((toreal(Val) / TotalMemory) * 100.0)\r\n| summarize Average=round(avg(CommittedMemoryPercentage),3) by _ResourceId\r\n| join (trend) on _ResourceId\r\n| extend Status = case (\r\n                  Average > 90, "Critical",\r\n                  Average > 60, "Warning",\r\n                  Average <= 60, "Healthy", "Unknown"\r\n)\r\n\r\n| project Status, _ResourceId, Average, Trend\r\n| sort by Average '
        size: 0
        showAnalytics: true
        title: 'Thresholds (Warning>60; Critical>90) - All Computers'
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        crossComponentResources: [
          '{Workspace}'
        ]
        gridSettings: {
          formatters: [
            {
              columnMatch: 'Status'
              formatter: 18
              formatOptions: {
                thresholdsOptions: 'icons'
                thresholdsGrid: [
                  {
                    operator: '=='
                    thresholdValue: 'Healthy'
                    representation: 'success'
                    text: '{1}'
                  }
                  {
                    operator: '=='
                    thresholdValue: 'Warning'
                    representation: '2'
                    text: '{1}'
                  }
                  {
                    operator: '=='
                    thresholdValue: 'Critical'
                    representation: 'critical'
                    text: '{1}'
                  }
                  {
                    operator: 'Default'
                    thresholdValue: null
                    representation: 'unknown'
                    text: '{1}'
                  }
                ]
              }
            }
            {
              columnMatch: 'Average'
              formatter: 8
              formatOptions: {
                min: 0
                max: 100
                palette: 'greenRed'
              }
            }
            {
              columnMatch: 'Trend'
              formatter: 21
              formatOptions: {
                palette: 'green'
              }
            }
          ]
          filter: true
          sortBy: [
            {
              itemKey: '$gen_link__ResourceId_1'
              sortOrder: 2
            }
          ]
          labelSettings: [
            {
              columnId: 'Status'
              label: 'Status'
            }
            {
              columnId: '_ResourceId'
              label: 'Computer'
            }
          ]
        }
        sortBy: [
          {
            itemKey: '$gen_link__ResourceId_1'
            sortOrder: 2
          }
        ]
      }
      customWidth: '50'
      name: 'query - 9 - Copy'
      styleSettings: {
        showBorder: true
      }
    }
    {
      type: 1
      content: {
        json: '## Logical Disk: _Free Megabytes_ and _Avg read/write per sec_ '
      }
      name: 'text - 12'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'let TopDiscos = InsightsMetrics \r\n| where Origin == "vm.azm.ms"\r\n| extend RGName = tolower(split(_ResourceId, "/")[4])\r\n| where RGName in ({ResourceGroup})\r\n| where _ResourceId contains "{_ResourceId}" or "{_ResourceId}"=="All"\r\n| where Namespace == "LogicalDisk" and Name == "FreeSpaceMB"\r\n| extend Disk = tostring(todynamic(Tags)["vm.azm.ms/mountId"])\r\n| where (strlen(Disk) ==2 and Disk contains ":") or Disk=="/"\r\n| extend Disco = strcat(Disk, " - ",Computer )\r\n| summarize FreeSpace = round(avg(Val),2) by Disco\r\n| top 10 by FreeSpace asc\r\n| project Disco; \r\nInsightsMetrics \r\n| where Origin == "vm.azm.ms"\r\n| where Namespace == "LogicalDisk" and Name == "FreeSpaceMB"\r\n| extend Disk = tostring(todynamic(Tags)["vm.azm.ms/mountId"])\r\n| where (strlen(Disk) ==2 and Disk contains ":") or Disk=="/"\r\n| extend Disco = strcat(Disk, " - ",Computer )\r\n| where Disco in (TopDiscos) \r\n| summarize FreeSpace = round(avg(Val),2) by Disco, bin(TimeGenerated, ({TimeRange:end} - {TimeRange:start})/100)\r\n\r\n\r\n'
        size: 0
        aggregation: 3
        showAnalytics: true
        title: 'Free Megabytes - Top 10 Computers-Volumes'
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        crossComponentResources: [
          '{Workspace}'
        ]
        visualization: 'timechart'
        chartSettings: {
          showLegend: true
          ySettings: {
            numberFormatSettings: {
              unit: 4
              options: {
                style: 'decimal'
                useGrouping: true
              }
            }
          }
        }
      }
      customWidth: '50'
      name: 'query - 6'
      styleSettings: {
        showBorder: true
      }
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'let trend = \r\nInsightsMetrics \r\n| where Origin == "vm.azm.ms"\r\n| extend RGName = tolower(split(_ResourceId, "/")[4])\r\n| where RGName in ({ResourceGroup})         \r\n| where _ResourceId contains "{_ResourceId}" or "{_ResourceId}"=="All"\r\n| where Namespace == "LogicalDisk" and Name == "FreeSpaceMB"\r\n| extend Disk=tostring(todynamic(Tags)["vm.azm.ms/mountId"])\r\n| where (strlen(Disk) ==2 and Disk contains ":") or Disk=="/"\r\n| extend Disco = strcat(Disk, " - ", _ResourceId)\r\n| make-series Average = round(avg(Val), 3) default = 0 on TimeGenerated from {TimeRange:start} to {TimeRange:end} step totimespan(\'00:30:00\') by Disco     \r\n| project Disco, [\'Trend\'] = Average; \r\n\r\nInsightsMetrics\r\n| where Origin == "vm.azm.ms"\r\n| extend RGName = tolower(split(_ResourceId, "/")[4])\r\n| where RGName in ({ResourceGroup})\r\n| where _ResourceId contains "{_ResourceId}" or "{_ResourceId}"=="All"\r\n| where Namespace == "LogicalDisk" and Name == "FreeSpaceMB"\r\n| extend Disk=tostring(todynamic(Tags)["vm.azm.ms/mountId"])\r\n| where (strlen(Disk) ==2 and Disk contains ":") or Disk=="/"\r\n| extend Disco = strcat(Disk, " - ",_ResourceId )\r\n| summarize Average=round(avg(Val),2) by Disco,_ResourceId,Disk\r\n| join (trend) on Disco\r\n| extend Status = case (\r\n                  Average < 5000, "Critical",\r\n                  Average < 30000, "Warning",\r\n                  Average >= 30000, "Healthy", "Unknown"\r\n)\r\n\r\n| project Status, _ResourceId,Disk, Average, Trend\r\n| sort by Average asc '
        size: 0
        showAnalytics: true
        title: 'Thresholds (Warning < 30GB; Critical < 5GB) - All Computers-Volumes'
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        crossComponentResources: [
          '{Workspace}'
        ]
        gridSettings: {
          formatters: [
            {
              columnMatch: 'Status'
              formatter: 18
              formatOptions: {
                thresholdsOptions: 'icons'
                thresholdsGrid: [
                  {
                    operator: '=='
                    thresholdValue: 'Healthy'
                    representation: 'success'
                    text: '{1}'
                  }
                  {
                    operator: '=='
                    thresholdValue: 'Warning'
                    representation: '2'
                    text: '{1}'
                  }
                  {
                    operator: '=='
                    thresholdValue: 'Critical'
                    representation: 'critical'
                    text: '{1}'
                  }
                  {
                    operator: 'Default'
                    thresholdValue: null
                    representation: 'unknown'
                    text: '{1}'
                  }
                ]
              }
            }
            {
              columnMatch: 'Average'
              formatter: 8
              formatOptions: {
                min: 0
                max: 40000
                palette: 'redGreen'
              }
              numberFormat: {
                unit: 4
                options: {
                  style: 'decimal'
                  useGrouping: false
                  minimumFractionDigits: 2
                  maximumFractionDigits: 2
                }
              }
            }
            {
              columnMatch: 'Trend'
              formatter: 21
              formatOptions: {
                palette: 'green'
              }
            }
          ]
          filter: true
          sortBy: [
            {
              itemKey: '$gen_link__ResourceId_1'
              sortOrder: 2
            }
          ]
          labelSettings: [
            {
              columnId: 'Status'
              label: 'Status'
            }
            {
              columnId: '_ResourceId'
              label: 'Computer'
            }
          ]
        }
        sortBy: [
          {
            itemKey: '$gen_link__ResourceId_1'
            sortOrder: 2
          }
        ]
      }
      customWidth: '50'
      name: 'query - 9 - Copy - Copy'
      styleSettings: {
        showBorder: true
      }
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'let TopDiscos = InsightsMetrics \r\n| where Origin == "vm.azm.ms"\r\n| extend RGName = tolower(split(_ResourceId, "/")[4])\r\n| where RGName in ({ResourceGroup})\r\n| where _ResourceId contains "{_ResourceId}" or "{_ResourceId}"=="All"\r\n| where Namespace == "LogicalDisk" and Name == "ReadsPerSecond"\r\n| extend Disk=tostring(todynamic(Tags)["vm.azm.ms/mountId"])\r\n| where (strlen(Disk) ==2 and Disk contains ":") or ( Disk == "/")\r\n| extend Disco = strcat(Disk, " - ",Computer )\r\n| summarize MilliSeconds = avg(Val) by Disco\r\n| top 10 by MilliSeconds desc\r\n| project Disco; \r\nInsightsMetrics \r\n| where Origin == "vm.azm.ms"\r\n| where Namespace == "LogicalDisk" and Name == "ReadsPerSecond"\r\n| extend Disk=tostring(todynamic(Tags)["vm.azm.ms/mountId"])\r\n| where (strlen(Disk) ==2 and Disk contains ":") or ( Disk == "/")\r\n| extend Disco = strcat(Disk, " - ",Computer )\r\n| where Disco in (TopDiscos) \r\n| summarize MilliSeconds = avg(Val) by Disco, bin(TimeGenerated, ({TimeRange:end} - {TimeRange:start})/100)\r\n| render timechart\r\n\r\n\r\n'
        size: 0
        aggregation: 3
        showAnalytics: true
        title: 'Disk Reads/sec - Top 10 Computers-Volume'
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        crossComponentResources: [
          '{Workspace}'
        ]
        visualization: 'timechart'
        chartSettings: {
          group: 'Disco'
          createOtherGroup: 22
          showLegend: true
        }
      }
      customWidth: '50'
      name: 'query - 6 - Copy'
      styleSettings: {
        showBorder: true
      }
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'let trend = \r\nInsightsMetrics\r\n| where Origin == "vm.azm.ms"     \r\n| extend RGName = tolower(split(_ResourceId, "/")[4])\r\n| where RGName in ({ResourceGroup}) \r\n| where _ResourceId contains "{_ResourceId}" or "{_ResourceId}"=="All"    \r\n| where Namespace == "LogicalDisk" and Name == "ReadsPerSecond"\r\n| extend Disk=tostring(todynamic(Tags)["vm.azm.ms/mountId"])\r\n| where ((strlen(Disk) == 2 and Disk contains ":") or (Disk == "/"))\r\n| extend Disco = strcat(Disk, " - ",_ResourceId )\r\n| make-series AVGReads = round(avg(Val),2) default = 0 on TimeGenerated from {TimeRange:start} to {TimeRange:end} step totimespan(\'00:30:00\') by Disco     \r\n| project Disco, [\'Trend\'] = AVGReads; \r\n\r\nInsightsMetrics\r\n| where Origin == "vm.azm.ms"\r\n| extend RGName = tolower(split(_ResourceId, "/")[4])\r\n| where RGName in ({ResourceGroup})\r\n| where _ResourceId contains "{_ResourceId}" or "{_ResourceId}"=="All"\r\n| where Namespace == "LogicalDisk" and Name == "ReadsPerSecond"\r\n| extend Disk=tostring(todynamic(Tags)["vm.azm.ms/mountId"])\r\n| where ((strlen(Disk) == 2 and Disk contains ":") or (Disk == "/"))\r\n| extend Disco = strcat(Disk, " - ",_ResourceId )\r\n| summarize AVGReads=round(avg(Val),2) by Disco,_ResourceId,Disk\r\n| join (trend) on Disco\r\n| extend Status = case (\r\n                  AVGReads > 25, "Critical",\r\n                  AVGReads > 15, "Warning",\r\n                  AVGReads <= 15, "Healthy", "Unknown"\r\n)\r\n| project  _ResourceId,Disk, ["Reads"]=AVGReads, Trend\r\n| sort by ["Reads"] desc '
        size: 0
        showAnalytics: true
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        crossComponentResources: [
          '{Workspace}'
        ]
        gridSettings: {
          formatters: [
            {
              columnMatch: 'Trend'
              formatter: 21
              formatOptions: {
                palette: 'green'
              }
            }
            {
              columnMatch: 'Status'
              formatter: 18
              formatOptions: {
                thresholdsOptions: 'icons'
                thresholdsGrid: [
                  {
                    operator: '=='
                    thresholdValue: 'Healthy'
                    representation: 'success'
                    text: '{1}'
                  }
                  {
                    operator: '=='
                    thresholdValue: 'Warning'
                    representation: '2'
                    text: '{1}'
                  }
                  {
                    operator: '=='
                    thresholdValue: 'Critical'
                    representation: 'critical'
                    text: '{1}'
                  }
                  {
                    operator: 'Default'
                    thresholdValue: null
                    representation: 'unknown'
                    text: '{1}'
                  }
                ]
              }
            }
            {
              columnMatch: 'Average'
              formatter: 8
              formatOptions: {
                min: 0
                max: 100
                palette: 'blue'
              }
            }
          ]
          filter: true
          sortBy: [
            {
              itemKey: '$gen_link__ResourceId_0'
              sortOrder: 2
            }
          ]
          labelSettings: [
            {
              columnId: '_ResourceId'
              label: 'Computer'
            }
          ]
        }
        sortBy: [
          {
            itemKey: '$gen_link__ResourceId_0'
            sortOrder: 2
          }
        ]
      }
      customWidth: '50'
      name: 'query - 9 - Copy - Copy - Copy'
      styleSettings: {
        showBorder: true
      }
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'let TopDiscos= InsightsMetrics \r\n| where Origin == "vm.azm.ms"\r\n| extend RGName = tolower(split(_ResourceId, "/")[4])\r\n| where RGName in ({ResourceGroup})\r\n| where _ResourceId contains "{_ResourceId}" or "{_ResourceId}"=="All"\r\n| where Namespace == "LogicalDisk" and Name == "WritesPerSecond"\r\n| extend Disk=tostring(todynamic(Tags)["vm.azm.ms/mountId"])\r\n| where (strlen(Disk) ==2 and Disk contains ":") or Disk=="/"\r\n| extend Disco = strcat(Disk, " - ",Computer )\r\n| summarize MilliSeconds = avg(Val) by Disco\r\n| top 10 by MilliSeconds desc\r\n| project Disco; \r\nInsightsMetrics \r\n| where Origin == "vm.azm.ms"\r\n| where Namespace == "LogicalDisk" and Name == "WritesPerSecond"\r\n| extend Disk=tostring(todynamic(Tags)["vm.azm.ms/mountId"])\r\n| where (strlen(Disk) ==2 and Disk contains ":") or Disk=="/"\r\n| extend Disco = strcat(Disk, " - ",Computer )\r\n| where Disco in (TopDiscos) \r\n| summarize MilliSeconds = avg(Val) by Disco, bin(TimeGenerated, ({TimeRange:end} - {TimeRange:start})/100)\r\n| render timechart\r\n\r\n\r\n'
        size: 0
        showAnalytics: true
        title: 'Disk Writes/sec - Top 10 Computers-Volume'
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        crossComponentResources: [
          '{Workspace}'
        ]
        visualization: 'timechart'
        chartSettings: {
          group: 'Disco'
          createOtherGroup: 22
          showLegend: true
        }
      }
      customWidth: '50'
      name: 'query - 6 - Copy - Copy'
      styleSettings: {
        showBorder: true
      }
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'let trend = \r\nInsightsMetrics      \r\n| where Origin == "vm.azm.ms"  \r\n| extend RGName = tolower(split(_ResourceId, "/")[4])\r\n| where RGName in ({ResourceGroup})\r\n| where _ResourceId contains "{_ResourceId}" or "{_ResourceId}"=="All"\r\n| where Namespace == "LogicalDisk" and Name == "WritesPerSecond"\r\n| extend Disk=tostring(todynamic(Tags)["vm.azm.ms/mountId"])\r\n| where (strlen(Disk) ==2 and Disk contains ":") or Disk=="/"\r\n| extend Disco = strcat(Disk, " - ",_ResourceId )\r\n| make-series AVGWrites = round(avg(Val),2) default = 0 on TimeGenerated from {TimeRange:start} to {TimeRange:end} step totimespan(\'00:30:00\') by Disco     \r\n| project Disco, [\'Trend\'] = AVGWrites; \r\n\r\nInsightsMetrics\r\n| where Origin == "vm.azm.ms"\r\n| extend RGName = tolower(split(_ResourceId, "/")[4])\r\n| where RGName in ({ResourceGroup})\r\n| where _ResourceId contains "{_ResourceId}" or "{_ResourceId}"=="All"\r\n| where Namespace == "LogicalDisk" and Name == "WritesPerSecond"\r\n| extend Disk=tostring(todynamic(Tags)["vm.azm.ms/mountId"])\r\n| where (strlen(Disk) ==2 and Disk contains ":") or Disk=="/"\r\n| extend Disco = strcat(Disk, " - ",_ResourceId )\r\n| summarize AVGWrites=round(avg(Val),2) by Disco,_ResourceId,Disk\r\n| join (trend) on Disco\r\n| extend Status = case (\r\n                  AVGWrites > 25, "Critical",\r\n                  AVGWrites > 15, "Warning",\r\n                  AVGWrites <= 15, "Healthy", "Unknown"\r\n)\r\n\r\n| project  _ResourceId,Disk, ["Writes"]=AVGWrites, Trend\r\n| sort by ["Writes"] desc '
        size: 0
        showAnalytics: true
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        crossComponentResources: [
          '{Workspace}'
        ]
        gridSettings: {
          formatters: [
            {
              columnMatch: 'Trend'
              formatter: 21
              formatOptions: {
                palette: 'green'
              }
            }
            {
              columnMatch: 'Status'
              formatter: 18
              formatOptions: {
                thresholdsOptions: 'icons'
                thresholdsGrid: [
                  {
                    operator: '=='
                    thresholdValue: 'Healthy'
                    representation: 'success'
                    text: '{1}'
                  }
                  {
                    operator: '=='
                    thresholdValue: 'Warning'
                    representation: '2'
                    text: '{1}'
                  }
                  {
                    operator: '=='
                    thresholdValue: 'Critical'
                    representation: 'critical'
                    text: '{1}'
                  }
                  {
                    operator: 'Default'
                    thresholdValue: null
                    representation: 'unknown'
                    text: '{1}'
                  }
                ]
              }
            }
            {
              columnMatch: 'Average'
              formatter: 8
              formatOptions: {
                min: 0
                max: 100
                palette: 'blue'
              }
            }
          ]
          filter: true
          sortBy: [
            {
              itemKey: '$gen_link__ResourceId_0'
              sortOrder: 2
            }
          ]
          labelSettings: [
            {
              columnId: '_ResourceId'
              label: 'Computer'
            }
          ]
        }
        sortBy: [
          {
            itemKey: '$gen_link__ResourceId_0'
            sortOrder: 2
          }
        ]
      }
      customWidth: '50'
      name: 'query - 9 - Copy - Copy - Copy - Copy'
      styleSettings: {
        showBorder: true
      }
    }
    {
      type: 1
      content: {
        json: '## %CPU Usage by Process (Windows)'
      }
      customWidth: '50'
      name: 'text - 21'
    }
    {
      type: 1
      content: {
        json: '## Network Usage by Process (VMConnection)'
      }
      customWidth: '50'
      name: 'text - 25'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'let WindowsComputer = Heartbeat\r\n    | extend RGName = tolower(split(_ResourceId, "/")[4])\r\n    | where RGName in ({ResourceGroup})\r\n    | where _ResourceId contains "{_ResourceId}" or "{_ResourceId}"=="All"\r\n    | where OSType == "Windows"\r\n    | distinct _ResourceId;\r\nlet TopComputers = InsightsMetrics \r\n    | where _ResourceId in (WindowsComputer)\r\n    | where Origin == "vm.azm.ms"\r\n    | where Namespace == "Processor" and Name == "UtilizationPercentage"\r\n    | summarize AggregatedValue = avg(Val) by _ResourceId \r\n    | top 10 by AggregatedValue desc\r\n    | project _ResourceId; \r\nlet FindCPU = InsightsMetrics\r\n    | where _ResourceId in (TopComputers)\r\n    | where Origin == "vm.azm.ms"\r\n    | where Namespace == "Processor" and Name == "UtilizationPercentage"\r\n    | extend CPUs=toint(todynamic(Tags)["vm.azm.ms/totalCpus"])\r\n    | distinct _ResourceId, CPUs;\r\nlet ProcessUsage = Perf\r\n    | where _ResourceId in (TopComputers)\r\n    | where ObjectName == "Process" and CounterName == "% Processor Time"\r\n    | where InstanceName != "_Total" and InstanceName != "Idle"\r\n    | extend Process = iff(InstanceName contains "#",substring(InstanceName,0,indexof(InstanceName,"#",0)),InstanceName)\r\n    | extend newTimeGenerated = format_datetime(TimeGenerated, "yyyy-MM-dd HH:mm:ss")\r\n    | summarize TotalCPU = sum(CounterValue) by _ResourceId, newTimeGenerated, Process\r\n    | summarize average = avg(TotalCPU) by _ResourceId, Process;\r\nProcessUsage | join kind= inner (\r\n    FindCPU\r\n) on _ResourceId \r\n| project ParentId = _ResourceId, Id = Process, AvgUsage = average/CPUs\r\n| extend Computer = strcat(\'🎫 \', Id)\r\n| union (\r\nInsightsMetrics\r\n| where _ResourceId in (TopComputers)\r\n    | where _ResourceId in (WindowsComputer)\r\n    | where Origin == "vm.azm.ms"\r\n    | where Namespace == "Processor" and Name == "UtilizationPercentage"\r\n    | summarize AvgUsage = avg(Val) by Id = _ResourceId\r\n    | extend ParentId = \'\', Computer = Id)\r\n| project Computer, AvgUsage = round(AvgUsage, 2) , Id, ParentId\r\n| order by AvgUsage'
        size: 0
        title: '%CPU Usage by Process (Windows) - Top 10 Computers'
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        crossComponentResources: [
          '{Workspace}'
        ]
        visualization: 'table'
        gridSettings: {
          formatters: [
            {
              columnMatch: 'AvgUsage'
              formatter: 3
              formatOptions: {
                palette: 'blue'
              }
            }
            {
              columnMatch: 'Id'
              formatter: 5
            }
            {
              columnMatch: 'ParentId'
              formatter: 5
            }
            {
              columnMatch: 'Name'
              formatter: 13
              formatOptions: {
                linkTarget: 'Resource'
                showIcon: true
              }
            }
          ]
          filter: true
          hierarchySettings: {
            idColumn: 'Id'
            parentColumn: 'ParentId'
            treeType: 0
            expanderColumn: 'Computer'
            expandTopLevel: false
          }
        }
      }
      customWidth: '50'
      showPin: true
      name: 'query - 22'
      styleSettings: {
        showBorder: true
      }
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'VMConnection\r\n| extend RGName = tolower(split(_ResourceId, "/")[4])\r\n| where RGName in ({ResourceGroup})\r\n| where _ResourceId contains "{_ResourceId}" or "{_ResourceId}"=="All"\r\n| summarize TotalMB = sum(BytesSent+BytesReceived)/1024/1024  by ParentId = _ResourceId, Id = ProcessName\r\n| extend Computer = strcat(\'🎫 \', Id)\r\n| union (\r\n    VMConnection\r\n    | extend RGName = tolower(split(_ResourceId, "/")[4])\r\n    | where RGName in ({ResourceGroup})\r\n    | where _ResourceId contains "{_ResourceId}" or "{_ResourceId}"=="All"\r\n    | summarize TotalMB = sum(BytesSent+BytesReceived)/1024/1024 by Id = _ResourceId\r\n    | extend ParentId = \'\', Computer = Id\r\n    )\r\n    | project Computer, TotalMB, Id, ParentId\r\n    | order by TotalMB'
        size: 0
        title: 'Amount of Network Traffic (in MBytes) by Process (VMConnection)'
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        crossComponentResources: [
          '{Workspace}'
        ]
        visualization: 'table'
        gridSettings: {
          formatters: [
            {
              columnMatch: 'TotalMB'
              formatter: 3
              formatOptions: {
                palette: 'blue'
                customColumnWidthSetting: '491px'
              }
              numberFormat: {
                unit: 4
                options: {
                  style: 'decimal'
                }
              }
            }
            {
              columnMatch: 'Id'
              formatter: 5
            }
            {
              columnMatch: 'ParentId'
              formatter: 5
            }
            {
              columnMatch: 'Name'
              formatter: 0
              formatOptions: {
                customColumnWidthSetting: '32.5ch'
              }
            }
          ]
          filter: true
          hierarchySettings: {
            idColumn: 'Id'
            parentColumn: 'ParentId'
            treeType: 0
            expanderColumn: 'Computer'
            expandTopLevel: false
          }
        }
      }
      customWidth: '50'
      name: 'query - 26'
      styleSettings: {
        showBorder: true
      }
    }
  ]
  fallbackResourceIds: [
    'azure monitor'
  ]
  '$schema': 'https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json'
}
resource workbookId_resource 'microsoft.insights/workbooks@2022-04-01' = {
  name: workbookId
  location: location
  kind: 'shared'
  properties: {
    displayName: workbookDisplayName
    serializedData: string(workbookContent)
    version: '1.0'
    sourceId: workbookSourceId
    category: workbookType
  }
  dependsOn: []
}
output workbookId string = workbookId_resource.id
