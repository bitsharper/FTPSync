$uri = "ftp://10.10.0.106/foobar2000 Music Folder/"
function Get-FtpResponse {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Method,
        [Parameter(Mandatory=$true)]
        [string]$Uri,
        [Parameter(Mandatory=$false)]
        [System.IO.FileStream]$FileStream
    )
    #$Method = "ListDirectoryDetails"
    $ftpWebRequest = [System.Net.FtpWebRequest]::Create($Uri)
    [System.IO.FileStream]
    $ftpWebRequest.Method = [System.Net.WebRequestMethods+Ftp]::$Method
    $ftpWebRequest.UseBinary = $true
    $ftpCreds = New-Object -TypeName System.Net.NetworkCredential
    $ftpCreds.UserName = "test"
    $ftpCreds.Password = 'test'
    $ftpWebRequest.Credentials = $ftpCreds
    return $ftpWebRequest.GetResponse()
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
function Get-FtpDirectoryContent {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Uri
    )
    $ftpContent = @()
    $ftpMethod = "ListDirectoryDetails"
    $ftpResponse = Get-FtpResponse -method $ftpMethod -uri $uri
    $responseStream = $ftpResponse.GetResponseStream()
    
    $fileList = Get-DataFromStream -stream $responseStream
    foreach ($str in $fileList) {
        [string]$dirItem = ConvertFrom-UrlString -string $str
        $ftpContent += [PSCustomObject]@{
            isDirectory = $dirItem.Substring(0,1).ToLower()
            FileSize = ($dirItem.Split(" ", 9, [System.StringSplitOptions]::RemoveEmptyEntries))[4]
            FileName = ($dirItem.Split(" ", 9, [System.StringSplitOptions]::RemoveEmptyEntries))[8]
        }
    }
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
    
    write-host $ftpFilePath
    $ftpMethod = "DownloadFile"
    $fileStream = New-Object System.IO.FileStream $LocalPath, 'Append', 'Write', 'Read'
    $ftpResponse = Get-FtpResponse -method $ftpMethod -uri $ftpFilePath
    $ftpResponseStream = $ftpResponse.GetResponseStream()
    
    $ftpResponseStream.CopyTo($fileStream)
    $fileStream.Dispose()
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
    $LocalPath = "C:\tmp\01 - Давай Микрофон.flac"
    $fileStream = New-Object System.IO.FileStream $LocalPath, 'Append', 'Write', 'Read'
    if (Test-Path -LiteralPath $LocalPath) {
        $fileName = Split-Path -Leaf $LocalPath 
    }
   
    if ($Uri[$Uri.Length-1] -eq '/') {
        $ftpFilePath = $Uri + $FileName
    }
    else {
        $ftpFilePath =  $Uri/$fileName
    }
    
    write-host "File will be uploaded to: " $ftpFilePath
        
    $ftpResponse = Get-FtpResponse -method $ftpMethod -uri $ftpFilePath -FileStream $fileStream
    $ftpResponseStream = $ftpResponse.GetResponseStream()
    
    $ftpResponseStream.CopyTo($fileStream)
    $fileStream.Dispose()
    $ftpResponseStream.Close()
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

$filesList = Get-FtpDirectoryContent -uri $uri

foreach ($file in $filesList) {
    if ($file.isDirectory.ToLower() -eq "d") {

        $localDir = New-Item -Path c:\tmp\$($file.FileName) -ItemType Directory 
        #$remoteDir = $uri+$(file.FileName)+"/"
        #$dirContent = Get-FtpDirectoryContent -Uri $remoteDir
        
    } else {
        Copy-FileFromFtp -Uri $uri -FileName $file.FileName -LocalPath "c:\tmp"
    }
}
