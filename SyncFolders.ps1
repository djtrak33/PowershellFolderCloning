param (
    [string]$SourcePath,
    [string]$ReplicaPath,
    [string]$LogFilePath
)

$FileSizeThreshold = 500 * 1MB
$didcomplete = $false

# Function to log messages to both console and log file
function Log-Message {
    param (
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Message"
    
    Write-Host $logMessage
    
    Add-Content -Path $LogFilePath -Value $logMessage
}

# Check all paths validity and create paths that do not exist
function Verify-Paths{
    if (!(Test-Path -Path $LogFilePath -IsValid)) {
        Throw "Invalid folder log file path format: $LogFilePath"
    }

    if (!(Test-Path -Path $SourcePath -IsValid) -OR !(Test-Path -Path $SourcePath -PathType Container)){
        Throw "Invalid folder source path format or path does not point to a folder: $SourcePath"
    }

    if (!(Test-Path -Path $ReplicaPath -IsValid)) {
        Throw "Invalid folder replica path format: $ReplicaPath"
    }

    if (!(Test-Path $LogFilePath)) {
        Log-Message "Log file does not exist, creating it: $LogFilePath"
        New-Item -Path $LogFilePath -ItemType File
    }

    if (!(Test-Path $ReplicaPath)) {
        Log-Message "Replica folder does not exist, creating it: $ReplicaPath"
        New-Item -Path $ReplicaPath -ItemType Container
    }
}

# Remove files from replica that don't exist in source
function RemoveLeftOverFiles{
    $replicaItems = Get-ChildItem -Path $ReplicaPath -Recurse
    $foldersToDelete = @()

    foreach ($replicaItem in $replicaItems) {

        $relativePath = $replicaItem.FullName.Substring($ReplicaPath.Length)
        $sourceEquivalent = Join-Path $SourcePath $relativePath

        if (!(Test-Path $sourceEquivalent)) {
            if ($replicaItem.PSIsContainer) {
                $foldersToDelete += $replicaItem
             } else {
                Remove-Item -Path $replicaItem.FullName
                Log-Message "Removed file: $($replicaItem.FullName)"
             }
        }
    }
    #Leave folders for last and then sort by depth before removing them, this was made in order to be able to log every deleted item that was found inside folders that also needed to be deleted
    $foldersToDelete = $foldersToDelete | Sort-Object { $_.FullName.Split([IO.Path]::DirectorySeparatorChar).Count } -Descending

    foreach ($folder in $foldersToDelete) {
        Log-Message "Removed directory: $($folder.FullName)"
        Remove-Item -Path $folder.FullName -Recurse
    }
}

# Function for Folder Syncing
function Sync-Folders {
    #try/finally for graceful shutdown scenario, just removes files from replica that shouldnt be there, this was mostly to catch temporary files that could be created 
    try{
        Verify-Paths

        $sourceItems = Get-ChildItem -Path $SourcePath -Recurse

        foreach ($item in $sourceItems) {

            $relativePath = $item.FullName.Substring($SourcePath.Length)
            $targetPath = Join-Path $ReplicaPath $relativePath

            if ($item.PSIsContainer) {

                if (!(Test-Path $targetPath)) {
                    New-Item -ItemType Container -Path $targetPath
                    Log-Message "Created directory: $targetPath"
                }

            } else {

                $fileSize = (Get-Item $item.FullName).Length
                
                if ($fileSize -gt $FileSizeThreshold) {
                    # Use temporary file operations for large files and Timestamp and File Size checks for better performance
                    if (!(Test-Path $targetPath) -or (Get-Item $item.FullName).LastWriteTime -gt (Get-Item $targetPath).LastWriteTime -or $fileSize -ne (Get-Item $targetPath).Length) {
                        $tempTargetPath = "$targetPath.tmp"
                        Copy-Item -Path $item.FullName -Destination $tempTargetPath -Force
                        Move-Item -Path $tempTargetPath -Destination $targetPath
                        Log-Message "Copied/Updated large file using temp path: $targetPath"
                    }

                } else {

                    if (!(Test-Path $targetPath) -or (Get-FileHash $item.FullName).Hash -ne (Get-FileHash $targetPath).Hash) {
                        Copy-Item -Path $item.FullName -Destination $targetPath -Force
                        Log-Message "Copied/Updated file: $targetPath"
                    }

                }
            }
        }

        RemoveLeftOverFiles
        $didcomplete = $true

    }finally{
        if(!$didcomplete){
           RemoveLeftOverFiles
        }
    }
}

Log-Message "Starting synchronization from $SourcePath to $ReplicaPath"
Sync-Folders
Log-Message "Synchronization completed."