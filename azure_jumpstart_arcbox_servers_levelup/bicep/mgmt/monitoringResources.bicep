@description('Name of the workspace.')
param workspaceName string

@description('Id of the workspace.')
param workspaceId string

@description('Specifies the location in which to create the workspace.')
param location string = resourceGroup().location

//@description('Number of days to retain data.')
//@minValue(7)
//@maxValue(730)
//param dataRetention int = 30

@description('Short name up to 12 characters for the Action group.')
param emailAddress string

//var intervalSeconds = 60
//var workspaceResourceId = workspaceId
var actionGroupName = 'ag-arc-servers'
var alertsSeverity = 2
var windowSize = 'PT5M'
var evaluationFrequency = 'PT5M'
var convertRuleTag = 'hidden-link:'
var singlequote = '\''
var azureDashboardName = 'Azure Arc-enabled servers'
var windowsEventsWorkbookName = 'Windows Event Logs'
var osPerformanceWorkbookName = 'OS Performance and Capacity'
var alertsConsoleWorkbookName = 'Azure Monitor Alerts'
var windowsEventsWorkbookContent = {
  version: 'Notebook/1.0'
  items: [
    {
      type: 1
      content: {
        json: '# Event Logs'
      }
      name: 'text - 7'
    }
    {
      type: 9
      content: {
        version: 'KqlParameterItem/1.0'
        crossComponentResources: [
          'value::all'
        ]
        parameters: [
          {
            id: '2cf5311e-e4c3-4cbd-91d9-94f2e139ed50'
            version: 'KqlParameterItem/1.0'
            name: 'TimeRange'
            type: 4
            value: {
              durationMs: 604800000
            }
            typeSettings: {
              selectableValues: [
                {
                  durationMs: 3600000
                }
                {
                  durationMs: 86400000
                }
                {
                  durationMs: 604800000
                }
                {
                  durationMs: 2592000000
                }
              ]
            }
            timeContext: {
              durationMs: 0
            }
            timeContextFromParameter: 'TimeRange'
          }
          {
            id: 'b31e4dd2-f34c-4455-86e7-9d7785586ba2'
            version: 'KqlParameterItem/1.0'
            name: 'Workspace'
            type: 5
            isRequired: true
            multiSelect: true
            quote: '\''
            delimiter: ','
            query: 'where type =~ \'microsoft.operationalinsights/workspaces\'\r\n| summarize by id, name\r\n'
            crossComponentResources: [
              'value::all'
            ]
            value: [
              workspaceId
            ]
            typeSettings: {
              additionalResourceOptions: []
            }
            queryType: 1
            resourceType: 'microsoft.resourcegraph/resources'
          }
        ]
        style: 'pills'
        queryType: 1
        resourceType: 'microsoft.resourcegraph/resources'
      }
      name: 'parameters - 2'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'Event\r\n|  where EventLog in ("System","Application","Operations Manager")\r\n| project EventLog,EventLevelName\r\n| evaluate pivot(EventLevelName)'
        size: 1
        showAnalytics: true
        title: 'Windows Events - Summary'
        timeContext: {
          durationMs: 0
        }
        timeContextFromParameter: 'TimeRange'
        exportFieldName: 'EventLog'
        exportParameterName: 'EventLog'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        crossComponentResources: [
          '{Workspace}'
        ]
        gridSettings: {
          formatters: [
            {
              columnMatch: 'Information'
              formatter: 18
              formatOptions: {
                showIcon: true
                thresholdsOptions: 'icons'
                thresholdsGrid: [
                  {
                    operator: 'Default'
                    thresholdValue: null
                    representation: 'info'
                    text: '{0}{1}'
                  }
                ]
                aggregation: 'Unique'
              }
              numberFormat: {
                unit: 0
                options: {
                  style: 'decimal'
                }
              }
            }
            {
              columnMatch: 'Warning'
              formatter: 18
              formatOptions: {
                showIcon: true
                thresholdsOptions: 'icons'
                thresholdsGrid: [
                  {
                    operator: 'Default'
                    thresholdValue: null
                    representation: 'warning'
                    text: '{0}{1}'
                  }
                ]
                aggregation: 'Unique'
              }
              numberFormat: {
                unit: 0
                options: {
                  style: 'decimal'
                }
              }
            }
            {
              columnMatch: 'Error'
              formatter: 18
              formatOptions: {
                showIcon: true
                thresholdsOptions: 'icons'
                thresholdsGrid: [
                  {
                    operator: 'Default'
                    thresholdValue: null
                    representation: '3'
                    text: '{0}{1}'
                  }
                ]
                aggregation: 'Unique'
              }
              numberFormat: {
                unit: 0
                options: {
                  style: 'decimal'
                }
              }
            }
          ]
        }
      }
      customWidth: '50'
      showPin: true
      name: 'query - 0'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'Event\r\n|  where EventLog == "{EventLog}" and EventID != 0\r\n| summarize count() by bin(TimeGenerated, 1h),EventLevelName\r\n| sort by TimeGenerated desc\r\n'
        size: 0
        showAnalytics: true
        title: 'Events count hourly distribution'
        timeContext: {
          durationMs: 0
        }
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        crossComponentResources: [
          '{Workspace}'
        ]
        visualization: 'areachart'
        chartSettings: {
          seriesLabelSettings: [
            {
              seriesName: 'Information'
              color: 'blue'
            }
            {
              seriesName: 'Warning'
              color: 'yellow'
            }
            {
              seriesName: 'Error'
              color: 'red'
            }
          ]
        }
      }
      customWidth: '50'
      showPin: true
      name: 'query - 6'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'Event\r\n|  where EventLog == "{EventLog}" and EventLevelName == "Error"\r\n| summarize Count=count() by Computer, EventLog, EventLevelName\r\n| sort by Count\r\n'
        size: 0
        showAnalytics: true
        title: 'Error Events'
        timeContext: {
          durationMs: 0
        }
        timeContextFromParameter: 'TimeRange'
        exportedParameters: [
          {
            fieldName: 'Computer'
            parameterName: 'Computer'
            parameterType: 1
          }
          {
            fieldName: 'EventLog'
            parameterName: 'EventLog'
            parameterType: 1
          }
          {
            fieldName: 'Count'
            parameterName: 'Count'
            parameterType: 1
          }
          {
            fieldName: 'EventLevelName'
            parameterName: 'EventLevelName'
            parameterType: 1
          }
        ]
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        crossComponentResources: [
          '{Workspace}'
        ]
        visualization: 'table'
        gridSettings: {
          formatters: [
            {
              columnMatch: 'EventLog'
              formatter: 5
              formatOptions: {
                showIcon: true
              }
            }
            {
              columnMatch: 'EventLevelName'
              formatter: 5
              formatOptions: {
                showIcon: true
              }
            }
            {
              columnMatch: 'Count'
              formatter: 8
              formatOptions: {
                min: 0
                palette: 'red'
                showIcon: true
              }
            }
          ]
        }
      }
      customWidth: '33'
      showPin: true
      name: 'query - 3'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'Event\r\n|  where EventLog == "{EventLog}" and EventLevelName == "Warning"\r\n| summarize Count=count() by Computer, EventLog,EventLevelName\r\n| sort by Count\r\n'
        size: 0
        showAnalytics: true
        title: 'Warning Events'
        timeContext: {
          durationMs: 0
        }
        timeContextFromParameter: 'TimeRange'
        exportedParameters: [
          {
            fieldName: 'Computer'
            parameterName: 'Computer'
            parameterType: 1
          }
          {
            fieldName: 'EventLog'
            parameterName: 'EventLog'
            parameterType: 1
          }
          {
            fieldName: 'Count'
            parameterName: 'Count'
            parameterType: 1
          }
          {
            fieldName: 'EventLevelName'
            parameterName: 'EventLevelName'
            parameterType: 1
          }
        ]
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        crossComponentResources: [
          '{Workspace}'
        ]
        visualization: 'table'
        gridSettings: {
          formatters: [
            {
              columnMatch: 'EventLog'
              formatter: 5
              formatOptions: {
                showIcon: true
              }
            }
            {
              columnMatch: 'EventLevelName'
              formatter: 5
              formatOptions: {
                showIcon: true
              }
            }
            {
              columnMatch: 'Count'
              formatter: 8
              formatOptions: {
                min: 0
                palette: 'yellow'
                showIcon: true
              }
            }
          ]
        }
      }
      customWidth: '34'
      showPin: true
      name: 'query - 2'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'Event\r\n|  where EventLog == "{EventLog}" and EventLevelName == "Information"\r\n| summarize Count=count() by Computer, EventLog,EventLevelName\r\n| sort by Count\r\n'
        size: 0
        showAnalytics: true
        title: 'Information Events'
        timeContext: {
          durationMs: 0
        }
        timeContextFromParameter: 'TimeRange'
        exportedParameters: [
          {
            fieldName: 'Computer'
            parameterName: 'Computer'
            parameterType: 1
          }
          {
            fieldName: 'EventLog'
            parameterName: 'EventLog'
            parameterType: 1
          }
          {
            fieldName: 'Count'
            parameterName: 'Count'
            parameterType: 1
          }
          {
            fieldName: 'EventLevelName'
            parameterName: 'EventLevelName'
            parameterType: 1
          }
        ]
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        crossComponentResources: [
          '{Workspace}'
        ]
        visualization: 'table'
        gridSettings: {
          formatters: [
            {
              columnMatch: 'EventLog'
              formatter: 5
              formatOptions: {
                showIcon: true
              }
            }
            {
              columnMatch: 'EventLevelName'
              formatter: 5
              formatOptions: {
                showIcon: true
              }
            }
            {
              columnMatch: 'Count'
              formatter: 8
              formatOptions: {
                min: 0
                palette: 'blue'
                showIcon: true
              }
            }
          ]
        }
      }
      customWidth: '33'
      showPin: true
      name: 'query - 4'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'Event\r\n|  where EventLog == "{EventLog}" and EventLevelName == "{EventLevelName}" and Computer == "{Computer}" and EventID != 0\r\n| project TimeGenerated,Computer, EventLog, ["Level"]=EventLevelName, ["Rendered Description"]=RenderedDescription\r\n| sort by Computer, EventLog, ["Level"]\r\n\r\n'
        size: 0
        showAnalytics: true
        title: 'Event ID Description'
        timeContext: {
          durationMs: 0
        }
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
              columnMatch: 'Level'
              formatter: 18
              formatOptions: {
                showIcon: true
                thresholdsOptions: 'icons'
                thresholdsGrid: [
                  {
                    operator: '=='
                    thresholdValue: 'Error'
                    representation: 'error'
                    text: '{0}{1}'
                  }
                  {
                    operator: '=='
                    thresholdValue: 'Warning'
                    representation: '2'
                    text: '{0}{1}'
                  }
                  {
                    operator: '=='
                    thresholdValue: 'Information'
                    representation: 'info'
                    text: '{0}{1}'
                  }
                  {
                    operator: 'Default'
                    thresholdValue: null
                    representation: 'success'
                    text: '{0}{1}'
                  }
                ]
              }
            }
          ]
        }
        tileSettings: {
          showBorder: false
        }
        graphSettings: {
          type: 0
        }
      }
      showPin: true
      name: 'query - 5'
    }
  ]
  isLocked: false
  fallbackResourceIds: [
    'Azure Monitor'
  ]
}

var osPerformanceWorkbookContent = {
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
              'value::all'
            ]
            value: [
              workspaceId
            ]
            typeSettings: {
              additionalResourceOptions: []
            }
            timeContext: {
              durationMs: 0
            }
            timeContextFromParameter: 'TimeRange'
            queryType: 1
            resourceType: 'microsoft.resourcegraph/resources'
          }
          {
            id: 'fb251a5f-fd61-44fe-853b-d31624075420'
            version: 'KqlParameterItem/1.0'
            name: 'ComputerFilter'
            type: 1
            isHiddenWhenLocked: true
            timeContext: {
              durationMs: 0
            }
            timeContextFromParameter: 'TimeRange'
            value: ''
          }
          {
            id: '787717b8-68fe-4d5a-a57d-ed900f7d8981'
            version: 'KqlParameterItem/1.0'
            name: 'Counter'
            type: 2
            isRequired: true
            query: 'Perf\r\n| where TimeGenerated {TimeRange}\r\n| summarize by CounterName, ObjectName, CounterText = CounterName\r\n| order by ObjectName asc, CounterText asc\r\n| project Counter = pack(\'counter\', CounterName, \'object\', ObjectName), CounterText, group = ObjectName'
            crossComponentResources: [
              '{Workspace}'
            ]
            isHiddenWhenLocked: true
            typeSettings: {
              additionalResourceOptions: []
            }
            queryType: 0
            resourceType: 'microsoft.operationalinsights/workspaces'
          }
          {
            id: '852b924f-41bc-4081-a0b6-c758873e702d'
            version: 'KqlParameterItem/1.0'
            name: 'Order'
            type: 2
            isRequired: true
            isHiddenWhenLocked: true
            typeSettings: {
              additionalResourceOptions: []
            }
            jsonData: '[\r\n    { "value":"asc", "label":"asc", "selected": false },\r\n    { "value":"desc", "label":"desc", "selected": true }\r\n]'
            timeContext: {
              durationMs: 0
            }
            timeContextFromParameter: 'TimeRange'
          }
        ]
        style: 'pills'
        queryType: 0
        resourceType: 'microsoft.insights/components'
      }
      name: 'parameters - 1'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'let trend = ( Heartbeat\r\n   | make-series InternalTrend=iff(count() > 0, 1, 0) default = 0 on TimeGenerated from {TimeRange:start} to {TimeRange:end} step 15m by Computer\r\n    | extend Trend=array_slice(InternalTrend, array_length(InternalTrend) - 30, array_length(InternalTrend)-1)); \r\n\r\nlet PerfCPU = (Perf\r\n    | where ObjectName contains "Processor" and CounterName == "% Processor Time" and (InstanceName=="_Total" or InstanceName=="total")\r\n    | summarize AvgCPU=round(avg(CounterValue),2), MaxCPU=round(max(CounterValue),2) by Computer\r\n    | extend StatusCPU = case (\r\n                  AvgCPU > 80, 2,\r\n                  AvgCPU > 50, 1,\r\n                  AvgCPU <= 50, 0, -1\r\n                )\r\n    );\r\n\r\nlet PerfMemory = (Perf\r\n    | where ObjectName contains "Memory" and (CounterName == "Available Bytes" or CounterName == "Available MBytes Memory")\r\n    | summarize AvgMEM=round(avg(CounterValue/1024),2), MaxMEM=round(max(CounterValue/1024),2) by Computer\r\n    | extend StatusMEM = case (\r\n                  AvgMEM > 4, 0,\r\n                  AvgMEM >= 1, 1,\r\n                  AvgMEM < 1, 2, -1\r\n            )\r\n    );\r\n\r\nlet PerfDisk = (Perf\r\n    | where (ObjectName == "LogicalDisk" or ObjectName == "Logical Disk") and CounterName == "Free Megabytes" and (InstanceName == "_Total" or InstanceName == "/")\r\n    | summarize AvgDisk=round(avg(CounterValue),2), (TimeGenerated,LastDisk)=arg_max(TimeGenerated,round(CounterValue,2)) by Computer\r\n    | extend StatusDisk = case (\r\n                  AvgDisk < 5000, 2,\r\n                  AvgDisk < 30000, 1,\r\n                  AvgDisk >= 30000, 0,-1\r\n)\r\n    | project Computer, AvgDisk , LastDisk ,StatusDisk\r\n    );\r\nPerfCPU\r\n| join (PerfMemory) on Computer\r\n| join (PerfDisk) on Computer\r\n| join (trend) on Computer\r\n| project Computer,StatusCPU, AvgCPU,MaxCPU,StatusMEM,AvgMEM,MaxMEM,StatusDisk,AvgDisk,LastDisk, Trend\r\n| sort by Computer '
        size: 0
        showAnalytics: true
        title: 'Top servers (data aggregated based on TimeRange)'
        timeContextFromParameter: 'TimeRange'
        exportFieldName: 'Computer'
        exportParameterName: 'Computer'
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
              formatter: 2
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
                unit: 5
                options: {
                  style: 'decimal'
                }
              }
            }
            {
              columnMatch: 'MaxMEM'
              formatter: 0
              numberFormat: {
                unit: 39
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
          sortBy: [
            {
              itemKey: '$gen_number_AvgCPU_2'
              sortOrder: 2
            }
          ]
          labelSettings: [
            {
              columnId: 'StatusCPU'
              label: 'CPU'
            }
            {
              columnId: 'AvgCPU'
              label: 'CPU (avg)'
            }
            {
              columnId: 'MaxCPU'
              label: 'CPU (max)'
            }
            {
              columnId: 'StatusMEM'
              label: 'Memory'
            }
            {
              columnId: 'AvgMEM'
              label: 'Memory (avg)'
            }
            {
              columnId: 'MaxMEM'
              label: 'Memory (max)'
            }
            {
              columnId: 'StatusDisk'
              label: 'Disk'
            }
            {
              columnId: 'AvgDisk'
              label: 'Disk (avg)'
            }
            {
              columnId: 'LastDisk'
              label: 'Disk (last)'
            }
          ]
        }
        sortBy: [
          {
            itemKey: '$gen_number_AvgCPU_2'
            sortOrder: 2
          }
        ]
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
        json: '## Processor(total)\\% Processor Time'
      }
      name: 'text - 10'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'let TopComputers = Perf \r\n| where Computer contains "{Computer}" or "{Computer}"=="All"\r\n| where ObjectName contains "Processor" and CounterName == "% Processor Time" and (InstanceName=="_Total" or InstanceName=="total")\r\n| summarize AvgCPU = avg(CounterValue) by Computer \r\n| top 10 by AvgCPU desc\r\n| project Computer; \r\nPerf \r\n| where Computer in (TopComputers) \r\n| where ObjectName contains "Processor" and CounterName == "% Processor Time" and (InstanceName=="_Total" or InstanceName=="total") \r\n| summarize Used_CPU = round(avg(CounterValue),1) by Computer, bin(TimeGenerated, ({TimeRange:end} - {TimeRange:start})/100)\r\n| render timechart'
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
          ySettings: {
            numberFormatSettings: {
              unit: 1
              options: {
                style: 'decimal'
                useGrouping: true
              }
            }
          }
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
        query: 'let trend = \r\nPerf           \r\n| where Computer contains "{Computer}" or "{Computer}"=="All"\r\n| where ObjectName contains "Processor" and CounterName == "% Processor Time" and (InstanceName=="_Total" or InstanceName=="total") \r\n| make-series Average = round(avg(CounterValue), 3) default = 0 on TimeGenerated from {TimeRange:start} to {TimeRange:end} step totimespan("00:30:00") by Computer     \r\n| project Computer, ["Trend"] = Average; \r\n\r\nPerf\r\n| where Computer contains "{Computer}" or "{Computer}"=="All"\r\n| where ObjectName contains "Processor" and CounterName == "% Processor Time" and (InstanceName=="_Total" or InstanceName=="total")\r\n| summarize Average=round(avg(CounterValue),3) by Computer\r\n| join (trend) on Computer\r\n| extend Status = case (\r\n                  Average > 80, "Critical",\r\n                  Average > 50, "Warning",\r\n                  Average <= 50, "Healthy", "Unknown"\r\n)\r\n\r\n| project Status, Computer, Average, Trend\r\n| sort by Average '
        size: 0
        showAnalytics: true
        title: 'Thresholds (Warning>50; Critical>80) - All Computers'
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
              numberFormat: {
                unit: 1
                options: {
                  style: 'decimal'
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
        }
        sortBy: []
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
        query: 'let TopComputers = Perf \r\n| where Computer contains "{Computer}" or "{Computer}"=="All"\r\n| where ObjectName == "Memory" and (CounterName == "Available MBytes" or CounterName == "Available MBytes Memory" )\r\n| summarize AvailableGBytes = round(avg(CounterValue)/1024,2) by Computer\r\n| top 10 by AvailableGBytes asc\r\n| project Computer; \r\nPerf \r\n| where Computer in (TopComputers) \r\n| where ObjectName == "Memory" and (CounterName == "Available MBytes" or CounterName == "Available MBytes Memory" )\r\n| summarize AvailableGBytes = round(avg(CounterValue)/1024,2) by Computer, bin(TimeGenerated, ({TimeRange:end} - {TimeRange:start})/100)\r\n| render timechart'
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
        query: 'let trend = \r\nPerf           \r\n| where Computer contains "{Computer}" or "{Computer}"=="All"\r\n| where ObjectName == "Memory" and (CounterName == "Available MBytes" or CounterName == "Available MBytes Memory" )\r\n| make-series Average = round(avg(CounterValue), 3) default = 0 on TimeGenerated from {TimeRange:start} to {TimeRange:end} step totimespan("00:30:00") by Computer     \r\n| project Computer, ["Trend"] = Average; \r\n\r\nPerf\r\n| where Computer contains "{Computer}" or "{Computer}"=="All"\r\n| where ObjectName == "Memory" and (CounterName == "Available MBytes" or CounterName == "Available MBytes Memory" )\r\n| summarize ["Available GBytes"]=round(avg(CounterValue)/1024,2) by Computer\r\n| join (trend) on Computer\r\n| extend Status = case (\r\n                  ["Available GBytes"] > 4, "Healthy",\r\n                  ["Available GBytes"] >= 1, "Warning",\r\n                  ["Available GBytes"] < 1, "Critical", "Unknown"\r\n)\r\n| project Status, Computer, ["Available GBytes"], Trend\r\n| sort by ["Available GBytes"] asc'
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
              formatter: 0
              numberFormat: {
                unit: 5
                options: {
                  style: 'decimal'
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
            {
              columnMatch: 'Average'
              formatter: 8
              formatOptions: {
                palette: 'blue'
              }
              numberFormat: {
                unit: 5
                options: {
                  style: 'decimal'
                }
              }
            }
          ]
          labelSettings: [
            {
              columnId: 'Available GBytes'
              label: 'Average'
            }
          ]
        }
        sortBy: []
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
        query: 'let TopComputers = Perf \r\n| where Computer contains "{Computer}" or "{Computer}"=="All"\r\n| where ObjectName == "Memory" and (CounterName == "% Committed Bytes In Use"  or CounterName == "% Used Memory")\r\n| summarize PctCommittedBytes = round(avg(CounterValue),2) by Computer\r\n| top 10 by PctCommittedBytes desc\r\n| project Computer; \r\nPerf \r\n| where Computer in (TopComputers) \r\n| where ObjectName == "Memory" and (CounterName == "% Committed Bytes In Use"  or CounterName == "% Used Memory")\r\n| summarize PctCommittedBytes = round(avg(CounterValue),2) by Computer, bin(TimeGenerated, ({TimeRange:end} - {TimeRange:start})/100)\r\n| render timechart'
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
        query: 'let trend = \r\nPerf           \r\n| where Computer contains "{Computer}" or "{Computer}"=="All"\r\n| where ObjectName == "Memory" and (CounterName == "% Committed Bytes In Use" or CounterName=="% Used Memory")\r\n| make-series Average = round(avg(CounterValue), 3) default = 0 on TimeGenerated from {TimeRange:start} to {TimeRange:end} step totimespan("00:30:00") by Computer     \r\n| project Computer, ["Trend"] = Average; \r\n\r\nPerf\r\n| where Computer contains "{Computer}" or "{Computer}"=="All"\r\n| where ObjectName == "Memory" and (CounterName == "% Committed Bytes In Use" or CounterName=="% Used Memory") \r\n| summarize Average=round(avg(CounterValue),3) by Computer\r\n| join (trend) on Computer\r\n| extend Status = case (\r\n                  Average > 90, "Critical",\r\n                  Average > 60, "Warning",\r\n                  Average <= 60, "Healthy", "Unknown"\r\n)\r\n\r\n| project Status, Computer, Average, Trend\r\n| sort by Average '
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
              numberFormat: {
                unit: 1
                options: {
                  style: 'decimal'
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
          sortBy: [
            {
              itemKey: '$gen_heatmap_Average_2'
              sortOrder: 2
            }
          ]
        }
        sortBy: [
          {
            itemKey: '$gen_heatmap_Average_2'
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
        query: 'let TopDiscos = Perf \r\n| where Computer contains "{Computer}" or "{Computer}"=="All"\r\n| where CounterName == "Free Megabytes" and (ObjectName == "LogicalDisk" or ObjectName == "Logical Disk")\r\n| where (strlen(InstanceName) ==2 and InstanceName contains ":") or (InstanceName contains "/")\r\n| extend Disco = strcat(InstanceName, " - ",Computer )\r\n| summarize FreeSpace = round(avg(CounterValue),2) by Disco\r\n| top 10 by FreeSpace asc\r\n| project Disco; \r\nPerf \r\n| where CounterName == "Free Megabytes" and (ObjectName == "LogicalDisk" or ObjectName == "Logical Disk")\r\n| where (strlen(InstanceName) ==2 and InstanceName contains ":") or (InstanceName contains "/")\r\n| extend Disco = strcat(InstanceName, " - ",Computer)\r\n| where Disco in (TopDiscos) \r\n| summarize FreeSpace = round(avg(CounterValue),2) by Disco, bin(TimeGenerated, ({TimeRange:end} - {TimeRange:start})/100)\r\n\r\n\r\n'
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
        query: 'let trend = \r\nPerf           \r\n| where Computer contains "{Computer}" or "{Computer}"=="All"\r\n| where CounterName == "Free Megabytes" and (ObjectName == "LogicalDisk" or ObjectName == "Logical Disk")\r\n| where (strlen(InstanceName) ==2 and InstanceName contains ":") or (InstanceName contains "/")\r\n| extend Disco = strcat(InstanceName, " - ",Computer )\r\n| make-series Average = round(avg(CounterValue), 3) default = 0 on TimeGenerated from {TimeRange:start} to {TimeRange:end} step totimespan("00:30:00") by Disco     \r\n| project Disco, ["Trend"] = Average; \r\n\r\nPerf\r\n| where Computer contains "{Computer}" or "{Computer}"=="All"\r\n| where CounterName == "Free Megabytes" and (ObjectName == "LogicalDisk" or ObjectName == "Logical Disk")\r\n| where (strlen(InstanceName) ==2 and InstanceName contains ":") or (InstanceName contains "/")\r\n| extend Disco = strcat(InstanceName, " - ",Computer )\r\n| summarize Average=round(avg(CounterValue),2) by Disco,Computer,InstanceName\r\n| join (trend) on Disco\r\n| extend Status = case (\r\n                  Average <5000, "Critical",\r\n                  Average < 30000, "Warning",\r\n                  Average >= 30000, "Healthy", "Unknown"\r\n)\r\n\r\n| project Status, Computer,Disk=InstanceName, Average, Trend\r\n| sort by Average asc '
        size: 0
        showAnalytics: true
        title: 'Thresholds (Warning < 30GB; Critical < 5GB) - All Computers-Volumes'
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
              formatter: 0
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
        }
        sortBy: []
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
        query: 'let TopDiscos = Perf \r\n| where Computer contains "{Computer}" or "{Computer}"=="All"\r\n| where CounterName == "Disk Reads/sec" and (ObjectName == "LogicalDisk" or ObjectName == "Logical Disk")\r\n| where (strlen(InstanceName) ==2 and InstanceName contains ":") or ( InstanceName == "/")\r\n| extend Disco = strcat(InstanceName, " - ",Computer )\r\n| summarize AVGReads = avg(CounterValue) by Disco\r\n| top 10 by AVGReads desc\r\n| project Disco; \r\nPerf \r\n| where CounterName == "Disk Reads/sec" and (ObjectName == "LogicalDisk" or ObjectName == "Logical Disk")\r\n| where (strlen(InstanceName) ==2 and InstanceName contains ":") or ( InstanceName == "/")\r\n| extend Disco = strcat(InstanceName, " - ",Computer )\r\n| where Disco in (TopDiscos) \r\n| summarize AVGReads = avg(CounterValue) by Disco, bin(TimeGenerated, ({TimeRange:end} - {TimeRange:start})/100)\r\n| render timechart\r\n\r\n\r\n'
        size: 0
        aggregation: 3
        showAnalytics: true
        title: 'Disk Reads/sec - Top 10 Computers-Volumes'
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
        query: 'let trend = \r\nPerf           \r\n| where Computer contains "{Computer}" or "{Computer}"=="All"\r\n| where (ObjectName == "LogicalDisk" or ObjectName=="Logical Disk") and CounterName == "Disk Reads/sec" and ((strlen(InstanceName) == 2 and InstanceName contains ":") or (InstanceName == "/"))\r\n| extend Disco = strcat(InstanceName, " - ",Computer)\r\n| make-series AVGReads = round(avg(CounterValue),2) default = 0 on TimeGenerated from {TimeRange:start} to {TimeRange:end} step totimespan("00:30:00") by Disco     \r\n| project Disco, ["Trend"] = AVGReads; \r\n\r\nPerf\r\n| where Computer contains "{Computer}" or "{Computer}"=="All"\r\n| where (ObjectName == "LogicalDisk" or ObjectName=="Logical Disk") and CounterName == "Disk Reads/sec" and ((strlen(InstanceName) == 2 and InstanceName contains ":") or (InstanceName == "/"))\r\n| extend Disco = strcat(InstanceName, " - ",Computer )\r\n| summarize AVGReads=round(avg(CounterValue),2) by Disco,Computer,InstanceName\r\n| join (trend) on Disco\r\n| extend Status = case (\r\n                  AVGReads > 25, "Critical",\r\n                  AVGReads > 15, "Warning",\r\n                  AVGReads <= 15, "Healthy", "Unknown"\r\n)\r\n| project  Status, Computer,Disk=InstanceName, ["Reads"]=AVGReads, Trend\r\n| sort by ["Reads"] desc '
        size: 0
        showAnalytics: true
        title: 'Thresholds (Warning > 15Reads/sec; Critical > 25Reads/sec) - All Computers-Volumes'
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
              columnMatch: 'Trend'
              formatter: 21
              formatOptions: {
                palette: 'green'
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
          sortBy: [
            {
              itemKey: 'Reads'
              sortOrder: 2
            }
          ]
          labelSettings: [
            {
              columnId: 'Reads'
              label: 'Average'
            }
          ]
        }
        sortBy: [
          {
            itemKey: 'Reads'
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
        query: 'let TopDiscos= Perf \r\n| where Computer contains "{Computer}" or "{Computer}"=="All"\r\n| where CounterName == "Disk Writes/sec" and (ObjectName == "LogicalDisk" or ObjectName=="Logical Disk")\r\n| where (strlen(InstanceName) ==2 and InstanceName contains ":") or InstanceName=="/"\r\n| extend Disco = strcat(InstanceName, " - ",Computer )\r\n| summarize AVGWrites = avg(CounterValue) by Disco\r\n| top 10 by AVGWrites desc\r\n| project Disco; \r\nPerf \r\n| where CounterName == "Disk Writes/sec" and (ObjectName == "LogicalDisk" or ObjectName=="Logical Disk")\r\n| where (strlen(InstanceName) ==2 and InstanceName contains ":") or InstanceName=="/"\r\n| extend Disco = strcat(InstanceName, " - ",Computer )\r\n| where Disco in (TopDiscos) \r\n| summarize AVGWrites = avg(CounterValue) by Disco, bin(TimeGenerated, ({TimeRange:end} - {TimeRange:start})/100)\r\n| render timechart\r\n\r\n\r\n'
        size: 0
        showAnalytics: true
        title: 'Disk Writes/sec - Top 10 Computers-Volumes'
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
        query: 'let trend = \r\nPerf           \r\n| where Computer contains "{Computer}"  or "{Computer}"=="All"\r\n| where CounterName == "Disk Writes/sec" and (ObjectName == "LogicalDisk" or ObjectName=="Logical Disk")\r\n| where (strlen(InstanceName) ==2 and InstanceName contains ":") or InstanceName=="/"\r\n| extend Disco = strcat(InstanceName, " - ",Computer )\r\n| make-series AVGWrites = round(avg(CounterValue),2) default = 0 on TimeGenerated from {TimeRange:start} to {TimeRange:end} step totimespan("00:30:00") by Disco     \r\n| project Disco, ["Trend"] = AVGWrites; \r\n\r\nPerf\r\n| where Computer contains "{Computer}" or "{Computer}"=="All"\r\n| where CounterName == "Disk Writes/sec" and (ObjectName == "LogicalDisk" or ObjectName=="Logical Disk")\r\n| where (strlen(InstanceName) ==2 and InstanceName contains ":") or InstanceName=="/"\r\n| extend Disco = strcat(InstanceName, " - ",Computer )\r\n| summarize AVGWrites=round(avg(CounterValue),2) by Disco,Computer,InstanceName\r\n| join (trend) on Disco\r\n| extend Status = case (\r\n                  AVGWrites > 25, "Critical",\r\n                  AVGWrites > 15, "Warning",\r\n                  AVGWrites <= 15, "Healthy", "Unknown"\r\n)\r\n\r\n| project  Status, Computer,Disk=InstanceName, ["Writes"]=AVGWrites, Trend\r\n| sort by ["Writes"] desc '
        size: 0
        showAnalytics: true
        title: 'Thresholds (Warning > 15Writes/sec; Critical > 25Writes/sec) - All Computers-Volumes'
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
              columnMatch: 'Trend'
              formatter: 21
              formatOptions: {
                palette: 'green'
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
          sortBy: [
            {
              itemKey: 'Writes'
              sortOrder: 2
            }
          ]
          labelSettings: [
            {
              columnId: 'Writes'
              label: 'Average'
            }
          ]
        }
        sortBy: [
          {
            itemKey: 'Writes'
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
  ]
  isLocked: false
  fallbackResourceIds: [
    'azure monitor'
  ]
}

var alertsConsoleWorkbookContent = {
  version: 'Notebook/1.0'
  items: [
    {
      type: 9
      content: {
        version: 'KqlParameterItem/1.0'
        crossComponentResources: [
          '{Subscription}'
        ]
        parameters: [
          {
            id: '1f74ed9a-e3ed-498d-bd5b-f68f3836a117'
            version: 'KqlParameterItem/1.0'
            name: 'Subscription'
            label: 'Subscriptions'
            type: 6
            isRequired: true
            multiSelect: true
            quote: '\''
            delimiter: ','
            value: [
              subscription().id
            ]
            typeSettings: {
              additionalResourceOptions: [
                'value::all'
              ]
              includeAll: false
              showDefault: false
            }
          }
          {
            id: 'b616a3a3-4271-4208-b1a9-a92a78efed08'
            version: 'KqlParameterItem/1.0'
            name: 'ResourceGroups'
            label: 'Resource groups'
            type: 2
            isRequired: true
            multiSelect: true
            quote: '\''
            delimiter: ','
            query: 'Resources\r\n| summarize by resourceGroup\r\n| order by resourceGroup asc\r\n| project id=resourceGroup, resourceGroup'
            crossComponentResources: [
              '{Subscription}'
            ]
            value: [
              'value::all'
            ]
            typeSettings: {
              additionalResourceOptions: [
                'value::all'
              ]
              selectAllValue: '*'
            }
            queryType: 1
            resourceType: 'microsoft.resourcegraph/resources'
          }
          {
            id: '0e85e0e4-a7e8-4ea8-b291-e444c317843a'
            version: 'KqlParameterItem/1.0'
            name: 'ResourceTypes'
            label: 'Resource types'
            type: 7
            isRequired: true
            multiSelect: true
            quote: '\''
            delimiter: ','
            query: 'where "*" in ({ResourceGroups}) or resourceGroup in ({ResourceGroups})\r\n| summarize by type\r\n| project type, label=type\r\n'
            crossComponentResources: [
              '{Subscription}'
            ]
            value: [
              'value::all'
            ]
            typeSettings: {
              additionalResourceOptions: [
                'value::all'
              ]
              selectAllValue: '*'
            }
            queryType: 1
            resourceType: 'microsoft.resourcegraph/resources'
          }
          {
            id: 'f60ea0a0-3703-44ca-a59b-df0246423f41'
            version: 'KqlParameterItem/1.0'
            name: 'Resources'
            type: 5
            isRequired: true
            multiSelect: true
            quote: '\''
            delimiter: ','
            query: 'Resources\r\n| where "*" in ({ResourceTypes}) or type in~({ResourceTypes})\r\n| where \'*\' in~({ResourceGroups}) or resourceGroup in~({ResourceGroups}) \r\n| order by name asc\r\n| extend Rank = row_number()\r\n| project value = id, label = name, selected = Rank <= 10, group = resourceGroup'
            crossComponentResources: [
              '{Subscription}'
            ]
            value: [
              'value::all'
            ]
            typeSettings: {
              additionalResourceOptions: [
                'value::all'
              ]
              selectAllValue: '*'
              defaultItemsText: 'First 10'
            }
            queryType: 1
            resourceType: 'microsoft.resourcegraph/resources'
          }
          {
            id: '015d1a5e-357f-4e01-ac77-598e7b493db0'
            version: 'KqlParameterItem/1.0'
            name: 'timeRange'
            label: 'Time Range'
            type: 4
            isRequired: true
            value: {
              durationMs: 2592000000
            }
            typeSettings: {
              selectableValues: [
                {
                  durationMs: 300000
                }
                {
                  durationMs: 900000
                }
                {
                  durationMs: 1800000
                }
                {
                  durationMs: 3600000
                }
                {
                  durationMs: 14400000
                }
                {
                  durationMs: 43200000
                }
                {
                  durationMs: 86400000
                }
                {
                  durationMs: 172800000
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
                  durationMs: 2419200000
                }
                {
                  durationMs: 2592000000
                }
              ]
              allowCustom: true
            }
          }
          {
            id: 'bd6d6075-dc8f-43d3-829f-7e2245a3eb21'
            version: 'KqlParameterItem/1.0'
            name: 'State'
            type: 2
            isRequired: true
            multiSelect: true
            quote: '\''
            delimiter: ','
            query: '{"version":"1.0.0","content":"[ \\r\\n    {"id":"New", "label": "New"},\\r\\n    {"id":"Acknowledged", "label": "Acknowledged"},\\r\\n    {"id":"Closed", "label": "Closed"}\\r\\n]","transformers":null}'
            crossComponentResources: [
              '{Subscription}'
            ]
            value: [
              'value::all'
            ]
            typeSettings: {
              additionalResourceOptions: [
                'value::all'
              ]
              selectAllValue: '*'
              showDefault: false
            }
            queryType: 8
          }
        ]
        style: 'above'
        queryType: 1
        resourceType: 'microsoft.resourcegraph/resources'
      }
      name: 'parameters'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'AlertsManagementResources \r\n| where type =~ \'microsoft.alertsmanagement/alerts\'\r\n| where properties.essentials.startDateTime {timeRange}  \r\n| where properties.essentials.actionStatus.isSuppressed == false\r\n| extend Severity=tostring(properties.essentials.severity)\r\n| extend State=tostring(properties.essentials.alertState)\r\n| extend comp = properties.context.context.condition.allOf[0].dimensions\r\n| mvexpand comp\r\n| where comp.name == \'Computer\'\r\n| where "*" in ({State}) or State in ({State})\r\n| where "*" in ({ResourceTypes}) or properties.essentials.targetResourceType in~ ({ResourceTypes})\r\n| where "*" in ({ResourceGroups}) or properties.essentials.targetResourceGroup in~ ({ResourceGroups})\r\n| where "*" in ({Resources}) or properties.essentials.targetResource in~ ({Resources})\r\n| project AlertId=id, StartTime=todatetime(tostring(properties.essentials.startDateTime)), Name=name, Severity, State=tostring(properties.essentials.alertState), MonitorCondition=tostring(properties.essentials.monitorCondition), SignalType=tostring(properties.essentials.signalType), TargetResource = split(comp.value, \'.\')[0]\r\n| order by StartTime desc\r\n'
        size: 0
        title: 'Azure Monitor alerts'
        queryType: 1
        resourceType: 'microsoft.resourcegraph/resources'
        crossComponentResources: [
          '{Subscription}'
        ]
        gridSettings: {
          formatters: [
            {
              columnMatch: 'AlertId'
              formatter: 5
            }
            {
              columnMatch: 'StartTime'
              formatter: 6
            }
            {
              columnMatch: 'Name'
              formatter: 1
              formatOptions: {
                linkTarget: 'OpenBlade'
                linkIsContextBlade: true
                bladeOpenContext: {
                  bladeName: 'AlertDetailsTemplateBlade'
                  extensionName: 'Microsoft_Azure_Monitoring'
                  bladeParameters: [
                    {
                      name: 'alertId'
                      source: 'column'
                      value: 'AlertId'
                    }
                    {
                      name: 'alertName'
                      source: 'column'
                      value: 'Name'
                    }
                    {
                      name: 'invokedFrom'
                      source: 'static'
                      value: 'Workbooks'
                    }
                  ]
                }
              }
              tooltipFormat: {
                tooltip: 'View alert details'
              }
            }
            {
              columnMatch: 'Severity'
              formatter: 11
            }
            {
              columnMatch: 'State'
              formatter: 1
            }
            {
              columnMatch: 'MonitorCondition'
              formatter: 18
              formatOptions: {
                thresholdsOptions: 'icons'
                thresholdsGrid: [
                  {
                    operator: '=='
                    thresholdValue: 'Fired'
                    representation: 'Fired'
                    text: '{0}{1}'
                  }
                  {
                    operator: '=='
                    thresholdValue: 'Resolved'
                    representation: 'Resolved'
                    text: '{0}{1}'
                  }
                  {
                    operator: 'Default'
                    thresholdValue: null
                    representation: 'success'
                    text: '{0}{1}'
                  }
                ]
              }
            }
            {
              columnMatch: 'TargetResource'
              formatter: 13
              formatOptions: {
                linkTarget: null
                showIcon: true
              }
            }
            {
              columnMatch: 'ResourceType'
              formatter: 16
              formatOptions: {
                showIcon: true
              }
            }
            {
              columnMatch: 'Resource Type'
              formatter: 11
            }
            {
              columnMatch: 'essentials'
              formatter: 5
            }
          ]
        }
      }
      showPin: true
      name: 'query - 3'
    }
  ]
  isLocked: false
  fallbackResourceIds: [
    'azure monitor'
  ]
}

resource actionGroup 'Microsoft.Insights/actionGroups@2022-06-01' = {
  name: actionGroupName
  location: 'Global'
  properties: {
    groupShortName: 'agarcservers'
    enabled: true
    emailReceivers: [
      {
        name: 'ArcServersEmail'
        emailAddress: emailAddress
      }
    ]
  }
}

resource Processor_Time_Percent 'Microsoft.Insights/scheduledQueryRules@2021-02-01-preview' = {
  name: 'Processor Time Percent'
  location: location
  tags: {
    '${'${convertRuleTag}${workspaceId}'}': 'Resource'
  }
  kind: 'LogToMetric'
  properties: {
    displayName: 'Processor Time Percent'
    description: 'Monitor Alert for Processor Time Percent'
    enabled: true
    scopes: [
      workspaceId
    ]
    criteria: {
      allOf: [
        {
          metricName: 'Average_% Processor Time'
          dimensions: [
            {
              name: 'Computer'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'ObjectName'
              operator: 'Include'
              values: [
                'Processor'
              ]
            }
          ]
        }
      ]
    }
  }
}

resource Microsoft_Insights_metricAlerts_Processor_Time_Percent 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Processor Time Percent'
  location: 'global'
  tags: {}
  properties: {
    severity: alertsSeverity
    enabled: true
    scopes: [
      workspaceId
    ]
    description: 'Monitor Alert for Processor Time Percent'
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    criteria: {
      allOf: [
        {
          threshold: 80
          name: 'Metric1'
          metricNamespace: 'Microsoft.OperationalInsights/workspaces'
          metricName: 'Average_% Processor Time'
          dimensions: [
            {
              name: 'Computer'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'ObjectName'
              operator: 'Include'
              values: [
                'Processor'
              ]
            }
          ]
          operator: 'GreaterThan'
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    autoMitigate: true
    targetResourceType: 'Microsoft.OperationalInsights/workspaces'
    targetResourceRegion: location
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
  dependsOn: [
    Processor_Time_Percent

  ]
}

resource Memory_Available_MBytes 'Microsoft.Insights/scheduledQueryRules@2021-02-01-preview' = {
  name: 'Memory Available MBytes'
  location: location
  tags: {
    '${'${convertRuleTag}${workspaceId}'}': 'Resource'
  }
  kind: 'LogToMetric'
  properties: {
    displayName: 'Memory Available MBytes'
    description: 'Monitor alert for Memory Available MBytes'
    enabled: true
    scopes: [
      workspaceId
    ]
    criteria: {
      allOf: [
        {
          metricName: 'Average_Available MBytes'
          dimensions: [
            {
              name: 'Computer'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'ObjectName'
              operator: 'Include'
              values: [
                'Memory'
              ]
            }
          ]
        }
      ]
    }
  }
}

resource Microsoft_Insights_metricAlerts_Memory_Available_MBytes 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Memory Available MBytes'
  location: 'global'
  tags: {}
  properties: {
    severity: alertsSeverity
    enabled: true
    scopes: [
      workspaceId
    ]
    description: 'Monitor alert for Memory Available MBytes'
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    criteria: {
      allOf: [
        {
          threshold: 1500
          name: 'Metric1'
          metricNamespace: 'Microsoft.OperationalInsights/workspaces'
          metricName: 'Average_Available MBytes'
          dimensions: [
            {
              name: 'Computer'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'ObjectName'
              operator: 'Include'
              values: [
                'Memory'
              ]
            }
          ]
          operator: 'LessThan'
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    autoMitigate: true
    targetResourceType: 'Microsoft.OperationalInsights/workspaces'
    targetResourceRegion: location
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
  dependsOn: [
    Memory_Available_MBytes

  ]
}

resource Memory_Commited_Bytes_in_use_Percent 'Microsoft.Insights/scheduledQueryRules@2021-02-01-preview' = {
  name: 'Memory Commited Bytes in use Percent'
  location: location
  tags: {
    '${'${convertRuleTag}${workspaceId}'}': 'Resource'
  }
  kind: 'LogToMetric'
  properties: {
    displayName: 'Memory Commited Bytes in use Percent'
    description: 'Monitor Alert for Memory Commited Bytes in use Percent'
    enabled: true
    scopes: [
      workspaceId
    ]
    criteria: {
      allOf: [
        {
          metricName: 'Average_% Committed Bytes In Use'
          dimensions: [
            {
              name: 'Computer'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'ObjectName'
              operator: 'Include'
              values: [
                'Memory'
              ]
            }
          ]
        }
      ]
    }
  }
}

resource Microsoft_Insights_metricAlerts_Memory_Commited_Bytes_in_use_Percent 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Memory Commited Bytes in use Percent'
  location: 'global'
  tags: {}
  properties: {
    severity: alertsSeverity
    enabled: true
    scopes: [
      workspaceId
    ]
    description: 'Monitor Alert for Memory Commited Bytes in use Percent'
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    criteria: {
      allOf: [
        {
          threshold: 80
          name: 'Metric1'
          metricNamespace: 'Microsoft.OperationalInsights/workspaces'
          metricName: 'Average_% Committed Bytes In Use'
          dimensions: [
            {
              name: 'Computer'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'ObjectName'
              operator: 'Include'
              values: [
                'Memory'
              ]
            }
          ]
          operator: 'GreaterThan'
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    autoMitigate: true
    targetResourceType: 'Microsoft.OperationalInsights/workspaces'
    targetResourceRegion: location
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
  dependsOn: [
    Memory_Commited_Bytes_in_use_Percent

  ]
}

resource Memory_Pages_per_Sec 'Microsoft.Insights/scheduledQueryRules@2021-02-01-preview' = {
  name: 'Memory Pages per Sec'
  location: location
  tags: {
    '${'${convertRuleTag}${workspaceId}'}': 'Resource'
  }
  kind: 'LogToMetric'
  properties: {
    displayName: 'Memory Pages per Sec'
    description: 'Monitor Alert for Memory Pages per Sec'
    enabled: true
    scopes: [
      workspaceId
    ]
    criteria: {
      allOf: [
        {
          metricName: 'Average_Pages/sec'
          dimensions: [
            {
              name: 'Computer'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'ObjectName'
              operator: 'Include'
              values: [
                'Memory'
              ]
            }
          ]
        }
      ]
    }
  }
}

resource Microsoft_Insights_metricAlerts_Memory_Pages_per_Sec 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Memory Pages per Sec'
  location: 'global'
  tags: {}
  properties: {
    severity: alertsSeverity
    enabled: true
    scopes: [
      workspaceId
    ]
    description: 'Monitor Alert for Memory Pages per Sec'
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    criteria: {
      allOf: [
        {
          threshold: 5000
          name: 'Metric1'
          metricNamespace: 'Microsoft.OperationalInsights/workspaces'
          metricName: 'Average_Pages/sec'
          dimensions: [
            {
              name: 'Computer'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'ObjectName'
              operator: 'Include'
              values: [
                'Memory'
              ]
            }
          ]
          operator: 'GreaterThan'
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    autoMitigate: true
    targetResourceType: 'Microsoft.OperationalInsights/workspaces'
    targetResourceRegion: location
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
  dependsOn: [
    Memory_Pages_per_Sec

  ]
}

resource LogicalDisk_Avg_Disk_sec_per_Read 'Microsoft.Insights/scheduledQueryRules@2021-02-01-preview' = {
  name: 'LogicalDisk Avg. Disk sec per Read'
  location: location
  tags: {
    '${'${convertRuleTag}${workspaceId}'}': 'Resource'
  }
  kind: 'LogToMetric'
  properties: {
    displayName: 'LogicalDisk Avg. Disk sec per Read'
    description: 'Monitor Alert for LogicalDisk Avg. Disk sec per Read'
    enabled: true
    scopes: [
      workspaceId
    ]
    criteria: {
      allOf: [
        {
          metricName: 'Average_Avg. Disk sec/Read'
          dimensions: [
            {
              name: 'Computer'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'ObjectName'
              operator: 'Include'
              values: [
                'LogicalDisk'
              ]
            }
          ]
        }
      ]
    }
  }
}

resource Microsoft_Insights_metricAlerts_LogicalDisk_Avg_Disk_sec_per_Read 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'LogicalDisk Avg. Disk sec per Read'
  location: 'global'
  tags: {}
  properties: {
    severity: alertsSeverity
    enabled: true
    scopes: [
      workspaceId
    ]
    description: 'Monitor Alert for LogicalDisk Avg. Disk sec per Read'
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    criteria: {
      allOf: [
        {
          threshold: json('0.04')
          name: 'Metric1'
          metricNamespace: 'Microsoft.OperationalInsights/workspaces'
          metricName: 'Average_Avg. Disk sec/Read'
          dimensions: [
            {
              name: 'Computer'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'ObjectName'
              operator: 'Include'
              values: [
                'LogicalDisk'
              ]
            }
          ]
          operator: 'GreaterThan'
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    autoMitigate: true
    targetResourceType: 'Microsoft.OperationalInsights/workspaces'
    targetResourceRegion: location
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
  dependsOn: [
    LogicalDisk_Avg_Disk_sec_per_Read

  ]
}

resource LogicalDisk_Avg_Disk_sec_per_Write 'Microsoft.Insights/scheduledQueryRules@2021-02-01-preview' = {
  name: 'LogicalDisk Avg. Disk sec per Write'
  location: location
  tags: {
    '${'${convertRuleTag}${workspaceId}'}': 'Resource'
  }
  kind: 'LogToMetric'
  properties: {
    displayName: 'LogicalDisk Avg. Disk sec per Write'
    description: 'Monitor Alert for LogicalDisk Avg. Disk sec per Write'
    enabled: true
    scopes: [
      workspaceId
    ]
    criteria: {
      allOf: [
        {
          metricName: 'Average_Avg. Disk sec/Write'
          dimensions: [
            {
              name: 'Computer'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'ObjectName'
              operator: 'Include'
              values: [
                'LogicalDisk'
              ]
            }
          ]
        }
      ]
    }
  }
}

resource Microsoft_Insights_metricAlerts_LogicalDisk_Avg_Disk_sec_per_Write 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'LogicalDisk Avg. Disk sec per Write'
  location: 'global'
  tags: {}
  properties: {
    severity: alertsSeverity
    enabled: true
    scopes: [
      workspaceId
    ]
    description: 'Monitor Alert for LogicalDisk Avg. Disk sec per Write'
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    criteria: {
      allOf: [
        {
          threshold: json('0.04')
          name: 'Metric1'
          metricNamespace: 'Microsoft.OperationalInsights/workspaces'
          metricName: 'Average_Avg. Disk sec/Write'
          dimensions: [
            {
              name: 'Computer'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'ObjectName'
              operator: 'Include'
              values: [
                'LogicalDisk'
              ]
            }
          ]
          operator: 'GreaterThan'
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    autoMitigate: true
    targetResourceType: 'Microsoft.OperationalInsights/workspaces'
    targetResourceRegion: location
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
  dependsOn: [
    LogicalDisk_Avg_Disk_sec_per_Write

  ]
}

resource LogicalDisk_Current_Queue_Length 'Microsoft.Insights/scheduledQueryRules@2021-02-01-preview' = {
  name: 'LogicalDisk Current Queue Length'
  location: location
  tags: {
    '${'${convertRuleTag}${workspaceId}'}': 'Resource'
  }
  kind: 'LogToMetric'
  properties: {
    displayName: 'LogicalDisk Current Queue Length'
    description: 'Monitor Alert for LogicalDisk Current Queue Length'
    enabled: true
    scopes: [
      workspaceId
    ]
    criteria: {
      allOf: [
        {
          metricName: 'Average_Current Disk Queue Length'
          dimensions: [
            {
              name: 'Computer'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'ObjectName'
              operator: 'Include'
              values: [
                'LogicalDisk'
              ]
            }
          ]
        }
      ]
    }
  }
}

resource Microsoft_Insights_metricAlerts_LogicalDisk_Current_Queue_Length 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'LogicalDisk Current Queue Length'
  location: 'global'
  tags: {}
  properties: {
    severity: alertsSeverity
    enabled: true
    scopes: [
      workspaceId
    ]
    description: 'Monitor Alert for LogicalDisk Current Queue Length'
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    criteria: {
      allOf: [
        {
          threshold: 2
          name: 'Metric1'
          metricNamespace: 'Microsoft.OperationalInsights/workspaces'
          metricName: 'Average_Current Disk Queue Length'
          dimensions: [
            {
              name: 'Computer'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'ObjectName'
              operator: 'Include'
              values: [
                'LogicalDisk'
              ]
            }
          ]
          operator: 'GreaterThan'
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    autoMitigate: true
    targetResourceType: 'Microsoft.OperationalInsights/workspaces'
    targetResourceRegion: location
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
  dependsOn: [
    LogicalDisk_Current_Queue_Length

  ]
}

resource LogicalDisk_Free_Space_Percent 'Microsoft.Insights/scheduledQueryRules@2021-02-01-preview' = {
  name: 'LogicalDisk Free Space Percent'
  location: location
  tags: {
    '${'${convertRuleTag}${workspaceId}'}': 'Resource'
  }
  kind: 'LogToMetric'
  properties: {
    displayName: 'LogicalDisk Free Space Percent'
    description: 'Monitor Alert for LogicalDisk Free Space Percent'
    enabled: true
    scopes: [
      workspaceId
    ]
    criteria: {
      allOf: [
        {
          metricName: 'Average_% Free Space'
          dimensions: [
            {
              name: 'Computer'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'ObjectName'
              operator: 'Include'
              values: [
                'LogicalDisk'
              ]
            }
          ]
        }
      ]
    }
  }
}

resource Microsoft_Insights_metricAlerts_LogicalDisk_Free_Space_Percent 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'LogicalDisk Free Space Percent'
  location: 'global'
  tags: {}
  properties: {
    severity: alertsSeverity
    enabled: true
    scopes: [
      workspaceId
    ]
    description: 'Monitor Alert for LogicalDisk Free Space Percent'
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    criteria: {
      allOf: [
        {
          threshold: 10
          name: 'Metric1'
          metricNamespace: 'Microsoft.OperationalInsights/workspaces'
          metricName: 'Average_% Free Space'
          dimensions: [
            {
              name: 'Computer'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'ObjectName'
              operator: 'Include'
              values: [
                'LogicalDisk'
              ]
            }
          ]
          operator: 'LessThan'
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    autoMitigate: true
    targetResourceType: 'Microsoft.OperationalInsights/workspaces'
    targetResourceRegion: location
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
  dependsOn: [
    LogicalDisk_Free_Space_Percent

  ]
}

resource LogicalDisk_Idle_Time_Percent 'Microsoft.Insights/scheduledQueryRules@2021-02-01-preview' = {
  name: 'LogicalDisk Idle Time Percent'
  location: location
  tags: {
    '${'${convertRuleTag}${workspaceId}'}': 'Resource'
  }
  kind: 'LogToMetric'
  properties: {
    displayName: 'LogicalDisk Idle Time Percent'
    description: 'Monitor Alert for LogicalDisk Idle Time Percent'
    enabled: true
    scopes: [
      workspaceId
    ]
    criteria: {
      allOf: [
        {
          metricName: 'Average_% Idle Time'
          dimensions: [
            {
              name: 'Computer'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'ObjectName'
              operator: 'Include'
              values: [
                'LogicalDisk'
              ]
            }
          ]
        }
      ]
    }
  }
}

resource Microsoft_Insights_metricAlerts_LogicalDisk_Idle_Time_Percent 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'LogicalDisk Idle Time Percent'
  location: 'global'
  tags: {}
  properties: {
    severity: alertsSeverity
    enabled: true
    scopes: [
      workspaceId
    ]
    description: 'Monitor Alert for LogicalDisk Idle Time Percent'
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    criteria: {
      allOf: [
        {
          threshold: 20
          name: 'Metric1'
          metricNamespace: 'Microsoft.OperationalInsights/workspaces'
          metricName: 'Average_% Idle Time'
          dimensions: [
            {
              name: 'Computer'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'ObjectName'
              operator: 'Include'
              values: [
                'LogicalDisk'
              ]
            }
          ]
          operator: 'LessThan'
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    autoMitigate: true
    targetResourceType: 'Microsoft.OperationalInsights/workspaces'
    targetResourceRegion: location
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
  dependsOn: [
    LogicalDisk_Idle_Time_Percent

  ]
}

resource Heartbeat_Missed 'Microsoft.Insights/scheduledQueryRules@2021-02-01-preview' = {
  name: 'Heartbeat Missed'
  location: location
  tags: {
    '${'${convertRuleTag}${workspaceId}'}': 'Resource'
  }
  kind: 'LogToMetric'
  properties: {
    displayName: 'Heartbeat Missed'
    description: 'Monitor Alert for Heartbeat Missed'
    enabled: true
    scopes: [
      workspaceId
    ]
    criteria: {
      allOf: [
        {
          metricName: 'Heartbeat'
          dimensions: [
            {
              name: 'Computer'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
        }
      ]
    }
  }
}

resource Microsoft_Insights_metricAlerts_Heartbeat_Missed 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Heartbeat Missed'
  location: 'global'
  tags: {}
  properties: {
    severity: alertsSeverity
    enabled: true
    scopes: [
      workspaceId
    ]
    description: 'Monitor Alert for Heartbeat Missed'
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    criteria: {
      allOf: [
        {
          threshold: 0
          name: 'Metric1'
          metricNamespace: 'Microsoft.OperationalInsights/workspaces'
          metricName: 'Heartbeat'
          dimensions: [
            {
              name: 'Computer'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          operator: 'LessThanOrEqual'
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    autoMitigate: true
    targetResourceType: 'Microsoft.OperationalInsights/workspaces'
    targetResourceRegion: location
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
  dependsOn: [
    Heartbeat_Missed

  ]
}

resource Unexpected_System_Shutdown 'microsoft.insights/scheduledqueryrules@2021-08-01' = {
  name: 'Unexpected System Shutdown'
  location: location
  properties: {
    displayName: 'Unexpected System Shutdown'
    description: 'Monitor Alert for Unexpected System Shutdown'
    severity: alertsSeverity
    enabled: true
    evaluationFrequency: evaluationFrequency
    scopes: [
      workspaceId
    ]
    targetResourceTypes: [
      'Microsoft.OperationalInsights/workspaces'
    ]
    windowSize: windowSize
    criteria: {
      allOf: [
        {
          query: 'Event | where (EventID == 6008 and Source =="EventLog") or (EventID == 1074 and Source == "User32" and (RenderedDescription has "shutdown" or RenderedDescription has "power off")) \n'
          timeAggregation: 'Count'
          dimensions: [
            {
              name: 'Computer'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          resourceIdColumn: '_ResourceId'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: false
    actions: {
      actionGroups: [
        actionGroup.id
      ]
    }
  }
}

resource windowsEventsWorkbook 'microsoft.insights/workbooks@2021-03-08' = {
  name: guid(windowsEventsWorkbookName)
  location: location
  kind: 'shared'
  properties: {
    displayName: windowsEventsWorkbookName
    serializedData: string(windowsEventsWorkbookContent)
    version: '1.0'
    sourceId: 'azure monitor'
    category: 'workbook'
  }
}

resource osPerformanceWorkbook 'microsoft.insights/workbooks@2021-03-08' = {
  name: guid(osPerformanceWorkbookName)
  location: location
  kind: 'shared'
  properties: {
    displayName: osPerformanceWorkbookName
    serializedData: string(osPerformanceWorkbookContent)
    version: '1.0'
    sourceId: 'azure monitor'
    category: 'workbook'
  }
}

resource alertsConsoleWorkbook 'microsoft.insights/workbooks@2021-03-08' = {
  name: guid(alertsConsoleWorkbookName)
  location: location
  kind: 'shared'
  properties: {
    displayName: alertsConsoleWorkbookName
    serializedData: string(alertsConsoleWorkbookContent)
    version: '1.0'
    sourceId: 'azure monitor'
    category: 'workbook'
  }
  dependsOn: []
}

resource azureDashboard 'Microsoft.Portal/dashboards@2015-08-01-preview' = {
  name: guid(azureDashboardName)
  location: location
  tags: {
    'hidden-title': azureDashboardName
  }
  properties: {
    lenses: {
      '0': {
        order: 0
        parts: {
          '0': {
            position: {
              x: 0
              y: 0
              colSpan: 17
              rowSpan: 4
            }
            metadata: {
              inputs: [
                {
                  name: 'ComponentId'
                  value: 'azure monitor'
                  isOptional: true
                }
                {
                  name: 'TimeContext'
                  value: null
                  isOptional: true
                }
                {
                  name: 'ResourceIds'
                  value: [
                    'azure monitor'
                  ]
                  isOptional: true
                }
                {
                  name: 'ConfigurationId'
                  value: osPerformanceWorkbook.id
                  isOptional: true
                }
                {
                  name: 'Type'
                  value: 'workbook'
                  isOptional: true
                }
                {
                  name: 'GalleryResourceType'
                  value: 'azure monitor'
                  isOptional: true
                }
                {
                  name: 'PinName'
                  value: osPerformanceWorkbookName
                  isOptional: true
                }
                {
                  name: 'StepSettings'
                  value: '{"version":"KqlItem/1.0","query":"let trend = ( Heartbeat\\r\\n    | make-series InternalTrend=iff(count() > 0, 1, 0) default = 0 on TimeGenerated from {TimeRange:start} to {TimeRange:end} step 15m by Computer\\r\\n    | extend Trend=array_slice(InternalTrend, array_length(InternalTrend) - 30, array_length(InternalTrend)-1)); \\r\\n\\r\\nlet PerfCPU = (Perf\\r\\n    | where ObjectName == "Processor" and CounterName == "% Processor Time" and InstanceName=="total"\\r\\n    | summarize AvgCPU=round(avg(CounterValue),2), MaxCPU=round(max(CounterValue),2) by Computer\\r\\n    | extend StatusCPU = case (\\r\\n                  AvgCPU > 80, 2,\\r\\n                  AvgCPU > 50, 1,\\r\\n                  AvgCPU <= 50, 0, -1\\r\\n                )\\r\\n    );\\r\\n\\r\\nlet PerfMemory = (Perf\\r\\n    | where ObjectName == "Memory" and (CounterName == "Available MBytes" or CounterName == "Available MBytes Memory")\\r\\n    | summarize AvgMEM=round(avg(CounterValue/1024),2), MaxMEM=round(max(CounterValue/1024),2) by Computer\\r\\n    | extend StatusMEM = case (\\r\\n                  AvgMEM > 4, 0,\\r\\n                  AvgMEM >= 1, 1,\\r\\n                  AvgMEM < 1, 2, -1\\r\\n            )\\r\\n    );\\r\\n\\r\\nlet PerfDisk = (Perf\\r\\n    | where (ObjectName == "LogicalDisk" or ObjectName == "Logical Disk") and CounterName == "Free Megabytes" and (InstanceName =~ "C:" or InstanceName == "/")\\r\\n    | summarize AvgDisk=round(avg(CounterValue),2), (TimeGenerated,LastDisk)=arg_max(TimeGenerated,round(CounterValue,2)) by Computer\\r\\n    | extend StatusDisk = case (\\r\\n                  AvgDisk < 5000, 2,\\r\\n                  AvgDisk < 30000, 1,\\r\\n                  AvgDisk >= 30000, 0,-1\\r\\n)\\r\\n    | project Computer, AvgDisk , LastDisk ,StatusDisk\\r\\n    );\\r\\nPerfCPU\\r\\n| join (PerfMemory) on Computer\\r\\n| join (PerfDisk) on Computer\\r\\n| join (trend) on Computer\\r\\n| project Computer,StatusCPU, AvgCPU,MaxCPU,StatusMEM,AvgMEM,MaxMEM,StatusDisk,AvgDisk,LastDisk, Trend\\r\\n| sort by Computer ","size":0,"showAnalytics":true,"title":"Top servers (data aggregated based on TimeRange)","timeContextFromParameter":"TimeRange","exportFieldName":"Computer","exportParameterName":"Computer","exportDefaultValue":"All","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspace}"],"gridSettings":{"formatters":[{"columnMatch":"StatusCPU","formatter":18,"formatOptions":{"thresholdsOptions":"icons","thresholdsGrid":[{"operator":"==","thresholdValue":"0","representation":"success","text":"{1}"},{"operator":"==","thresholdValue":"1","representation":"2","text":"{1}"},{"operator":"==","thresholdValue":"2","representation":"4","text":"{1}"},{"operator":"Default","thresholdValue":null,"representation":"Unknown","text":"{1}"}]}},{"columnMatch":"AvgCPU","formatter":2,"numberFormat":{"unit":1,"options":{"style":"decimal"}}},{"columnMatch":"MaxCPU","formatter":0,"numberFormat":{"unit":1,"options":{"style":"decimal"}}},{"columnMatch":"StatusMEM","formatter":18,"formatOptions":{"thresholdsOptions":"icons","thresholdsGrid":[{"operator":"==","thresholdValue":"0","representation":"success","text":"{1}"},{"operator":"==","thresholdValue":"1","representation":"2","text":"{1}"},{"operator":"==","thresholdValue":"2","representation":"critical","text":"{1}"},{"operator":"Default","thresholdValue":null,"representation":"unknown","text":"{1}"}]}},{"columnMatch":"AvgMEM","formatter":0,"numberFormat":{"unit":5,"options":{"style":"decimal"}}},{"columnMatch":"MaxMEM","formatter":0,"numberFormat":{"unit":39,"options":{"style":"decimal","maximumFractionDigits":2}}},{"columnMatch":"StatusDisk","formatter":18,"formatOptions":{"thresholdsOptions":"icons","thresholdsGrid":[{"operator":"==","thresholdValue":"0","representation":"success","text":"{1}"},{"operator":"==","thresholdValue":"1","representation":"2","text":"{1}"},{"operator":"==","thresholdValue":"2","representation":"4","text":"{1}"},{"operator":"Default","thresholdValue":null,"representation":"success","text":"{1}"}]}},{"columnMatch":"AvgDisk","formatter":0,"numberFormat":{"unit":38,"options":{"style":"decimal","maximumFractionDigits":2}}},{"columnMatch":"LastDisk","formatter":0,"numberFormat":{"unit":4,"options":{"style":"decimal","maximumFractionDigits":2}}},{"columnMatch":"Trend","formatter":10,"formatOptions":{"palette":"blue"}},{"columnMatch":"Max","formatter":0,"numberFormat":{"unit":0,"options":{"style":"decimal"}}},{"columnMatch":"Average","formatter":8,"formatOptions":{"palette":"yellowOrangeRed"},"numberFormat":{"unit":0,"options":{"style":"decimal","useGrouping":false}}},{"columnMatch":"Min","formatter":8,"formatOptions":{"palette":"yellowOrangeRed","aggregation":"Min"},"numberFormat":{"unit":0,"options":{"style":"decimal"}}}],"sortBy":[{"itemKey":"$gen_number_AvgCPU_2","sortOrder":2}],"labelSettings":[{"columnId":"StatusCPU","label":"CPU"},{"columnId":"AvgCPU","label":"CPU (avg)"},{"columnId":"MaxCPU","label":"CPU (max)"},{"columnId":"StatusMEM","label":"Memory"},{"columnId":"AvgMEM","label":"Memory (avg)"},{"columnId":"MaxMEM","label":"Memory (max)"},{"columnId":"StatusDisk","label":"Disk"},{"columnId":"AvgDisk","label":"Disk (avg)"},{"columnId":"LastDisk","label":"Disk (last)"}]},"sortBy":[{"itemKey":"$gen_number_AvgCPU_2","sortOrder":2}]}'
                  isOptional: true
                }
                {
                  name: 'ParameterValues'
                  value: {
                    TimeRange: {
                      type: 4
                      value: {
                        durationMs: 86400000
                      }
                      isPending: false
                      isWaiting: false
                      isFailed: false
                      isGlobal: false
                      labelValue: 'Last 24 hours'
                      displayName: 'TimeRange'
                      formattedValue: 'Last 24 hours'
                    }
                    Workspace: {
                      type: 5
                      value: [
                        workspaceId
                      ]
                      isPending: false
                      isWaiting: false
                      isFailed: false
                      isGlobal: false
                      labelValue: workspaceId
                      displayName: 'Workspace'
                      formattedValue: workspaceId
                    }
                    ComputerFilter: {
                      type: 1
                      value: ''
                      isPending: false
                      isWaiting: false
                      isFailed: false
                      isGlobal: false
                      labelValue: '<unset>'
                      displayName: 'ComputerFilter'
                      formattedValue: ''
                    }
                    Counter: {
                      type: 2
                      value: '{"counter":"% Free Space","object":"LogicalDisk"}'
                      isPending: false
                      isWaiting: false
                      isFailed: false
                      isGlobal: false
                      labelValue: '% Free Space'
                      displayName: 'Counter'
                      formattedValue: '{"counter":"% Free Space","object":"LogicalDisk"}'
                    }
                    Order: {
                      type: 2
                      value: 'desc'
                      isPending: false
                      isWaiting: false
                      isFailed: false
                      isGlobal: false
                      labelValue: 'desc'
                      displayName: 'Order'
                      formattedValue: 'desc'
                    }
                  }
                  isOptional: true
                }
                {
                  name: 'Location'
                  value: location
                  isOptional: true
                }
              ]
              type: 'Extension/AppInsightsExtension/PartType/PinnedNotebookQueryPart'
            }
          }
          '1': {
            position: {
              x: 0
              y: 4
              colSpan: 12
              rowSpan: 4
            }
            metadata: {
              inputs: [
                {
                  name: 'ComponentId'
                  value: 'Azure Monitor'
                  isOptional: true
                }
                {
                  name: 'TimeContext'
                  value: null
                  isOptional: true
                }
                {
                  name: 'ResourceIds'
                  value: [
                    'Azure Monitor'
                  ]
                  isOptional: true
                }
                {
                  name: 'ConfigurationId'
                  value: alertsConsoleWorkbook.id
                  isOptional: true
                }
                {
                  name: 'Type'
                  value: 'workbook'
                  isOptional: true
                }
                {
                  name: 'GalleryResourceType'
                  value: 'Azure Monitor'
                  isOptional: true
                }
                {
                  name: 'PinName'
                  value: alertsConsoleWorkbookName
                  isOptional: true
                }
                {
                  name: 'StepSettings'
                  value: '{"version":"KqlItem/1.0","query":"AlertsManagementResources \\r\\n| where type =~ \'microsoft.alertsmanagement/alerts\'\\r\\n| where properties.essentials.startDateTime {timeRange}  \\r\\n| where properties.essentials.actionStatus.isSuppressed == false\\r\\n| extend Severity=tostring(properties.essentials.severity)\\r\\n| extend State=tostring(properties.essentials.alertState)\\r\\n| extend comp = properties.context.context.condition.allOf[0].dimensions\\r\\n| mvexpand comp\\r\\n| where comp.name == \'Computer\' or comp.name == \'TestConfigurationName\' or isnull(comp)\\r\\n| where "*" in ({State}) or State in ({State})\\r\\n| where "*" in ({ResourceTypes}) or properties.essentials.targetResourceType in~ ({ResourceTypes})\\r\\n| where "*" in ({ResourceGroups}) or properties.essentials.targetResourceGroup in~ ({ResourceGroups})\\r\\n| where "*" in ({Resources}) or properties.essentials.targetResource in~ ({Resources})\\r\\n| project AlertId=id, StartTime=todatetime(tostring(properties.essentials.startDateTime)), Name=name, Severity, State=tostring(properties.essentials.alertState), MonitorCondition=tostring(properties.essentials.monitorCondition), SignalType=tostring(properties.essentials.signalType), TargetResource = split(comp.value, \'.\')[0]\\r\\n| order by StartTime desc\\r\\n","size":0,"title":"Azure Monitor alerts","queryType":1,"resourceType":"microsoft.resourcegraph/resources","crossComponentResources":["{Subscription}"],"gridSettings":{"formatters":[{"columnMatch":"AlertId","formatter":5},{"columnMatch":"StartTime","formatter":6},{"columnMatch":"Name","formatter":1,"formatOptions":{"linkTarget":"OpenBlade","linkIsContextBlade":true,"bladeOpenContext":{"bladeName":"AlertDetailsTemplateBlade","extensionName":"Microsoft_Azure_Monitoring","bladeParameters":[{"name":"alertId","source":"column","value":"AlertId"},{"name":"alertName","source":"column","value":"Name"},{"name":"invokedFrom","source":"static","value":"Workbooks"}]}},"tooltipFormat":{"tooltip":"View alert details"}},{"columnMatch":"Severity","formatter":11},{"columnMatch":"State","formatter":1},{"columnMatch":"MonitorCondition","formatter":18,"formatOptions":{"thresholdsOptions":"icons","thresholdsGrid":[{"operator":"==","thresholdValue":"Fired","representation":"Fired","text":"{0}{1}"},{"operator":"==","thresholdValue":"Resolved","representation":"Resolved","text":"{0}{1}"},{"operator":"Default","thresholdValue":null,"representation":"success","text":"{0}{1}"}]}},{"columnMatch":"TargetResource","formatter":13,"formatOptions":{"linkTarget":null,"showIcon":true}},{"columnMatch":"ResourceType","formatter":16,"formatOptions":{"showIcon":true}},{"columnMatch":"Resource Type","formatter":11},{"columnMatch":"essentials","formatter":5}]}}'
                  isOptional: true
                }
                {
                  name: 'ParameterValues'
                  value: {
                    Subscription: {
                      type: 6
                      value: [
                        subscription().id
                      ]
                      isPending: false
                      isWaiting: false
                      isFailed: false
                      isGlobal: false
                      labelValue: subscription().displayName
                      displayName: 'Subscriptions'
                      formattedValue: '${singlequote}${subscription().id}${singlequote}'
                    }
                    ResourceGroups: {
                      type: 2
                      value: [
                        resourceGroup().name
                      ]
                      isPending: false
                      isWaiting: false
                      isFailed: false
                      isGlobal: false
                      labelValue: resourceGroup().name
                      displayName: 'Resource groups'
                      formattedValue: '${singlequote}${resourceGroup().name}${singlequote}'
                    }
                    ResourceTypes: {
                      type: 7
                      value: [
                        '*'
                      ]
                      isPending: false
                      isWaiting: false
                      isFailed: false
                      isGlobal: false
                      labelValue: 'All'
                      displayName: 'Resource types'
                      specialValue: [
                        'value::all'
                      ]
                      formattedValue: '\'*\''
                    }
                    Resources: {
                      type: 5
                      value: [
                        '*'
                      ]
                      isPending: false
                      isWaiting: false
                      isFailed: false
                      isGlobal: false
                      labelValue: 'All'
                      displayName: 'Resources'
                      specialValue: [
                        'value::all'
                      ]
                      formattedValue: '\'*\''
                    }
                    timeRange: {
                      type: 4
                      value: {
                        durationMs: 2592000000
                      }
                      isPending: false
                      isWaiting: false
                      isFailed: false
                      isGlobal: false
                      labelValue: 'Last 30 days'
                      displayName: 'Time Range'
                      formattedValue: 'Last 30 days'
                    }
                    State: {
                      type: 2
                      value: [
                        '*'
                      ]
                      isPending: false
                      isWaiting: false
                      isFailed: false
                      isGlobal: false
                      labelValue: 'All'
                      displayName: 'State'
                      specialValue: [
                        'value::all'
                      ]
                      formattedValue: '\'*\''
                    }
                  }
                  isOptional: true
                }
                {
                  name: 'Location'
                  value: location
                  isOptional: true
                }
              ]
              type: 'Extension/AppInsightsExtension/PartType/PinnedNotebookQueryPart'
            }
          }
          '2': {
            position: {
              x: 12
              y: 4
              colSpan: 5
              rowSpan: 4
            }
            metadata: {
              inputs: [
                {
                  name: 'ComponentId'
                  value: 'Azure Monitor'
                  isOptional: true
                }
                {
                  name: 'TimeContext'
                  value: null
                  isOptional: true
                }
                {
                  name: 'ResourceIds'
                  value: [
                    'Azure Monitor'
                  ]
                  isOptional: true
                }
                {
                  name: 'ConfigurationId'
                  value: windowsEventsWorkbook.id
                  isOptional: true
                }
                {
                  name: 'Type'
                  value: 'workbook'
                  isOptional: true
                }
                {
                  name: 'GalleryResourceType'
                  value: 'Azure Monitor'
                  isOptional: true
                }
                {
                  name: 'PinName'
                  value: windowsEventsWorkbookName
                  isOptional: true
                }
                {
                  name: 'StepSettings'
                  value: '{"version":"KqlItem/1.0","query":"Event\\r\\n|  where EventLog in ("System","Application","Operations Manager")\\r\\n| project EventLog,EventLevelName\\r\\n| evaluate pivot(EventLevelName)","size":1,"showAnalytics":true,"title":"Windows Events - Summary","timeContext":{"durationMs":0},"timeContextFromParameter":"TimeRange","exportFieldName":"EventLog","exportParameterName":"EventLog","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspace}"],"gridSettings":{"formatters":[{"columnMatch":"Information","formatter":18,"formatOptions":{"showIcon":true,"thresholdsOptions":"icons","thresholdsGrid":[{"operator":"Default","thresholdValue":null,"representation":"info","text":"{0}{1}"}],"aggregation":"Unique"},"numberFormat":{"unit":0,"options":{"style":"decimal"}}},{"columnMatch":"Warning","formatter":18,"formatOptions":{"showIcon":true,"thresholdsOptions":"icons","thresholdsGrid":[{"operator":"Default","thresholdValue":null,"representation":"warning","text":"{0}{1}"}],"aggregation":"Unique"},"numberFormat":{"unit":0,"options":{"style":"decimal"}}},{"columnMatch":"Error","formatter":18,"formatOptions":{"showIcon":true,"thresholdsOptions":"icons","thresholdsGrid":[{"operator":"Default","thresholdValue":null,"representation":"3","text":"{0}{1}"}],"aggregation":"Unique"},"numberFormat":{"unit":0,"options":{"style":"decimal"}}}]}}'
                  isOptional: true
                }
                {
                  name: 'ParameterValues'
                  value: {
                    TimeRange: {
                      type: 4
                      value: {
                        durationMs: 604800000
                      }
                      isPending: false
                      isWaiting: false
                      isFailed: false
                      isGlobal: false
                      labelValue: 'Last 7 days'
                      displayName: 'TimeRange'
                      formattedValue: 'Last 7 days'
                    }
                    Workspace: {
                      type: 5
                      value: [
                        workspaceId
                      ]
                      isPending: false
                      isWaiting: false
                      isFailed: false
                      isGlobal: false
                      labelValue: workspaceName
                      displayName: 'Workspace'
                      formattedValue: workspaceId
                    }
                  }
                  isOptional: true
                }
                {
                  name: 'Location'
                  value: location
                  isOptional: true
                }
              ]
              type: 'Extension/AppInsightsExtension/PartType/PinnedNotebookQueryPart'
            }
          }
        }
      }
    }
    metadata: {
      model: {
        timeRange: {
          value: {
            relative: {
              duration: 24
              timeUnit: 1
            }
          }
          type: 'MsPortalFx.Composition.Configuration.ValueTypes.TimeRange'
        }
        filterLocale: {
          value: 'en-us'
        }
        filters: {
          value: {
            MsPortalFx_TimeRange: {
              model: {
                format: 'utc'
                granularity: 'auto'
                relative: '24h'
              }
              displayCache: {
                name: 'UTC Time'
                value: 'Past 24 hours'
              }
              filteredPartIds: [
                'StartboardPart-PinnedNotebookQueryPart-952cffdb-b288-4824-9872-6327c6028516'
                'StartboardPart-PinnedNotebookQueryPart-952cffdb-b288-4824-9872-6327c6028518'
                'StartboardPart-PinnedNotebookQueryPart-952cffdb-b288-4824-9872-6327c602851a'
                'StartboardPart-PinnedNotebookQueryPart-952cffdb-b288-4824-9872-6327c602851c'
              ]
            }
          }
        }
      }
    }
  }
}
