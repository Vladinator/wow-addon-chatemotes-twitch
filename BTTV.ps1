$baseFolder = Get-Item -Path ".\emotes\BTTV"
$folders = Get-ChildItem -Path $baseFolder -Directory
$lua = @()

foreach ($folder in $folders)
{

	$first = Get-ChildItem -Path $folder.FullName | Select-Object -First 1
	$file = $first.FullName.Split($baseFolder.FullName)[1]
	$name = $first.Directory.Name
	$frame = [IO.Path]::GetFileNameWithoutExtension($file)

	$frames_files = Get-ChildItem -Path $folder -Filter *.png
	$durations = [int[]]::new($frames_files.Count)

	foreach ($frame_file in $frames_files)
	{
		if ($frame_file.Name -match "_(\d+)_(\d+)_(\d+)\.png$")
		{
			$durations[+$matches[1]-1] = +$matches[3]
		}
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

	$lua += "{ name = `"$name`", file = `"$name/$frame`", animated = true, $lua_duration },"

}

@"
emotes["BTTV"] = {
`t$($lua -join "`r`n`t")
}
"@
