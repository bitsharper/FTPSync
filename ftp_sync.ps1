#$uri = "ftp://10.10.0.102/foobar2000 Music Folder/"
$uri = New-Object -TypeName System.Uri -ArgumentList "ftp://10.10.0.106/foobar2000 Music Folder/"
#$uri = New-Object -TypeName System.Uri -ArgumentList "ftp://172.31.145.224/"
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
    $ftpCreds.UserName = 'test'
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
        [System.Uri]$Uri,
        [Parameter(Mandatory=$false)]
        [bool]$Recurse
    )
    
    $ftpContent = [pscustomobject]@{
        DirectoryName = ""
        DirectoryItems = @()
    }
    $ftpDirectory = @()
    
    $ftpMethod = "ListDirectoryDetails"
    $ftpRequest = Get-FtpRequest -Method $ftpMethod -Uri $Uri.OriginalString
    $ftpResponse = $ftpRequest.GetResponse()
    $ftpResponseStream = $ftpResponse.GetResponseStream()
    
    $fileList = Get-DataFromStream -Stream $ftpResponseStream
    $ftpContent.DirectoryName = $Uri.LocalPath
    foreach ($str in $fileList) {
        [string]$dirItem = ConvertFrom-UrlString -string $str
        
        $ftpContent.DirectoryItems += [PSCustomObject]@{
            isDirectory = if ($dirItem.Substring(0,1).ToLower() -eq 'd') {$true} else {$false}
            FileSize = ($dirItem.Split(" ", 9, [System.StringSplitOptions]::RemoveEmptyEntries))[4]
            FileName = ($dirItem.Split(" ", 9, [System.StringSplitOptions]::RemoveEmptyEntries))[8]
        }
    }
    $ftpDirectory += $ftpContent

    if ($Recurse) {
        $ftpDirectory.DirectoryItems.Where({$_.isDirectory}).ForEach({
            $ftpDirectory += Get-FtpDirectoryContent -Uri $($Uri.OriginalString + $_.FileName + "/") -Recurse $true
        })
    }
    
    $ftpResponseStream.Close()
    $ftpResponse.Close()
    return $ftpDirectory
    #TODO to check if the string is URL encoded. Can compare decoded and original if eq then decode is required
}
function Compare-FtpFolderContent {
    [CmdletBinding()]
    Param(
            [Parameter(Mandatory=$true)]
            [PSCustomObject]$ReferenceFolder,
            [Parameter(Mandatory=$true)]
            [PSCustomObject]$DifferenceFolder
        )

    $deltaObject = @()
    foreach ($refItem in $ReferenceFolder.DirectoryItems.Where({!$_.isDirectory})) {
        $index = 0
        foreach ($diffItem in $DifferenceFolder.DirectoryItems) {
            
            if (($refItem.FileName -eq $diffItem.FileName) -and ($refItem.FileSize -eq $diffItem.FileSize)) { $index++ }
        }
        if ($index -eq 0) {
            $deltaObject += $refItem
        }
    }
    return $deltaObject
}

function Compare-FtpDirectories {
    [CmdletBinding()]
    Param(
            [Parameter(Mandatory=$true)]
            [PSCustomObject]$Reference,
            [Parameter(Mandatory=$true)]
            [PSCustomObject]$Difference
        )
    foreach ($refDir in )    
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
function Invoke-FtpSync {
    [CmdletBinding()]
    Param(
            [Parameter(Mandatory=$true)]
            [string]$SourceUri,
            [Parameter(Mandatory=$true)]
            [string]$DestinationUri
        )
    $sourceContent = Get-FtpDirectoryContent -Uri $uri -Recurse $true
    $destinationContent = Get-FtpDirectoryContent -Uri $uri -Recurse $true

    Compare-FtpFolderContent -ReferenceFolder $sourceContent[0] -DifferenceFolder $destinationContent[0]
}
    

