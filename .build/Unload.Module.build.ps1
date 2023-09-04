param (
    # Base directory of all output (default to 'output')
    [Parameter()]
    [string]
    $OutputDirectory = (property OutputDirectory (Join-Path -Path $BuildRoot -ChildPath 'output')),

    [Parameter()]
    [System.String]
    $BuiltModuleSubdirectory = (property BuiltModuleSubdirectory ''),

    [Parameter()]
    [System.String]
    $ProjectName = (property ProjectName ''),

    [Parameter()]
    [System.String]
    $BuildModuleOutput = (property BuildModuleOutput (Join-Path $OutputDirectory $BuiltModuleSubdirectory)),

    [Parameter()]
    [string]
    $PFX_BASE64 = (property PFX_BASE64),

    [Parameter()]
    [string]
    $PFX_PASS = (property PFX_PASS 'test')
)

# Synopsis: Deleting the content of the Build Output folder, except ./modules
Task Unload_Module {
    . Set-SamplerTaskVariable

    Remove-Module $ProjectName -Force -ErrorAction SilentlyContinue

}
