BeforeDiscovery {
    $RootItem = Get-Item $PSScriptRoot
    while ($RootItem.GetDirectories().Name -notcontains 'source')
    {
        $RootItem = $RootItem.Parent
    }
    $ProjectPath = $RootItem.FullName
    $ProjectName = (Get-ChildItem $ProjectPath\*\*.psd1 | Where-Object {
            ($_.Directory.Name -eq 'source') -and
            $(try
                {
                    Test-ModuleManifest $_.FullName -ErrorAction Stop
                }
                catch
                {
                    $false
                })
        }
    ).BaseName

    Import-Module $ProjectName -Force

}

InModuleScope $ProjectName {

    Describe -Tags Targets, TargetFile 'File target' {

        It 'should resolve relative paths' {

            Add-LoggingTarget -Name File -Configuration @{
                Path = '..\Test.log'
            }

            $a = Get-LoggingTarget
            $a.Values.Path.Contains('..') | Should -Befalse
        }

    }
}
