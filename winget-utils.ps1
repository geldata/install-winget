# Shared utilities for winget version management

function Normalize-Version([string]$v) {
    # turn "v1.11.430" -> "1.11.430"; "1.11" -> "1.11.0" for [version]
    $v = $v.Trim().TrimStart('v','V')
    if ($v -match '^\d+(\.\d+){2,3}$') { return $v }
    if ($v -match '^\d+\.\d+$')        { return "$v.0" }
    if ($v -match '^\d+$')             { return "$v.0.0" }
    return $v
}

function Parse-Comparators([string]$spec) {
    $comparators = @()
    foreach ($token in ($spec -split '\s+')) {
        if (-not $token) { continue }
        if ($token -match '^(<=|>=|<|>|=)?\s*(\d+(\.\d+){0,3})$') {
            $op = if ($matches[1]) { $matches[1] } else { '=' }
            $ver = [version](Normalize-Version $matches[2])
            $comparators += @{ op = $op; ver = $ver }
        } else {
            throw "Unsupported version token '$token' in spec '$spec'."
        }
    }
    return ,$comparators
}

function Satisfies-Comparators([version]$v, $comparators) {
    foreach ($c in $comparators) {
        switch ($c.op) {
            '='  { if ($v -ne $c.ver) { return $false } }
            '>'  { if ($v -le $c.ver) { return $false } }
            '<'  { if ($v -ge $c.ver) { return $false } }
            '>=' { if ($v -lt $c.ver) { return $false } }
            '<=' { if ($v -gt $c.ver) { return $false } }
        }
    }
    return $true
}

function Test-VersionSatisfiesSpec([version]$installedVersion, [string]$spec) {
    $spec = $spec.Trim()
    if ($spec -eq '' -or $spec -eq 'latest') {
        # For 'latest', we need to fetch releases to compare
        return $false
    }
    if ($spec -match '^\=') { $spec = $spec.Substring(1) }

    # Handle exact version matches
    if ($spec -match '^\d+(\.\d+){2,3}$') {
        $targetVersion = [version](Normalize-Version $spec)
        return $installedVersion -eq $targetVersion
    }

    # Handle prefix matches like "1.11" or "1.11.x"
    if ($spec -match '^\d+(\.\d+)?(\.x)?$') {
        $prefix = ($spec -replace '\.x$','').TrimEnd('.')
        $normalizedPrefix = Normalize-Version $prefix
        $prefixParts = $normalizedPrefix.Split('.')
        $installedParts = $installedVersion.ToString().Split('.')

        # Check if installed version starts with the prefix
        for ($i = 0; $i -lt $prefixParts.Length -and $i -lt $installedParts.Length; $i++) {
            if ($prefixParts[$i] -ne $installedParts[$i]) {
                return $false
            }
        }
        return $true
    }

    # Handle comparator expressions
    try {
        $comparators = Parse-Comparators $spec
        return Satisfies-Comparators $installedVersion $comparators
    } catch {
        # If we can't parse the spec, we need to fetch releases
        return $false
    }
}

function Get-InstalledWingetVersion {
    try {
        $v = winget --version
        if ($LASTEXITCODE -ne 0) { return $null }
        return [version]($v -replace '[^\d\.]')
    } catch { return $null }
}

function Select-Version([string]$spec, $releases) {
    $spec = $spec.Trim()
    if ($spec -eq '' -or $spec -eq 'latest') { return $releases[0] }
    if ($spec -match '^\=') { $spec = $spec.Substring(1) }

    if ($spec -match '^\d+(\.\d+)?(\.x)?$') {
        $prefix = ($spec -replace '\.x$','').TrimEnd('.')
        return $releases | Where-Object {
            $_.Version.ToString().StartsWith((Normalize-Version $prefix).Split('.')[0..1] -join '.')
        } | Select-Object -First 1
    }

    if ($spec -match '^\d+(\.\d+){2,3}$') {
        return $releases | Where-Object { $_.Version.ToString() -eq (Normalize-Version $spec) } | Select-Object -First 1
    }

    $comparators = Parse-Comparators $spec
    foreach ($r in $releases) {
        $rv = $r.Version
        if (Satisfies-Comparators $rv $comparators) { return $r }
    }
    return $null
}
