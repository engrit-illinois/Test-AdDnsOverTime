# Summary
Script to monitor changes in the IPs of a set of AD DNS records over time.  

As an example of the purpose, the original use case was to monitor the IPs returned by the AD DNS records for a cart of laptops, to see when and how often they would switch between wired and wireless. The data gathered was useful in optimizing device power management and network adapter priority.  

# Requirements
- PowerShell 7+ for the use of `ForEach-Object -Parallel` within the `Ping-All` module.
- [Ping-All](https://github.com/engrit-illinois/Ping-All) module

# Behavior
This script pings a set of AD computer names a given number of times with a given interval in between (e.g. once a minute for 24 hours), and outputs the resulting IPv4 IPs to the console and to a CSV file.  

The script accepts 2 IP ranges, and will color code the console output depending on which range each IP falls in. This is just to make it easier to see changes over time at a glance without actually reading each IP. If desired, the raw CSV output can be similarly and easily color coded in Excel using conditional formatting.  

Note that IP ranges are accepted and output with leading zeros for padding, such that all IPs are always displayed with the same 15-character width.  

# Usage
1. Download `Test-AdDnsOverTime.psm1` to the appropriate subdirectory of your PowerShell [modules directory](https://github.com/engrit-illinois/how-to-install-a-custom-powershell-module).
2. Download [Ping-All](https://github.com/engrit-illinois/Ping-All) to the appropriate subdirectory of your PowerShell [modules directory](https://github.com/engrit-illinois/how-to-install-a-custom-powershell-module).
3. Run `Test-AdDnsOverTime` using the documentation below.

# Example
```powershell
$comps = Get-ADComputer -Filter "name -like 'lt-cart01-*'" | Sort "Name" | Select -ExpandProperty "Name" | Select -First 10
Test-AdDnsOverTime -Computer $comps -IpRange1 "010.000.000.*" -IpRange2 "172.016.000.*"
```

<img title='Screenshot of example console output' alt='Screenshot of example console output' src='./example.png' />

# Parameters
WIP

# Notes
By mseng3. See my other projects here: https://github.com/mmseng/code-compendium.