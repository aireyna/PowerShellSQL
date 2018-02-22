<#
Requires Use of following Functions:
    Invoke-Sqlcmd2.ps1:     https://github.com/RamblingCookieMonster/PowerShell
	Out-DataTable.ps1:      https://github.com/RamblingCookieMonster/PowerShell

v1.0	- Arleigh Reyna
#>


# Folder Information - File Path must be accesseable to SQL Server.  Easiest to place data in folder on local server drive and run from powershell from SQL Server.  It can be network path.
$FolderPath = ""

#Server Information
$ServerName = ""
$DatabaseName = ""
$Schema = "dbo"
$TableName = "TestData"
$UserName = "" #Not Needed if using Windows Authentication - set equal to empty string ""
$Password ="" #Not Needed if using Windows Authentication - set equal to empty string ""

#Create Powershell Credentials using SQL Account if UserName and Password are provided. Otherwise defaults to Windows Authentication.
if (-not ([string]::IsNullOrEmpty($UserName)) -and -not ([string]::IsNullOrEmpty($Password)))
    {
        $SecurePassword = convertto-securestring $Password -asplaintext -force
        $Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $SecurePassword
    }

#clear-variable -name Credentials

#Creates Blob Table in SQL
$CreateTableSQLScript = "CREATE TABLE $Schema.$TableName (Name VARCHAR(255),FileExtension VARCHAR(255),OriginalFilePath VARCHAR(512),FileSize BIGINT, LastModified DATEIMT, FileBlob IMAGE);"
Invoke-Sqlcmd2 -ServerInstance $ServerName -Database $DatabaseName -Query $CreateTableSQLScript -Credential $Credentials

#Indexes all files in folder
$FileList = get-childitem $FolderPath | Select-Object FullName,Name,Extension,Length,LastWriteTime | Out-DataTable

#Bulk Uploads one file at a time to table
foreach($f in $FileList)
{
$Name = $f.Name
$FileExtension = $f.Extension
$OriginalFilePath = $f.FullName
$FileSize = $f.Length
$LastModified = $f.LastWriteTime

$Query = "INSERT INTO $DatabaseName.$Schema.$TableName (Name,FileExtension,OriginalFilePath,FileSize,LastModified,FileBlob)
SELECT
	 '$Name'
	,'$FileExtension'
	,'$OriginalFilePath'
	,'$FileSize'
	,'$LastModified'
	,bulkcolumn
FROM
	OPENROWSET(BULK '$OriginalFilePath', SINGLE_BLOB) AS B"
 
sqlcmd -Q $Query -S $ServerName
}

#clear-variable -name Data