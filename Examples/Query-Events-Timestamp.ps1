Import-Module -Name LogInsight

$sConnect = @{
    Server = 'LogInsight.local.lab'
    User = 'admin'
    Password = 'VMware1!'
}

Connect-LogInsight @sConnect

$constraint = Get-LogInsightConstraint -Field 'timestamp' -Operator GE -Value (Get-Date).AddHours(-1)

$result = Get-LogInsightEvent -Constraint $constraint -Event
$result.events
