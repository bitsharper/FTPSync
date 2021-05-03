$uri = "ftp://172.26.7.184/"
function Get-FtpRequest {
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
    $ftpWebRequest.Method = [System.Net.WebRequestMethods+Ftp]::$Method
    $ftpWebRequest.UseBinary = $true
    $ftpCreds = New-Object -TypeName System.Net.NetworkCredential
    $ftpCreds.UserName = "test"
    $ftpCreds.Password = 'test'
    $ftpWebRequest.Credentials = $ftpCreds
    return $ftpWebRequest
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
function Copy-FileToFtp {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Uri,
        [Parameter(Mandatory=$true)]
        [string]$LocalPath
    )

    $ftpMethod = "UploadFile"
    [string]$LocalPath = "C:\tmp\14 - Кирпичи Тяжелы.flac"
    
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
        
    $ftpRequest = Get-FtpRequest -method $ftpMethod -uri $ftpFilePath -FileStream $fileStream
    $ftpRequestStream = $ftpRequest.GetRequestStream()
    Write-DataToStream -Stream $ftpRequestStream -LocalPath $LocalPath
}
