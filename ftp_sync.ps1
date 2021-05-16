#$uri = "ftp://10.10.0.106/foobar2000 Music Folder/"
$uri = "ftp://172.31.145.224/"
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
    $streamReader.Close()
    return $data
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

    $ftpDirectories = @()
    $ftpContent = @()
    $ftpMethod = "ListDirectoryDetails"
    $ftpRequest = Get-FtpRequest -Method $ftpMethod -Uri $uri
    $ftpResponse = $ftpRequest.GetResponse()
    $ftpResponseStream = $ftpResponse.GetResponseStream()
    
    $fileList = Get-DataFromStream -Stream $ftpResponseStream

    foreach ($str in $fileList) {
        [string]$dirItem = ConvertFrom-UrlString -string $str
        $ftpContent += [PSCustomObject]@{
            #Directory = $Uri.split("/", 3, [system.stringSplitOptions]::RemoveEmptyEntries)[-1]
            Directory = $Uri.Substring($Uri.LastIndexOf("/"))
            isDirectory = if ($dirItem.Substring(0,1).ToLower() -eq 'd') {$true} else {$false}
            FileSize = ($dirItem.Split(" ", 9, [System.StringSplitOptions]::RemoveEmptyEntries))[4]
            FileName = ($dirItem.Split(" ", 9, [System.StringSplitOptions]::RemoveEmptyEntries))[8]
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