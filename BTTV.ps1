$ignore = @(
	"emDface"
)

$remap = @{
	"(ditto)" = @{ code = ":ditto:"; file = "ditto" }
	":tf:" = @{ code = ":tf:"; file = "tf" }
	"M&Mjc" = @{ code = "MnMjc"; file = "MnMjc" }
	"D:" = @{ code = "emDface"; file = "D"; alias = @("D:") }
	"h!" = @{ code = ":bttvh:"; file = "h" }
	"l!" = @{ code = ":bttvl:"; file = "l" }
	"r!" = @{ code = ":bttvr:"; file = "r" }
	"v!" = @{ code = ":bttvv:"; file = "v" }
	"z!" = @{ code = ":bttvz:"; file = "z" }
	"w!" = @{ code = ":bttvw:"; file = "w" }
	"c!" = @{ code = ":bttvc:"; file = "c" }
	"BOOBA" = @{ alias = @("booba") }
	"catJAM" = @{ alias = @("CatJam", "CatJAM") }
	"pepeD" = @{ alias = @("PepeD") }
	"PepeLaugh" = @{ alias = @("FeelsKekMan") }
	"Aware" = @{ code = ":Aware:" }
}

$nameRemap = @{}
$aliasRemap = @{}

foreach ($key in $remap.Keys) {
	$file = $remap[$key].file
	$code = $remap[$key].code
	$alias = $remap[$key].alias
	if (-not $file) { $file = $key }
	if (-not $code) { $code = $key }
	if ($file -ne $code)
	{
		$nameRemap[$file] = $code
	}
	if ($alias)
	{
		$aliasRemap[$code] = $alias
	}
}

$download = $args.Contains("--download")
$keep = $args.Contains("--keep")
$combined = $args.Contains("--combined")
$save = $args.Contains("--save")
$git = $args.Contains("--git")

$cwd = Get-Item -Path "."
$baseFolder = Get-Item -Path ".\emotes\BTTV"

if ($download)
{
	$json = Invoke-WebRequest -Uri "https://chatemotes.bool.no/?json" | ConvertFrom-Json
	foreach ($item in $json)
	{
		$itemFileName = $item.code
		$itemFileNameRemap = $remap[$itemFileName]
		if ($itemFileNameRemap)
		{
			if ($itemFileNameRemap.file)
			{
				$itemFileName = $itemFileNameRemap.file
			}
			if ($itemFileNameRemap.code)
			{
				$item.code = $itemFileNameRemap.code
			}
		}
		$itemFileName = $item.code -replace "[\:]+", ""
		if ($itemFileName -match "^[A-Za-z0-9_\-]+$")
		{
			if ($ignore.Contains($itemFileName))
			{
				continue
			}
			if ($itemFileName -ne $item.code -and (-not $itemFileNameRemap -or (-not $itemFileNameRemap.code)))
			{
				Write-Warning ("""{0}"" requires manual validation: ""{1}""" -f $item.code, $itemFileName)
			}
			$itemPath = Join-Path -Path $baseFolder -ChildPath "$($itemFileName).webp"
			if (Test-Path $itemPath -PathType Leaf)
			{
				continue
			}
			Invoke-WebRequest -Uri "https://cdn.betterttv.net/emote/$($item.id)/3x.webp" -OutFile $itemPath
		}
		else
		{
			Write-Warning ("""{0}"" unhandled name contents: ""{1}""" -f $item.code, $itemFileName)
		}
	}
}

function webp_info
{
	param(
		[string] $InputFile
	)
	process
	{
		$lines = & webpinfo $InputFile
		$animated = $null
		$width = -1
		$height = -1
		$ratio = 1
		$stretch = $false
		foreach ($line in $lines)
		{
			if ($null -eq $animated -and $line -match "^\s*Animation:\s*(\d+)\s*$")
			{
				$animated = +$matches[1] -eq 1
			}
			if ($width -eq -1)
			{
				if ($line -match "^\s*Canvas\s+size\s+(\d+)\s*x\s*(\d+)\s*$")
				{
					$width = +$matches[1]
					$height = +$matches[2]
				}
				elseif ($line -match "^\s*Width:\s*(\d+)\s*$")
				{
					$width = +$matches[1]
				}
			}
			if ($height -eq -1)
			{
				if ($line -match "^\s*Height:\s*(\d+)\s*$")
				{
					$height = +$matches[1]
				}
			}
		}
		$valid = $width -gt -1 -and $height -gt -1
		if ($valid)
		{
			$ratio = $width/$height
			$stretch = $ratio -lt 0.9 -or $ratio -gt 1.1
		}
		return [PSCustomObject] @{
			Animated = $animated
			Width = $width
			Height = $height
			Ratio = $ratio
			Stretch = $stretch
			Valid = $valid
		}
	}
}

$webpFiles = Get-ChildItem -Path $baseFolder -Filter *.webp

foreach ($webpFile in $webpFiles)
{

	$name = [IO.Path]::GetFileNameWithoutExtension($webpFile)
	$webpFileInfo = webp_info $webpFile

	if (-not $webpFileInfo.Valid)
	{
		Write-Error ("""{0}"" unable to process image information" -f $name)
		continue
	}

	$outputFolderPath = Join-Path -Path $webpFile.Directory -ChildPath $name
	if (Test-Path $outputFolderPath -PathType Container)
	{
		continue
	}

	if ($webpFileInfo.Stretch) # -and (-not $webpFileInfo.Animated)
	{
		& webp_frames $webpFile @args --stretch
	}
	else
	{
		& webp_frames $webpFile @args
	}

	$folderFileSelector = Join-Path -Path $outputFolderPath -ChildPath "*_*_*_*.png"
	$folderFiles = Get-ChildItem -Path $folderFileSelector | Sort-Object { [regex]::Replace($_.Name, "\d+", { $args[0].Value.PadLeft(20) }) }
	$prevFolderFile = $null

	foreach ($folderFile in $folderFiles)
	{
		$stdoutFile = [System.IO.Path]::GetTempFileName()
		$stderrFile = [System.IO.Path]::GetTempFileName()
		$process = Start-Process -FilePath "magick" -ArgumentList "convert `"$($folderFile.FullName)`" -define png:bit-depth=8 -define png:color-type=6 -define png:compression-level=9 -define png:compression-strategy=2 -define png:filter-type=5 -define png:compression-filter=4 -define png:exclude-chunk=all -define png:transparency-threshold=128 -define png:interlace-type=0 `"$($folderFile.FullName)`"" -NoNewWindow -PassThru -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
		$process.WaitForExit()
		$stdoutText = Get-Content -Path $stdoutFile
		$stderrText = Get-Content -Path $stderrFile
		Remove-Item $stdoutFile
		Remove-Item $stderrFile
		$stdText = @()
		if ($stdoutText.Length -gt 0) { $stdText += $stdoutText }
		if ($stderrText.Length -gt 0) { $stdText += $stderrText }
		$stdText = $stdText -join "`r`n"
		if ($stdText.Length -gt 0)
		{
			if ($stdText.Contains("convert: Cannot write image with defined png:bit-depth or png:color-type."))
			{
				Write-Warning ("""{0}"" {1}" -f $name, $stdText)
				if (-not $prevFolderFile)
				{
					$prevFolderFile = $folderFiles[1]
				}
				Copy-Item $prevFolderFile $folderFile -Force
			}
			else
			{
				Write-Error ("""{0}"" {1}" -f $name, $stdText)
			}
		}
		$prevFolderFile = $folderFile
	}

}

$folders = Get-ChildItem -Path $baseFolder -Directory
$emotes = @()

foreach ($folder in $folders)
{

	$name = [IO.Path]::GetFileNameWithoutExtension($folder)
	$folderPath = $folder.FullName

	$folderFileSelector = Join-Path -Path $folderPath -ChildPath "*_*_*_*"
	$folderFilesMixed = Get-ChildItem -Path $folderFileSelector
	$animated = $true

	if ($null -eq $folderFilesMixed)
	{
		$animated = $false
		$folderFileSelector = Join-Path -Path $folderPath -ChildPath "$($name).*"
		$folderFilesMixed = Get-ChildItem -Path $folderFileSelector
	}

	$folderFilesPNG = $folderFilesMixed | Where-Object { $_.Extension -eq ".png" }
	$folderFilesBLP = $folderFilesMixed | Where-Object { $_.Extension -eq ".blp" }
	$folderFiles = if ($folderFilesPNG.Count -ge $folderFilesBLP.Count) { $folderFilesPNG } else { $folderFilesBLP }

	$emote = [PSCustomObject] @{
		Name = $name
		Folder = $folderPath.Replace($cwd.FullName, "").Substring(1)
		Frames = @()
		Duration = 0
		Width = 0
		Height = 0
		Valid = $false
		IsPNG = $folderFiles[0].Extension -eq ".png"
	}
	$emotes += $emote

	foreach ($folderFile in $folderFiles)
	{
		if (-not $animated)
		{
			$emote.Frames += [PSCustomObject] @{
				File = $folderFile
				Current = 1
				Total = 1
				Duration = 0
			}
		}
		elseif ($folderFile.Name -match "^([^_]+)_(\d+)_(\d+)_(\d+)\.(.+)$")
		{
			$current = +$matches[2]
			$total = +$matches[3]
			$duration = +$matches[4]
			$emote.Frames += [PSCustomObject] @{
				File = $folderFile
				Current = $current
				Total = $total
				Duration = $duration
			}
		}
	}

	if ($emote.Frames.Count -eq 0)
	{
		Write-Error ("""{0}"" has no frames" -f $name)
		continue
	}

	if ($emote.Frames.Count -eq 1)
	{
		$animated = $false
		foreach ($frame in $emote.Frames)
		{
			$singleFilePath = Join-Path -Path $frame.File.Directory -ChildPath "$($name)$($frame.File.Extension)"
			Move-Item -Path $frame.File -Destination $singleFilePath
			$frame.File = Get-Item -LiteralPath $singleFilePath
		}
	}

	$emote.Frames = $emote.Frames | Sort-Object -Property Current

	$firstFrame = $emote.Frames[0]
	$firstFrameInfo = & magick identify -verbose -format "%w %h" "$($firstFrame.File.FullName)"

	if (-not ($firstFrameInfo -match "^\s*(\d+)\s+(\d+)\s*$"))
	{
		Write-Error ("""{0}"" could not extract image dimensions" -f $name)
		continue
	}

	$emote.Width = +$matches[1]
	$emote.Height = +$matches[1]
	$emote.Valid = $true

	$emoteFolder = Join-Path -Path $baseFolder -ChildPath $emote.Name
	$processBLPs = @()

	foreach ($frame in $emote.Frames)
	{

		$frame.File = $frame.File.Name
		$emote.Duration += $frame.Duration

		$frameFilePathBLP = Join-Path -Path $emoteFolder -ChildPath $frame.File.Replace(".png", ".blp")

		if (Test-Path $frameFilePathBLP)
		{
			continue
		}

		$frameFilePath = Join-Path -Path $emoteFolder -ChildPath $frame.File
		$frameFile = Get-Item -LiteralPath $frameFilePath

		$processBLPs += $frameFile.FullName

	}

	if ($processBLPs.Count -gt 0)
	{

		Write-Host ("""{0}"" converting {1} PNG to BLP" -f $emote.Name, $processBLPs.Count)

		$processBLPsBatchSize = 100

		if ($processBLPs.Count -le $processBLPsBatchSize)
		{
			& blppng @processBLPs
		}
		else
		{
			for ($i = 0; $i -lt $processBLPs.Count; $i += $processBLPsBatchSize) {
				$processBLPsBatch = $processBLPs[$i .. ($i + $processBLPsBatchSize - 1)]
				& blppng @processBLPsBatch
			}
		}

		foreach ($frameFileFullName in $processBLPs)
		{

			$frameFilePathBLP = $frameFileFullName.Replace(".png", ".blp")
			$frameFileBLP = Get-Item -LiteralPath $frameFilePathBLP -ErrorAction SilentlyContinue

			if (-not $frameFileBLP -or $frameFileBLP.Length -eq 0)
			{
				Write-Error ("""{0}"" unable to convert frame ""{1}""" -f $emote.Name, $frameFileFullName)
			}

		}

	}

	if ($keep)
	{
		$emoteJsonPath = Join-Path -Path $folderPath -ChildPath "$name.json"
		$emote | ConvertTo-Json | Set-Content -Path $emoteJsonPath
	}

}

if ($keep)
{
	$emotesJsonPath = Join-Path -Path $cwd -ChildPath "BTTV.json"
	$emotes | ConvertTo-Json -Depth 3 | Set-Content -Path $emotesJsonPath
}

if ($combined)
{

	function CalculateEmoteInfo
	{

		param(
			$emote
		)

		$emoteSize = [System.Math]::Max($emote.Width, $emote.Height)
		$framesCountSqrt = [System.Math]::Sqrt($emote.Frames.Count)
		$framesCountSqrt = [System.Math]::Ceiling($framesCountSqrt)
		$framesCountSqrtSize = $emoteSize * $framesCountSqrt

		for (
			$squaredSize = 2;
			$squaredSize -lt $framesCountSqrtSize;
			$squaredSize *= 2
		) {}

		$squareSize = [System.Math]::Max($squaredSize, $emoteSize)

		$row = 0
		$col = 0
		$slots = @()
		$totalDuration = 0

		foreach ($frame in $emote.Frames)
		{

			$x = $col * $emoteSize
			$y = $row * $emoteSize

			$totalDuration += $frame.Duration

			$slots += [PSCustomObject] @{
				Frame = $frame
				X = $x
				Y = $y
				TotalDuration = $totalDuration
			}

			if (++$col -ge $framesCountSqrt)
			{
				$col = 0
				$row++
			}

		}

		return [PSCustomObject] @{
			EmoteSize = $emoteSize
			FramesCountSqrt = $framesCountSqrt
			FramesCountSqrtSize = $framesCountSqrtSize
			SquaredSize = $squaredSize
			SquareSize = $squareSize
			Slots = $slots
		}

	}

	foreach ($emote in $emotes)
	{

		if (-not $emote.IsPNG)
		{
			Write-Warning ("""{0}"" skipped because it's missing PNG frames" -f $emote.Name)
			continue
		}

		$squareEmoteOutputFolder = Join-Path -Path $baseFolder -ChildPath $emote.Name
		$squareEmoteOutputFolder = Join-Path -Path $squareEmoteOutputFolder -ChildPath ".."
		$squareImageFilePath = Join-Path -Path $squareEmoteOutputFolder -ChildPath "$($emote.Name).png"

		$emoteInfo = CalculateEmoteInfo $emote

		if (Test-Path $squareImageFilePath)
		{
			continue
		}

		Write-Host ("""{0}"" combining one animation file" -f $emote.Name)

		$squareImage = New-Object System.Drawing.Bitmap -ArgumentList $emoteInfo.SquareSize, $emoteInfo.SquareSize
		$squareGraphics = [System.Drawing.Graphics]::FromImage($squareImage)

		foreach ($slot in $emoteInfo.Slots)
		{

			$frame = $slot.Frame
			$x = $slot.X
			$y = $slot.Y

			$frameFilePath = Join-Path -Path $emoteFolder -ChildPath $frame.File
			$frameFile = Get-Item -LiteralPath $frameFilePath

			$frameImage = [System.Drawing.Image]::FromFile($frameFile)
			$squareGraphics.DrawImage($frameImage, $x, $y)
			$frameImage.Dispose()

		}

		$squareImage.Save($squareImageFilePath, [System.Drawing.Imaging.ImageFormat]::Png)
		$squareImage.Dispose()
		$squareGraphics.Dispose()

	}

}

$lua = @()
$dupeEmoteChecks = @()

foreach ($emote in $emotes)
{

	$name = $emote.Name
	$durations = [int[]]::new($emote.Frames.Count)
	$corruptFrames = 0

	foreach ($frame in $emote.Frames)
	{
		$i = $frame.Current - 1
		if ($i -gt $durations.Count)
		{
			$corruptFrames++
		}
		else
		{
			$durations[$i] = $frame.Duration
		}
	}

	if ($corruptFrames -gt 0)
	{
		Write-Error ("""{0}"" has {1} corrupt frames" -f $name, $corruptFrames)
	}

	$durationsTrimmed = @()
	$prevFrameDuration = $null

	for ($i = 0; $i -lt $durations.Count; $i++)
	{
		$frameDuration = $durations[$i]
		if ($null -eq $prevFrameDuration -or $prevFrameDuration -ne $frameDuration)
		{
			$durationsTrimmed += "[$($i + 1)] = $frameDuration"
		}
		$prevFrameDuration = $frameDuration
	}

	if ($durationsTrimmed.Count -eq 1)
	{
		$luaDuration = ", duration = $($durations[0])"
	}
	else
	{
		$luaDuration = ", duration = { $($durationsTrimmed -join ", ") }"
	}

	$luaRatio = ""
	$webpFilePath = Join-Path -Path $baseFolder -ChildPath "$($name).webp"
	if (Test-Path $webpFilePath -PathType Leaf)
	{
		$webpFileInfo = webp_info $webpFilePath
		if ($webpFileInfo.Valid)
		{
			if ($webpFileInfo.Stretch) # -and (-not $webpFileInfo.Animated)
			{
				$luaRatio = ", ratio = {0:f}" -f $webpFileInfo.Ratio
			}
		}
		else
		{
			Write-Error ("""{0}"" could not extract image dimensions" -f $name)
		}
	}
	else
	{
		Write-Warning ("""{0}"" missing original WEBP for original ratio" -f $name)
	}

	$animated = $emote.Frames.Count -gt 1
	$luaAnimated = ""
	if ($animated) 
	{
		$luaAnimated = ", animated = true"
	}
	else
	{
		$luaDuration = ""
	}

	$firstFrame = $emote.Frames[0]
	$firstFrameFile = [IO.Path]::GetFileNameWithoutExtension($firstFrame.File)
	$luaFile = "$name/$firstFrameFile"

	if ($nameRemap[$name])
	{
		$name = $nameRemap[$name]
	}

	$aliases = $aliasRemap[$name]
	if ($aliases)
	{
		$aliases = $aliases -join '", "'
		$aliases = " alias = { `"$aliases`" },"
	}
	else
	{
		$aliases = ""
	}

	if ($combined)
	{
		$luaCombinedSlots = @()
		$emoteInfo = CalculateEmoteInfo $emote
		foreach ($slot in $emoteInfo.Slots)
		{
			$luaCombinedSlots += $slot.Frame.Duration
		}
		$luaDuration = ", duration = { $($luaCombinedSlots -join ", ") }"
		$lua += "{{ name = `"{0}`",{1}{2}{3}, textureSize = {4}, contentSize = {5}{6} }}," -f $name, $aliases, $luaRatio, $luaAnimated, $emoteInfo.SquareSize, ($emoteInfo.FramesCountSqrt * $emote.Width), $luaDuration
	}
	else
	{
		$lua += "{{ name = `"{0}`",{1} file = `"{2}`"{3}{4}{5} }}," -f $name, $aliases, $luaFile, $luaRatio, $luaAnimated, $luaDuration
	}

	$dupeEmoteChecks += " (name = `"{0}`"|alias = {{.*?`"{0}`".*?}})" -f $name

}

$lua = $lua | Sort-Object -Unique

$luaBlock = @"
emotes["BTTV"] = {
`t$($lua -join "`r`n`t")
}
"@

if ($save)
{
	$coreFilePath = Join-Path -Path $cwd -ChildPath "core.lua"
	$coreFile = Get-Item -LiteralPath $coreFilePath
	$coreText = Get-Content $coreFile
	$coreLines = $coreText -split "(`r`n|`r|`n)"
	$blockStart = -1
	$blockEnd = -1
	for ($i = 0; $i -lt $coreLines.Count; $i++)
	{
		$line = $coreLines[$i]
		if ($blockStart -eq -1 -and $line -eq "emotes[`"BTTV`"] = {")
		{
			$blockStart = $i
		}
		elseif ($blockStart -ne -1 -and $blockEnd -eq -1 -and $line -eq "}")
		{
			$blockEnd = $i
			break
		}
	}
	if ($blockStart -ne -1 -and $blockEnd -ne -1)
	{
		$startPart = $coreLines[0 .. $blockStart]
		$endPart = $coreLines[$blockEnd .. ($coreLines.Length - 1)]
		$dupeWarning = @()
		foreach ($dupeEmoteCheck in $dupeEmoteChecks)
		{
			$matches1 = $startPart | Select-String $dupeEmoteCheck -CaseSensitive
			$matches2 = $endPart | Select-String $dupeEmoteCheck -CaseSensitive
			if ($matches1.Count -gt 0)
			{
				$matches1 | ForEach-Object { if (-not ($_.Line -match "^\s*--\s*")) { $dupeWarning += $_.Line } }
			}
			if ($matches2.Count -gt 0)
			{
				$matches2 | ForEach-Object { if (-not ($_.Line -match "^\s*--\s*")) { $dupeWarning += $_.Line } }
			}
		}
		if ($dupeWarning.Count -gt 0)
		{
			Write-Warning "These emotes collide with our BTTV emotes:"
			$dupeWarning | ForEach-Object { Write-Warning $_ }
		}
		$tempLua = $lua | ForEach-Object { "`t$_" }
		$coreLinesNew = $startPart + $tempLua + $endPart
		$coreLinesNew | Set-Content $coreFile
		Write-Host ("""{0}"" has been updated" -f $coreFile.Name)
		$tocFilesPattern = Join-Path -Path $cwd -ChildPath "*.toc"
		$tocFiles = Get-ChildItem -Path $tocFilesPattern
		$tocDate = (Get-Date).AddHours(-12).ToString("yyMMdd")
		$latestVersion = $null
		foreach ($tocFile in $tocFiles)
		{
			$tocLines = Get-Content $tocFile
			foreach ($tocLine in $tocLines)
			{
				if ($tocLine -match "(## Version: )((\d+)\.(\d+)\.(\d+))\.(\d+)( \(@project-version@\))")
				{
					$newTocLine = "{0}{1}.{2}{3}" -f $matches[1], $matches[2], $tocDate, $matches[7]
					$tocLines = $tocLines.Replace($tocLine, $newTocLine)
					$latestVersion = "v{0}.{1}" -f $matches[2], $tocDate
					break
				}
			}
			$tocLines | Set-Content $tocFile -Force
		}
		if ($git -and $latestVersion -and $dupeWarning.Count -eq 0)
		{
			git add .
			git commit -m "Added the latest BTTV emotes."
			git tag -a $latestVersion -m $latestVersion
			git push --tags
		}
	}
	else
	{
		Write-Error "Unable to locate the block of lua code!"
	}
	return
}

$luaBlock
