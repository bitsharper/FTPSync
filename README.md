# FTPSync

This is a PowerShell learning project for syncronyzing data between 2 different FTP servers. 

Input parameters: 

$sourceUri = New-Object -TypeName System.Uri -ArgumentList "ftp://10.10.0.106/foobar2000 Music Folder/"
$destinationUri = New-Object -TypeName System.Uri -ArgumentList "ftp://10.10.0.3/"

Invoke-FtpToFtpSync -SourceUri $sourceUri -DestinationUri $destinationUri