@{
    Name          = 'OutputDebugString'
    Description   = 'Writes messages to the Windows debugger using OutputDebugStringW. Silently does nothing on other platforms.'
    Configuration = @{
        Level          = @{Required = $false; Type = [string]; Default = $Logging.Level }
        Format         = @{Required = $false; Type = [string]; Default = $Logging.Format }
        PrintException = @{Required = $false; Type = [bool]; Default = $true }
    }
    Logger        = {
        param(
            [hashtable] $Log,
            [hashtable] $Configuration
        )

        # Windows PowerShell 5.1 does not define $IsWindows.
        if ($PSVersionTable.PSEdition -ne 'Desktop' -and -not $IsWindows)
        {
            return
        }

        $NativeMethods = 'PSLogs.OutputDebugStringNativeMethods' -as [type]
        if ($null -eq $NativeMethods)
        {
            $NativeMethods = Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;

namespace PSLogs
{
    public static class OutputDebugStringNativeMethods
    {
        [DllImport("kernel32.dll", EntryPoint = "OutputDebugStringW", CharSet = CharSet.Unicode, ExactSpelling = true)]
        public static extern void OutputDebugString(string message);
    }
}
'@ -PassThru -ErrorAction Stop
        }

        $logText = Format-Pattern -Pattern $Configuration.Format -Source $Log

        if (![String]::IsNullOrWhiteSpace($Log.ExecInfo) -and $Configuration.PrintException)
        {
            $logText += "`n{0}" -f $Log.ExecInfo.Exception.Message
            $logText += "`n{0}" -f (($Log.ExecInfo.ScriptStackTrace -split "`r`n" | ForEach-Object { "`t{0}" -f $_ }) -join "`n")
        }

        $NativeMethods::OutputDebugString($logText)
    }
}
