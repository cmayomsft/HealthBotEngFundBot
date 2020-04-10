$ModuleName = "HCBotScenarioIE";
$ModulePath = Join-Path $PSScriptRoot "..";
$ModuleManifestName = "${ModuleName}.psd1";
$ModuleManifestPath = Join-Path $PSScriptRoot "../$ModuleManifestName";

Import-Module $ModulePath -Force;

Describe 'Module Manifest Tests' {
    It 'Passes Test-ModuleManifest' {
        Test-ModuleManifest -Path $ModuleManifestPath | Should Not BeNullOrEmpty
        $? | Should Be $true
    }
}

Describe 'Get-HCBScenario' {
    InModuleScope $ModuleName {
        $TENANT_NAME = "TEST_TENANT";
        $JWT_SECRET = "TEST_JWT_SECRET";
        $SCENARIOS_GET_SUCCESS_FIXTURE_PATH = Join-Path $PSScriptRoot "fixture/scenarios_get_success_stub.json";
        $SCENARIOS_GET_SUCCESS_RESPONSE_STUB = Get-Content $SCENARIOS_GET_SUCCESS_FIXTURE_PATH -Raw | ConvertFrom-JSON;

        Context 'When Called With Default Arguments' {

            Mock Invoke-WebRequest -ModuleName $ModuleName {
                return $SCENARIOS_GET_SUCCESS_RESPONSE_STUB;
            }

            $scenarios = Get-HCBScenario -Tenant $TENANT_NAME -JwtSecret $JWT_SECRET;

            It 'Returns Expected Scenarios' {
                $scenarios | Select-Object -ExpandProperty Name | Sort-Object | Should Be "Greetings", "Main"
            }

            It 'Returns Parsed Scenarios with Expected Content' {
                $scenarios[0] | Should Not BeOfType [string];

                $greetingsScenario = ($scenarios | Where-Object { $_.name -eq "Greetings" })[0];

                $greetingsScenario.scenario_trigger | Should Be "Greetings";
                $greetingsScenario.id | Should Be "398e4a12-a1df-4770-9ff0-fa54dcb5c718";
                $greetingsScenario.code | Should BeLike "*aaa3073dc553-32a44525cced8e2f-2200*" #step id
            }

            It 'Returns Code As JSON String' {
                $scenarios[0].code | Should BeOfType [string];
            }

            It 'Calls Invoke-WebRequest with OAuth Authorization' {
                Assert-MockCalled Invoke-WebRequest -ParameterFilter { $Authentication -in "OAuth", "Bearer" }
            }

            It 'Call Invoke-WebRequest with Required Claims' {
                Assert-MockCalled Invoke-WebRequest -ParameterFilter { 
                    $Token && 
                    $Token.header.alg -eq "HS256" &&
                    $Token.header.typ -eq "JWT" &&
                    $Token.payload.tenantName -eq $TENANT_NAME &&
                    $Token.payload.iat -is [int]
                }
            }

            It 'Calls Invoke-WebRequest with the correct URL' {
                Assert-MockCalled Invoke-WebRequest -ParameterFilter { $Uri -like "**healthbot.microsoft.com**${TENANT_NAME}**" }
            }
        }

        Context 'When Called with -SaveToFolder' {
            $SAVE_PATH = "TestDrive:\$(New-Guid)";

            Mock Invoke-WebRequest -ModuleName $ModuleName {
                return $SCENARIOS_GET_SUCCESS_RESPONSE_STUB;
            }

            Get-HCBScenario -Tenant $TENANT_NAME -ParseCode -ReturnAsString -SaveToFolder $SAVE_PATH -JwtSecret $JWT_SECRET;

            It 'Creates Files for Each Scenario' {
                Get-ChildItem $SAVE_PATH | Should HaveCount 2
                Get-ChildItem $SAVE_PATH | Where-Object { $_.Name -like "**Greetings.scenario.json" } | Should HaveCount 1
                Get-ChildItem $SAVE_PATH | Where-Object { $_.Name -like "**Main.scenario.json" } | Should HaveCount 1
            }
            
            It 'Creates File with Expected Content Parts' {
                "$SAVE_PATH\Greetings.scenario.json" | Should FileContentMatch '"name":\s*"Greetings"';
                "$SAVE_PATH\Greetings.scenario.json" | Should FileContentMatch '"scenario_trigger":\s*"Greetings"';
                "$SAVE_PATH\Greetings.scenario.json" | Should FileContentMatch '"id":\s*"aaa3073dc553-32a44525cced8e2f-2200"' #step
            }
        }

        It 'Returns Only Specified Scenarios when -Name Pattern Is Passed' {
            Mock Invoke-WebRequest -ModuleName $ModuleName {
                return $SCENARIOS_GET_SUCCESS_RESPONSE_STUB;
            }

            $scenarios = Get-HCBScenario -Name "nonexistingscenario", "Greeting*" -Tenant $TENANT_NAME -JwtSecret $JWT_SECRET;

            $scenarios | Select-Object -ExpandProperty Name | Sort-Object | Should Be "Greetings";
        }

        It 'Uses the Specified Field for Testing when -NameProperty Is Passed' {
            Mock Invoke-WebRequest -ModuleName $ModuleName {
                return $SCENARIOS_GET_SUCCESS_RESPONSE_STUB;
            }

            $scenarios = Get-HCBScenario -Name "*fa54dcb5c718" -NameProperty "id" -Tenant $TENANT_NAME -JwtSecret $JWT_SECRET;

            $scenarios | Select-Object -ExpandProperty Name | Sort-Object | Should Be "Greetings";
        }

        It 'Uses Specified Name Property for File Names When -NameName Is Passed' {
            $SAVE_PATH = "TestDrive:\$(New-Guid)";
            Mock Invoke-WebRequest -ModuleName $ModuleName {
                return $SCENARIOS_GET_SUCCESS_RESPONSE_STUB;
            }

            Get-HCBScenario -Tenant $TENANT_NAME -NameProperty id -SaveToFolder $SAVE_PATH -JwtSecret $JWT_SECRET;

            Get-ChildItem $SAVE_PATH | Should HaveCount 2
            Get-ChildItem $SAVE_PATH | Where-Object { $_.Name -like "**398e4a12-a1df-4770-9ff0-fa54dcb5c718.scenario.json" } | Should HaveCount 1
            Get-ChildItem $SAVE_PATH | Where-Object { $_.Name -like "**d36b9743-8736-4db4-ac1a-558ada599cd5.scenario.json" } | Should HaveCount 1
        }

        It 'Returns JSON Strings When Called with -ReturnAsStrings' {
            Mock Invoke-WebRequest -ModuleName $ModuleName {
                return $SCENARIOS_GET_SUCCESS_RESPONSE_STUB;
            }

            $scenarios = Get-HCBScenario -Tenant $TENANT_NAME -JwtSecret $JWT_SECRET -ReturnAsString;

            $scenarios[0] | Should BeOfType [string];
        }

        It 'Returns Parsed Code When Called with -ParseCode' {
            Mock Invoke-WebRequest -ModuleName $ModuleName {
                return $SCENARIOS_GET_SUCCESS_RESPONSE_STUB;
            }

            $scenarios = Get-HCBScenario -Tenant $TENANT_NAME -ParseCode -JwtSecret $JWT_SECRET;

            $scenarios[0].code | Should Not BeOfType [string];

            
            $code = ($scenarios | Where-Object { $_.name -eq "Greetings" })[0].code;
            $code.steps[0].id | Should Be "aaa3073dc553-32a44525cced8e2f-2200"
            $code.steps[0].type | Should Be "statement"
            $code.steps[0].text | Should Be "Greetings!"
            $code.steps[0].stringId | Should Be "stringId_f36dc98419815572"
        }

        It "Calls Europe Service Instance When Called with -ServiceRegion eu" {
            Mock Invoke-WebRequest -ModuleName $ModuleName {
                return $SCENARIOS_GET_SUCCESS_RESPONSE_STUB;
            }

            Get-HCBScenario -Tenant $TENANT_NAME -ServiceRegion eu -JwtSecret $JWT_SECRET | Out-Null;

            Assert-MockCalled Invoke-WebRequest -ParameterFilter { $Uri -like "**eu.healthbot.microsoft.com**" }
        }

        It 'Creates Files with Specified Postfix When Called with -FilePostfix' {
            $SAVE_PATH = "TestDrive:\$(New-Guid)";
            Mock Invoke-WebRequest -ModuleName $ModuleName {
                return $SCENARIOS_GET_SUCCESS_RESPONSE_STUB;
            }

            Get-HCBScenario -Tenant $TENANT_NAME -SaveToFolder $SAVE_PATH -FilePostfix ".out.sce" -JwtSecret $JWT_SECRET | Out-Null;

            Get-ChildItem $SAVE_PATH | Should HaveCount 2
            Get-ChildItem $SAVE_PATH | Where-Object { $_.Name -like "**Greetings.out.sce" } | Should HaveCount 1
            Get-ChildItem $SAVE_PATH | Where-Object { $_.Name -like "**Main.out.sce" } | Should HaveCount 1
        }

        It 'Overrides the file if it''s called with the same output folder' {
            $SAVE_PATH = "TestDrive:\$(New-Guid)";
            Mock Invoke-WebRequest -ModuleName $ModuleName {
                return $SCENARIOS_GET_SUCCESS_RESPONSE_STUB;
            }

            Get-HCBScenario -Tenant $TENANT_NAME -Name "Greetings" -SaveToFolder $SAVE_PATH -JwtSecret $JWT_SECRET | Out-Null;
            $firstRunModificationDate = (Get-ChildItem $SAVE_PATH -Filter "Greetings.scenario.json").LastWriteTime;
            $firstRunLength = (Get-ChildItem $SAVE_PATH -Filter "Greetings.scenario.json").Length;

            Get-HCBScenario -Tenant $TENANT_NAME -Name "Greetings" -SaveToFolder $SAVE_PATH -JwtSecret $JWT_SECRET | Out-Null;
            $secondRunModificationDate = (Get-ChildItem $SAVE_PATH -Filter "Greetings.scenario.json").LastWriteTime;
            $secondRunLength = (Get-ChildItem $SAVE_PATH -Filter "Greetings.scenario.json").Length;

            $secondRunModificationDate | Should BeGreaterThan $firstRunModificationDate;
            $firstRunLength | Should Be $secondRunLength;
        }
    }
}

Describe 'Set-HCBScenario' {
    InModuleScope $ModuleName {
        $TENANT_NAME = "TEST_TENANT";
        $JWT_SECRET = "TEST_JWT_SECRET";
        $SCENARIOS_FIXTURE_PATH = Join-Path $PSScriptRoot "fixture";
        $SCENARIOS_FIXTURE_PATTERN = Join-Path $SCENARIOS_FIXTURE_PATH "*.scenario.json";
        $TEST_SCENARIOS = Get-ChildItem $SCENARIOS_FIXTURE_PATTERN | Get-Content -Raw;

        Context 'When Called With Scenario Passed as JSON String Argument' {

            Mock Invoke-WebRequest -ModuleName $ModuleName { }

            Set-HCBScenario $TEST_SCENARIOS -Tenant $TENANT_NAME -JwtSecret $JWT_SECRET;

            It 'Posts Expected Scenarios' {
                Assert-MockCalled Invoke-WebRequest -Times 2 -ParameterFilter { $Method -eq "POST" }
                Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter { $Method -eq "POST" && $Body -like "**greeting**" }
                Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter { $Method -eq "POST" && $Body -like "**Main**" }
            }

            It 'Posts Expected ScenarioContent Parts' {
                Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter { $Method -eq "POST" && $Body -like '**"name": *"Greetings"**' };
                Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter { $Method -eq "POST" && $Body -like '**"scenario_trigger": *"Greetings"**' };
                Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter { $Method -eq "POST" && $Body -like '**"id":\s*"aaa3073dc553-32a44525cced8e2f-2200"**' } #step
            }

            It 'Posts Code As JSON String' {
                Assert-MockCalled Invoke-WebRequest -Times 2 -ParameterFilter { $Method -eq "POST" && $Body -like '**"code": "**' }
            }

            It 'Calls Invoke-WebRequest with OAuth Authorization' {
                Assert-MockCalled Invoke-WebRequest -Times 2 -ParameterFilter { $Authentication -in "OAuth", "Bearer" }
            }

            It 'Call Invoke-WebRequest with Required Claims' {
                Assert-MockCalled Invoke-WebRequest -Times 2 -ParameterFilter { 
                    $Token && 
                    $Token.header.alg -eq "HS256" &&
                    $Token.header.typ -eq "JWT" &&
                    $Token.payload.tenantName -eq $TENANT_NAME &&
                    $Token.payload.iat -is [int]
                }
            }

            It 'Calls Invoke-WebRequest with the correct URL' {
                Assert-MockCalled Invoke-WebRequest -Times 2 -ParameterFilter { $Uri -like "**healthbot.microsoft.com**${TENANT_NAME}**" }
            }
        }

        Context 'When Called With Parsed Scenarios Passed through Pipe' {

            Mock Invoke-WebRequest -ModuleName $ModuleName { }

            $TEST_SCENARIOS | ConvertFrom-Json | Set-HCBScenario -Tenant $TENANT_NAME -JwtSecret $JWT_SECRET;

            It 'Posts Expected Scenarios' {
                Assert-MockCalled Invoke-WebRequest -Times 2 -ParameterFilter { $Method -eq "POST" }
                Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter { $Method -eq "POST" && $Body -like "**greeting**" }
                Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter { $Method -eq "POST" && $Body -like "**Main**" }
            }

            It 'Posts Expected ScenarioContent Parts' {
                Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter { $Method -eq "POST" && $Body -like '**"name": *"Greetings"**' };
                Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter { $Method -eq "POST" && $Body -like '**"scenario_trigger": *"Greetings"**' };
                Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter { $Method -eq "POST" && $Body -like '**"id":\s*"aaa3073dc553-32a44525cced8e2f-2200"**' } #step
            }

            It 'Posts Code As JSON String' {
                Assert-MockCalled Invoke-WebRequest -Times 2 -ParameterFilter { $Method -eq "POST" && $Body -like '**"code": "**' }
            }

            It 'Calls Invoke-WebRequest with Authorization' {
                Assert-MockCalled Invoke-WebRequest -Times 2 -ParameterFilter { $Authentication -in "OAuth", "Bearer" }
            }

            It 'Calls Invoke-WebRequest with the correct URL' {
                Assert-MockCalled Invoke-WebRequest -Times 2 -ParameterFilter { $Uri -like "**healthbot.microsoft.com**${TENANT_NAME}**" }
            }
        }

        Context 'When Called With -FromFolder' {

            Mock Invoke-WebRequest -ModuleName $ModuleName { }

            Set-HCBScenario -FromFolder $SCENARIOS_FIXTURE_PATH -Tenant $TENANT_NAME -JwtSecret $JWT_SECRET;

            It 'Posts Expected Scenarios' {
                Assert-MockCalled Invoke-WebRequest -Times 2 -ParameterFilter { $Method -eq "POST" }
                Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter { $Method -eq "POST" && $Body -like "**greeting**" }
                Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter { $Method -eq "POST" && $Body -like "**Main**" }
            }

            It 'Posts Expected ScenarioContent Parts' {
                Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter { $Method -eq "POST" && $Body -like '**"name": *"Greetings"**' };
                Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter { $Method -eq "POST" && $Body -like '**"scenario_trigger": *"Greetings"**' };
                Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter { $Method -eq "POST" && $Body -like '**"id":\s*"aaa3073dc553-32a44525cced8e2f-2200"**' } #step
            }

            It 'Posts Code As JSON String' {
                Assert-MockCalled Invoke-WebRequest -Times 2 -ParameterFilter { $Method -eq "POST" && $Body -like '**"code": "**' }
            }

            It 'Calls Invoke-WebRequest with Authorization' {
                Assert-MockCalled Invoke-WebRequest -Times 2 -ParameterFilter { $Authentication -in "OAuth", "Bearer" }
            }

            It 'Calls Invoke-WebRequest with the correct URL' {
                Assert-MockCalled Invoke-WebRequest -Times 2 -ParameterFilter { $Uri -like "**healthbot.microsoft.com**${TENANT_NAME}**" }
            }
        }

        It "Calls Europe Service Instance When Called with -ServiceRegion eu" {
            Mock Invoke-WebRequest -ModuleName $ModuleName {
                return $SCENARIOS_GET_SUCCESS_RESPONSE_STUB;
            }

            Set-HCBScenario $TEST_SCENARIOS -Tenant $TENANT_NAME -ServiceRegion eu -JwtSecret $JWT_SECRET;

            Assert-MockCalled Invoke-WebRequest -ParameterFilter { $Uri -like "**eu.healthbot.microsoft.com**" }
        }

        It 'Posts Files with Specified Pattern When Called with -FileFilter' {
            Mock Invoke-WebRequest -ModuleName $ModuleName { }

            Set-HCBScenario -FromFolder $SCENARIOS_FIXTURE_PATH -FileFilter "*.out.sce", "*.scenario.json" -Tenant $TENANT_NAME -JwtSecret $JWT_SECRET;

            Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter { $Method -eq "POST" }
            Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter { $Method -eq "POST" && $Body -like "**greeting**" }
        }
    }
}



# Utility Functions
function Parse-JWTtoken {
 
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$token
    )

    if (!$token.Contains(".") -or !$token.StartsWith("eyJ")) { Write-Error "Invalid token" -ErrorAction Stop }
 
    #Header
    $tokenheader = $token.Split(".")[0].Replace('-', '+').Replace('_', '/')
    while ($tokenheader.Length % 4) { $tokenheader += "=" }
    $header = [System.Text.Encoding]::ASCII.GetString([system.convert]::FromBase64String($tokenheader)) | ConvertFrom-Json;
 
    #Payload
    $tokenPayload = $token.Split(".")[1].Replace('-', '+').Replace('_', '/')
    while ($tokenPayload.Length % 4) { $tokenPayload += "=" }

    $payload = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($tokenPayload)) | ConvertFrom-Json
    
    return @{ header = $header; payload = $payload };
}