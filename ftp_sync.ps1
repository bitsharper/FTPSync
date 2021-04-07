$uri = "ftp://172.20.10.1/foobar2000 Music Folder"
$localFileName = "%d0%90%d0%ba%d0%b2%d0%b0%d1%80%d0%b8%d1%83%d0%bc-%d0%a1%d0%b5%d1%81%d1%82%d1%80%d0%b0 %d0%a5%d0%b0%d0%be%d1%81 [2002, %d0%a1%d0%be%d1%8e%d0%b7, SZCD 1429-02]-%d0%91%d1%80%d0%b0%d1%82 %d0%9d%d0%b8%d0%ba%d0%be%d1%82%d0%b8%d0%bd.mp3"
$fileName = "ftp://10.10.0.103/foobar2000 Music Folder/%d0%90%d0%ba%d0%b2%d0%b0%d1%80%d0%b8%d1%83%d0%bc-%d0%a1%d0%b5%d1%81%d1%82%d1%80%d0%b0 %d0%a5%d0%b0%d0%be%d1%81 [2002, %d0%a1%d0%be%d1%8e%d0%b7, SZCD 1429-02]-%d0%91%d1%80%d0%b0%d1%82 %d0%9d%d0%b8%d0%ba%d0%be%d1%82%d0%b8%d0%bd.mp3"
function Get-FtpContent {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$uri
    )

    $ftpWebRequest = [System.Net.FtpWebRequest]::Create($uri)
    $ftpWebRequest.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectoryDetails
    
    $ftpWebRequest.UseBinary = $true
    $ftpCreds = New-Object -TypeName System.Net.NetworkCredential
    $ftpCreds.UserName = "anonymous"
    
    $ftpWebRequest.Credentials = $ftpCreds

    $ftpResponse = $ftpWebRequest.GetResponse()

    $responseStream = $ftpResponse.GetResponseStream()
    
    #$encoding = [System.Text.Encoding]::GetEncoding(URL)
    $streamReader = New-Object -TypeName System.IO.StreamReader -ArgumentList $responseStream, $encoding, $true
    
    $detailedFilesList = $streamReader.ReadToEnd()
    [System.Web.HttpUtility]::UrlDecode($localFileName)
    #TODO to check if the string is URL encoded we can decode and compare with the original
}