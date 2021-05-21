$uri = "ftp://10.10.0.106/foobar2000 Music Folder/"
#$uri = "ftp://172.26.7.184/"
function Get-FtpRequest {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Method,
        [Parameter(Mandatory=$true)]
        [string]$Uri
    )
    #$Method = "ListDirectoryDetails"
    $ftpWebRequest = [System.Net.FtpWebRequest]::Create($Uri)
    $ftpWebRequest.Method = [System.Net.WebRequestMethods+Ftp]::$Method
    $ftpWebRequest.UseBinary = $true
    $ftpCreds = New-Object -TypeName System.Net.NetworkCredential
    $ftpCreds.UserName = "test"
    $ftpCreds.Password = 'test'
    $ftpWebRequest.Credentials = $ftpCreds
    return $ftpWebRequest
}
function Get-DataFromStream {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [System.IO.Stream]$Stream
    )
    $streamReader = New-Object -TypeName System.IO.StreamReader -ArgumentList $Stream
    $data = @()

    DO {
        $data += $streamReader.ReadLine()
    } while ($streamReader.EndOfStream -eq $false)

    return $data
    $streamReader.Close()
}
function Write-DataToStream {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [System.IO.Stream]$Stream,
        [Parameter(Mandatory=$true)]
        [String]$LocalPath
    )
    $localPath = 
    $fileStream = New-Object System.IO.FileStream $LocalPath, 'Open', 'Read', 'Read'
    $fileStream.CopyTo($Stream)
    $fileStream.close()
    $Stream.Close()
}
function Get-FtpDirectoryContent {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Uri,
        [Parameter(Mandatory=$false)]
        [string]$Recurse
        
    )
    $ftpDirectories = [PSCustomObject]@{
        DirectoryName = '' 
        Items = [PSCustomObject]@{
            "isDirectory" = ''  

        }
    }
    
    $ftpContent = @()
    $ftpMethod = "ListDirectoryDetails"
    $ftpRequest = Get-FtpRequest -Method $ftpMethod -Uri $uri
    $ftpResponse = $ftpRequest.GetResponse()
    $ftpResponseStream = $ftpResponse.GetResponseStream()
    
    $fileList = Get-DataFromStream -stream $ftpResponseStream
    foreach ($str in $fileList) {
        [string]$dirItem = ConvertFrom-UrlString -string $str
        $ftpDirectories.DirectoryName = '/'


        $ftpContent += [PSCustomObject]@{
            "isDirectory" = if ($dirItem.Substring(0,1).ToLower() -eq 'd') {$true} else {$false}
            "FileSize" = ($dirItem.Split(" ", 9, [System.StringSplitOptions]::RemoveEmptyEntries))[4]
            "FileName" = ($dirItem.Split(" ", 9, [System.StringSplitOptions]::RemoveEmptyEntries))[8]
        }
    }
    $ftpResponseStream.Close()
    $ftpResponse.Close()
    return $ftpContent
    #TODO to check if the string is URL encoded we can decode and compare with the original
}
function Copy-FileFromFtp {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Uri,
        [Parameter(Mandatory=$true)]
        [string]$FileName,
        [Parameter(Mandatory=$true)]
        [string]$LocalPath
    )
    
    if ($Uri[$Uri.Length-1] -eq '/') {
        $ftpFilePath = $Uri + $($FileName)
    }
    else {
        $ftpFilePath =  $Uri + "/$($Filename)"
    }
    
    Write-Host Starting copying file $ftpFilePath to $Local
    $ftpMethod = "DownloadFile"
    $fileStream = New-Object System.IO.FileStream $LocalPath, 'Create', 'Write', 'Read'
    $ftpRequest = Get-FtpRequest -method $ftpMethod -uri $ftpFilePath
    $ftpResponse = $ftpRequest.GetResponse()
    $ftpResponseStream = $ftpResponse.GetResponseStream()
    
    $ftpResponseStream.CopyTo($fileStream)
    $fileStream.Close()
    # TODO check $responseStream.Dispose()
    $ftpResponseStream.Close()
}
function Copy-FileToFtp {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Uri,
        [Parameter(Mandatory=$true)]
        [string]$LocalPath
    )

    $ftpMethod = "UploadFile"
    
    if (Test-Path -LiteralPath $LocalPath) {
        [string]$fileName = Split-Path -Leaf $LocalPath 
    }
   
    if ($Uri[$Uri.Length-1] -eq '/') {
        [string]$ftpFilePath = $Uri + $FileName
    }
    else {
        $ftpFilePath =  $Uri + "/" + $fileName
    }
    
    write-host "File will be uploaded to: " $ftpFilePath
        
    $ftpRequest = Get-FtpRequest -method $ftpMethod -uri $ftpFilePath
    $ftpRequestStream = $ftpRequest.GetRequestStream()
    Write-DataToStream -Stream $ftpRequestStream -LocalPath $LocalPath
}
function ConvertFrom-UrlString {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$String
    )
    
    if ($String.Contains("+")) {
        $String = $String.Replace("+", "%2b")
        return [System.Net.WebUtility]::UrlDecode($String)
    }
    else {
        return [System.Net.WebUtility]::UrlDecode($String)
    }
}
function ConvertTo-UrlString {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$String
    )
    return [System.Web.HttpUtility]::UrlEncode($string)
}

$rootContent = Get-FtpDirectoryContent -uri $uri

function Get-ChildContent () {


}

copy-fileFromFtp -Uri $uri -FileName "test1.txt" -LocalPath "c:\tmp\test1.txt"
Copy-FileToFtp -Uri $uri -LocalPath "C:\tmp\01 - Давай Микрофон.flac"

foreach ($file in $filesList) {
    if ($file.isDirectory.ToLower() -eq "d") {

        $localDir = New-Item -Path c:\tmp\$($file.FileName) -ItemType Directory 
        #$remoteDir = $uri+$(file.FileName)+"/"
        #$dirContent = Get-FtpDirectoryContent -Uri $remoteDir
        
    } else {
        Copy-FileFromFtp -Uri $uri -FileName $file.FileName -LocalPath "c:\tmp"
    }
}
