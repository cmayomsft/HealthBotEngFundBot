# Implement your module commands in this script.

function Get-JWT {
    <#
.SYNOPSIS
    Create a JWT (JSON Web Token).
.DESCRIPTION
    Generate and signs JWT given a payload and a symmetric secret.

    Inspired by https://www.reddit.com/r/PowerShell/comments/8bc3rb/generate_jwt_json_web_token_in_powershell/

.INPUTS
    Pipe input is not supported.
    See parameters for more details.
.OUTPUTS
    System.String. Get-JWT returns a string with the signed JWT.

.PARAMETER Algorithm
    Specifies the symmetric algorithm (header "alg" property) to sign: HS256, HS384, HS512.

.PARAMETER Type
    Specifies a value included into header "typ" property.

.PARAMETER AdditionalHeaders
    Specifies a hashtable of other header properties to include.
    Use -Algorithm and -Type to override "alg" and "typ" values.

.PARAMETER Payload
    Specifies a hashtable of claims (payload properties) to include. "Issued at" (iat) is added automatically.

.PARAMETER SecretKey
    Specifies the secret key to sign the token.

.PARAMETER ValidForSeconds
    Controls the value of "Expiration Time" (exp) claim, calculated as "Issued at" (iat) + $ValidForSeconds.

.PARAMETER IssuedAtDelay
    Seconds. Specifies a delay added to "Issued at" (iat), calculated as <Current Unix Time Stamp> + IssuesAtDalay.
    Can be negative to incorporate possible client/server time difference.

.EXAMPLE
    Get-JWT -Algorithm HS256 -AdditionalHeaders @{ Header1 = "Value"; Header2 = 2 } -Payload @{ Claim1 = "Value"; Claim2 = 1 } -SecretKey "SECRET_KEY" -IssuedAtDelay -60 -ValidForSeconds 3600;

.LINK
    https://jwt.io/
.LINK
    https://jwt.ms/
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        [ValidateSet("HS256", "HS384", "HS512")]
        $Algorithm,

        [Parameter(Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        $Type = "JWT",

        [Parameter(Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [hashtable]$AdditionalHeaders = @{ },

        [Parameter(Mandatory = $True, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [hashtable]$Payload,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        $SecretKey,

        [Parameter(Mandatory = $False)]
        [int]$ValidForSeconds = $null,

        [Parameter(Mandatory = $False)]
        [int]$IssuedAtDelay = 0
    )
    # Build header
    [hashtable]$header = @{alg = $Algorithm; typ = $Type }
    foreach ($key in $AdditionalHeaders.Keys) {
        $header.Add($key, $AdditionalHeaders[$key]);
    }

    # Build payload
    $iat = ([int][double]::parse((Get-Date -Date $((Get-Date).ToUniversalTime()) -UFormat %s))) + $IssuedAtDelay;
    $Payload.Add("iat", $iat);

    if ($ValidForSeconds) {
        $exp = $iat + $ValidForSeconds;
        $Payload.Add("exp", $exp);
    }

    # Convert to JSON and sign
    $headerjson = $header | ConvertTo-Json -Compress
    $payloadjson = $payload | ConvertTo-Json -Compress

    $headerjsonbase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($headerjson)).Split('=')[0].Replace('+', '-').Replace('/', '_')
    $payloadjsonbase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($payloadjson)).Split('=')[0].Replace('+', '-').Replace('/', '_')

    $toBeSigned = $headerjsonbase64 + "." + $payloadjsonbase64

    $signingAlgorithm = switch ($Algorithm) {
        "HS256" { New-Object System.Security.Cryptography.HMACSHA256 }
        "HS384" { New-Object System.Security.Cryptography.HMACSHA384 }
        "HS512" { New-Object System.Security.Cryptography.HMACSHA512 }
    }

    $signingAlgorithm.Key = [System.Text.Encoding]::UTF8.GetBytes($SecretKey)
    $signature = [Convert]::ToBase64String($signingAlgorithm.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($toBeSigned))).Split('=')[0].Replace('+', '-').Replace('/', '_')

    # Return JWT
    $token = "$headerjsonbase64.$payloadjsonbase64.$signature"
    $token
}

function Get-HCBScenario {
    <#
.SYNOPSIS
    Exports scenarios from Azure Healthcare Bot instance.
.DESCRIPTION
    Use Healthcare Bot Service API to export all scenarios from the specified tenant. Jwt Secret is required.

.INPUTS
    Pipe input is not supported.
    See parameters for more details.
.OUTPUTS
    Collection of System.String with JSON/Parsed Object (controlled with -ReturnAsString) representing scenarios from the bot.

.PARAMETER Tenant
    Specifies the instance/tenant name of Healthcare Bot Service.

    Check Integration -> Secrets -> tenantName on Healthcare Bot Service management portal for a value.

.PARAMETER JwtSecret
    Specifies the JWT Secret to authenticate the request.

    Check Integration -> Secrets -> API_JWT_SECRET on Healthcare Bot Service management portal for a value.

.PARAMETER Name
    Specifies scenario, list of scenarios or wildcard patterns to export from the service.

    Scenario propert (name, scenario_trigger or id) tested againes is controlled by -NameProperty argument, defaults to "name".

.PARAMETER ParseCode
    Specifies whether to parse scenario's code property. It contains JSON in string format that complicates management with source control systems.

    Once parsed, produced JSON cannot be used to directly post values back to scenarios REST endpoint. Set-HCBScenario knows how to undo the conversion.

.PARAMETER ReturnAsString
    Specifies whether the returned value should be a JSON strings instead of PowerShell objects.

.PARAMETER SaveToFolder
    Specifies whether and where to write scenarios as json files.

.PARAMETER NameProperty
    Specified property used as "name" in the service. Affects values tested against -Name filter and file name prefix when saving to folder.

    Possible values: name, scenario_trigger, id. Defaults to: name

.PARAMETER FilePostfix
    Specifies a postfix for output files, default: ".scenario.json".

.PARAMETER ServiceRegion
    Specifies which regional Healthcare Bot Service endpoint to use. Default: "us"; Possible values: "us", "eu".

.EXAMPLE
    # Minimal command
    Get-HCBScenario -Tenant $TENANT_NAME -JwtSecret $JWT_SECRET -InformationAction Continue;

.EXAMPLE
    # Export only specific scenarios
    Get-HCBScenario -Name "COVID19 - *","Greetings" -Tenant $TENANT_NAME -JwtSecret $JWT_SECRET -InformationAction Continue;

.EXAMPLE
    # Return values as JSON string
    Get-HCBScenario -Tenant $TENANT_NAME -ReturnAsString -JwtSecret $JWT_SECRET -InformationAction Continue;

.EXAMPLE
    # Save scenarios locally
    Get-HCBScenario -Tenant $TENANT_NAME -SaveToFolder ./temp/ -ParseCode -JwtSecret $JWT_SECRET -InformationAction Continue;


.NOTES
    Use -InformationAction Continue argument to see execution output.

.LINK
    https://docs.microsoft.com/en-us/healthbot/integrations/managementapi
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, Position = 0)]
        [string]$Tenant,

        [Parameter(Mandatory = $True)]
        [string]$JwtSecret,

        [Parameter(Mandatory = $False)]
        [Alias("Names")]
        [string[]]$Name = $null,

        [Parameter(Mandatory = $False)]
        [switch]$ParseCode,

        [Parameter(Mandatory = $False)]
        [switch]$ReturnAsString,

        [Parameter(Mandatory = $False)]
        [string]$SaveToFolder = $null,

        [Parameter(Mandatory = $False)]
        [ValidateSet("scenario_trigger", "name", "id")]
        [string]$NameProperty = "name",

        [Parameter(Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePostfix = ".scenario.json",

        [Parameter(Mandatory = $False)]
        [ValidateSet("us", "eu")]
        [string]$ServiceRegion = "us"
    )

    $baseUrl = "https://${ServiceRegion}.healthbot.microsoft.com/";
    $apiUrl = "${baseUrl}api/account/${Tenant}/scenarios";
    Write-Information "Using API URL: $apiUrl";

    $jwtToken = Get-JWT -Algorithm HS256 -Payload @{ tenantName = $Tenant } -SecretKey $JwtSecret -IssuedAtDelay -60;
    Write-Information "Using JWT Token: $jwtToken";

    try {
        Write-Information "Requesting information from $Tenant";
        $jwtToken = ConvertTo-SecureString $jwtToken -AsPlainText -Force;
        $response = Invoke-WebRequest $apiUrl -Method GET -Authentication OAuth -Token $jwtToken;

        $scenarios = $response.Content | ConvertFrom-Json;
        if ($Name) {
            $scenarios = $scenarios | Where-Object {
                $scenarioName = $_.$NameProperty
                ($Name | Where-Object { $scenarioName -like $_ }).Count -gt 0;
            };
        }

        foreach ($scenario in $scenarios) {
            try {
                Write-Information "Processing ""$($scenario.$NameProperty)""";
                if ($ParseCode) {
                    $scenario.code = $scenario.code | ConvertFrom-Json;
                }

                if ($SaveToFolder) {
                    New-Item $SaveToFolder -ItemType Directory -Force | Out-Null;
                    $filePath = Join-Path $SaveToFolder "$($scenario.$NameProperty)$FilePostfix";
    
                    Write-Information "Saving ""$($scenario.$NameProperty)"" to ${filePath}";
                    ConvertTo-Json -Depth 100 $scenario | Out-File $filePath -ErrorAction Continue;
                }
                if ($ReturnAsString) {
                    $scenario = ConvertTo-Json -Depth 100 $scenario;
                }

                $scenario; # Implicit yield return
            }
            catch {
                $scenarioName = $scenario.$NameProperty ?? "UNDEFINED";
                Write-Error "Failed to process scenario ""$scenarioName"", skipping: $_";
            }
        }
    }
    catch [Microsoft.PowerShell.Commands.HttpResponseException] {
        throw "Failed to request data from Health Bot Service: ""$_""";
    }
    catch {
        # Too Generic ArgumentException, therefore here
        if ($_.FullyQualifiedErrorId -eq "System.ArgumentException,Microsoft.PowerShell.Commands.ConvertFromJsonCommand") {
            throw "Failed to parse scenario JSON: ""$_"""
        }
        throw "Failed: ""$_""";
    }
}

function Set-HCBScenario {
    <#
.SYNOPSIS
    Import scenarios to Azure Healthcare Bot instance.
.DESCRIPTION
    Use Healthcare Bot Service API to import scenarios to the specified tenant. Jwt Secret is required.

.INPUTS
    Pipe: Array of JSON strings | Array of PowerShell Objects of corresponding format
    Argument -Scenarios: Array of JSON strings | Array of PowerShell Objects of corresponding format
    Read from files with -FromFolder <path> -FileFilter <string>
.OUTPUTS
    None

.PARAMETER Tenant
    Specifies the instance/tenant name of Healthcare Bot Service.

    Check Integration -> Secrets -> tenantName on Healthcare Bot Service management portal for a value.

.PARAMETER JwtSecret
    Specifies the JWT Secret to authenticate the request.

    Check Integration -> Secrets -> API_JWT_SECRET on Healthcare Bot Service management portal for a value.

.PARAMETER Scenarios
    Arrays of scenarios to import. Arrays of both JSON strings and PowerShell objects of expected format are accepted.
    Supports pipe input.

.PARAMETER FromFolder
    Specifies whether and from where to read scenarios as json files. When specified, pipe input or -Scenarios argument are ignored.

.PARAMETER FileFilter
    Specifies a wildcard pattern for for files to read, default: "*.scenario.json".

.PARAMETER ServiceRegion
    Specifies which regional Healthcare Bot Service endpoint to use. Default: "us"; Possible values: "us", "eu".

.EXAMPLE
    # Pass scenarios as an argument

    $scenarios = Get-HCBScenario -Tenant $TENANT_NAME -ParseCode -JwtSecret $JWT_SECRET;
    Set-HCBScenario $scenarios -Tenant $TENANT_NAME -JwtSecret $JWT_SECRET -InformationAction Continue;

.EXAMPLE
    # Pipeline input
    Get-HCBScenario -Tenant $DEV_TENANT_NAME -JwtSecret $DEV_JWT_SECRET | Set-HCBScenario -Tenant $PROD_TENANT_NAME -JwtSecret $PROD_JWT_SECRET -InformationAction Continue;

.EXAMPLE
    # Read from files
    Set-HCBScenario -FromFolder "./temp" -FileFilter "main-*.scenario.json" -Tenant $TENANT_NAME -ServiceRegion eu -JwtSecret $JWT_SECRET -InformationAction Continue;

.NOTES
    Code property is automatically converted to string if needed.

.LINK
    https://docs.microsoft.com/en-us/healthbot/integrations/managementapi
#>
    [CmdletBinding(DefaultParameterSetName = "Argument")]
    param (
        [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True, ParameterSetName = "Argument")]
        [Alias("Scenario")]
        [object[]]$Scenarios,

        [Parameter(Mandatory = $True)]
        [string]$Tenant,

        [Parameter(Mandatory = $True)]
        [string]$JwtSecret,

        [Parameter(Mandatory = $True, ParameterSetName = "Files")]
        [ValidateNotNullOrEmpty()]
        [string]$FromFolder,

        [Parameter(Mandatory = $False, ParameterSetName = "Files")]
        [ValidateNotNullOrEmpty()]
        [string[]]$FileFilter = "*.scenario.json",

        [Parameter(Mandatory = $False)]
        [ValidateSet("us", "eu")]
        [string]$ServiceRegion = "us"
    )
    begin {
        $baseUrl = "https://${ServiceRegion}.healthbot.microsoft.com/";
        $apiUrl = "${baseUrl}api/account/${Tenant}/scenarios";
        Write-Information "Using API URL: $apiUrl";

        $jwtToken = Get-JWT -Algorithm HS256 -Payload @{ tenantName = $Tenant } -SecretKey $JwtSecret -IssuedAtDelay -60;
        Write-Information "Using JWT Token: $jwtToken";
        $jwtToken = ConvertTo-SecureString $jwtToken -AsPlainText -Force;

        try {
            if ($FromFolder) {
                if (!$FromFolder.EndsWith("*")) { $FromFolder = Join-Path $FromFolder "*" };
                $Scenarios = Get-ChildItem -Path $FromFolder -Include $FileFilter -ErrorAction Stop | Get-Content -Raw;
                if (!$Scenarios -or $Scenarios.Count -eq 0) {
                    Write-Warning "No scenario files were found. Check -FileFilter pattern";
                }
            }
        }
        catch {
            throw "Failed or partially failed to read the files: $_";
        }
    }

    process {
        foreach ($scenario in $Scenarios) {
            # prepare scenario content
            try {
                if ($scenario -is [string]) {
                    $scenario = $scenario | ConvertFrom-Json;
                }
                if ($scenario.code -isnot [string]) {
                    $scenario.code = $scenario.code | ConvertTo-Json -Depth 100;
                }
    
                Write-Information "Uploading ""$($scenario.name)"" to $Tenant";
                $scenario | ConvertTo-Json -Depth 100 | Invoke-WebRequest $apiUrl -Method POST -Authentication OAuth -Token $jwtToken -ContentType "application/json; charset=utf-8" | Out-Null;
            }
            catch [Microsoft.PowerShell.Commands.HttpResponseException] {
                throw "Update request to Health Bot Service failed: ""$_""";
            }
            catch {
                # Too Generic ArgumentException, therefore here
                if ($_.FullyQualifiedErrorId -eq "System.ArgumentException,Microsoft.PowerShell.Commands.ConvertFromJsonCommand") {
                    throw "Failed to parse scenario JSON: ""$_""";
                }
                throw "Failed: ""$_""";
            }
        }
    }
}

# Export only the functions using PowerShell standard verb-noun naming.
# Be sure to list each exported functions in the FunctionsToExport field of the module manifest file.
# This improves performance of command discovery in PowerShell.
Export-ModuleMember -Function Get-HCBScenario, Set-HCBScenario