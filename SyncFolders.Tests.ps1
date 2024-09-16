. "$PSScriptRoot\SyncFolders.ps1"

$SourcePath = "$PSScriptRoot\Source_Test"
$ReplicaPath = "$PSScriptRoot\Replica_Test"
$LogFilePath = "$PSScriptRoot\sync_log.txt"

Describe "Log-Message Function" {
    It "Should log messages to a file" {
        # Arrange
        $testMessage = "Test message"
        $testLogFilePath = "$PSScriptRoot\test_log.txt"
        Remove-Item -Path $testLogFilePath -ErrorAction Ignore

        # Act
        Log-Message -Message $testMessage

        # Assert
        $logContent = Get-Content -Path $testLogFilePath
        $logContent | Should -Contain $testMessage
    }
}

Describe "Verify-Paths Function" {
    It "Should throw an exception for an invalid log file path" {
        $LogFilePath = "TR:\"  # Invalid path
        { Verify-Paths } | Should -Throw "Invalid folder log file path format"
    }

    It "Should create the log file if it does not exist" {
        $LogFilePath = "$PSScriptRoot\log_test.txt"
        Remove-Item -Path $LogFilePath -ErrorAction Ignore
        Verify-Paths
        Test-Path -Path $LogFilePath | Should -BeTrue
    }

    It "Should throw an exception for an invalid source folder path" {
        $SourcePath = "TR:\"  # Invalid path
        { Verify-Paths } | Should -Throw "Invalid folder source path format"
    }

    It "Should create the replica folder if it does not exist" {
        Remove-Item -Path $ReplicaPath -Recurse -ErrorAction Ignore
        Verify-Paths
        Test-Path -Path $ReplicaPath | Should -BeTrue
    }
}

Describe "Sync-Folders Function" {
    BeforeAll {
        # Setup mock directories
        New-Item -Path $SourcePath -ItemType Directory -Force
        New-Item -Path $ReplicaPath -ItemType Directory -Force
        New-Item -Path "$SourcePath\file1.txt" -ItemType File -Force
        New-Item -Path "$SourcePath\file2.txt" -ItemType File -Force
    }

    It "Should copy files from source to replica" {
        Sync-Folders
        Test-Path "$ReplicaPath\file1.txt" | Should -BeTrue
        Test-Path "$ReplicaPath\file2.txt" | Should -BeTrue
    }

    It "Should remove files from replica that are not in the source" {
        New-Item -Path "$ReplicaPath\file3.txt" -ItemType File -Force
        Sync-Folders
        Test-Path "$ReplicaPath\file3.txt" | Should -BeFalse
    }

    It "Should create directories in replica that are in source" {
        New-Item -Path "$SourcePath\SubFolder" -ItemType Directory -Force
        Sync-Folders
        Test-Path "$ReplicaPath\SubFolder" | Should -BeTrue
    }

    It "Should remove files in replica that do not exist in source" {
        New-Item -Path "$ReplicaPath\file_to_remove.txt" -ItemType File -Force
        Sync-Folders
        Test-Path "$ReplicaPath\file_to_remove.txt" | Should -BeFalse
    }

    AfterAll {
        Remove-Item -Path $SourcePath -Recurse -Force
        Remove-Item -Path $ReplicaPath -Recurse -Force
        Remove-Item -Path $LogFilePath -Force
    }
}