# Healthcare Bot Scenario Import/Export CmdLets

This PowerShell module allows you to import and export Health Bot scenarios. Through integration into existing SCS/DevOps tools it provides tracking and versioning capabilities for scenarios as well as unlock some DevOps practices for bot developers.

Originally, Health Bot Service allows you to develop bots fully at the portal. While it is very handy for piloting and prototyping, lack of versioning, approvals and control complicates management of production environments.

This cmdlets were implemented with two main usage scenarios in mind (check **Examples** section for quick snippets):
* Bot Replication: copy scenarios from development bot instance to production with a single command. That's especially useful when bot consists of multiple independent scenarios, that are too tedious to export/import manually.
* Full/Partial DevOps process with approvals (steps covered by this cmdlets are marked with _italic_):
  * Develop bot on the production service instance
  * _Export scenarios as a multiple JSON files using `Get-HCBScenario`_
  * Use source control tools locally (eg. git) to version and track changes
  * Once have finished with developing use the preferred Pull Request tools to discuss, review and undergo approval process, tag the commit
  * _Upload scenarios to the production bot instance either directly or through automatic deployment pipelines using `Set-HCBScenario`_

> The healthcare bot API enables exporting/importing scenarios only. Translations, models, data connections and etc are still required to be managed manually. Even without translation management in place, you can still add new stringIds to your scenario JSON. They will be automatically created on the first deployment with value set to the text property value for the default "en-US" locale.

## Requirements

* **OS**: Linux, Windows
* PowerShell (tested on Powershell Core 7.0)
* No additional software or modules are required

## References

* [Health Bot Service REST API Documentation](https://docs.microsoft.com/en-us/healthbot/integrations/managementapi)
* [Reddit thread](https://www.reddit.com/r/PowerShell/comments/8bc3rb/generate_jwt_json_web_token_in_powershell/) on PowerShell JWT symmetric signing

# Usage

Designed to be used locally for development and with any DevOps pipeline engine that support PowerShell. Hosted Azure DevOps pools have PowerShell installed on Windows and Ubuntu agent: use `powershell` step instead of generic `script`.

To import functions into the current PowerShell session import the module explicitly:

```powershell
PS > Import-Module -Name ./HCBotScenarioIE/ -Force
```

Before using, run tests with:
```powershell
PS > Install-Module -Name Pester -Force -SkipPublisherCheck
PS > Invoke-Pester
```

## Examples

To export and save all scenarios locally run the following. Then you can edit them manually, version with source control systems and carry through approval processes like PRs.

```powershell
PS > $SOURCE_TENANT_NAME="<YOUR_TENANT_NAME_HERE>";
PS > $SOURCE_JWT_SECRET="<YOUR_TENANT_JWT_SECRET_HERE>";

PS > Import-Module -Name ./HCBotScenarioIE/;
PS > Get-HCBScenario -Tenant $SOURCE_TENANT_NAME -SaveToFolder ./temp/ -ParseCode -JwtSecret $SOURCE_JWT_SECRET -InformationAction Continue;
```

Code below allows to import edited files to Health Bot Service tenant (potentially another one) manually or with DevOps tools.

```powershell
PS > $TARGET_TENANT_NAME="<YOUR_TENANT_NAME_HERE>";
PS > $TARGET_JWT_SECRET="<YOUR_TENANT_JWT_SECRET_HERE>";

PS > Import-Module -Name ./HCBotScenarioIE/;
PS > Set-HCBScenario -FromFolder "./temp" -Tenant $TARGET_TENANT_NAME -JwtSecret $TARGET_JWT_SECRET -InformationAction Continue;
```

Or unite them into the single piped command when want to export all scenarios from one tenant to the other:

```powershell
PS > $SOURCE_TENANT_NAME="<YOUR_TENANT_NAME_HERE>";
PS > $SOURCE_JWT_SECRET="<YOUR_TENANT_JWT_SECRET_HERE>";
PS > $TARGET_TENANT_NAME="<YOUR_TENANT_NAME_HERE>";
PS > $TARGET_JWT_SECRET="<YOUR_TENANT_JWT_SECRET_HERE>";

PS > Import-Module -Name ./HCBotScenarioIE/;
PS > Get-HCBScenario -Tenant $SOURCE_TENANT_NAME -JwtSecret $SOURCE_JWT_SECRET |
    Set-HCBScenario -Tenant $TARGET_TENANT_NAME -JwtSecret $TARGET_JWT_SECRET;
```

Check later sections for more details and reference.

## Scenario Export

Full syntax:

```powershell
Get-HCBScenario [-Tenant] <String> -JwtSecret <String> [-Name <String[]>] [-ParseCode] [-ReturnAsString] [-SaveToFolder <String>] [-FilePostfix <String>] [-NameProperty <String>] [-ServiceRegion <String>] [-InformationAction Continue]
```

> Use `Get-Help Get-HCBScenario -Full` for a detailed command reference.

To export all scenarios to local variable, run the following (check Health Bot Service -> Interaction -> Secrets for Tenant Name and JWT Secret values):

```powershell
PS > $scenarios = Get-HCBScenario -Tenant $TENANT_NAME -JwtSecret $JWT_SECRET;
```

To filter exported scenarios add optional `-Name` argument with wildcard expressions (supports * and ?). By default expressions are tested with `-like` against scenario's "name" property, but this behavior can be changed to "scenario_trigger" or "id" with `-NameProperty` flag.

```powershell
PS > Get-HCBScenario -Name "covid19_*","greetings" -NameProperty scenario_trigger -Tenant $TENANT_NAME -JwtSecret $JWT_SECRET -InformationAction Continue;
```

Special argument `-ParseCode` allows to parse scenario `$_.code` attribute (originally represented as a one-line string) for better change tracking with source control tools. This flag breaks expected REST API message format, but `Set-HCBScenario` handles that correctly before sending a request.

By default, scenarios are returned as an array of PowerShell objects. If you need them as a JSON string, set `-ReturnAsString` flag.

To additionally save scenarios locally, pass `-SaveToFolder <folder_path>` and if needed specify optional file name postfix (e.g `-FilePostfix ".scenario.json"`).

```powershell
PS > Get-HCBScenario -Tenant $TENANT_NAME -SaveToFolder ./temp/ -ParseCode -JwtSecret $JWT_SECRET -InformationAction Continue;
```

PowerShell common parameter `-InformationAction Continue` from the snippet above enables information-level output on cmdlet progress, otherwise it'll exit silently on success.

> For European deployments make sure to use `-ServiceRegion eu` to modify service base URI to https://eu.healthbot.microsoft.com/.

## Import scenarios

Full syntax:

```powershell
# Argument and Pipe forwarding
Set-HCBScenario [-Scenarios] <Object[]> -Tenant <String> -JwtSecret <String> [-ServiceRegion <String>] [-InformationAction Continue]

# Read from files
Set-HCBScenario -Tenant <String> -JwtSecret <String> -FromFolder <String> [-FileFilter <String>] [-ServiceRegion <String>] [-InformationAction Continue]
```

> Use `Get-Help Get-HCBScenario -Full` for a detailed command reference.

For importing scenarios to existing Health Bot Service instance pass exported scenarios directly to Set-HCBScenario cmdlet, like the following:

```powershell
Set-HCBScenario $scenarios -Tenant $TENANT_NAME -JwtSecret $JWT_SECRET;
```

You can also use pipe forwarding to achieve the same result. It can be used, for example, to forward scenarios from a dev instance to production.

```powershell
Get-HCBScenario -Tenant $DEV_TENANT_NAME -JwtSecret $DEV_JWT_SECRET | Set-HCBScenario -Tenant $PROD_TENANT_NAME -JwtSecret $PROD_JWT_SECRET -InformationAction Continue;
```

To post from previously exported and potentially manually modified files use `-FromFolder` parameter and narrow scenario selection with `-FileFilter`.

```powershell
Set-HCBScenario -FromFolder "./temp" -FileFilter "main-*.scenario.json" -Tenant $TENANT_NAME -ServiceRegion eu -JwtSecret $JWT_SECRET
```