$uri = "ftp://10.10.0.106/foobar2000 Music Folder/"
function Get-FtpResponse {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$method,
        [Parameter(Mandatory=$true)]
        [string]$uri
    )

    $ftpWebRequest = [System.Net.FtpWebRequest]::Create($uri)
    $ftpWebRequest.Method = [System.Net.WebRequestMethods+Ftp]::$method
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
function Get-FtpContent {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$uri
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
function Get-FtpFile {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Uri,
        [Parameter(Mandatory=$true)]
        [string]$FileName,
        [Parameter(Mandatory=$true)]
        [string]$Destination
    )
    
    if ($Uri[$Uri.Length-1] -eq '/') {
        $ftpFilePath = $Uri + $($FileName)
    }
    else {
        $ftpFilePath =  $Uri + "/$($Filename)"
    }
    
    write-host $ftpFilePath
    $ftpMethod = "DownloadFile"
    $fileStream = New-Object System.IO.FileStream $Destination\$FileName, 'Append', 'Write', 'Read'
    $ftpResponse = Get-FtpResponse -method $ftpMethod -uri $ftpFilePath
    $ftpResponseStream = $ftpResponse.GetResponseStream()
    
    $ftpResponseStream.CopyTo($fileStream)
    $fileStream.Dispose()
    #$responseStream.Dispose()
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
    return [System.Net.WebUtility]::UrlDecode($String)
}
function ConvertTo-UrlString {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$String
    )
    return [System.Web.HttpUtility]::UrlEncode($string)
}

$filesList = Get-FtpContent -uri $uri

foreach ($file in $filesList) {
    Get-FtpFile -Uri $uri -FileName $file.FileName -Destination "c:\tmp"
}

