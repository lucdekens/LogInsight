Import-Module -Name LogInsight

$sConnect = @{
    Server = 'LogInsight.local.lab'
    User = 'admin'
    Password = 'VMware1!'
}

Connect-LogInsight @sConnect

$agents = Get-LogInsightAgent
