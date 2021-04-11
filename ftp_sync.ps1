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
}
function Get-FtpContent {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$uri
    )
    $ftpMethod = "ListDirectoryDetails"
    $ftpResponse = Get-FtpResponse -method $ftpMethod
    $responseStream = $ftpResponse.GetResponseStream()
    $streamReader = New-Object -TypeName System.IO.StreamReader -ArgumentList $responseStream
    $ftpContent = @()

    DO {
        [string]$dirItem = Get-DecodedUrlString -string ($streamReader.ReadLine())
        $ftpContent += [PSCustomObject]@{
            isDirectory = $dirItem.Substring(0,1).ToLower()
            FileName = ($dirItem.Split(" ", 9, [System.StringSplitOptions]::RemoveEmptyEntries))[8]
        }
    } while ($streamReader.EndOfStream -eq $false)

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
    $ftpWebRequest = [System.Net.FtpWebRequest]::Create($uri)
    $ftpWebRequest.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectoryDetails
    $ftpWebRequest.UseBinary = $true
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
