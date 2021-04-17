$uri = "ftp://10.10.0.106/foobar2000 Music Folder"
function Get-FtpResponse {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$method
    )

    $ftpWebRequest = [System.Net.FtpWebRequest]::Create($uri)
    $ftpWebRequest.Method = [System.Net.WebRequestMethods+Ftp]::$method
    $ftpWebRequest.UseBinary = $true
    $ftpCreds = New-Object -TypeName System.Net.NetworkCredential
    $ftpCreds.UserName = "anonymous"
    $ftpWebRequest.Credentials = $ftpCreds
    return $ftpWebRequest.GetResponse()
}
function Get-DataFromStream {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [System.IO.Stream]$stream
    )
    $streamReader = New-Object -TypeName System.IO.StreamReader -ArgumentList $stream
    $data = @()

    DO {
        $data += $streamReader.ReadLine()
    } while ($streamReader.EndOfStream -eq $false)

    return $data
}
function Get-FtpContent {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$uri
    )
    $ftpContent = @()

    $ftpMethod = "ListDirectoryDetails"
    $ftpResponse = Get-FtpResponse -method $ftpMethod
    $responseStream = $ftpResponse.GetResponseStream()
    
    $fileList = Get-DataFromStream -stream $responseStream
    foreach ($str in $fileList) {
        [string]$dirItem = Get-DecodedUrlString -string $str
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
        [string]$Path,
        [Parameter(Mandatory=$true)]
        [string]$uri
    )
    $ftpMethod = "ListDirectoryDetails"
}
function Get-DecodedUrlString {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$string
    )
    return [System.Web.HttpUtility]::UrlDecode($string)
}



$fileList = Get-FtpContent -uri $uri
