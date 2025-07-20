# ========================================
# MacSniff - Beautiful MAC Check Tool V2
# Windows PowerShell Version
# ========================================

param(
    [Parameter(Mandatory=$false)]
    [string]$query,
    
    [Parameter(Mandatory=$false)]
    [string]$xmlPath = "mac_database.xml",
    
    [Parameter(Mandatory=$false)]
    [switch]$searchVendor,
    
    [Parameter(Mandatory=$false)]
    [switch]$interactive
)

# Color scheme
$colors = @{
    'Header' = 'Magenta'
    'Success' = 'Green' 
    'Info' = 'Cyan'
    'Warning' = 'Yellow'
    'Error' = 'Red'
    'Highlight' = 'White'
    'Subtle' = 'DarkGray'
}

function Show-Banner {
    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor $colors.Header
    Write-Host "                    MacSniff v2.0                               " -ForegroundColor $colors.Header
    Write-Host "              Made by MANA BrotherHood                " -ForegroundColor $colors.Header
    Write-Host "=================================================================" -ForegroundColor $colors.Header
    Write-Host ""
}

function Show-Menu {
    Write-Host "+- Choose your search type -----------------------------------+" -ForegroundColor $colors.Info
    Write-Host "| [1] Search by MAC Address (e.g., xx:xx:xx:xx:xx:xx)         |" -ForegroundColor $colors.Info
    Write-Host "| [2] Search by Vendor Name (e.g., intel, apple, cisco)       |" -ForegroundColor $colors.Info
    Write-Host "| [3] Show Database Stats                                     |" -ForegroundColor $colors.Info
    Write-Host "| [4] Exit                                                    |" -ForegroundColor $colors.Info
    Write-Host "+-------------------------------------------------------------+" -ForegroundColor $colors.Info
    Write-Host ""
}

function Get-DatabaseStats {
    param([string]$XmlFilePath)
    
    if (-not (Test-Path $XmlFilePath)) {
        Write-Host "ERROR: Database file not found!" -ForegroundColor $colors.Error
        return
    }
    
    try {
        [xml]$xmlContent = Get-Content $XmlFilePath
        $totalEntries = $xmlContent.MacSniffDB.VendorMapping.Count
        
        # Get unique vendors
        $uniqueVendors = $xmlContent.MacSniffDB.VendorMapping.vendor_name | Sort-Object -Unique
        
        # Get top vendors by count
        $vendorCounts = $xmlContent.MacSniffDB.VendorMapping | Group-Object vendor_name | Sort-Object Count -Descending | Select-Object -First 5
        
        Write-Host "Database Statistics" -ForegroundColor $colors.Header
        Write-Host "=============================================================" -ForegroundColor $colors.Subtle
        Write-Host "Total MAC Prefixes: $totalEntries" -ForegroundColor $colors.Success
        Write-Host "Unique Vendors: $($uniqueVendors.Count)" -ForegroundColor $colors.Success
        Write-Host ""
        Write-Host "Top 5 Vendors by MAC Count:" -ForegroundColor $colors.Warning
        
        foreach ($vendor in $vendorCounts) {
            $barLength = [Math]::Min(20, [Math]::Max(1, [int]($vendor.Count / $vendorCounts[0].Count * 20)))
            $bar = "#" * $barLength
            Write-Host "   $($vendor.Name): $($vendor.Count) " -NoNewline -ForegroundColor $colors.Info
            Write-Host $bar -ForegroundColor $colors.Header
        }
        Write-Host ""
        
    } catch {
        Write-Host "ERROR: Error reading database: $($_.Exception.Message)" -ForegroundColor $colors.Error
    }
}

function Search-MacAddress {
    param(
        [string]$MacAddress,
        [string]$XmlFilePath
    )
    
    if (-not (Test-Path $XmlFilePath)) {
        Write-Host "ERROR: XML database file not found at: $XmlFilePath" -ForegroundColor $colors.Error
        return
    }
    
    $normalizedMac = $MacAddress -replace '[:-]', '' 
    $normalizedMac = $normalizedMac.ToUpper()
    
    if ($normalizedMac.Length -lt 6) {
        Write-Host "ERROR: Invalid MAC address format" -ForegroundColor $colors.Error
        return
    }
    
    try {
        [xml]$xmlContent = Get-Content $XmlFilePath
        
        $bestMatch = $null
        $bestMatchLength = 0
        
        foreach ($mapping in $xmlContent.MacSniffDB.VendorMapping) {
            $dbPrefix = $mapping.mac_prefix -replace '[:-]', ''
            $dbPrefix = $dbPrefix.ToUpper()
            
            if ($normalizedMac.StartsWith($dbPrefix)) {
                if ($dbPrefix.Length -gt $bestMatchLength) {
                    $bestMatch = $mapping
                    $bestMatchLength = $dbPrefix.Length
                }
            }
        }
        
        Write-Host "MAC Address Search Results" -ForegroundColor $colors.Header
        Write-Host "=============================================================" -ForegroundColor $colors.Subtle
        
        if ($bestMatch) {
            $formattedMac = Format-MacAddress $MacAddress
            Write-Host "SUCCESS: Match found!" -ForegroundColor $colors.Success
            Write-Host "MAC Address: " -NoNewline -ForegroundColor $colors.Info
            Write-Host $formattedMac -ForegroundColor $colors.Highlight
            Write-Host "Vendor: " -NoNewline -ForegroundColor $colors.Info
            Write-Host $bestMatch.vendor_name -ForegroundColor $colors.Highlight
            Write-Host "Matching Prefix: " -NoNewline -ForegroundColor $colors.Info
            Write-Host $bestMatch.mac_prefix -ForegroundColor $colors.Warning
        } else {
            Write-Host "ERROR: No vendor found for MAC address: $MacAddress" -ForegroundColor $colors.Error
        }
        
    } catch {
        Write-Host "ERROR: Error parsing XML file: $($_.Exception.Message)" -ForegroundColor $colors.Error
    }
    Write-Host ""
}

function Search-VendorName {
    param(
        [string]$SearchTerm,
        [string]$XmlFilePath
    )
    
    if (-not (Test-Path $XmlFilePath)) {
        Write-Host "ERROR: XML database file not found at: $XmlFilePath" -ForegroundColor $colors.Error
        return
    }
    
    try {
        [xml]$xmlContent = Get-Content $XmlFilePath
        
        $searchPattern = $SearchTerm.ToLower()
        $matches = @()
        
        foreach ($mapping in $xmlContent.MacSniffDB.VendorMapping) {
            $vendorName = $mapping.vendor_name.ToLower()
            if ($vendorName -like "*$searchPattern*") {
                $matches += $mapping
            }
        }
        
        Write-Host "Vendor Name Search Results" -ForegroundColor $colors.Header
        Write-Host "=============================================================" -ForegroundColor $colors.Subtle
        Write-Host "Search Pattern: *$SearchTerm*" -ForegroundColor $colors.Info
        Write-Host "Found $($matches.Count) result(s)" -ForegroundColor $colors.Success
        Write-Host ""
        
        if ($matches.Count -gt 0) {
            if ($matches.Count -gt 10) {
                Write-Host "WARNING: Showing first 10 results (total: $($matches.Count))" -ForegroundColor $colors.Warning
                Write-Host ""
            }
            
            $sortedMatches = $matches | Sort-Object vendor_name | Select-Object -First 10
            
            $counter = 1
            foreach ($match in $sortedMatches) {
                $formattedPrefix = Format-MacPrefix $match.mac_prefix
                Write-Host "[$counter] " -NoNewline -ForegroundColor $colors.Subtle
                Write-Host $formattedPrefix -NoNewline -ForegroundColor $colors.Warning
                Write-Host " -> " -NoNewline -ForegroundColor $colors.Subtle
                Write-Host $match.vendor_name -ForegroundColor $colors.Highlight
                $counter++
            }
        } else {
            Write-Host "ERROR: No vendors found matching: *$SearchTerm*" -ForegroundColor $colors.Error
        }
        
    } catch {
        Write-Host "ERROR: Error parsing XML file: $($_.Exception.Message)" -ForegroundColor $colors.Error
    }
    Write-Host ""
}

function Format-MacAddress {
    param([string]$mac)
    
    $cleanMac = $mac -replace '[:-]', ''
    $formatted = ""
    for ($i = 0; $i -lt $cleanMac.Length; $i += 2) {
        if ($i -gt 0) { $formatted += ":" }
        $formatted += $cleanMac.Substring($i, [Math]::Min(2, $cleanMac.Length - $i))
    }
    return $formatted.ToLower()
}

function Format-MacPrefix {
    param([string]$prefix)
    
    $cleanPrefix = $prefix -replace '[:-]', ''
    $formatted = ""
    for ($i = 0; $i -lt $cleanPrefix.Length; $i += 2) {
        if ($i -gt 0) { $formatted += ":" }
        $formatted += $cleanPrefix.Substring($i, [Math]::Min(2, $cleanPrefix.Length - $i))
    }
    return $formatted.ToLower()
}

function Start-InteractiveMode {
    param([string]$XmlFilePath)
    
    Show-Banner
    
    while ($true) {
        Show-Menu
        $choice = Read-Host "Enter your choice (1-4)"
        
        switch ($choice) {
            "1" {
                Write-Host ""
                $macInput = Read-Host "Enter MAC address (e.g., xx:xx:xx:xx:xx:xx)"
                if ($macInput) {
                    Write-Host ""
                    Search-MacAddress -MacAddress $macInput -XmlFilePath $XmlFilePath
                }
            }
            "2" {
                Write-Host ""
                $vendorInput = Read-Host "Enter vendor name or part of it (e.g., intel, apple)"
                if ($vendorInput) {
                    Write-Host ""
                    Search-VendorName -SearchTerm $vendorInput -XmlFilePath $XmlFilePath
                }
            }
            "3" {
                Write-Host ""
                Get-DatabaseStats -XmlFilePath $XmlFilePath
            }
            "4" {
                Write-Host ""
                Write-Host "Thanks for using MacSniff! Goodbye!" -ForegroundColor $colors.Success
                Write-Host ""
                break
            }
            default {
                Write-Host ""
                Write-Host "ERROR: Invalid choice. Please select 1-4." -ForegroundColor $colors.Error
                Write-Host ""
            }
        }
        
        if ($choice -ne "4") {
            Write-Host "Press any key to continue..." -ForegroundColor $colors.Subtle
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            Clear-Host
            Show-Banner
        }
    }
}

# Main execution
if ($interactive -or (-not $query)) {
    Start-InteractiveMode -XmlFilePath $xmlPath
} elseif ($searchVendor) {
    Show-Banner
    Search-VendorName -SearchTerm $query -XmlFilePath $xmlPath
} else {
    Show-Banner
    Search-MacAddress -MacAddress $query -XmlFilePath $xmlPath
}