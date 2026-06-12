param(
  [string]$OutFile = 'gt7_car_list.json'
)

$ErrorActionPreference = 'Stop'

$api = 'https://gran-turismo.fandom.com/api.php'

function Get-WikiText([string]$Page) {
  $encPage = [uri]::EscapeDataString($Page)
  $url = "${api}?action=parse&page=$encPage&prop=wikitext&format=json&formatversion=2"
  $data = Invoke-RestMethod -Uri $url -Headers @{ 'User-Agent' = 'Gt7CarListExtractor/1.0' }
  if ($null -ne $data.error) {
    throw ("API error for {0}: {1}" -f $Page, ($data.error | ConvertTo-Json -Compress))
  }
  $data.parse.wikitext
}

function Get-PagesWikitext([string[]]$Pages) {
  $titles = [string]::Join('|', $Pages)
  $encTitles = [uri]::EscapeDataString($titles)
  $url = "${api}?action=query&prop=revisions&rvslots=main&rvprop=content&format=json&formatversion=2&titles=$encTitles"
  $data = Invoke-RestMethod -Uri $url -Headers @{ 'User-Agent' = 'Gt7CarListExtractor/1.0' }
  if ($null -ne $data.error) {
    throw ("API error: {0}" -f ($data.error | ConvertTo-Json -Compress))
  }

  $result = @{}
  foreach ($p in $data.query.pages) {
    if ($p.missing -eq $true) { continue }
    if ($null -eq $p.revisions -or $p.revisions.Count -lt 1) { continue }
    $result[$p.title] = $p.revisions[0].slots.main.content
  }
  $result
}

$carListWikitext = Get-WikiText 'Gran_Turismo_7/Car_List'

$sections = @()
$currentManufacturer = $null

foreach ($lineRaw in ($carListWikitext -split "`n")) {
  $line = $lineRaw.TrimEnd("`r")

  if ($line -match '^==\s*\[\[(.+?)\]\].*==\s*$') {
    $link = $Matches[1]
    $currentManufacturer = if ($link -match '\|') { ($link -split '\|', 2)[1].Trim() } else { $link.Trim() }
    continue
  }

  if ($line -match '^\{\{\s*(CarListing/GT7/[^\}]+?)\s*\}\}\s*$') {
    if ($null -ne $currentManufacturer) {
      $sections += [pscustomobject]@{
        manufacturer = $currentManufacturer
        templatePage = ('Template:' + $Matches[1].Trim())
      }
    }
  }
}

$carInvocationRegex = [regex]::new('\{\{\s*CarListing(?!Table)[^{}]*?\}\}', [System.Text.RegularExpressions.RegexOptions]::Singleline)

$cars = New-Object System.Collections.Generic.List[object]

$manufacturerByTemplate = @{}
foreach ($s in $sections) {
  $manufacturerByTemplate[$s.templatePage] = $s.manufacturer
}

$templatePages = @($sections | ForEach-Object { $_.templatePage })

for ($offset = 0; $offset -lt $templatePages.Count; $offset += 50) {
  $batch = $templatePages[$offset..([Math]::Min($offset + 49, $templatePages.Count - 1))]
  $templatesWikitext = Get-PagesWikitext $batch

  foreach ($templateTitle in $templatesWikitext.Keys) {
    $templateWikitext = $templatesWikitext[$templateTitle]
    $manufacturer = $manufacturerByTemplate[$templateTitle]

    foreach ($m in $carInvocationRegex.Matches($templateWikitext)) {
      $inv = $m.Value
      if ($inv.Length -lt 4) { continue }

      $inner = $inv.Substring(2, $inv.Length - 4).Trim()
      $parts = @($inner -split '\|' | ForEach-Object { $_.Trim() })
      if ($parts.Count -lt 2) { continue }

      $params = @{}
      for ($i = 1; $i -lt $parts.Count; $i++) {
        $p = $parts[$i]
        if (-not $p) { continue }

        $eq = $p.IndexOf('=')
        if ($eq -lt 1) { continue }

        $k = $p.Substring(0, $eq).Trim().ToLowerInvariant()
        $v = $p.Substring($eq + 1).Trim()
        $params[$k] = $v
      }

      if (-not $params.ContainsKey('car')) { continue }

      $carName = [System.Net.WebUtility]::HtmlDecode($params['car']).Trim()
      if (-not $carName) { continue }

      $group = $null
      if ($params.ContainsKey('group')) {
        $g = [System.Net.WebUtility]::HtmlDecode($params['group']).Trim()
        if ($g) {
          if ($g -notmatch '^Gr\.') {
            $g = 'Gr.' + $g
          }
          $group = $g
        }
      }

      $cars.Add([pscustomobject]@{
        name = $carName
        manufacturer = $manufacturer
        group = $group
      })
    }
  }
}

$json = $cars | ConvertTo-Json -Compress -Depth 6

[System.IO.File]::WriteAllText((Join-Path (Get-Location) $OutFile), $json, [System.Text.Encoding]::UTF8)

Write-Output ("TOTAL_COUNT=" + $cars.Count)
