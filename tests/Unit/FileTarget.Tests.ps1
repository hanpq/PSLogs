BeforeAll {

    $RootItem = Get-Item $PSScriptRoot
    while ($RootItem.GetDirectories().Name -notcontains 'source')
    {
        $RootItem = $RootItem.Parent
    }
    $ProjectPath = $RootItem.FullName
    $ModuleManifestFileInfo = Get-ChildItem $ProjectPath -Recurse -Filter '*.psd1' | Where-Object fullname -Like "*\output\$($RootItem.Name)\*"

    Remove-Module $ModuleManifestFileInfo.BaseName -Force -ErrorAction SilentlyContinue

    Import-Module $ModuleManifestFileInfo.BaseName -Force
}

AfterAll {
    Remove-Module $ModuleManifestFileInfo.BaseName -Force
}

InModuleScope $ProjectName {

    Describe -Tags Targets, TargetFile 'File target' {

        It 'should resolve relative paths' {

            Add-LoggingTarget -Name File -Configuration @{
                Path = '..\Test.log'
            }

            $a = Get-LoggingTarget
            $a.Values.Path.Contains('..') | Should -BeFalse
        }

    }
}
