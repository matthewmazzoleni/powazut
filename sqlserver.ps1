







$targetServer = "TARGET_SERVER_NAME"
$newDbName = "NEW_DATABASE_NAME"
$newMdfPath = "C:\path_to_new_files\newfile.mdf"
$newLdfPath = "C:\path_to_new_files\newfile.ldf"

# Ensure the SQLServer module is loaded
Import-Module SQLServer

# Set connection details


# Set the database to single-user mode
Set-SqlDatabase -ServerInstance $SqlServerInstance -Database "ABenergie" -UserAccess Single

# Restore the database
Restore-SqlDatabase -ServerInstance $SqlServerInstance `
    -Database "ABenergie" `
    -BackupFile @(
        '\\abfileserver01.file.core.windows.net\sql-vault\DATA\VM-SQL2014-01\ABenergie01.bak',
        '\\abfileserver01.file.core.windows.net\sql-vault\DATA\VM-SQL2014-01\ABenergie02.bak',
        '\\abfileserver01.file.core.windows.net\sql-vault\DATA\VM-SQL2014-01\ABenergie03.bak'
    ) `
    -FileNumber 1 `
    -RelocateFile @(
        New-SqlBackupRelocateFile -LogicalFileName 'ABENERGIE_MASTER' -PhysicalFileName 'J:\Data\ABENERGIE.mdf',
        New-SqlBackupRelocateFile -LogicalFileName 'ABENERGIE_DATA1' -PhysicalFileName 'J:\Data\ABENERGIE_DATA1.ndf',
        New-SqlBackupRelocateFile -LogicalFileName 'ABENERGIE_DATA2' -PhysicalFileName 'K:\Data\ABENERGIE_DATA2.ndf',
        New-SqlBackupRelocateFile -LogicalFileName 'ABENERGIE_DATA3' -PhysicalFileName 'L:\Data\ABENERGIE_DATA3.ndf',
        New-SqlBackupRelocateFile -LogicalFileName 'ABENERGIE_Log' -PhysicalFileName 'X:\Log\ABENERGIE_Log.ldf'
    ) `
    -ReplaceDatabase

# Set the database back to multi-user mode
Set-SqlDatabase -ServerInstance $SqlServerInstance -Database "ABenergie" -UserAccess Multi