# https://github.com/rajivharris/Set-PsEnv
Import-Module -Name ./Scripts/Set-PsEnv/Set-PsEnv;
# Import the contents of .env file into $env.
Set-PsEnv

# Import-Module -Name ./Scripts/ScenarioImportExport/HCBotScenarioIE/;
# # Export Scenarios from the bot instance specified in .env variables to the ./Scenarios folder.
# Get-HCBScenario -Tenant $env.SOURCE_TENANT_NAME -SaveToFolder ./Scenarios -ParseCode -JwtSecret $env.SOURCE_JWT_SECRET -InformationAction Continue;