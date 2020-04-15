function Scan-Ports {
<#
.SYNOPSIS
    Tests port on hosts.

.DESCRIPTION
    Tests port on hosts.

.PARAMETER hosts
    Name of servers to test the port connections on.

.PARAMETER TCP
    TCP ports to scan

.PARAMETER UDP
    UDP ports to scan

.PARAMETER UDPTimeOut
    Sets a timeout for UDP port query. (In milliseconds, Default is 1000)

.PARAMETER TCPTimeOut
    Sets a timeout for TCP port query. (In milliseconds, Default is 1000)

.NOTES
    Name: scan-Ports.ps1
    Author: Noel Algora
    DateCreated: 15April2020
    List of Ports: http://www.iana.org/assignments/port-numbers

    To Do:
        Add capability to run background jobs for each host to shorten the time to scan.

.EXAMPLE
    Test-Port -hosts 'target' -TCP 80
    Checks port 80 on target 'target'

.EXAMPLE
    Test-Port -hosts 'target' -TCP @(1..80)
    Checks ports from 1 to 80 on 'target'
    -TCP @(1..59)

.EXAMPLE
    'target' | Test-Port -TCP @(80, 443, 8080)
    Checks ports 80, 443, 8080 on 'target'

.EXAMPLE
    Test-Port -hosts @("server1","server2") -TCP 80
    Checks port 80 on server1 and server2 to see if it is listening

.EXAMPLE
    Test-Port -hosts 'server' -TCP 80 -udp 139 -UDPtimeout 10000

    Server   : dc1
    Port     : 17
    TypePort : UDP
    Open     : True
    Notes    : "My spelling is Wobbly.  It's good spelling but it Wobbles, and the letters
            get in the wrong places." A. A. Milne (1882-1958)

    Description
    -----------
    Queries port 17 (qotd) on the UDP port and returns whether port is open or not

.EXAMPLE
    @("server1","server2") | Test-Port -TCP 80
    Checks port 80 on server1 and server2

.EXAMPLE
    (Get-Content hosts.txt) | Test-Port -TCP 80
    Checks port 80 on servers in host file

.EXAMPLE
    Test-Port -hosts (Get-Content hosts.txt) -TCP 80
    Checks port 80 on servers in host file

.EXAMPLE
    Test-Port -hosts (Get-Content hosts.txt) -TCP 80
    Checks port 80 on all servers in the hosts.txt file

#>
[cmdletbinding(
    DefaultParameterSetName = '',
    ConfirmImpact = 'low'
)]
    Param(
        [Parameter(
            Mandatory = $True,
            Position = 0,
            ParameterSetName = '',
            ValueFromPipeline = $True)]
            [array]$hosts,
        [Parameter(
            Mandatory = $False,
            ParameterSetName = '')]
            [array]$TCP,
        [Parameter(
            Mandatory = $False,
            ParameterSetName = '')]
            [array]$UDP,
        [Parameter(
            Mandatory = $False,
            ParameterSetName = '')]
            [int]$TCPtimeout=1000,
        [Parameter(
            Mandatory = $False,
            ParameterSetName = '')]
            [int]$UDPtimeout=1000
        )
    Begin {
        If (!$TCP -AND !$UDP) {$TCP = $True}
        #Typically you never do this, but in this case I felt it was for the benefit of the function
        #as any errors will be noted in the output of the report
        
        $report = @()
    }
    Process {
        ForEach ($hostname in $hosts) {
            ForEach ($port in $TCP) {
                # What about a progress-bar?
                #Write-Progress -activity "Scanning $($portEnd-$portStart) ports on $target" `
                #-status "*" -PercentComplete( (($port-$portStart) / ($portEnd-$portStart))  * 100 )
                $report += Test-Port-TCP $hostname $port
            }
        }
    }
    End {
        #Generate Report
        $report
    }
}


function Test-Port-TCP ($hostname, $port, $timeOut=1000){
<#
.SYNOPSIS
    Tests port on a given host on TCP.

.PARAMETER hostname
    Name of server to test the port connection on.

.PARAMETER port
    Port to test

.PARAMETER timeOut
    Sets a timeout for port query. (In milliseconds, Default is 1000)

.NOTES
    To Do:
        Read for reverse proxy

.EXAMPLE
    Test-Port -hostname 'server' -port 80
    Checks port 80 on server 'server' to see if it is listening

.EXAMPLE
    Test-Port-TCP -hostname dc1 -port 17  -timeOut 10000

    Server   : dc1
    Port     : 17
    TypePort : UDP
    Open     : True
    Notes    : "My spelling is Wobbly.  It's good spelling but it Wobbles, and the letters
            get in the wrong places." A. A. Milne (1882-1958)

    Description
    -----------
    Queries port 17 (qotd) on the UDP port and returns whether port is open or not

#>
    $temp = "" | Select Server, Port, TypePort, Open, Notes

    $temp.Server = $hostname
    $temp.Port = $port
    $temp.TypePort = "TCP"
    $temp.Open = $False

    #Create object for connecting to port on hosts and start connection
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $tcpConnection = $tcpClient.BeginConnect($hostname, $port, $null, $null)

    #Configure the timeout
    $wait = $tcpConnection.AsyncWaitHandle.WaitOne($timeOut, $false)

    #If timeout
    If(!$wait) {
        #Close connection
        $tcpClient.Close()
        Write-Verbose "Connection Timeout"
        #Build report
        $temp.Notes = "Connection to Port Timed Out"
    } Else {
        try
        {
            $tcpStream = $tcpClient.GetStream()
            $reader = New-Object System.IO.StreamReader($tcpStream)
            $writer = New-Object System.IO.StreamWriter($tcpStream).WriteLine("ASDA") | Out-Null

            $writer.WriteLine("ASDA") | Out-Null
            $writer.Flush()
            start-sleep -Milliseconds 2500

            while ($tcpStream.DataAvailable) {
                Write-Host "available:"
                $rawresponse = $reader.Read($buffer, 0, 1024)
                $response = $encoding.GetString($buffer, 0, $rawresponse)   
                Write-Host "`ravailable: $response"
            }

            $tcpClient.EndConnect($tcpConnection)
            $tcpClient.Close()
            $temp.Open = $True
            $temp.Notes = $response
            # Established connection closed: port is open
            Write-Host "`r$port <($port)> is open!"-foregroundcolor Green
            $tcpClient = $null
        } catch($error) {
            Write-Host "`r$error"
            # No active connection to be closed: port is closed
            #Write-Host "`r$port" -ForegroundColor Red -NoNewline
        }

        #Close connection
        $tcpClient.Close()
    }

    return $temp

}