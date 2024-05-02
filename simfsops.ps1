<#
.SYNOPSIS
  Create a dataset from a specification, manage change random rate files, grow and shrink files.
.DESCRIPTION
  The objective is to create a testing data set or use existing testing data set to simulate file changes, new and deletions.
.EXAMPLE
  ./simfsops.ps1 -Path test -buildDataSet -specJson spec.json -Estimate
  Minimum size of the data set   :   90.00 KB (9 files)
  This simulated random data set :   53.64 MB (12 files)
  Maximum size of the data set   :  270.00 MB (27 files)

  Estimate the size of the data set, like a dry-run.
.EXAMPLE
  ./simfsops.ps1 -Path test -buildDataSet -specJson spec.json -Estimate -fillToMaxSize
  Minimum size of the data set   :   90.00 KB (9 files)
  This simulated random data set :  275.93 MB (62 files) (Fill to maximum size selected)
  Maximum size of the data set   :  270.00 MB (27 files)

  Similar to the previous example, estimate the size of the data set, like a dry-run. However, aims to fill the maximum size of the data set.
.EXAMPLE
  ./simfsops.ps1 -Path test -buildDataSet -specJson spec.json

  Build a data set using specification from file.

  JSON Specification file must define all these settings:
    {
      "foldersWidth": 3,
      "foldersDepth": 3,
      "maxFilesPerDir": 3,
      "minFileSize": "10KB",
      "maxFileSize": "10MB"
    }
.EXAMPLE
  ./simfsops.ps1 -Path test -buildDataSet -specJson spec.json -minDate 01/15/2020 -maxDate 01/15/2022

  Build a data set while setting a random Creation, Last Accessed and Modified date within a range of two dates
  minDate and maxDate format is MM/DD/YYYY

.EXAMPLE
  ./simfsops.ps1 -Path test -buildDataSet -gauge tiny -specJson specGauge.json -Estimate
  Minimum size of the data set   :  120.00  B (120 files)
  This simulated random data set :  121.47 MB (62317 files)
  Maximum size of the data set   :  468.75 MB (120000 files)

  Omiitting the -Estimate switch will create +50k tiny files, the gauge options uses a built-in minFileSize and maxFileSize.
  So, there is no need to specify them in the provided specification:
    {
      "foldersWidth": 30,
      "foldersDepth": 4,
      "maxFilesPerDir": 1000
    }


  Empty files can be added to the above popluated structure

  PS > ./simfsops.ps1 -Path test -buildDataSet -gauge empty -specJson specGauge.json -Estimate
  Minimum size of the data set   :  (120 files)
  This simulated random data set :  (59808 files)
  Maximum size of the data set   :  (120000 files)
.EXAMPLE
  ./simfsops.ps1 -Path test -scanPath
  Scan saved to "test.xml".

  Scan path for files and directories

  For convenience and with large data set, the scan can be time consuming.
  The scan is saved by default to an xml file named after the end of the path.

  Noe, the scan file can be queried with no strain on the filesystem or time

  PS > Import-Clixml test.xml | Where-Object { $_.T -ne 'd' }
.EXAMPLE
  ./simfsops.ps1 -Path test -percFiles 20 -percData 10
  
  Changing 10 percent of the data of each file in 20 percent of the total files in test directory/sub-directories
.EXAMPLE
  ./simfsops.ps1 -Path test -percFiles 10 -backDate 01/15/2020

  Changing 10 percent of the files' Creation, Last Accessed, and Last Write time to a January 15th, 2020
  backDate format is MM/DD/YYYY
.INPUTS

.NOTES
  Author: Adly Taibi
  Date: 04/19/2024
#>

param (
  # Path to top level data set.
  [Parameter(Mandatory = $true)]
  [string]$Path = 'test',
  # Build a data set with a given specification, check examples below for mandatory fields.
  [switch]$buildDataSet,
  # Estimate the number of files and the size of the data set from the given specification file.
  [switch]$Estimate,
  # Specify path to the JSON specification file. Mandatory field when -buildDataSet is used.
  [string]$specJson,
  # Choose a gauge from a template (empty, tiny, small, medium, large, huge)
  [ValidateSet('empty', 'tiny', 'small', 'medium', 'large', 'huge')]
  [string]$gauge,
  # Keep going beyond the foldersDepth and foldersWidth to reach the maximum of (foldersDepth * foldersWidth * maxFilesPerDir * maxFileSize)
  [switch]$fillToMaxSize,
  # Scan path for files and subdirectories.
  [switch]$scanPath,
  # Pretty print file size in human readable format
  [switch]$prettyPrint,
  # Make changes to X percent of files.
  [ValidateRange(1, 100)]
  [byte]$percFiles,
  # Reduce each picked file to X percent of its size, value of 100 sets orignal size.
  # Any value above 100 will grow the file size.
  [ValidateRange(0, 150)]
  [byte]$percData = 0,
  # Set Creation, Last Accessed Time and Last Write Time to specified date
  [ValidatePattern('(0[1-9]|1[012])[\/](0[1-9]|[12][0-9]|3[01])[\/](19|20)\d\d')]
  [string]$backDate,
  # Set a random date between two dates (minDate and maxDate) during data set build
  [ValidatePattern('(0[1-9]|1[012])[\/](0[1-9]|[12][0-9]|3[01])[\/](19|20)\d\d')]
  [string]$minDate,
  [ValidatePattern('(0[1-9]|1[012])[\/](0[1-9]|[12][0-9]|3[01])[\/](19|20)\d\d')]
  [string]$maxDate
)

$fsSep = [IO.Path]::DirectorySeparatorChar
$fullPath = [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location -PSProvider FileSystem).ProviderPath, $Path))

$template = @{
  empty  = @{
    minFileSize = 0
    maxFileSize = 0
  }
  tiny   = @{
    minFileSize = 1
    maxFileSize = 4kb
  }
  small  = @{
    minFileSize = 4kb
    maxFileSize = 256kb
  }
  medium = @{
    minFileSize = 256kb
    maxFileSize = 4mb
  }
  large  = @{
    minFileSize = 4mb
    maxFileSize = 512mb
  }
  huge   = @{
    minFileSize = 512mb
    maxFileSize = 640mb
  }
}

function ScanPath {
  param (
    [Parameter(mandatory = $true)]
    [string]$Path
  )
  $dataset = $null
  $fullPath = $fullPath.TrimEnd($fsSep)
  $fullPath = [Regex]::Escape($fullPath)
  if (Test-Path -Path $Path -PathType Container) {
    $dataset = Get-ChildItem $Path -Recurse | ForEach-Object {
      if ($_.PSIsContainer) {
        $Dir = $_.Parent
        $RDir = $_.Parent -replace "$fullPath", 'TOP'
        $T = 'd'
      }
      else {
        $Dir = $_.Directory
        $RDir = $_.Directory -replace "$fullPath", 'TOP'
        $T = 'f'
      }
      Write-Progress -Activity 'Scanning files' -Status ('{0} {1}' -f $_.Name, $RDir)
      [PSCustomObject][ordered]@{
        T      = $T
        Name   = $_.Name
        Size   = $_.Length
        ppSize = FormatSize $_.Length
        Create = $_.CreationTime
        Access = $_.LastAccessTime
        Modify = $_.LastWriteTime
        RDir   = $RDir
        Dir    = $Dir
      }
    }
  }
  return $dataset
}

function msg {
  Param (
    [string]$txt,
    [ValidateSet('green', 'yellow', 'blue', 'purple', 'cyan')]
    [string]$color = 'red'
  )
  switch ($color) {
    'green' { $code = 92 }
    'yellow' { $code = 93 }
    'blue' { $code = 94 }
    'purple' { $code = 95 }
    'cyan' { $code = 96 }
    Default { $code = 91 }
  }
  return "$([char]0x1b)[${code}m${txt}$([char]0x1b)[0m"
}

function FormatSize {
  param (
    [Int64]$Size
  )
  $fsize = ''
  if ($size -ge 1PB) { $fsize = '{0,7:0.00} PB' -f ($size / 1PB) }
  elseif ($size -ge 1TB) { $fsize = '{0,7:0.00} TB' -f ($size / 1TB) }
  elseif ($size -ge 1GB) { $fsize = '{0,7:0.00} GB' -f ($size / 1GB) }
  elseif ($size -ge 1MB) { $fsize = '{0,7:0.00} MB' -f ($size / 1MB) }
  elseif ($size -ge 1KB) { $fsize = '{0,7:0.00} KB' -f ($size / 1KB) }
  elseif ($size -gt 0) { $fsize = '{0,7:0.00}  B' -f $size }
  return $fsize
}

function CreateDataSet {
  param (
    [Parameter(mandatory = $true)]
    [string]$Path,
    [psobject]$Spec,
    [string]$DirName = 'test'
  )
  if ($gauge) {
    foreach ($key in ('foldersWidth', 'foldersDepth', 'maxFilesPerDir')) {
      if (-not $Spec.PSobject.Properties.Name.Contains($key)) {
        return msg ('"{0}" does not exist in data set specification.' -f $key)
      }
    }
  }
  else {
    foreach ($key in ('foldersWidth', 'foldersDepth', 'maxFilesPerDir', 'minFileSize', 'maxFileSize')) {
      if (-not $Spec.PSobject.Properties.Name.Contains($key)) {
        return msg ('"{0}" does not exist in data set specification.' -f $key)
      }
    }
    if ($Spec.minFileSize -gt $Spec.maxFileSize) {
      return msg '"minFileSize" cannot be greater than "maxFileSize".'
    }
  }
  if ($Spec.maxFilesPerDir -gt 9999) {
    return msg '"maxFilesPerDir" does not support a value greather than 9999.'
  }
  if ($minDate -and $maxDate) {
    $sDate = [datetime]::ParseExact($minDate, 'mm/dd/yyyy', $null)
    $eDate = [datetime]::ParseExact($maxDate, 'mm/dd/yyyy', $null)
    if ($eDate -le $sDate) {
      return msg '"minDate" cannot be greater or equal to "maxDate".'
    }
  }
  $totSize = 0
  $totNFiles = 0
  if ($gauge) {
    $minFileSize = [Int64]$template.$gauge.minFileSize
    $maxFileSize = [Int64]$template.$gauge.maxFileSize
  }
  else {
    $minFileSize = [Int64]$Spec.minFileSize
    $maxFileSize = [Int64]$Spec.maxFileSize
  }
  $foldersDepth = [int64]$Spec.foldersDepth
  $foldersWidth = [int64]$Spec.foldersWidth
  $totNDirs = $foldersDepth * $foldersWidth
  $totMaxNFiles = [int64]$Spec.maxFilesPerDir * $totNDirs
  $totMinSize = $minFileSize * $totNDirs
  $totMaxSize = $maxFileSize * $totMaxNFiles
  $realTot = $totMaxNFiles
  $sPad = $maxFileSize.ToString().length
  $nfile = 0
  for ($dd = 1; $dd -le $foldersDepth; $dd++) {
    $incarnation = '{0:X}' -f [int64](Get-Date).ToFileTime()
    $DirDName = '{0}d{1}' -f $incarnation, $dd.ToString()
    $DirDepth = Join-Path -Path $Path -ChildPath $DirDName
    if (-not (Test-Path -Path $DirDepth)) {
      if (-not $Estimate) {
        $null = New-Item -Path $DirDepth -ItemType Directory
      }
    }
    for ($dw = 1; $dw -le $foldersWidth; $dw++) {
      $incarnation = '{0:X}' -f [int64](Get-Date).ToFileTime()
      $DirWName = '{0}w{1}' -f $incarnation, $dw.ToString()
      $DirWidth = Join-Path -Path $DirDepth -ChildPath $DirWName
      if (-not (Test-Path -Path $DirWidth)) {
        if (-not $Estimate) {
          $null = New-Item -Path $DirWidth -ItemType Directory
        }
      }
      if ($Spec.maxFilesPerDir -eq 1) {
        $maxFilesPerDir = 1
      }
      else {
        $maxFilesPerDir = Get-Random -Minimum 1 -Maximum $Spec.maxFilesPerDir
      }
      $realTot -= ($Spec.maxFilesPerDir - $maxFilesPerDir)
      for ($nf = 1; $nf -le $maxFilesPerDir; $nf++) {
        if ($minFileSize -eq $maxFileSize) {
          $fsize = $minFileSize
        }
        else {
          $fsize = Get-Random -Minimum $minFileSize -Maximum $maxFileSize
        }
        if ($totSize -le $totMaxSize) {
          $totSize += $fsize
          $totNFiles++
          $fName = "{0:d4}{1:d${sPad}}.file" -f $nf, $fsize
          $fPath = Join-Path -Path $DirWidth -ChildPath $fName
          if (-not (Test-Path -Path $fPath)) {
            $fullPath = [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location -PSProvider FileSystem).ProviderPath, $fPath))
            if ($Estimate) { $label = 'Computing' } else { $label = 'Writing' }
            $pct = $nfile / $realTot * 100
            $nfile++
            Write-Progress -Activity $DirWidth -Status ('{0} file: {1}' -f $label, $fName) -PercentComplete $pct
            if (-not $Estimate) {
              $null = New-Item -Path $fPath -ItemType File
              $out = new-object byte[] $fsize
              (New-Object System.Random).NextBytes($out)
              [IO.File]::WriteAllBytes($fullPath, $out)
              if ($minDate -and $maxDate) {
                $oDate = [DateTime](Get-Random -Minimum $sDate.Ticks -Maximum $eDate.Ticks)
                SetTimeStamp -Path $fullPath -Date $oDate
                SetTimeStamp -Path $DirWidth -Date $oDate
                SetTimeStamp -Path $DirDepth -Date $oDate
              }
            }
            if ($VerbosePreference -eq 'Continue') {
              msg ('{0}' -f $fullPath) -color blue
            }
          }
        }
      }
    }
    $Path = $DirDepth
    if ($fillToMaxSize -and $dd -eq $foldersDepth -and $totSize -lt $totMaxSize) {
      $foldersDepth++
      $realTot += [int64]$Spec.maxFilesPerDir * $foldersWidth
    }
  }
  if ($Estimate) {
    $lblfilltomax = ''
    if ($fillToMaxSize) {
      $lblfilltomax = '(Fill to maximum size selected)'
    }
    msg ('Minimum size of the data set   : {0} ({1} files)' -f (FormatSize $totMinSize), $totNDirs) -color cyan
    msg ('This simulated random data set : {0} ({1} files) {2}' -f (FormatSize $totSize), $totNFiles, $lblfilltomax) -color cyan
    msg ('Maximum size of the data set   : {0} ({1} files)' -f (FormatSize $totMaxSize), $totMaxNFiles) -color cyan
  }
}

function SetTimeStamp {
  Param (
    [Parameter(mandatory = $true)]
    [string]$Path,
    [datetime]$Date = (Get-Date)
  )
  Get-ChildItem -Path $Path | ForEach-Object {
    $_.CreationTime = $Date
    $_.LastAccessTime = $Date
    $_.LastWriteTime = $Date
  }
}

function UpdateDataSet {
  Param (
    [Parameter(mandatory = $true)]
    [string]$Path
  )
  if ($PercFiles -ge 1 -and $PercFiles -le 100) {
    $scan = ScanPath -Path $Path
    $files = $scan | Where-Object { $_.T -ne 'd' }
    $fcount = ($files | Measure-Object).count
    $percount = [Math]::Ceiling($fcount * $PercFiles / 100)
    $picked = @()
    while ($picked.Length -lt $percount) {
      $rand = Get-Random -Minimum 0 -Maximum $fcount
      $fpath = $files | Select-Object -Index $rand
      if ($picked -notcontains $fpath ) {
        $picked += $fpath
      }
    }
    if ($backDate) {
      $oDate = [datetime]::ParseExact($backDate, 'mm/dd/yyyy', $null)
    }
    $c = 0
    $picked | ForEach-Object {
      $dataChange = ($_.Size * $percData / 100)
      Write-Progress -Activity 'Changing files' -Status ('Writing bytes to file {0} in {1}' -f $_.Name, $_.RDir) -PercentComplete ($c / $picked.length * 100)
      $fullPath = Join-Path -Path $_.Dir -ChildPath $_.Name
      if ($backDate) {
        SetTimeStamp -Path $fullPath -Date $oDate
      }
      else {
        if ($dataChange) {
          if ($percData -eq 100) {
            $dataChange = [int]$_.Name.split('.')[0].substring(4)
          }
          $out = new-object byte[] $dataChange
          (New-Object System.Random).NextBytes($out)
          [IO.File]::WriteAllBytes($fullPath, $out)
          if ($VerbosePreference -eq 'Continue') {
            msg ('{0}' -f $fullPath) -color cyan
          }
        }
      }
      $c++
    }
  }
  else {
    msg "Please provide a value between 1 and 100."
  }
}

if ($buildDataSet) {
  if (-not (Test-Path -Path $specJson)) {
    msg "Data Set Building Specification file does not exist."
  }
  else {
    $dataSetSpec = get-content -raw $specJson | convertFrom-Json
    CreateDataSet -Path $Path -Spec $dataSetSpec
  }
  exit
}

if ($scanPath) {
  if (Test-Path -Path $Path) {
    $outScan = 'scan_{0}_{1}.xml' -f $fullPath.TrimEnd($fsSep).Split($fsSep)[-1], (Get-Date -Format 'yyyyMMddHHmmss')
    $dataset = ScanPath -Path $Path
    $dataset | Export-Clixml -Path $outScan
    msg ("Scan saved to ""{0}""." -f $outScan) -color green
    if ($prettyPrint) {
      $size = @{l = 'Size'; e = { $_.ppSize } }
      $rdir = @{l = 'Relative Path'; e = { $_.RDir } }
      $mod = @{l = 'Last Modify Time'; e = { $_.Modify } }
      $dataset | Select-Object T, Name, $size, $rdir, $mod | Sort-Object 'Last Modify Time' | Format-Table
      $dirs = $dataset | Where-Object { $_.T -eq 'd' } | Measure-Object -Property Size -Sum
      $files = $dataset | Where-Object { $_.T -eq 'f' } | Measure-Object -Property Size -Sum
      msg ("Summary:`nDirectories: {0} ({1})" -f $dirs.Count, (FormatSize $dirs.Sum)) -color green
      msg ("Files      : {0} ({1})" -f $files.Count, (FormatSize $files.Sum)) -color green  
    }
  }
  else {
    msg ("The given path ""{0}"" does not exist." -f $Path)
  }  
  exit
}

if ($percFiles) {
  UpdateDataSet -Path $Path
  exit
}
