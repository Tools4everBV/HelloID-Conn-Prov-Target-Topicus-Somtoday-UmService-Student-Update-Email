#########################################################
# HelloID-Conn-Prov-Target-Topicus-Sometoday-Update-Email
# create.ps1
#
# Version: 1.0.0
#########################################################
$VerbosePreference = "Continue"

# Initialize default value's
$config = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$success = $false
$auditLogs = New-Object Collections.Generic.List[PSCustomObject]

$account = @{
    LeerlingNummer = $p.ExternalId
    LeerlingEmail  = $($p.Contact.Business.Email)
}

try {
    $splatRestMethodParams = @{
        Uri         = $($config.BaseUrl)
        Method      = 'POST'
        ContentType = "text/xml; charset=utf-8"
    }

    Write-Verbose "Veryfing if student with id: [$($p.ExternalId)] exists"
    $getStudentXmlBody = @"
    <?xml version="1.0" encoding="utf-8"?>
    <Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <Body>
            <getDataLeerlingen xmlns="http://services.mijnsom.nl">
                <brinNr xmlns="">
                    $($config.BrinNr)
                </brinNr>
                <username xmlns="">
                    $($config.UserName)
                </username>
                <password xmlns="">
                    $($config.Password)
                </password>
                <schooljaar xmlns=""/>
                <vestigingAfkorting xmlns=""/>
                <leerlingnummer xmlns="">
                    $($account.LeerlingNummer)
                </leerlingnummer>
            </getDataLeerlingen>
        </Body>
    </Envelope>
"@

    $splatRestMethodParams['Body'] = $getStudentXmlBody
    $responseGetLeerling = Invoke-RestMethod @splatRestMethodParams

    if ($responseGetLeerling.Envelope.Body.getDataLeerlingenResponse.return.leerlingNummer){

        # If the emailAddress from HelloID matches with the emailAddress in Somtoday, we only need to correlate.
        Write-Verbose "Verifying if the emailAddress for: [$($p.DisplayName)] must be updated"
        if ($responseGetLeerling.Envelope.Body.getDataLeerlingenResponse.return.leerlingEmail -eq $p.Contact.Business.Email){
            $action = 'Correlate'
        } elseif ($responseGetLeerling.Envelope.Body.getDataLeerlingenResponse.return.leerlingEmail -ne $p.Contact.Business.Email){
            $action = 'Correlate-Update'
        }

        $msg = "$action Somtoday account for: [$($p.DisplayName)] will be executed during enforcement"

    } elseif (!$responseGetLeerling.Envelope.Body.getDataLeerlingenResponse.return.leerlingNummer){
        $action = 'Exit'
        $msg = "Somtoday student with id: [$($account.leerlingNummer)] cannot be found"
    }

    # Add an auditMessage showing what will happen during enforcement
    if ($dryRun -eq $true){
        $auditMessage = $msg
    }

    if (-not ($dryRun -eq $true)){
        switch ($action) {
            'Correlate'{
                Write-Verbose "Correlating Somtoday account for: [$($p.DisplayName)]"
                $accountReference = $responseGetLeerling.Envelope.Body.getDataLeerlingenResponse.return.leerlingNummer
                $success = $true
                $auditLogs.Add([PSCustomObject]@{
                    Message = "Correlated Sometoday account for: $($p.DisplayName)"
                    IsError = $false
                })
                break
            }

            'Correlate-Update' {
                Write-Verbose "Correlating and updating Somtoday account for: [$($p.DisplayName)]"

                $updateStudentXmlBody = @"
                <?xml version="1.0" encoding="utf-8"?>
                <Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
                    <Body>
                        <writeDataLeerlingen xmlns="http://services.mijnsom.nl">
                            <brinNr xmlns="">
                                $($config.BrinNr)
                            </brinNr>
                            <username xmlns="">
                                $($config.UserName)
                            </username>
                            <password xmlns="">
                                $($config.Password)
                            </password>
                            <leerlingen xmlns="">
                                <leerlingEmail>
                                    $($account.LeerlingEmail)
                                </leerlingEmail>
                                <leerlingNummer>
                                    $($account.LeerlingNummer)
                                </leerlingNummer>
                            </leerlingen>
                        </writeDataLeerlingen>
                    </Body>
                </Envelope>
"@

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
