[CmdletBinding()]
param()

Function TransformXML
{
    param(
        [string] $SourceFile,
        [string] $TransformFile,
        [string] $OutputFile
    )

    # validate inputs
    if (!(Test-Path $SourceFile))
    {
        Write-Error "File '${SourceFile}' not found."
        return
    }

    if (!(Test-Path $TransformFile))
    {
        Write-Error "File '${TransformFile}' not found."
        return
    }

    # apply transformations
    Write-Host "Applying transformations '${TransformFile}' on file '${SourceFile}'..."
      

    try {
        $xslt_settings = New-Object System.Xml.Xsl.XsltSettings;
        $XmlUrlResolver = New-Object System.Xml.XmlUrlResolver;
        $xslt_settings.EnableScript = 1;
        $xslt = New-Object System.Xml.Xsl.XslCompiledTransform;
        $xslt.Load($TransformFile,$xslt_settings,$XmlUrlResolver);
        if($SourceFile == $OutputFile -or $OutputFile -eq $null){
            $xslt.Transform($SourceFile,"$SourceFile.output");
            Remove-Item $SourceFile;
            Rename-Item "$SourceFile.output" $SourceFile;
        }else{
            $xslt.Transform($SourceFile,$OutputFile);
        }
        
    
    }
    catch {
        Write-Error "Error while applying transformations '${TransformFile}' on file '${SourceFile}'."
        return
    }
}

Trace-VstsEnteringInvocation $MyInvocation
try
{
    # get inputs
    [string] $workingFolder = Get-VstsInput -Name 'workingFolder'
    [string] $transforms = Get-VstsInput -Name 'transforms' -Require

    if (!$workingFolder)
    {
        $workingFolder = $env:SYSTEM_DEFAULTWORKINGDIRECTORY
    }

    $workingFolder = $workingFolder.Trim()

    # apply transforms
    $transforms -split "(?:`n`r?)|," | % {
        $rule = $_.Trim()
        if (!$rule)
        {
            Write-Warning "Found empty rule."

            return
        }

        $ruleParts = $rule -split " *=> *"
        if ($ruleParts.Length -lt 2)
        {
            Write-Error "Invalid rule '${rule}'."

            return
        }

        $transformFile = $ruleParts[0].Trim()
        if (![System.IO.Path]::IsPathRooted($transformFile))
        {
            $transformFile = Join-Path $workingFolder $transformFile
        }

        $sourceFile = $ruleParts[1].Trim()
        if (![System.IO.Path]::IsPathRooted($sourceFile))
        {
            $sourceFile = Join-Path $workingFolder $sourceFile
        }

        $outputFile = $sourceFile
        if ($ruleParts.Length -eq 3)
        {
            $outputFile = $ruleParts[2].Trim()
            if (![System.IO.Path]::IsPathRooted($outputFile))
            {
                $outputFile = Join-Path $workingFolder $outputFile
            }
        }

        TransformXML -SourceFile $sourceFile -TransformFile $transformFile -OutputFile $outputFile
    }
}
finally
{
    Trace-VstsLeavingInvocation $MyInvocation
}