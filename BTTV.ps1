$baseFolder = Get-Item -Path ".\emotes\BTTV"
$folders = Get-ChildItem -Path $baseFolder -Directory
$lua = @()

$alias = @{
	"BOOBA" = @("booba")
	"catJAM" = @("CatJam", "CatJAM")
	"pepeD" = @("PepeD")
	"PepeLaugh" = @("FeelsKekMan")
}

foreach ($folder in $folders)
{

	$first = Get-ChildItem -Path $folder.FullName | Select-Object -First 1
	$file = $first.FullName.Split($baseFolder.FullName)[1]
	$name = $first.Directory.Name
	$frame = [IO.Path]::GetFileNameWithoutExtension($file)

	$frames_files = (Get-ChildItem -Path $folder -Filter *.png) + (Get-ChildItem -Path $folder -Filter *.blp)
	$durations = [int[]]::new($frames_files.Count)
	$corrupt_frames = 0

	foreach ($frame_file in $frames_files)
	{
		if ($frame_file.Name -match "_(\d+)_(\d+)_(\d+)\.(png|blp)$")
		{
			$i = +$matches[1] - 1
			if ($i -gt $durations.Count)
			{
				$corrupt_frames++
			}
			else
			{
				$durations[$i] = +$matches[3]
			}
		}
	}

	if ($corrupt_frames -gt 0)
	{
		Write-Error ("""{0}"" has {1} corrupt frames" -f $name, $corrupt_frames)
	}

	$durations_trimmed = @()
	$prev_frame_duration = $null

	for ($i = 0; $i -lt $durations.Count; $i++)
	{
		$frame_duration = $durations[$i]
		if ($null -eq $prev_frame_duration -or $prev_frame_duration -ne $frame_duration)
		{
			$durations_trimmed += "[$($i + 1)] = $frame_duration"
		}
		$prev_frame_duration = $frame_duration
	}

	if ($durations_trimmed.Count -eq 1)
	{
		$lua_duration = "duration = $($durations[0])"
	}
	else
	{
		$lua_duration = "duration = { $($durations_trimmed -join ", ") }"
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

	$lua += "{ name = `"$name`",$aliases file = `"$name/$frame`", animated = true, $lua_duration },"

}

@"
emotes["BTTV"] = {
`t$($lua -join "`r`n`t")
}
"@
