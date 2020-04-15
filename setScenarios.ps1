# https://github.com/rajivharris/Set-PsEnv
Import-Module -Name ./Scripts/Set-PsEnv/;
# Import the contents of .env file into $env.
Set-PsEnv

Import-Module -Name ./Scripts/ScenarioImportExport/HCBotScenarioIE/;
# Export Scenarios from the bot instance specified in .env variables to the ./Scenarios folder.
Set-HCBScenario -FromFolder ./Scenarios -Tenant $env:SOURCE_TENANT_NAME -JwtSecret $env:SOURCE_JWT_SECRET -InformationAction Continue;