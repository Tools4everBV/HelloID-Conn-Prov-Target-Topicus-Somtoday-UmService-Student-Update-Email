#########################################################
# HelloID-Conn-Prov-Target-Topicus-Sometoday-Update-Email
# update.ps1
#
# Version: 1.0.0
#########################################################
$VerbosePreference = "Continue"

# Initialize default value's
$config = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$pd = $personDifferences | ConvertFrom-Json
$aRef = $AccountReference | ConvertFrom-Json
$success = $false
$auditLogs = New-Object Collections.Generic.List[PSCustomObject]

if([string]::IsNullOrEmpty($config.BrinNr))
{
    $brin = $p.Custom.Brin
}
else
{
    $brin = $config.BrinNr
}

$account = @{
    LeerlingNummer = $aRef
    LeerlingEmail  = $($p.Accounts.MicrosoftActiveDirectory.mail)
}

try {
    $splatRestMethodParams = @{
        Uri         = $($config.BaseUrl)
        Method      = 'POST'
        ContentType = "text/xml; charset=utf-8"
    }

    Write-Verbose "Veryfing if student with id: [$($p.ExternalId)] exists"
    $getStudentXmlBody = "<?xml version=`"1.0`" encoding=`"utf-8`"?><soap:Envelope xmlns:soap=`"http://schemas.xmlsoap.org/soap/envelope/`" xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`" xmlns:xsd=`"http://www.w3.org/2001/XMLSchema`" xmlns=`"http://services.mijnsom.nl`"><soap:Body><getDataLeerlingen><brinNr xmlns=`"`">$brin</brinNr><username xmlns=`"`">$($config.UserName)</username><password xmlns=`"`">$($config.Password)</password><leerlingnummer xmlns=`"`">$($p.ExternalId)</leerlingnummer></getDataLeerlingen></soap:Body></soap:Envelope>"


    $splatRestMethodParams['Body'] = $getStudentXmlBody
    $responseGetLeerling = Invoke-RestMethod @splatRestMethodParams
    if ($responseGetLeerling.Envelope.Body.getDataLeerlingenResponse.return.leerlingEmail -ne $account.LeerlingEmail){
        $action = 'Update'
        $msg = "$action Somtoday account for: [$($p.DisplayName)] will be executed during enforcement"
    } elseif ($responseGetLeerling.Envelope.Body.getDataLeerlingenResponse.return.leerlingEmail -eq $account.LeerlingEmail){
        $action = 'Exit'
        $msg = "Email address: [$($account.LeerlingEmail)] for student with id: [$($account.leerlingNummer)] is the same as in Somtoday and does not require an update"
    } elseif (!$responseGetLeerling.Envelope.Body.GetDataLeerlingenResponse.return.leerlingNummer){
        $msg = "Student with id: [$($account.leerlingNummer)] cannot be found"
        $action = 'Exit'
    }

    # Add an auditMessage showing what will happen during enforcement
    if ($dryRun -eq $true){
        $auditMessage = $msg
    }

    if (-not ($dryRun -eq $true)){
        switch ($action) {
            'Update' {
                Write-Verbose "Updating Somtoday account for: [$($p.DisplayName)]"

                $updateStudentXmlBody = "<?xml version=`"1.0`" encoding=`"utf-8`"?><soap:Envelope xmlns:soap=`"http://schemas.xmlsoap.org/soap/envelope/`" xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`" xmlns:xsd=`"http://www.w3.org/2001/XMLSchema`"><soap:Body><writeDataLeerlingen xmlns=`"http://services.mijnsom.nl`"><brinNr xmlns=`"`">$brin</brinNr><username xmlns=`"`">$($config.UserName)</username><password xmlns=`"`">$($config.Password)</password><leerlingen xmlns=`"`"><leerlingEmail>$($account.LeerlingEmail)</leerlingEmail><leerlingNummer> $($account.LeerlingNummer)</leerlingNummer></leerlingen></writeDataLeerlingen></soap:Body></soap:Envelope>"

                $splatRestMethodParams['Body'] = $updateStudentXmlBody
                $responseWriteDataLeerling = Invoke-RestMethod @splatRestMethodParams
                if ($($responseWriteDataLeerling.Envelope.Body.writeDataLeerlingenResponse.return) -like "Fout tijdens*"){
                    $success = $false
                    throw $responseWriteDataLeerling.Envelope.Body.writeDataLeerlingenResponse.return
                } else {
                    $accountReference = $responseGetLeerling.Envelope.Body.getDataLeerlingenResponse.return.leerlingNummer
                    $success = $true
                    $auditLogs.Add([PSCustomObject]@{
                        Message = "Updated emailAddress for: $($p.DisplayName)"
                        IsError = $false
                    })
                }
                break
            }

            'Exit'{
                $success = $false
                $auditLogs.Add([PSCustomObject]@{
                    Message = $msg
                    IsError = $false
                })
                break
            }
        }
    }
} catch {
    $ex = $_
    $errorMessage = "Could not update emailAddress for: [$($p.DisplayName)]. Error: $($ex.Exception.Message)"
    $success = $false

    Write-Verbose $errorMessage
    $auditLogs.Add([PSCustomObject]@{
        Message = $errorMessage
        IsError = $true
    })
} finally {
    $result = [PSCustomObject]@{
        Success          = $success
        AccountReference = $accountReference
        Auditlogs        = $auditLogs
        AuditDetails     = $auditMessage
        Account          = $account
    }
    Write-Output $result | ConvertTo-Json -Depth 10
}