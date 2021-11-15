# HelloID-Conn-Prov-Target-Topicus-Somtoday-Update-Email

<p align="center">
  <img src="https://som.today/wp-content/uploads/2019/07/logo-blue.svg">
</p>

## Table of contents

- [Introduction](#Introduction)
- [Getting started](#Getting-started)
  + [Connection settings](#Connection-settings)
  + [Remarks](#Remarks)
- [Getting help](#Getting-help)
- [HelloID Docs](#HelloID-docs)

## Introduction

_HelloID-Conn-Prov-Target-Topicus-Somtoday-Update-Email_ is a _target_ connector. Somtoday provides a SOAP API that allows you to programmatically interact with it's data.

> This connector only updates the email address for a student.

## Getting started

Note that this connector only updates the email address for a student. The _create.ps1_ does not create accounts but merely correlates a HelloID person with a Somtoday student account.

### Connection settings

The following settings are required to connect to the API.

| Setting      | Description                        | Mandatory   |
| ------------ | -----------                        | ----------- |
| UserName     | The UserName to connect to the API | Yes         |
| Password     | -                                  | Yes         |
| BaseUrl      | The URL to the API. Like: https://_your-environment_.somtoday.nl/services/umService?wsdl'                 | Yes         |
| BrinNummer   | The BrinNummer of the school       | Yes         |

### Remarks

> This connector is created for both Windows PowerShell 5.1 and PowerShell Core. This means that the connector can be executed in both cloud and on-premises using the HelloID agent.

## Getting help

> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012557600-Configure-a-custom-PowerShell-source-system) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/
