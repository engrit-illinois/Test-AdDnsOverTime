function Test-AdDnsOverTime {

	param(
		[Parameter(Mandatory=$true)]
		[string[]]$Computer,
		
		[Parameter(Mandatory=$true)]
		[string]$IpRange1,
		[Parameter(Mandatory=$true)]
		[string]$IpRange2,
		
		[int]$Loops = 1440,
		[int]$IntervalSeconds = 60,
		[int]$PingCount = 2,
		[int]$PingTimeoutSeconds = 2,

		[string]$IpRange1Fc = "green",
		[string]$IpRange2Fc = "yellow",
		[string]$IpUnknownRangeBc = "red",
		
		[string]$LogDir = "c:\engrit\logs"
	)

	$ts = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
	$logName = "Test-AdDnsOverTime_$($ts)"
	$csv = "$LogDir\$($logName).csv"

	function csv($line) {
		$line | Out-File $csv -Append
	}

	function log {
		param(
			[string]$Msg,
			[ValidateScript({[System.Enum]::GetValues([System.ConsoleColor]) -contains $_})]
			[string]$FC = (get-host).ui.rawui.ForegroundColor, # foreground color
			[ValidateScript({[System.Enum]::GetValues([System.ConsoleColor]) -contains $_})]
			[string]$BC = (get-host).ui.rawui.BackgroundColor, # background color
			[switch]$NoTs,
			[switch]$NoNl
		)
		
		if(-not $NoTs) {
			$ts = Get-Date -Format "HH:mm:ss"
			$Msg = "[$ts] $Msg"
		}
		
		$params = @{
			Object = $Msg
		}
		if($NoNl) { $params.NoNewline = $true }
		if($FC) { $params.ForegroundColor = $FC }
		if($BC) { $params.BackgroundColor = $BC }
		
		Write-Host @params
	}
	
	if($Computer) {
		$compsCount = @($Computer).count
	}

	# Header for console output
	$compsPadded = $comps | ForEach-Object {
		$_.PadRight(15," ")
	}
	$compsLine = $compsPadded -join " | "
	log $compsLine
	
	$underlineSegments = $comps | ForEach-Object {
		"---------------"
	}
	$underline = $underlineSegments -join "-|-"
	log $underline
	
	# Header for CSV
	$compsLineCsv = $comps -join ","
	csv $compsLineCsv
	
	# Loop once for each interval
	@(0..$Loops) | ForEach-Object {
		
		# Get results of pings
		$result = $null
		$result = Ping-All $comps -Quiet -PassThru -Count $PingCount -TimeoutSeconds $PingTimeoutSeconds | Sort "TargetName"
		
		# Console output timestamp for current line
		log -NoNl
		
		# Loop through each IP
		$i = 0
		$ipsPadded = $null
		$ipsPadded = $result.IPv4_IP | ForEach-Object {
			$ip = $_
			
			# Format the IP to be a consistent length
			$ipPadded = "               "
			if($ip) {
				$ipParts = $ip.Split('.')
				$ipPartsPadded = $ipParts | ForEach-Object {
					$part = $_
					$part.PadLeft(3, '0')
				}
				$ipPadded = $ipPartsPadded -join '.'
			}
			
			# Output line to console
			$params = @{
				Msg = $ipPadded
				NoNl = $true
				NoTs = $true
			}
			if($ipPadded -ne "               ") {
				if($ipPadded -like $IpRange1) {
					$params.FC = $IpRange1Fc
				}
				elseif($ipPadded -like $IpRange2) {
					$params.FC = $IpRange2Fc
				}
				else {
					$params.BC = $IpUnknownRangeBc
				}
			}
			
			log @params
			
			if($i -lt ($compsCount -1)) {
				log " | " -NoNl -NoTs
			}
			else {
				log "" -NoTs
			}
			$i += 1
			
			# Return IPs for CSV output
			$ipPadded
		}
		
		# Output CSV line
		$ipLineCsv = $ipsPadded.Replace(" ","") -join ","
		csv $ipLineCsv
		
		# Wait for next loop
		Start-Sleep -Seconds $IntervalSeconds
	}

	log "EOF"
}