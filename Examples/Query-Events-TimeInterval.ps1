Import-Module -Name LogInsight

$sConnect = @{
    Server = 'LogInsight.local.lab'
    User = 'admin'
    Password = 'VMware1!'
}

Connect-LogInsight @sConnect

$start = (Get-Date).AddHours(-1)
$intervalMinutes = 10

$constraint = (Get-LogInsightConstraint -Field 'timestamp' -Operator GE -Value $start),
    (Get-LogInsightConstraint -Field 'timestamp' -Operator LT -Value $start.AddMinutes($intervalMinutes))

$result = Get-LogInsightEvent -Event -Constraint $constraint
$result.events
