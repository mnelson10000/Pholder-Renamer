# --- CONFIGURATION ---
$ApiKey = "PUT_YOUR_PHISH.NET_PRIVATE_KEY_HERE"
$DefaultStartDir = $PWD.Path 
# ---------------------

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

# --- HELPER FUNCTIONS ---

Function Select-TargetFolder {
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowser.Description = "Select the folder containing Phish shows"
    $FolderBrowser.SelectedPath = $DefaultStartDir
    $FolderBrowser.ShowNewFolderButton = $false

    $Result = $FolderBrowser.ShowDialog()
    if ($Result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $FolderBrowser.SelectedPath
    }
    return $null
}

Function Fix-Mojibake {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $Text }
    try {
        $Bytes = [System.Text.Encoding]::GetEncoding(28591).GetBytes($Text)
        return [System.Text.Encoding]::UTF8.GetString($Bytes)
    }
    catch { return $Text }
}

Function Get-PhishShow {
    param($ShowDate)
    try {
        # Check if user forgot to update the key
        if ($ApiKey -eq "PUT_YOUR_KEY_HERE") {
            Write-Host "ERROR: You have not updated the `$ApiKey variable at the top of the script!" -ForegroundColor Red
            return $null
        }

        $Url = "https://api.phish.net/v5/shows/showdate/${ShowDate}.json?apikey=$ApiKey"
        $Response = Invoke-RestMethod -Uri $Url -Method Get -ErrorAction Stop
        
        if ($Response.data -and $Response.data.count -gt 0) {
            return $Response.data[0]
        } else {
            Write-Host "API Warning: No show found for date $ShowDate" -ForegroundColor Yellow
        }
    }
    catch { 
        Write-Host "API ERROR for $ShowDate : $($_.Exception.Message)" -ForegroundColor Red
    }
    return $null
}

Function Show-RenameDialog {
    param(
        [string]$OriginalName,
        [string]$SuggestedName
    )

    $Form = New-Object System.Windows.Forms.Form
    $Form.Text = "Confirm Rename"
    $Form.Width = 900
    $Form.Height = 240
    $Form.StartPosition = "CenterScreen"
    $Form.FormBorderStyle = "FixedDialog"
    $Form.MaximizeBox = $false
    $Form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

    # Label: Original
    $lblOrig = New-Object System.Windows.Forms.Label
    $lblOrig.Location = New-Object System.Drawing.Point(20, 15)
    $lblOrig.Size = New-Object System.Drawing.Size(840, 20)
    $lblOrig.Text = "Original Name (Reference):"
    $lblOrig.ForeColor = "Gray"
    $Form.Controls.Add($lblOrig)

    # Text: Original (ReadOnly)
    $txtOrig = New-Object System.Windows.Forms.TextBox
    $txtOrig.Location = New-Object System.Drawing.Point(20, 38)
    $txtOrig.Size = New-Object System.Drawing.Size(840, 25)
    $txtOrig.Text = $OriginalName
    $txtOrig.ReadOnly = $true
    $Form.Controls.Add($txtOrig)

    # Label: New
    $lblNew = New-Object System.Windows.Forms.Label
    $lblNew.Location = New-Object System.Drawing.Point(20, 75)
    $lblNew.Size = New-Object System.Drawing.Size(840, 20)
    $lblNew.Text = "New Name (Editable):"
    $Form.Controls.Add($lblNew)

    # Text: New (Editable)
    $txtNew = New-Object System.Windows.Forms.TextBox
    $txtNew.Location = New-Object System.Drawing.Point(20, 98)
    $txtNew.Size = New-Object System.Drawing.Size(840, 25)
    $txtNew.Text = $SuggestedName
    $Form.Controls.Add($txtNew)

    # BUTTONS
    $btnAbort = New-Object System.Windows.Forms.Button
    $btnAbort.Location = New-Object System.Drawing.Point(20, 145)
    $btnAbort.Size = New-Object System.Drawing.Size(120, 30)
    $btnAbort.Text = "STOP / ABORT"
    $btnAbort.ForeColor = "Red"
    $btnAbort.DialogResult = [System.Windows.Forms.DialogResult]::Abort
    $Form.Controls.Add($btnAbort)

    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Location = New-Object System.Drawing.Point(650, 145)
    $btnOK.Size = New-Object System.Drawing.Size(100, 30)
    $btnOK.Text = "Rename"
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $Form.Controls.Add($btnOK)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Location = New-Object System.Drawing.Point(760, 145)
    $btnCancel.Size = New-Object System.Drawing.Size(100, 30)
    $btnCancel.Text = "Skip"
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $Form.Controls.Add($btnCancel)

    $Form.AcceptButton = $btnOK
    $Form.CancelButton = $btnCancel

    $Form.Add_Load({ 
        $Form.ActiveControl = $txtNew
        $txtNew.Select($txtNew.Text.Length, 0)
    })

    $result = $Form.ShowDialog()
    
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) { return $txtNew.Text }
    elseif ($result -eq [System.Windows.Forms.DialogResult]::Abort) { return "ABORT_LOOP" }
    return $null
}

# --- MAIN SCRIPT ---

# 1. Select Folder (Defaults to Current Directory)
Write-Host "Please select a folder..." -ForegroundColor Cyan
$SelectedDir = Select-TargetFolder

if (-not $SelectedDir) {
    Write-Host "No folder selected. Exiting." -ForegroundColor Yellow
    exit
}

$Dirs = Get-ChildItem -Path $SelectedDir -Directory | Sort-Object Name
$Total = $Dirs.Count
$Count = 0

foreach ($Dir in $Dirs) {
    $Count++
    $OriginalName = $Dir.Name
    $FullPath = $Dir.FullName
    $DetectedDate = $null
    
    # Initialize Tag Placeholders
    $SourceTag = ""
    $SpecialTag = "" 
    $ShnidTag = ""
    $SetTag = ""
    $PartialTag = ""
    $SoundcheckTag = ""

    Write-Progress -Activity "Renaming Phish Shows" -Status "Processing: $OriginalName" -PercentComplete (($Count / $Total) * 100)

    # 2. Detect Date
    if ($OriginalName -match "(\d{4}-\d{2}-\d{2})") {
        $DetectedDate = $matches[1]
    } else {
        $Prompt = "Date not found in:`n$OriginalName`n`nEnter Date (YYYY-MM-DD):"
        $DetectedDate = [Microsoft.VisualBasic.Interaction]::InputBox($Prompt, "Manual Date Entry", "")
        if ([string]::IsNullOrWhiteSpace($DetectedDate)) { continue }
    }

    # 3. Detect "dhmatrix"
    if ($OriginalName -match "(?i)dhmatrix") {
        $SpecialTag = "(dhmatrix)"
    }

    # 4. Detect SHNID (6 digits separated by periods)
    if ($OriginalName -match "\.(\d{6})\.") {
        $ShnidTag = "($($matches[1]))"
    }

    # 5. NEW: Detect Soundcheck (Looking for "sndchk" or "soundcheck")
    if ($OriginalName -match "(?i)(sndchk|soundcheck)") {
        $SoundcheckTag = "(Soundcheck)"
    }

    # 6. Detect Sets (Smart "Set 2 & 3" logic)
    $SetMatches = [Regex]::Matches($OriginalName, "[._-]set(\d+)", "IgnoreCase")
    if ($SetMatches.Count -gt 0) {
        $SetNums = $SetMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
        $JoinedSets = $SetNums -join " & "
        $SetTag = "(Set $JoinedSets)"
    }

    # 7. Detect Partial
    if ($OriginalName -match "[._-]partial") {
        $PartialTag = "(Partial)"
    }

    # 8. Detect Source / FLAC
    if ($OriginalName -match "((?:\[|\().+(?:\]|\)))$") {
        $RawTag = $matches[1]
        # Remove (dhmatrix) from the tail tag to avoid duplication
        $SourceTag = $RawTag -replace "(?i)\(dhmatrix\)", "" 
        $SourceTag = $SourceTag.Trim()
    } 
    elseif ($OriginalName -match "(?i)(flac[\s\.\d\-]+)") {
        $RawFlac = $matches[1]
        $CleanFlac = $RawFlac -replace "^[\.\s]+", "" -replace "-", ""
        $CleanFlac = $CleanFlac.ToUpper()
        $SourceTag = "[$CleanFlac]"
    }

    # 9. Query API
    $ShowData = Get-PhishShow -ShowDate $DetectedDate

    if ($ShowData) {
        # FIX ENCODING (Mojibake Fix)
        $City    = Fix-Mojibake -Text $ShowData.city
        $State   = Fix-Mojibake -Text $ShowData.state
        $Country = Fix-Mojibake -Text $ShowData.country
        $VenueRaw = Fix-Mojibake -Text $ShowData.venue
        
        $Venue = $VenueRaw -replace '[\\/:*?"<>|]', '' 
        
        # SMART JOIN LOCATION
        $LocParts = @()
        if (-not [string]::IsNullOrWhiteSpace($City)) { $LocParts += $City }
        if (-not [string]::IsNullOrWhiteSpace($State)) { $LocParts += $State }
        if ($Country -ne "USA") { $LocParts += $Country }
        $LocationStr = $LocParts -join ", "

        # BUILD NAME
        # Base: Date Location - Venue
        $SuggestedName = "$DetectedDate $LocationStr - $Venue"
        
        # Append SHNID
        if ($ShnidTag) { $SuggestedName = "$SuggestedName $ShnidTag" }

        # Append Soundcheck (Before Sets)
        if ($SoundcheckTag) { $SuggestedName = "$SuggestedName $SoundcheckTag" }

        # Append Set Info
        if ($SetTag) { $SuggestedName = "$SuggestedName $SetTag" }

        # Append Partial Info
        if ($PartialTag) { $SuggestedName = "$SuggestedName $PartialTag" }

        # Append Special Tag (dhmatrix)
        if ($SpecialTag) { $SuggestedName = "$SuggestedName $SpecialTag" }

        # Append Source Tag
        if ($SourceTag) { $SuggestedName = "$SuggestedName $SourceTag" }

        # SHOW DIALOG
        if ($OriginalName -ne $SuggestedName) {
            $FinalName = Show-RenameDialog -OriginalName $OriginalName -SuggestedName $SuggestedName

            if ($FinalName -eq "ABORT_LOOP") {
                Write-Host "Aborted by user." -ForegroundColor Red
                break
            }

            if (-not [string]::IsNullOrWhiteSpace($FinalName)) {
                if ($OriginalName -ne $FinalName) {
                    try {
                        Rename-Item -LiteralPath $FullPath -NewName $FinalName -ErrorAction Stop
                    } catch {
                        [System.Windows.Forms.MessageBox]::Show("Error renaming: $($_.Exception.Message)", "Error", 0, 16)
                    }
                }
            }
        }
    }
}

Write-Progress -Activity "Renaming Phish Shows" -Completed
Write-Host "Batch processing complete." -ForegroundColor Green