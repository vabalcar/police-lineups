using namespace System
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Text

function Add-SemicolonIfMissing {
    [OutputType([string])]
    param()

    process {
        [string] $string = $_
        if ($string.Length -gt 0) {
            if ($string[$string.Length - 1] -ne ';') {
                "$string;"
            } else {
                $string
            }
        } else {
            ';'
        }
    }
}

function Get-TerminatedMysqlStmt {
    [OutputType([string])]
    param (
        [Parameter(Mandatory=$true)] [string] $stmt
    )

    $stmt | Add-SemicolonIfMissing
}

function Get-MysqlScriptStmt {
    [OutputType([string])]
    param (
        [Parameter(Mandatory=$true)] [string] $script
    )
    [string] $prevLine | Out-Null
    [bool] $firstNonEmptyLine = $true
    Get-Content -Path $script | ForEach-Object {
        [string] $trimmedCurLine = $_.Trim()
        if ($trimmedCurLine.Length -gt 0) {
            if (!$firstNonEmptyLine) {
                $prevLine
            } else {
                $firstNonEmptyLine = $false
            }
            $prevLine = $trimmedCurLine   
        }
    }
    
    $prevLine | Add-SemicolonIfMissing
}

function Get-CSVImportMysqlStmt {
    Param(
        [Parameter(Mandatory=$true)] [string] $csv,
        [Parameter(Mandatory=$true)] [string] $table,
        [string] $delimiter = (Get-Culture).TextInfo.ListSeparator,
        [string] $encoding = 'utf8BOM',
        [switch] $purge
    )

    if ($purge) {
        "DELETE FROM ``$table``;"
    }

    [string] $header | Out-Null
    [List[string]] $headerCells = [List[string]]::new()
    [StringBuilder] $sb = [StringBuilder]::new()

    Import-Csv -Path $csv -Delimiter $delimiter -Encoding $encoding | ForEach-Object {
        if ($null -eq $header) {
            $_ | Get-Member -MemberType NoteProperty | ForEach-Object {
                $headerCells.Add($_.name)
            }
            $sb.Append('(') | Out-Null
            for($i = 0; $i -lt $headerCells.Count; ++$i) {
                if ($i -ne 0) {
                    $sb.Append(', ') | Out-Null
                }
                $sb.Append("``$($headerCells[$i])``") | Out-Null
            }
            $sb.Append(')') | Out-Null
            $header = $sb.ToString()
            $sb.Clear() | Out-Null
        }

        $sb.Append('(') | Out-Null
        for($i = 0; $i -lt $headerCells.Count; ++$i) {
            if ($i -ne 0) {
                $sb.Append(', ') | Out-Null
            }
            $sb.Append("'$($_."$($headerCells[$i])")'") | Out-Null
        }
        $sb.Append(')') | Out-Null
        $row = $sb.ToString()
        $sb.Clear() | Out-Null
        
        "INSERT INTO ``$table`` $header VALUES $row;"
    }
}

class IMysqlStmt {
    [hashtable] GetStmtDescription() {
        throw [NotImplementedException]::new()
    }

    [scriptblock] GetStmtProvider() {
        throw [NotImplementedException]::new()
    }
}

class MysqlStmt : IMysqlStmt {
    hidden [string] $stmt
    
    MysqlStmt([string] $stmt) {
        $this.stmt = $stmt
    }
    
    [hashtable] GetStmtDescription() {
        return @{   
            Stmt = $this.stmt
        }
    }

    [scriptblock] GetStmtProvider() {
        return ${function:Get-TerminatedMysqlStmt}
    }
}

class MysqlScript : IMysqlStmt {
    hidden [string] $script

    MysqlScript([string] $script) {
        $this.script = $script
    }

    [hashtable] GetStmtDescription() {
        return @{
            Script = $this.script
        }
    }

    [scriptblock] GetStmtProvider() {
        return ${function:Get-MysqlScriptStmt}
    }
}

class MysqlCsvImport : IMysqlStmt {
    hidden [string] $csv
    [string] $table
    [string] $delimiter = (Get-Culture).TextInfo.ListSeparator
    [string] $encoding = 'utf8BOM'
    [bool] $purge = $false

    MysqlCsvImport([string] $csv) {
        $this.csv = $csv
        $this.table = [Path]::GetFileNameWithoutExtension((Split-Path -Leaf $csv))
    }
    
    [hashtable] GetStmtDescription() {
        return @{
            CSV = $this.csv;
            Table = $this.table;
            Delimiter = $this.delimiter;
            Encoding = $this.encoding;
            Purge = $this.purge
        }
    }

    [scriptblock] GetStmtProvider() {
        return ${function:Get-CSVImportMysqlStmt}
    }
}

function Get-DBCnf {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory=$true)] [string] $DBConfigFile
    )

    $configDir = $DBConfigFile | Resolve-Path | Split-Path -Parent
    $generatedConfigDir = Join-Path $configDir 'generated'
    $DBConfigInfo = Join-Path $generatedConfigDir 'dbConfigInfo.json'
    $dbCnf = Join-Path $generatedConfigDir 'db.cnf'
    $lastConfigUpdate = (Get-Item -Path $DBConfigFile).LastWriteTime.ToUniversalTime().Ticks

    if ((Test-Path -PathType Leaf -Path $DBConfigInfo) -and ($lastConfigUpdate -eq (Get-Content $DBConfigInfo | ConvertFrom-Json).LastUpdate)) {
        return $dbCnf
    }

    "Generating DB config file $DBConfigFile" | Out-Host
    $config = Get-Content $DBConfigFile | ConvertFrom-Json
    @"
[client]
host=$($config.host)
port=$($config.port)
user=$($config.user)
password=$($config.password)
"@ | Out-File $dbCnf

    @{
        LastUpdate = $lastConfigUpdate
    } | ConvertTo-Json | Out-File -Path $DBConfigInfo

    return $dbCnf
}

function Invoke-Mysql {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $DBConfigFile,
        [switch] $force,
        [switch] $omitCreation,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [IMysqlStmt[]] $stmt
    )

    begin {
        $dbConfig = Get-Content -Path $DBConfigFile | ConvertFrom-Json
        $mysqlArgs = @(
            "--defaults-extra-file=$(Get-DBCnf -DBConfigFile $DBConfigFile)",
            '--default-character-set=utf8mb4',
            '-B'
        )

        $database = $dbConfig.db
        $stmts = @()
        if ($force) {
            $stmts += [MysqlStmt]::new("DROP DATABASE IF EXISTS ``$database``")
        }
        if (!$omitCreation) {
            $stmts += [MysqlStmt]::new("CREATE DATABASE IF NOT EXISTS ``$database``")
        }
        $stmts += [MysqlStmt]::new("USE ``$database``")
    }
    process {
        $stmts += $stmt
    }
    end {
        $stmts | ForEach-Object { 
            $description = $_.GetStmtDescription()
            $result = & $_.GetStmtProvider() @description
            return $result
        } | & mysql @mysqlArgs
    }
}

function Import-MysqlTable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)] [string] $DBConfigFile,
        [string] $delimiter = (Get-Culture).TextInfo.ListSeparator,
        [string] $encoding = 'utf8BOM',
        [switch] $purge,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true)] [string] $csv
    )

    $input | ForEach-Object {
        [MysqlCsvImport] $importStmt = [MysqlCsvImport]::new($_)
        $importStmt.delimiter = $delimiter
        $importStmt.encoding = $encoding
        $importStmt.purge = $purge
        $importStmt
    } | Invoke-Mysql -DBConfigFile $DBConfigFile
}

function Import-MysqlDB {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)] [string] $DBConfigFile,
        [Parameter(Mandatory=$true)] [string] $path,
        [string] $delimiter = (Get-Culture).TextInfo.ListSeparator,
        [string] $encoding = 'utf8BOM',
        [switch] $purge
    )

    Get-ChildItem -Recurse -Path $path -Include '*.csv' | Import-MysqlTable -DBConfigFile $DBConfigFile -Delimiter $delimiter -Encoding $encoding -Purge:$purge
}

function Get-MysqlConstDecl {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $Type,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,
        
        [Parameter(Mandatory=$true)]
        $Value
    )

    $isString = $Type -eq 'string'
    if ($isString) {
        $Type = "CHAR($($Value.Length))"
    }

    return @"
DROP FUNCTION IF EXISTS $Name;
CREATE FUNCTION $Name() RETURNS $Type DETERMINISTIC
    RETURN $(if ($isString) {"'$Value'"} else {$Value});
"@
}

function ConvertTo-Encoding {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)] [string] $path,
        [Parameter(Mandatory=$true)] [string] $inEncoding,
        [Parameter(Mandatory=$true)] [string] $outEncoding
    )

    if (![Path]::IsPathRooted($path)) {
        $path = Join-Path (Get-Location) $path
    }
    $wd = Split-Path -Parent -Path $path
    $fileName = Split-Path -Leaf -Path $path
    $tmpFileName = "__tmp-$fileName"
    $tmpFile = Join-Path $wd $tmpFileName

    Rename-Item -Path $path -NewName $tmpFileName
    Get-Content -Encoding $inEncoding -Path $tmpFile | Out-File -Encoding $outEncoding -Path $path
    Remove-Item -Force -Path $tmpFile
}

function ConvertTo-MysqlPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string] $path
    )
    begin {
        $wd = Get-Location
    }
    process {
        if (![Path]::IsPathRooted($path)) {
            $path = Join-Path $wd $path
        }
        $path -replace '\\', '\\\\'
    }
}

function Export-MysqlTable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)] [string] $DBConfigFile,
        [Parameter(Mandatory=$true)] [string] $table,
        [Parameter(Mandatory=$true)] [string] $path,
        [string] $delimiter = (Get-Culture).TextInfo.ListSeparator,
        [string] $encoding = 'utf8BOM'
    )

    Remove-Item -Force -Path $path *> $null
    $mysqlPath = $path | ConvertTo-MysqlPath
    
    $call = [MysqlStmt]::new("CALL ExportTable('$table','$delimiter','$mysqlPath')")
    $call | Invoke-Mysql -DBConfigFile $DBConfigFile
    
    ConvertTo-Encoding -Path $path -InEncoding 'utf8NoBOM' -OutEncoding $encoding
}

function Export-MysqlDB {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string] $DBConfigFile,
        [Parameter(Mandatory=$true)] [string] $path,
        [string] $delimiter = (Get-Culture).TextInfo.ListSeparator,
        [string] $encoding = 'utf8BOM'
    )

    $timestamp = Get-Date -Format 'o' | ForEach-Object {$_ -replace ":", "."}
    $path = Join-path $path $timestamp
    New-Item -ItemType Directory -Force $path | Out-Null
    $mysqlPath = $path | ConvertTo-MysqlPath

    $call = [MysqlStmt]::new("CALL ExportDB('$delimiter','$pathDelim','$mysqlPath')")
    $call | Invoke-Mysql -DBConfigFile $DBConfigFile

    Get-ChildItem -Path $path | ForEach-Object {
        ConvertTo-Encoding -Path $_ -InEncoding 'utf8NoBOM' -OutEncoding $encoding
    }
}

function Get-MysqlVariable {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)] [string] $DBConfigFile,
        [Parameter(Mandatory=$true)] [string] $Name
    )
    
    $queryResult = [MysqlStmt]::new("SHOW VARIABLES LIKE '$Name'") | Invoke-Mysql -DBConfigFile $DBConfigFile
    if ($null -eq $queryResult) { return $null }

    $columnDelimiter = "`t"
    $filterResult = $queryResult | ForEach-Object { [string] $_ } | Where-Object { $_.StartsWith("$Name$columnDelimiter") }
    if ($null -eq $filterResult) { return $null }

    return $filterResult.Split($columnDelimiter)[1]
}