$cwd = Get-Item -Path "."
$baseFolder = Get-Item -Path ".\emotes\BTTV"
$webpFiles = Get-ChildItem -Path $baseFolder -Filter *.webp
$keep = $args.Contains("--keep")
$combined = $args.Contains("--combined")

$alias = @{
	"BOOBA" = @("booba")
	"catJAM" = @("CatJam", "CatJAM")
	"pepeD" = @("PepeD")
	"PepeLaugh" = @("FeelsKekMan")
}

foreach ($webpFile in $webpFiles)
{

	$name = [IO.Path]::GetFileNameWithoutExtension($webpFile)
	$outputFolderPath = Join-Path -Path $webpFile.Directory -ChildPath $name

	if (Test-Path $outputFolderPath -PathType Container)
	{
		continue
	}

	& webp_frames $webpFile @args

}

$folders = Get-ChildItem -Path $baseFolder -Directory
$emotes = @()

foreach ($folder in $folders)
{

	$name = [IO.Path]::GetFileNameWithoutExtension($folder)
	$folderPath = $folder.FullName

	$folderFileSelector = Join-Path -Path $folderPath -ChildPath "*_*_*_*"
	$folderFilesMixed = Get-ChildItem -Path $folderFileSelector

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
		if ($folderFile.Name -match "^([^_]+)_(\d+)_(\d+)_(\d+)\.(.+)$")
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

	foreach ($frame in $emote.Frames)
	{
		$frame.File = $frame.File.Name
		$emote.Duration += $frame.Duration
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

		$emoteFolder = Join-Path -Path $baseFolder -ChildPath $emote.Name

		foreach ($frame in $emote.Frames)
		{

			$frameFilePathBLP = Join-Path -Path $emoteFolder -ChildPath $frame.File.Replace(".png", ".blp")

			if (Test-Path $frameFilePathBLP)
			{
				continue
			}

			$frameFilePath = Join-Path -Path $emoteFolder -ChildPath $frame.File
			$frameFile = Get-Item -LiteralPath $frameFilePath

			& blppng "$($frameFile.FullName)"

			$frameFileBLP = Get-Item -LiteralPath $frameFilePathBLP -ErrorAction SilentlyContinue

			if (-not $frameFileBLP -or $frameFileBLP.Length -eq 0)
			{
				Write-Error ("""{0}"" unable to convert frame ""{1}""" -f $emote.Name, $frame.File)
			}

		}

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
		$luaDuration = "duration = $($durations[0])"
	}
	else
	{
		$luaDuration = "duration = { $($durationsTrimmed -join ", ") }"
	}

	$aliases = $alias[$name]
	if ($aliases)
	{
		$aliases = $aliases -join '", "'
		$aliases = " alias = { `"$aliases`" },"
	}
	else
	{
		$aliases = ""
	}

	$firstFrame = $emote.Frames[0]
	$firstFrameFile = [IO.Path]::GetFileNameWithoutExtension($firstFrame.File)
	$luaFile = "$name/$firstFrameFile"

	if ($combined)
	{
		$luaCombinedSlots = @()
		$emoteInfo = CalculateEmoteInfo $emote
		foreach ($slot in $emoteInfo.Slots)
		{
			$luaCombinedSlots += $slot.Frame.Duration
		}
		$luaDuration = "duration = { $($luaCombinedSlots -join ", ") }"
		$lua += "{ name = `"$name`",$aliases animated = true, textureSize = $($emoteInfo.SquareSize), contentSize = $($emoteInfo.FramesCountSqrt * $emote.Width), $($luaDuration) },"
	}
	else
	{
		$lua += "{ name = `"$name`",$aliases file = `"$luaFile`", animated = true, $($luaDuration) },"
	}

}

$luaBlock = @"
emotes["BTTV"] = {
`t$($lua -join "`r`n`t")
}
"@

$luaBlock
