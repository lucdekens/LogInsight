function ConvertTo-hLogInsightJsonDateTime
{
  [CmdletBinding()]
  param (
    [DateTime]$Date
  )
	
  Process
  {
    Write-Verbose -Message "$($MyInvocation.MyCommand.Name)"
    Write-Verbose -Message "`t$($PSCmdlet.ParameterSetName)"
    Write-Verbose -Message "`tCalled from $($stack = Get-PSCallStack; $stack[1].Command) at $($stack[1].Location)"

    [int64]($Date.ToUniversalTime() - (Get-Date '1/1/1970')).totalmilliseconds
  }
}

function ConvertFrom-hLogInsightJsonDateTime
{
  [CmdletBinding()]
  param (
    [int64]$DateTime
  )
	
  Process
  {
    Write-Verbose -Message "$($MyInvocation.MyCommand.Name)"
    Write-Verbose -Message "`t$($PSCmdlet.ParameterSetName)"
    Write-Verbose -Message "`tCalled from $($stack = Get-PSCallStack; $stack[1].Command) at $($stack[1].Location)"

    (New-Object -TypeName DateTime -ArgumentList (1970, 1, 1, 0, 0, 0, 0)).AddMilliseconds([long]$DateTime).ToLocalTime()
  }
}

function Convert-hLogInsightTimeField
{
  param(
    [psobject[]]$Object
  )
  
  Process
  {
    Write-Verbose -Message "$($MyInvocation.MyCommand.Name)"
    Write-Verbose -Message "`t$($PSCmdlet.ParameterSetName)"
    Write-Verbose -Message "`tCalled from $($stack = Get-PSCallStack; $stack[1].Command) at $($stack[1].Location)"

    foreach($obj in $Object)
    {
      $obj.psobject.properties | ForEach-Object -Process {
        if('System.Object[]','System.Management.Automation.PSCustomObject' -contains $_.TypeNameOfValue)
        {
          Convert-hLogInsightTimeField -Object $obj.$($_.Name)
        }
        elseif($_.Name -match 'Time|lastSeen|statsAsOf' -and $_.TypeNameOfValue -eq 'System.Int64')
        {
          $obj.$($_.Name) = (ConvertFrom-hLogInsightJsonDateTime -DateTime $obj.$($_.Name))
        }
      }
    }
  }
}

function Invoke-hLogInsightRest
{
  [CmdletBinding()]
  param (
    [String]$Method,
    [String]$Request,
    [PSObject]$Body
  )
	
  Process
  {
    Write-Verbose -Message "$($MyInvocation.MyCommand.Name)"
    Write-Verbose -Message "`t$($PSCmdlet.ParameterSetName)"
    Write-Verbose -Message "`tCalled from $($stack = Get-PSCallStack; $stack[1].Command) at $($stack[1].Location)"
		
    $sRest = @{
      Uri         = "https://$($script:LogInsightServer,'api/v1',$Request -join '/')"
      Method      = $Method
      ContentType = 'application/json'
      Headers     = $script:headers
      ErrorAction = 'Stop'
    }
    if (Get-Process -Name fiddler -ErrorAction SilentlyContinue)
    {
      $sRest.Add('Proxy', 'http://127.0.0.1:8888')
    }
    # To handle nested properties the Depth parameter is used explicitely (default is 2)
    if ($Body)
    {
      $sRest.Add('Body', ($Body | ConvertTo-Json -Depth 32 -Compress))
    }
		
    Write-Debug -Message "`tUri             : $($sRest.Uri)"
    Write-Debug -Message "`tMethod          : $($sRest.Method)"
    Write-Debug -Message "`tContentType     : $($sRest.ContentType)"
    Write-Debug -Message "`tHeaders"
    $sRest.Headers.GetEnumerator() | ForEach-Object -Process {
      Write-Debug "`t                : $($_.Name)`t$($_.Value)"
    }
    Write-Debug -Message "`tBody            : $($sRest.Body)"
		
    # The intermediate $result is used to avoid returning a PSMemberSet
    Try
    {
      $result = Invoke-RestMethod @sRest
    }
    Catch
    {
      $excpt = $_.Exception

      Write-Debug 'Exception'
      Write-Debug "`tERROR-CODE = $($excpt.Response.Headers['ERROR-CODE'])"
      Write-Debug "`tERROR-CODE = $($excpt.Response.Headers['ERROR-MESSAGE'])"
      Throw "$($excpt.Response.Headers['ERROR-CODE']) $($excpt.Response.Headers['ERROR-MESSAGE'])"
    }
    $result
    Write-Debug "Leaving $($MyInvocation.MyCommand.Name)"
  }
}

# .ExternalHelp LogInsight-Help.xml
function Connect-LogInsight
{
  [CmdletBinding(SupportsShouldProcess = $True, ConfirmImpact = 'Low')]
  param (
    [Parameter(Mandatory = $true)]
    [String]$Server,
    [Parameter(Mandatory = $True,
        ValueFromPipeline = $True,
    ParameterSetName = 'Credential')]
    [System.Management.Automation.PSCredential]$Credential,
    [Parameter(Mandatory = $True,
    ParameterSetName = 'PlainText')]
    [String]$User,
    [Parameter(Mandatory = $True,
    ParameterSetName = 'PlainText')]
    [String]$Password,
    [string]$Proxy,
    [Parameter(DontShow)]
    [switch]$Fiddler = $false
  )
	
  Process
  {
    Write-Verbose -Message "$($MyInvocation.MyCommand.Name)"
    Write-Verbose -Message "`t$($PSCmdlet.ParameterSetName)"
    Write-Verbose -Message "`tCalled from $($stack = Get-PSCallStack; $stack[1].Command) at $($stack[1].Location)"

    $script:LogInsightServer = $Server
    if ($Proxy)
    {
      if ($PSDefaultParameterValues.ContainsKey('*:Proxy'))
      {
        $PSDefaultParameterValues['*:Proxy'] = $Proxy
      }
      else
      {
        $PSDefaultParameterValues.Add('*:Proxy', $Proxy)
      }
      if ($PSDefaultParameterValues.ContainsKey('*:ProxyUseDefaultCredentials'))
      {
        $PSDefaultParameterValues['*:ProxyUseDefaultCredentials'] = $True
      }
      else
      {
        $PSDefaultParameterValues.Add('*:ProxyUseDefaultCredentials', $True)
      }
    }
    if ($PSCmdlet.ParameterSetName -eq 'PlainText')
    {
      $sPswd = ConvertTo-SecureString -String $Password -AsPlainText -Force
      $Script:LogInsightCredential = New-Object System.Management.Automation.PSCredential -ArgumentList ($User, $sPswd)
    }
    if ($PSCmdlet.ParameterSetName -eq 'Credential')
    {
      $Script:LogInsightCredential = $Credential
      $User = $Credential.GetNetworkCredential().username
      $Password = $Credential.GetNetworkCredential().password
    }

    # ToDo: add logic to determine 'provider'
    # Can be 'Local' or 'ActiveDirectory'
    # For now, only Local

    $sConnect = @{
      Method  = 'Post'
      Request = 'sessions'
      Body = @{
        provider = 'Local'
        username = $User
        password = $Password
      }
    }
    $script:headers = @{
        'Accept' = 'application/json'
    }
    if ($Fiddler)
    {
      if (Get-Process -Name fiddler -ErrorAction SilentlyContinue)
      {
        if ($PSDefaultParameterValues.ContainsKey('Invoke-RestMethod:Proxy'))
        {
          $PSDefaultParameterValues['Invoke-RestMethod:Proxy'] = 'http://127.0.0.1:8888'
        }
        else
        {
          $PSDefaultParameterValues.Add('Invoke-RestMethod:Proxy', 'http://127.0.0.1:8888')
        }
      }
    }
    If ($PSCmdlet.ShouldProcess('Connecting to Log Insight'))
    {
      $auth = Invoke-hLogInsightRest @sConnect

      $script:headers.Add('Authorization',"Bearer $($auth.sessionId)")
    }
  }
}

# .ExternalHelp LogInsight-Help.xml
function Get-LogInsightEvent
{
  [CmdletBinding(SupportsShouldProcess = $True, ConfirmImpact = 'Low')]
  param (
    [String[]]$Constraint,
    [Parameter(Mandatory = $True,ParameterSetName = 'Event')]
    [Switch]$Event,
    [Parameter(Mandatory = $True,ParameterSetName = 'Aggregated')]
    [Switch]$Aggregate,
    [Parameter(ParameterSetName = 'Event')]
    [Parameter(ParameterSetName = 'Aggregated')]
    [Int]$Limit,
    [Parameter(ParameterSetName = 'Event')]
    [Parameter(ParameterSetName = 'Aggregated')]
    [Int]$Timeout,
    [Parameter(ParameterSetName = 'Aggregated')]
    [Int]$BinWidth,
    [Parameter(ParameterSetName = 'Aggregated')]
    [ValidateSet('COUNT','SAMPLE','UCOUNT','MIN','MAX','SUM','STDEV','VARIANCE')]
    [String]$Function,
    [Switch]$Raw
  )

  Process
  {
    Write-Verbose -Message "$($MyInvocation.MyCommand.Name)"
    Write-Verbose -Message "`t$($PSCmdlet.ParameterSetName)"
    Write-Verbose -Message "`tCalled from $($stack = Get-PSCallStack; $stack[1].Command) at $($stack[1].Location)"

    $keyvalue = @()

    if($Limit)
    {
        $keyvalue += "limit=$($Limit)"
    }
    if($Timeout)
    {
        $keyvalue += "timeout=$($Timeout)"
    }
    if($BinWidth)
    {
        $keyvalue += "bin-width=$($BinWidth)"
    }
    if($Function)
    {
        $keyvalue += "aggregation-function=$($Function)"
    }
    $sEvent = @{
      Method  = 'Get'
      Request = 'events'
    }
    if($Aggregate)
    {
        $sEvent.Request = 'aggregated-events'
    }
    if($Constraint.Count -ne 0)
    {
        $sEvent.Request = $sEvent.Request,($Constraint -join '/') -join '/'
    }
    if($keyvalue.Count -ne 0)
    {
        $sEvent.Request = $sEvent.Request,($keyvalue -join '&') -join '?'
    }

    If ($PSCmdlet.ShouldProcess('Connecting to Log Insight'))
    {
      $events = Invoke-hLogInsightRest @sEvent

      if (!$Raw)
      {
          Convert-hLogInsightTimeField -Object $events
      }
      $events
    }
  }
}

# .ExternalHelp LogInsight-Help.xml
function Get-LogInsightConstraint
{
  [CmdletBinding(SupportsShouldProcess = $True, ConfirmImpact = 'Low')]
  param (
    [String]$Field,
    [ValidateSet('CONTAINS','NOTCONTAINS','MATCHES_REGEX','NOT_MATCHES_REGEX','STARTS_WITH','NOT_STARTS_WITH','EQ','NE','LE','LT','GE','GT')]
    [String]$Operator,
    [PSObject]$Value
  )

  Process
  {
    if($Value -is [DateTime])
    {
       $Value = ConvertTo-hLogInsightJsonDateTime -Date $Value 
    }
    $convertTab = @{
        'CONTAINS' = '$($Field)/$($Value)'
        'NOTCONTAINS' = '$($Field)/!$($Value)'
        'MATCHES_REGEX' = '$($Field)/=~$($Value)'
        'NOT_MATCHES_REGEX' = '$($Field)/!=~$($Value)'
        'STARTS_WITH' = '$($Field)/$($Value)*'
        'NOT_STARTS_WITH' = '$($Field)/!$($Value)*'
        'EQ' = '$($Field)/=$($Value)'
        'NE' = '$($Field)/!=$($Value)'
        'LE' = '$($Field)/<=$($Value)'
        'LT' = '$($Field)/<$($Value)'
        'GE' = '$($Field)/>=$($Value)'
        'GT' = '$($Field)/>$($Value)'     
    }

    return  $ExecutionContext.InvokeCommand.ExpandString($convertTab[$Operator])
  }
}

function Get-LogInsightAgent
{
  [CmdletBinding(SupportsShouldProcess = $True, ConfirmImpact = 'Low')]
  param (
    [Switch]$Raw
  )

  Process
  {
    Write-Verbose -Message "$($MyInvocation.MyCommand.Name)"
    Write-Verbose -Message "`t$($PSCmdlet.ParameterSetName)"
    Write-Verbose -Message "`tCalled from $($stack = Get-PSCallStack; $stack[1].Command) at $($stack[1].Location)"

    $sAgent = @{
      Method  = 'Get'
      Request = 'agent'
    }

    If ($PSCmdlet.ShouldProcess('Connecting to Log Insight'))
    {
      $agents = Invoke-hLogInsightRest @sAgent

      if (!$Raw)
      {
          Convert-hLogInsightTimeField -Object $agents
      }

      $agents.agents
    }
  }
}
