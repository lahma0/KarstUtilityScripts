- Open the database page on the Azure Admin Center website
- Navigate to `Query editor`, select `Microsoft Entra authentication`, and make sure that Entra authentication is enabled for your account. If it is not, there should be a link you can click to enable it
- If you do not already have `sqlpackage` installed, install it with `winget install --id Microsoft.SqlPackage -e`
- Open a PowerShell terminal and use the following, substituting the necessary values inside brackets:
```
$Output = "C:\Backup\[DB_NAME]-$(Get-Date -Format yyyyMMdd-HHmmss).bacpac"
$ConnectionString = "Server=tcp:[SERVER_URL],1433;Initial Catalog=[DB_NAME];User ID=[ADMIN_EMAIL];MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Authentication='Active Directory Interactive';"
sqlpackage /Action:Export "/SourceConnectionString:$ConnectionString" /TargetFile:$Output
```
