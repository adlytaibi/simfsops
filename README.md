# simfsops.ps1

## SYNOPSIS
Create a dataset from a specification, manage change random rate files, grow and shrink files.

## SYNTAX

```
simfsops.ps1 [-Path] <String> [-buildDataSet] [-Estimate] [[-specJson] <String>] [[-gauge] <String>]
 [-fillToMaxSize] [-scanPath] [-prettyPrint] [[-percFiles] <Byte>] [[-percData] <Byte>] [[-backDate] <String>]
 [[-minDate] <String>] [[-maxDate] <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
The objective is to create a testing data set or use existing testing data set to simulate file changes, new and deletions.

## EXAMPLES

### EXAMPLE 1
```
./simfsops.ps1 -Path test -buildDataSet -specJson spec.json -Estimate
Minimum size of the data set   :   90.00 KB (9 files)
This simulated random data set :   53.64 MB (12 files)
Maximum size of the data set   :  270.00 MB (27 files)
```

Estimate the size of the data set, like a dry-run.

### EXAMPLE 2
```
./simfsops.ps1 -Path test -buildDataSet -specJson spec.json -Estimate -fillToMaxSize
Minimum size of the data set   :   90.00 KB (9 files)
This simulated random data set :  275.93 MB (62 files) (Fill to maximum size selected)
Maximum size of the data set   :  270.00 MB (27 files)
```

Similar to the previous example, estimate the size of the data set, like a dry-run.
However, aims to fill the maximum size of the data set.

### EXAMPLE 3
```
./simfsops.ps1 -Path test -buildDataSet -specJson spec.json
```

Build a data set using specification from file.

JSON Specification file must define all these settings:
  {
    "foldersWidth": 3,
    "foldersDepth": 3,
    "maxFilesPerDir": 3,
    "minFileSize": "10KB",
    "maxFileSize": "10MB"
  }

### EXAMPLE 4
```
./simfsops.ps1 -Path test -buildDataSet -specJson spec.json -minDate 01/15/2020 -maxDate 01/15/2022
```

Build a data set while setting a random Creation, Last Accessed and Modified date within a range of two dates
minDate and maxDate format is MM/DD/YYYY

### EXAMPLE 5
```
./simfsops.ps1 -Path test -buildDataSet -gauge tiny -specJson specGauge.json -Estimate
Minimum size of the data set   :  120.00  B (120 files)
This simulated random data set :  121.47 MB (62317 files)
Maximum size of the data set   :  468.75 MB (120000 files)
```

Omiitting the -Estimate switch will create +50k tiny files, the gauge options uses a built-in minFileSize and maxFileSize.
So, there is no need to specify them in the provided specification:
  {
    "foldersWidth": 30,
    "foldersDepth": 4,
    "maxFilesPerDir": 1000
  }


Empty files can be added to the above popluated structure

PS \> ./simfsops.ps1 -Path test -buildDataSet -gauge empty -specJson specGauge.json -Estimate
Minimum size of the data set   :  (120 files)
This simulated random data set :  (59808 files)
Maximum size of the data set   :  (120000 files)

### EXAMPLE 6
```
./simfsops.ps1 -Path test -scanPath
Scan saved to "test.xml".
```

Scan path for files and directories

For convenience and with large data set, the scan can be time consuming.
The scan is saved by default to an xml file named after the end of the path.

Noe, the scan file can be queried with no strain on the filesystem or time

PS \> Import-Clixml test.xml | Where-Object { $_.T -ne 'd' }

### EXAMPLE 7
```
./simfsops.ps1 -Path test -percFiles 20 -percData 10
```

Changing 10 percent of the data of each file in 20 percent of the total files in test directory/sub-directories

### EXAMPLE 8
```
./simfsops.ps1 -Path test -percFiles 10 -backDate 01/15/2020
```

Changing 10 percent of the files' Creation, Last Accessed, and Last Write time to a January 15th, 2020
backDate format is MM/DD/YYYY

## PARAMETERS

### -Path
Path to top level data set.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: Test
Accept pipeline input: False
Accept wildcard characters: False
```

### -buildDataSet
Build a data set with a given specification, check examples below for mandatory fields.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Estimate
Estimate the number of files and the size of the data set from the given specification file.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -specJson
Specify path to the JSON specification file.
Mandatory field when -buildDataSet is used.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -gauge
Choose a gauge from a template (empty, tiny, small, medium, large, huge)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -fillToMaxSize
Keep going beyond the foldersDepth and foldersWidth to reach the maximum of (foldersDepth * foldersWidth * maxFilesPerDir * maxFileSize)

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -scanPath
Scan path for files and subdirectories.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -prettyPrint
Pretty print file size in human readable format

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -percFiles
Make changes to X percent of files.

```yaml
Type: Byte
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -percData
Reduce each picked file to X percent of its size, value of 100 sets orignal size.
Any value above 100 will grow the file size.

```yaml
Type: Byte
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -backDate
Set Creation, Last Accessed Time and Last Write Time to specified date

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -minDate
Set a random date between two dates (minDate and maxDate) during data set build

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -maxDate
{{ Fill maxDate Description }}

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 8
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## NOTES
Author: Adly Taibi
Date: 04/19/2024
