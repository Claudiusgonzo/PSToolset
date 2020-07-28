# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

function Start-JupyterNotebook
{
    <#
    .SYNOPSIS
        Start Jupyter Notebook in current folder or $env:DefaultJupyterNotebookPath.
        Reuse existing notebook already running if possible.

    .PARAMETER Force
        Don't reuse anything and don't use defaults.
        Just open a new notebook in the current folder.

    .EXAMPLE
        Start-JupyterNotebook

        Tries to reopen a currently opened jupyter notebook.
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Intended to be this way')]
    param
    (
        [switch] $Force
    )

    # Test if jupyter is installed
    if( -not (Get-Command jupyter.exe -ea Ignore) )
    {
        throw "jupyter.exe must be discoverable via PATH environment variable, you can install it via Anaconda"
    }

    # Cleanup cleanup jobs =)
    $cleanupJobName = "Start-JupyterNotebook cleanup"
    Get-Job $cleanupJobName -ea Ignore | where State -eq Completed | Remove-Job

    # Helper function
    function Open-Notebook( $folder = $pwd )
    {
        $ps = Start-Process `
            -FilePath "pwsh" `
            -ArgumentList '-Command "jupyter notebook"' `
            -WorkingDirectory $folder `
            -WindowStyle Hidden `
            -PassThru

        Start-Job -Name $cleanupJobName {
            Start-Sleep -Seconds 60
            $ps | Stop-Process
        } | Out-Null
    }

    # When need to open new notebook in current folder
    if( $Force )
    {
        "Open new jupyter notebook in current folder $pwd"
        Open-Notebook
        return
    }

    # Trying to reuse opened notebooks if possible
    if( Get-Process jupyter -ea Ignore )
    {
        "Found existing jupyter notebook, reopening default URL"
        Start-Process http://localhost:8888/
        return
    }

    # Run notebook from default location if possible
    if( $env:DefaultJupyterNotebookPath )
    {
        "Open new jupyter notebook in `$env:DefaultJupyterNotebookPath = $env:DefaultJupyterNotebookPath"
        Open-Notebook $env:DefaultJupyterNotebookPath
    }
    else
    {
        "Open new jupyter notebook in current folder $pwd, note that you can use `$env:DefaultJupyterNotebookPath instead if you define it"
        Open-Notebook
    }
}

function Stop-JupyterNotebook
{
    <#
    .SYNOPSIS
        Stop all Jupyter Notebooks running
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Intended to be this way')]
    param()

    # Test if jupyter is installed
    if( -not (Get-Command jupyter.exe -ea Ignore) )
    {
        throw "jupyter.exe must be discoverable via PATH environment variable, you can install it via Anaconda"
    }

    # Stop all opened notebooks, even crashed ones
    jupyter notebook list |
        Use-Parse "localhost:(\d+)" |
        foreach{ jupyter notebook stop $psitem }
}