#Requires -Version 5.1
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$GameSub = 'steamapps\common\Mount & Blade II Bannerlord\Modules'

# -- Steam Detection ----------------------------------------------------------

function Get-SteamPath {
    $registryPaths = @(
        'HKCU:\Software\Valve\Steam',
        'HKLM:\SOFTWARE\Valve\Steam',
        'HKLM:\SOFTWARE\Wow6432Node\Valve\Steam'
    )
    $valueNames = @('SteamPath', 'InstallPath')
    foreach ($regPath in $registryPaths) {
        foreach ($valueName in $valueNames) {
            try {
                $value = Get-ItemPropertyValue -Path $regPath -Name $valueName -ErrorAction SilentlyContinue
                if ($value) { return ([System.IO.Path]::GetFullPath(($value -replace '/', '\'))) }
            } catch {}
        }
    }
    return $null
}

function Find-ModulesFolder {
    $steamPath = Get-SteamPath
    if ($steamPath) {
        $candidate = Join-Path $steamPath $GameSub
        if (Test-Path $candidate) { return $candidate }
        $vdfPath = Join-Path $steamPath 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdfPath) {
            $vdfContent = Get-Content $vdfPath -Raw
            $extraPaths = [regex]::Matches($vdfContent, '"path"\s+"([^"]+)"') |
                ForEach-Object { $_.Groups[1].Value -replace '\\\\', '\' -replace '/', '\' }
            foreach ($libPath in $extraPaths) {
                $candidate = Join-Path $libPath $GameSub
                if (Test-Path $candidate) { return $candidate }
            }
        }
    }
    $drives = [System.IO.DriveInfo]::GetDrives() |
        Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady } |
        Select-Object -ExpandProperty RootDirectory
    $commonPaths = @('Steam','Program Files\Steam','Program Files (x86)\Steam','SteamLibrary','Games\Steam')
    foreach ($drive in $drives) {
        foreach ($common in $commonPaths) {
            $candidate = Join-Path $drive $common | Join-Path -ChildPath $GameSub
            if (Test-Path $candidate) { return $candidate }
        }
    }
    return $null
}

# -- Custom controls via Add-Type ---------------------------------------------

Add-Type -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

public class CardPanel : Panel {
    private int _cornerRadius;
    private Color _borderColor;

    public CardPanel() {
        _cornerRadius = 8;
        _borderColor = Color.FromArgb(33, 38, 45);
        this.DoubleBuffered = true;
    }

    public int CornerRadius {
        get { return _cornerRadius; }
        set { _cornerRadius = value; Invalidate(); }
    }

    public Color BorderColor {
        get { return _borderColor; }
        set { _borderColor = value; Invalidate(); }
    }

    private GraphicsPath GetRoundedPath(Rectangle r, int radius) {
        GraphicsPath path = new GraphicsPath();
        path.AddArc(r.X, r.Y, radius * 2, radius * 2, 180, 90);
        path.AddArc(r.Right - radius * 2, r.Y, radius * 2, radius * 2, 270, 90);
        path.AddArc(r.Right - radius * 2, r.Bottom - radius * 2, radius * 2, radius * 2, 0, 90);
        path.AddArc(r.X, r.Bottom - radius * 2, radius * 2, radius * 2, 90, 90);
        path.CloseFigure();
        return path;
    }

    protected override void OnPaintBackground(PaintEventArgs e) {
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        using (SolidBrush brush = new SolidBrush(this.BackColor))
        using (GraphicsPath path = GetRoundedPath(new Rectangle(0, 0, Width - 1, Height - 1), _cornerRadius))
            e.Graphics.FillPath(brush, path);
    }

    protected override void OnPaint(PaintEventArgs e) {
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        using (Pen pen = new Pen(_borderColor, 1))
        using (GraphicsPath path = GetRoundedPath(new Rectangle(0, 0, Width - 1, Height - 1), _cornerRadius))
            e.Graphics.DrawPath(pen, path);
    }
}

public class ModernProgressBar : Control {
    private int _value;
    private int _maximum;
    private Color _barColor;
    private Color _bgColor;

    public ModernProgressBar() {
        _value = 0;
        _maximum = 100;
        _barColor = Color.FromArgb(47, 129, 247);
        _bgColor = Color.FromArgb(33, 38, 45);
        this.DoubleBuffered = true;
    }

    public int Value {
        get { return _value; }
        set { _value = Math.Max(0, Math.Min(_maximum, value)); Invalidate(); }
    }

    public int Maximum {
        get { return _maximum; }
        set { _maximum = value; Invalidate(); }
    }

    public Color BarColor {
        get { return _barColor; }
        set { _barColor = value; Invalidate(); }
    }

    public Color BgColor {
        get { return _bgColor; }
        set { _bgColor = value; Invalidate(); }
    }

    private GraphicsPath RoundedRect(Rectangle r, int radius) {
        GraphicsPath path = new GraphicsPath();
        path.AddArc(r.X, r.Y, radius * 2, radius * 2, 180, 90);
        path.AddArc(r.Right - radius * 2, r.Y, radius * 2, radius * 2, 270, 90);
        path.AddArc(r.Right - radius * 2, r.Bottom - radius * 2, radius * 2, radius * 2, 0, 90);
        path.AddArc(r.X, r.Bottom - radius * 2, radius * 2, radius * 2, 90, 90);
        path.CloseFigure();
        return path;
    }

    protected override void OnPaint(PaintEventArgs e) {
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        int r = Height / 2;
        using (SolidBrush brush = new SolidBrush(_bgColor))
        using (GraphicsPath path = RoundedRect(new Rectangle(0, 0, Width, Height), r))
            e.Graphics.FillPath(brush, path);

        if (_maximum > 0 && _value > 0) {
            int fillW = (int)((double)_value / _maximum * Width);
            if (fillW < Height) fillW = Height;
            using (LinearGradientBrush brush = new LinearGradientBrush(
                new Rectangle(0, 0, fillW, Height),
                Color.FromArgb(56, 139, 253), _barColor,
                LinearGradientMode.Horizontal))
            using (GraphicsPath path = RoundedRect(new Rectangle(0, 0, fillW, Height), r))
                e.Graphics.FillPath(brush, path);
        }
    }
}
"@ -ReferencedAssemblies 'System.Windows.Forms','System.Drawing'

# -- Colours ------------------------------------------------------------------

$C_BG      = [System.Drawing.ColorTranslator]::FromHtml('#0d1117')
$C_Surface = [System.Drawing.ColorTranslator]::FromHtml('#161b22')
$C_Border  = [System.Drawing.ColorTranslator]::FromHtml('#21262d')
$C_Accent  = [System.Drawing.ColorTranslator]::FromHtml('#2f81f7')
$C_AccentH = [System.Drawing.ColorTranslator]::FromHtml('#388bfd')
$C_Success = [System.Drawing.ColorTranslator]::FromHtml('#3fb950')
$C_Warn    = [System.Drawing.ColorTranslator]::FromHtml('#d29922')
$C_Error   = [System.Drawing.ColorTranslator]::FromHtml('#f85149')
$C_Text    = [System.Drawing.ColorTranslator]::FromHtml('#e6edf3')
$C_TextMid = [System.Drawing.ColorTranslator]::FromHtml('#8b949e')
$C_TextDim = [System.Drawing.ColorTranslator]::FromHtml('#484f58')

$FontUI    = New-Object System.Drawing.Font('Segoe UI', 9)
$FontSmall = New-Object System.Drawing.Font('Segoe UI', 7.5)
$FontTitle = New-Object System.Drawing.Font('Segoe UI Semibold', 13)
$FontLabel = New-Object System.Drawing.Font('Segoe UI', 7, [System.Drawing.FontStyle]::Bold)
$FontBtn   = New-Object System.Drawing.Font('Segoe UI Semibold', 9)
$FontMono  = New-Object System.Drawing.Font('Consolas', 8.5)

# -- Form ---------------------------------------------------------------------

$form                 = New-Object System.Windows.Forms.Form
$form.Text            = 'Bannerlord DLL Unblock Utility'
$form.Size            = New-Object System.Drawing.Size(620, 560)
$form.MinimumSize     = New-Object System.Drawing.Size(620, 560)
$form.MaximumSize     = New-Object System.Drawing.Size(620, 560)
$form.StartPosition   = 'CenterScreen'
$form.BackColor       = $C_BG
$form.ForeColor       = $C_Text
$form.Font            = $FontUI
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox     = $false

# Icon is loaded after path detection in Add_Shown

# -- Helper: make a card panel ------------------------------------------------

function New-Card {
    param([int]$X, [int]$Y, [int]$W, [int]$H)
    $card              = New-Object CardPanel
    $card.Size         = New-Object System.Drawing.Size($W, $H)
    $card.Location     = New-Object System.Drawing.Point($X, $Y)
    $card.BackColor    = $C_Surface
    $card.BorderColor  = $C_Border
    $card.CornerRadius = 8
    $form.Controls.Add($card)
    return $card
}

# -- Header card --------------------------------------------------------------

$pnlHeader = New-Card 20 16 580 72

$lblTitle            = New-Object System.Windows.Forms.Label
$lblTitle.Text       = 'DLL Unblock Utility'
$lblTitle.Font       = $FontTitle
$lblTitle.ForeColor  = $C_Text
$lblTitle.AutoSize   = $true
$lblTitle.Location   = New-Object System.Drawing.Point(16, 12)
$pnlHeader.Controls.Add($lblTitle)

$lblSub              = New-Object System.Windows.Forms.Label
$lblSub.Text         = 'Unblocks DLL files that can/will causes crashes.'
$lblSub.Font         = $FontSmall
$lblSub.ForeColor    = $C_TextMid
$lblSub.AutoSize     = $true
$lblSub.Location     = New-Object System.Drawing.Point(17, 40)
$pnlHeader.Controls.Add($lblSub)

# -- Path card ----------------------------------------------------------------

$pnlPath = New-Card 20 100 580 90

$lblPathHeader           = New-Object System.Windows.Forms.Label
$lblPathHeader.Text      = 'MODULES FOLDER'
$lblPathHeader.Font      = $FontLabel
$lblPathHeader.ForeColor = $C_TextDim
$lblPathHeader.AutoSize  = $true
$lblPathHeader.Location  = New-Object System.Drawing.Point(16, 12)
$pnlPath.Controls.Add($lblPathHeader)

$txtPath             = New-Object System.Windows.Forms.TextBox
$txtPath.Size        = New-Object System.Drawing.Size(446, 24)
$txtPath.Location    = New-Object System.Drawing.Point(16, 32)
$txtPath.BackColor   = $C_BG
$txtPath.ForeColor   = $C_Text
$txtPath.BorderStyle = 'FixedSingle'
$txtPath.Font        = $FontUI
$pnlPath.Controls.Add($txtPath)

$btnBrowse                            = New-Object System.Windows.Forms.Button
$btnBrowse.Text                       = 'Browse'
$btnBrowse.Size                       = New-Object System.Drawing.Size(80, 24)
$btnBrowse.Location                   = New-Object System.Drawing.Point(468, 32)
$btnBrowse.BackColor                  = $C_Border
$btnBrowse.ForeColor                  = $C_Text
$btnBrowse.FlatStyle                  = 'Flat'
$btnBrowse.Font                       = $FontSmall
$btnBrowse.FlatAppearance.BorderColor = $C_Border
$pnlPath.Controls.Add($btnBrowse)

$lblDetect           = New-Object System.Windows.Forms.Label
$lblDetect.Text      = 'Searching for Modules folder...'
$lblDetect.Font      = $FontSmall
$lblDetect.ForeColor = $C_TextMid
$lblDetect.AutoSize  = $true
$lblDetect.Location  = New-Object System.Drawing.Point(17, 62)
$pnlPath.Controls.Add($lblDetect)

# -- Progress card ------------------------------------------------------------

$pnlProgress = New-Card 20 202 580 90

$lblStatusHeader           = New-Object System.Windows.Forms.Label
$lblStatusHeader.Text      = 'STATUS'
$lblStatusHeader.Font      = $FontLabel
$lblStatusHeader.ForeColor = $C_TextDim
$lblStatusHeader.AutoSize  = $true
$lblStatusHeader.Location  = New-Object System.Drawing.Point(16, 12)
$pnlProgress.Controls.Add($lblStatusHeader)

$lblStatus           = New-Object System.Windows.Forms.Label
$lblStatus.Text      = 'Ready'
$lblStatus.Font      = $FontUI
$lblStatus.ForeColor = $C_TextMid
$lblStatus.AutoSize  = $true
$lblStatus.Location  = New-Object System.Drawing.Point(16, 30)
$pnlProgress.Controls.Add($lblStatus)

$progressBar          = New-Object ModernProgressBar
$progressBar.Size     = New-Object System.Drawing.Size(548, 10)
$progressBar.Location = New-Object System.Drawing.Point(16, 58)
$progressBar.Maximum  = 100
$progressBar.Value    = 0
$progressBar.BarColor = $C_Accent
$progressBar.BgColor  = $C_Border
$pnlProgress.Controls.Add($progressBar)

$lblPercent           = New-Object System.Windows.Forms.Label
$lblPercent.Text      = ''
$lblPercent.Font      = $FontSmall
$lblPercent.ForeColor = $C_TextDim
$lblPercent.AutoSize  = $true
$lblPercent.Location  = New-Object System.Drawing.Point(16, 72)
$pnlProgress.Controls.Add($lblPercent)

# -- Log card -----------------------------------------------------------------

$pnlLog = New-Card 20 304 580 170

$lblLogHeader           = New-Object System.Windows.Forms.Label
$lblLogHeader.Text      = 'OUTPUT'
$lblLogHeader.Font      = $FontLabel
$lblLogHeader.ForeColor = $C_TextDim
$lblLogHeader.AutoSize  = $true
$lblLogHeader.Location  = New-Object System.Drawing.Point(16, 12)
$pnlLog.Controls.Add($lblLogHeader)

$txtLog             = New-Object System.Windows.Forms.RichTextBox
$txtLog.Size        = New-Object System.Drawing.Size(548, 140)
$txtLog.Location    = New-Object System.Drawing.Point(16, 28)
$txtLog.BackColor   = $C_BG
$txtLog.ForeColor   = $C_Text
$txtLog.BorderStyle = 'None'
$txtLog.ReadOnly    = $true
$txtLog.Font        = $FontMono
$txtLog.ScrollBars  = 'Vertical'
$pnlLog.Controls.Add($txtLog)

# -- Buttons ------------------------------------------------------------------

$btnUnblock                           = New-Object System.Windows.Forms.Button
$btnUnblock.Text                      = 'Unblock DLLs'
$btnUnblock.Size                      = New-Object System.Drawing.Size(140, 36)
$btnUnblock.Location                  = New-Object System.Drawing.Point(20, 492)
$btnUnblock.BackColor                 = $C_Accent
$btnUnblock.ForeColor                 = [System.Drawing.Color]::White
$btnUnblock.FlatStyle                 = 'Flat'
$btnUnblock.Font                      = $FontBtn
$btnUnblock.FlatAppearance.BorderSize = 0
$form.Controls.Add($btnUnblock)

$btnClose                             = New-Object System.Windows.Forms.Button
$btnClose.Text                        = 'Close'
$btnClose.Size                        = New-Object System.Drawing.Size(80, 36)
$btnClose.Location                    = New-Object System.Drawing.Point(520, 492)
$btnClose.BackColor                   = $C_Surface
$btnClose.ForeColor                   = $C_TextMid
$btnClose.FlatStyle                   = 'Flat'
$btnClose.Font                        = $FontBtn
$btnClose.FlatAppearance.BorderColor  = $C_Border
$form.Controls.Add($btnClose)

# -- Helpers ------------------------------------------------------------------

function Log {
    param([string]$Msg, [System.Drawing.Color]$Color = [System.Drawing.Color]::White)
    $txtLog.SelectionStart  = $txtLog.TextLength
    $txtLog.SelectionLength = 0
    $txtLog.SelectionColor  = $Color
    $txtLog.AppendText("$Msg`n")
    $txtLog.ScrollToCaret()
    $form.Refresh()
}

function Set-Status {
    param([string]$Msg, [System.Drawing.Color]$Color)
    $lblStatus.Text      = $Msg
    $lblStatus.ForeColor = $Color
    $form.Refresh()
}

# -- Browse -------------------------------------------------------------------

$btnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Select your Bannerlord Modules folder'
    if ($dlg.ShowDialog() -eq 'OK') {
        $txtPath.Text        = $dlg.SelectedPath
        $lblDetect.Text      = 'Path set manually.'
        $lblDetect.ForeColor = $C_Success
    }
})

# -- Hover effects ------------------------------------------------------------

$btnUnblock.Add_MouseEnter({ $btnUnblock.BackColor = $C_AccentH })
$btnUnblock.Add_MouseLeave({ $btnUnblock.BackColor = $C_Accent })
$btnClose.Add_MouseEnter({ $btnClose.ForeColor = $C_Text })
$btnClose.Add_MouseLeave({ $btnClose.ForeColor = $C_TextMid })

# -- Close --------------------------------------------------------------------

$btnClose.Add_Click({ $form.Close() })

# -- Unblock ------------------------------------------------------------------

$btnUnblock.Add_Click({
    $modulesPath = $txtPath.Text.Trim().Trim('"')

    if (-not $modulesPath -or -not (Test-Path $modulesPath)) {
        [System.Windows.Forms.MessageBox]::Show(
            'Please enter or browse to a valid Modules folder.',
            'Invalid Path',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }

    $btnUnblock.Enabled = $false
    $btnBrowse.Enabled  = $false
    $txtLog.Clear()
    $progressBar.Value  = 0
    $lblPercent.Text    = ''

    Set-Status 'Scanning for DLL files...' $C_TextMid
    Log '> Scanning for DLL files...' $C_TextMid

    $dlls = @(Get-ChildItem -Path $modulesPath -Recurse -Include '*.dll' -ErrorAction SilentlyContinue)
    $totalCount = $dlls.Count

    if ($totalCount -eq 0) {
        Set-Status 'No DLL files found.' $C_Warn
        Log '! No DLL files found in the Modules folder.' $C_Warn
        $btnUnblock.Enabled = $true
        $btnBrowse.Enabled  = $true
        return
    }

    Log "  Found $totalCount DLL file(s). Checking which are blocked..." $C_TextMid

    $blockedDlls = @($dlls | Where-Object {
        Get-Item -LiteralPath $_.FullName -Stream 'Zone.Identifier' -ErrorAction SilentlyContinue
    })
    $blockedCount = $blockedDlls.Count

    if ($blockedCount -eq 0) {
        Set-Status "All $totalCount DLL(s) are already unblocked." $C_Success
        Log "v All $totalCount DLL file(s) are already unblocked." $C_Success
        $progressBar.Value  = 100
        $btnUnblock.Enabled = $true
        $btnBrowse.Enabled  = $true
        return
    }

    Log "! $blockedCount of $totalCount DLL(s) are blocked. Unblocking..." $C_Warn

    $current = 0
    $skipped = @()
    $failed  = @()

    foreach ($dll in $blockedDlls) {
        $current++
        $pct = [math]::Floor(($current / $blockedCount) * 100)
        $progressBar.Value = $pct
        $lblPercent.Text   = "$current of $blockedCount files  ($pct%)"
        Set-Status "Unblocking: $($dll.Name)" $C_Accent
        $form.Refresh()

        try {
            Unblock-File -Path $dll.FullName -ErrorAction Stop
        } catch [System.UnauthorizedAccessException] {
            $skipped += $dll.FullName
            Log "  ! Skipped (access denied): $($dll.Name)" $C_Warn
        } catch {
            $failed += $dll.FullName
            Log "  x Failed: $($dll.Name)" $C_Error
        }
    }

    $progressBar.Value = 100
    $successCount = $blockedCount - $skipped.Count - $failed.Count

    Log '' $C_Text
    Log '----------------------------------------' $C_TextDim

    if ($successCount -gt 0) {
        Log "v Successfully unblocked $successCount of $blockedCount DLL(s)." $C_Success
    }
    if ($skipped.Count -gt 0) {
        Log "! $($skipped.Count) skipped (access denied) -- run as Administrator." $C_Warn
        foreach ($f in $skipped) { Log "    - $f" $C_TextMid }
    }
    if ($failed.Count -gt 0) {
        Log "x $($failed.Count) failed unexpectedly." $C_Error
        foreach ($f in $failed) { Log "    - $f" $C_TextMid }
    }

    if ($successCount -eq $blockedCount) {
        Set-Status "Done -- all $successCount DLL(s) unblocked successfully." $C_Success
        $lblPercent.Text = "Completed: $successCount files"
    } else {
        Set-Status "Finished with $($skipped.Count + $failed.Count) issue(s). Check output." $C_Warn
    }

    $btnUnblock.Enabled = $true
    $btnBrowse.Enabled  = $true
})

# -- Auto-detect on load ------------------------------------------------------

$form.Add_Shown({
    $found = Find-ModulesFolder
    if ($found) {
        $txtPath.Text        = $found
        $lblDetect.Text      = 'Modules folder detected automatically.'
        $lblDetect.ForeColor = $C_Success

        # Derive exe path from Modules folder: go up one level to game root
        $gameRoot = Split-Path $found -Parent
        $exePath  = Join-Path $gameRoot 'bin\Win64_Shipping_Client\Bannerlord.exe'
        if (Test-Path $exePath) {
            try { $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($exePath) } catch {}
        }
    } else {
        $lblDetect.Text      = 'Could not auto-detect. Please browse manually.'
        $lblDetect.ForeColor = $C_Warn
    }
})

[System.Windows.Forms.Application]::Run($form)
