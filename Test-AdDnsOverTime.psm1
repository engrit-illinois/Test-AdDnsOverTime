function Test-AdDnsOverTime {
	[CmdletBinding()]
	
	param(
		[Parameter(Mandatory=$true)]
		[string[]]$Computer,
		
		[string]$IpRanges,
		
		[int]$TestCount = 1440,
		[int]$IntervalSeconds = 60,
		[int]$PingCount = 4,
		[int]$PingTimeoutSeconds = 5,
		[switch]$FlushDnsCacheBeforeTests,
		
		[string]$IpUnknownRangeFc,
		[string]$IpUnknownRangeBc,
		
		[int]$Abbreviate,
		
		[string]$LogDir = "c:\engrit\logs"
	)
	
	# Logging
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
			[switch]$NoNl,
			[string]$TestNum
		)
		
		if($TestNum) {
			$Msg = "[$TestNum] $Msg"
		}
		
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
	
	function Parse-IpRanges {
		if($IpRanges) {
			$IpRanges.Split(";") | ForEach-Object {
				$rangeParts = $_.Split(":")
				# A properly-formatted range should have exactly 2 colons
				if(@($rangeParts).count -ne 3) {
					throw "Invalid syntax for -IpRanges parameter. See documentation. Each range must be separated by a semicolon, and should contain exactly 2 colons."
				}
				[PSCustomObject]@{
					Query = $rangeParts[0]
					FC = $rangeParts[1]
					BC = $rangeParts[2]
				}
			}
		}
	}
	
	function Get-TestNum {
		param(
			[int]$Num
		)
		$numString = "$Num".PadLeft("$TestCount".length,"0")
		"Test #$numString/$TestCount"
	}
	
	function Log-Headers {
		$comps = $Computer
		
		# Abbreviate if necessary
		$dataWidth = 15
		if($Abbreviate) {
			$dataWidth = $Abbreviate
			$comps = $comps | ForEach-Object {
				$_.SubString($_.length - $dataWidth)
			}
		}
		
		# Header for console output
		$comps = $comps | ForEach-Object {
			$_.PadRight($dataWidth," ")
		}
		$compsLine = $comps -join " | "
		log $compsLine -TestNum (Get-TestNum -Num 0)
		
		$underlineSegments = $comps | ForEach-Object {
			$segment = ""
			@(1..$dataWidth) | ForEach-Object {
				$segment = "$($segment)-"
			}
			$segment
		}
		$underline = $underlineSegments -join "-|-"
		log $underline -TestNum (Get-TestNum -Num 0)
		
		# Header for CSV
		$compsLineCsv = $Computer -join ","
		csv $compsLineCsv
	}
	
	function Get-ColorParams($params) {
		$ip = $params.Msg
		# If the IP is blank, no need to color it
		if($ip.Trim() -ne "") {
			# Only color things if IP ranges were supplied
			if($ranges) {
				$recognized = $false
				$ranges | ForEach-Object {
					$range = $_
					if($ipPadded -like $range.Query) {
						$recognized = $true
						if($range.FC) {
							if(($range.FC).length -gt 0) {
								$params.FC = $range.FC
							}
						}
						if($range.BC) {
							if(($range.BC).length -gt 0) {
								$params.BC = $range.BC
							}
						}
					}
				}
				
				if(-not $recognized) {
					if($IpUnknownRangeFc) {
						$params.FC = $IpUnknownRangeFc
					}
					if($IpUnknownRangeBc) {
						$params.BC = $IpUnknownRangeBc
					}
				}
			}
		}
		
		$params
	}
	
	function Flush-Dns {
		#ipconfig -flushdns
		Clear-DnsClientCache
	}
	
	function Test-Comps($testNum) {
		# Console output timestamp and test number for current line
		log -TestNum (Get-TestNum -Num $testNum) -NoNl
		
		# Get results of pings
		$result = $null
		$result = Ping-All $Computer -Quiet -PassThru -Count $PingCount -TimeoutSeconds $PingTimeoutSeconds | Sort "TargetName"
		
		if(-not $result) {
			throw "Failed to get result from Ping-All cmdlet!"
		}
		
		if(@($result).count -ne @($Computer).count) {
			throw "Number of results from Ping-All not equal to the number of computers given in -Computer!"
		}
		
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
			
			# Define log parameters
			$params = @{
				Msg = $ipPadded
				NoNl = $true
				NoTs = $true
			}
			# Colorize IPs if applicable
			$params = Get-ColorParams $params
			
			# Abbreviate if necessary
			if($Abbreviate) {
				$params.Msg = ($params.Msg).SubString(($params.Msg).length - $Abbreviate)
			}			
			
			# Output line to console
			log @params
			
			# Using @($Computer).count here instead of @($result).count or @($result.IPv4_IP).count just in case Ping-All returned fewer results than the number of computers it was supposed to ping, although that should not happen.
			if($i -lt (@($Computer).count -1)) {
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
	
	function Do-Stuff {
		$Computer = $Computer | Sort
		$ranges = Parse-IpRanges
		Log-Headers
		@(1..$TestCount) | ForEach-Object {
			if($FlushDnsCacheBeforeTests) {
				Flush-Dns
			}
			Test-Comps $_
		}
	}
	
	Do-Stuff

	log "EOF"
}