using 'main.bicep'

param flavor = 'DevOps'

param sshRSAPublicKey = 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDW6ZkCrWcuvDn7y9XbEulOSwx44wus3KLG8vOtFB+9m9YfTt/9RLJKD7ZiidvFQdD/ahKzLrdjJuUlcjsS6uqxvRBM+VUNY4O1zV+c7Zl6rHC7C/Ov9hB0wFW71ftUvKMwqIMFASh7etT0aW8FsSYnxRHf9hsYG5znwZTWsoxJO30gQOxwiLw+M1DCYmbOU3iOJuCyeG9VmzAfn/szXHDBogtkSx/ymiSCoJ3UbYmMqqoWNhfjfFTaLxZk7kkEDW6iFsIflsZOwZuB+tTOiOHE0KbgFyEtpzP3d+dfcSqgay6nb6RuzhZpthW42/qEmeqa16AkYLkYcgWl8DSqW/dRHq84MhVxggO7Shy+evuJpOTBp2SqplyYLRg3ScEe/BgyijN3Mo/baAYtGTbi3UAQKR0o/Ja9tm5DLOIuJM+fvKKCOU2yAQFeuc5xTl1gvYctevHjSEKUeE2tDkwHORPe7dZNVrSTAWNl3nLaIiauWzDKi1eMV3piao9om8Vg1uyYK3jI9AzH3uEH3cB9DqlNEhtHjz4ClFOkjAsTtf4xlkMkOfeGTRFgMpMwBsS46cKumy7PoMZnVowvUzDCsojqLdPpUHYM6vzGMvaovqg800mufxfEpiL/GIxU+KNgpbl9QxnFeoE5ZeHXWHdfczQSE0xi29x+6SLZ2F4YPQQKEw== mozaid@microsoft.com'

param tenantId = '16b3c013-d300-468d-ac64-7eda0820b6d3'

param windowsAdminUsername = 'arcdemo'

param windowsAdminPassword = 'ArcPassword123!!'

param logAnalyticsWorkspaceName = 'arcbox-la'

param deployBastion = false

param customLocationRPOID = 'af89a3ae-8ffe-4ce7-89fb-a615f4083dc3'

param resourceTags = {
  Solution: 'jumpstart_arcbox'
  Environment: 'sandbox'
  CostCenter: 'it'
}

param vmAutologon = false

param rdpPort = '13389'

param githubAccount = 'zaidmohd'

param githubBranch = 'arcbox_3.0'

param githubUser = 'zaidmohd'
