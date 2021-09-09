$uri0 = "ftp://10.10.0.106/foobar2000 Music Folder/"
$uri1 = New-Object -TypeName System.Uri -ArgumentList "ftp://10.10.0.3/mp3/"
#$uri = New-Object -TypeName System.Uri -ArgumentList "ftp://172.31.145.224/"

function Get-FtpRequest {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Method,
        [Parameter(Mandatory=$true)]
        [string]$Url
    )

    $ftpWebRequest = [System.Net.FtpWebRequest]::Create($Url)
    $ftpWebRequest.Method = [System.Net.WebRequestMethods+Ftp]::$Method
    $ftpWebRequest.UseBinary = $true
    $ftpCreds = New-Object -TypeName System.Net.NetworkCredential
    $ftpCreds.UserName = 'gentleman'
    $ftpCreds.Password = 'test_pass'
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
function Write-DataFromFileToStream {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [System.IO.Stream]$Stream,
        [Parameter(Mandatory=$true)]
        [String]$LocalPath
    )

    $fileStream = New-Object System.IO.FileStream $LocalPath, 'Open', 'Read', 'Read'
    $fileStream.CopyTo($Stream)
    $fileStream.Close()
    $Stream.Close()
}
function Write-StreamToStream {
    [Parameter(Mandatory=$true)]
    [System.IO.Stream]$FromStream,
    [Parameter(Mandatory=$true)]
    [System.IO.Stream]$ToStream

    $FromStream.CopyTo($ToStream)
    $FromStream.Close()
    $ToStream.Close()
}
function Get-FtpDataStream {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Url,
        [Parameter(Mandatory=$true)]
        [ValidateSet("UploadFile", "DownloadFile", "ListDirectoryDetails")]
        [string]$FtpMethod
    )    

    $ftpStream = $null
    $ftpRequest = Get-FtpRequest -method $ftpMethod -Url $Url
    
    Switch ($ftpMethod){
        "UploadFile" {
            $ftpRequest = Get-FtpRequest -method $ftpMethod -Url $Url
            $ftpStream = $ftpRequest.GetRequestStream()
        }
        {"DownloadFile" -or "ListDirectoryDetails"} {
            $ftpRequest = Get-FtpRequest -method $ftpMethod -Url $Url
            $ftpResponse = $ftpRequest.GetResponse()
            $ftpStream = $ftpResponse.GetResponseStream()
        }
    }
    return $ftpStream
}
function Get-FtpDirectoryContent {

    #TODO decouple returning FTP response operations(stream and response close) and preparing content object.
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
    $ftpResponseStream = Get-FtpDataStream -Url $Uri.OriginalString -FtpMethod $ftpMethod
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
function Compare-FtpDirectoryContent {
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
            [PSCustomObject]$ReferenceObject,
            [Parameter(Mandatory=$true)]
            [PSCustomObject]$DifferenceObject
        )
    $deltaObject = @()

    foreach ($refDir in $ReferenceObject) {
        $dirIndex = 0 
        foreach ($diffDir in $DifferenceObject) {
            if ($refDir.DirectoryName -eq $diffDir.DirectoryName ) {
                $dirIndex++
                $dirContentDelta = Compare-FtpDirectoryContent -ReferenceFolder $refDir -DifferenceFolder $diffDir
                if ($dirContentDelta.length -gt 0) {
                    $deltaObject += [PSCustomObject]@{
                        DirectoryName = $refDir.DirectoryName
                        DirectoryItems = $dirContentDelta
                    }
                }
            }
        }
        if ($dirIndex -eq 0) {
            $deltaObject += $refDir
        }
    }

    return $deltaObject    
}
function Copy-FileFromFtp {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Url,
        [Parameter(Mandatory=$true)]
        [string]$LocalPath
    )

    $fileName = $Url.Substring($Url.lastIndexOf("/")+1)
    $fileFullPath = "$($LocalPath + $fileName)"
     
    if (!(Test-Path -Path $LocalPath)) {
        Write-Host "Creating directory: $LocalPath" -ForegroundColor DarkYellow
        
        try {
            New-Item -Path $LocalPath -ItemType Directory -Force | Out-Null
        }
        catch {
            Write-Host $_ -ForegroundColor Red
        }
        
    }

    Write-Host "Copying file `"$fileName`" to $LocalPath" 
    $ftpMethod = "DownloadFile"
    $fileStream = New-Object System.IO.FileStream $fileFullPath, 'Create', 'Write', 'Read'
    $ftpDataStream = Get-FtpDataStream -Url $Url -FtpMethod $ftpMethod
    $ftpDataStream.CopyTo($fileStream)
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
    
    Write-Host "File will be uploaded to: " $ftpFilePath
    $ftpRequestStream =  Get-FtpDataStream -Url $ftpFilePath-FtpMethod $ftpMethod
    Write-DataFromFileToStream -Stream $ftpRequestStream -LocalPath $LocalPath
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
function Get-ContentDelta {
    [CmdletBinding()]
    Param(
            [Parameter(Mandatory=$true)]
            [string]$SourceUri,
            [Parameter(Mandatory=$true)]
            [string]$DestinationUri
        )
    #TODO add check for source and destination
    $sourceContent = Get-FtpDirectoryContent -Uri $SourceUri -Recurse $true
    $destinationContent = Get-FtpDirectoryContent -Uri $DestinationUri -Recurse $true
    $deltaContent = Compare-FtpDirectories -ReferenceObject $sourceContent -DifferenceObject $destinationContent
    return $deltaContent
}
function Invoke-LocalSync {
    [CmdletBinding()]
    Param(
            [Parameter(Mandatory=$true)]
            [string]$SourceUri,
            [Parameter(Mandatory=$true)]
            [string]$DestinationUri
        )

    [System.Uri]$SourceUri = $uri0
    [System.Uri]$DestinationUri = $uri1
    $syncContent = Get-ContentDelta -SourceUri $SourceUri -DestinationUri $DestinationUri
    
    ForEach ($item in $syncContent) {
        ForEach ($file in $item.DirectoryItems) {
            if (!$file.isDirectory){
                $dirName = "c:\tmp" + $item.DirectoryName.Trim().Replace("/","\")
                $url = "$($SourceUri.GetComponents(13,1) + $item.DirectoryName + $file.FileName)"
                Copy-FileFromFtp -Url $url -LocalPath $dirName
            }
        }
    }
}