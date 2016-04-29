Import-Module -Name LogInsight

$sConnect = @{
    Server = 'LogInsight.local.lab'
    User = 'admin'
    Password = 'VMware1!'
}

Connect-LogInsight @sConnect

$constraint = Get-LogInsightConstraint -Field 'hostname' -Operator STARTS_WITH -Value 'esx1'

$result = Get-LogInsightEvent -Constraint $constraint -Limit 100 -Aggregate -Function SAMPLE -BinWidth 60000
$result.bins
