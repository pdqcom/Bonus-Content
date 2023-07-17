#Modify the Application Name and Latest Application Version below:
$AppName = 'Microsoft OneDrive'
$AppVersion = '22.166.0807.0002'

###################################################################
$ScriptPath = Split-Path -parent $MyInvocation.MyCommand.Definition
$AppNameVariable = $AppName -replace '\s',''
$AppVersionVariable = "AppVer$AppNameVariable"
$AppNameVariable = "AppName$AppNameVariable"


$VariableXML = @"
<?xml version="1.0" encoding="utf-8"?>
<AdminArsenal.Export Code="PDQInventory" Name="PDQ Inventory" Version="19.0.40.0" MinimumVersion="5.0">
  <VariablesSettingsViewModel>
    <CustomVariables type="list">
      <CustomVariable>
        <Name>$AppNameVariable</Name>
        <Value>$AppName</Value>
      </CustomVariable>
      <CustomVariable>
        <Name>$AppVersionVariable</Name>
        <Value>$AppVersion</Value>
      </CustomVariable>
    </CustomVariables>
  </VariablesSettingsViewModel>
</AdminArsenal.Export>
"@


$CollectionXML = @"
<?xml version="1.0" encoding="utf-8"?>
<AdminArsenal.Export Code="PDQInventory" Name="PDQ Inventory" Version="19.0.40.0" MinimumVersion="4.0">
  <Collection>
    <ReportDefinition name="Definition">
      <RootFilter name="Filter">
        <Comparison>Any</Comparison>
        <Filters type="list">
          <ValueFilter>
            <Table>Application</Table>
            <Column>Name</Column>
            <Comparison>StartsWith</Comparison>
            <Value>@($AppNameVariable)</Value>
          </ValueFilter>
        </Filters>
      </RootFilter>
      <ReportDefinitionTypeName>BasicReportDefinition</ReportDefinitionTypeName>
      <Columns type="list">
        <Column>
          <Column>ComputerId</Column>
          <Summary></Summary>
          <Table>Computer</Table>
          <Title></Title>
        </Column>
      </Columns>
    </ReportDefinition>
    <IsDrilldown value="false" />
    <ImportedPath></ImportedPath>
    <TypeName>DynamicCollection</TypeName>
    <Created>0001-01-01T00:00:00.0000000-07:00</Created>
    <Description></Description>
    <Error></Error>
    <Id value="1341" />
    <LibraryCollectionId value="347" />
    <IsEnabled value="true" />
    <Modified>2022-09-20T16:57:24.0000000-06:00</Modified>
    <Name>Systems with $AppName INSTALLED</Name>
    <ParentId value="null" />
    <Path>Systems with $AppName INSTALLED</Path>
    <Type>DynamicCollection</Type>
    <Children type="list">
      <Collection>
        <ReportDefinition name="Definition">
          <RootFilter name="Filter">
            <Comparison>All</Comparison>
            <Filters type="list">
              <ValueFilter>
                <Table>Application</Table>
                <Column>Name</Column>
                <Comparison>StartsWith</Comparison>
                <Value>@($AppNameVariable)</Value>
              </ValueFilter>
              <ValueFilter>
                <Table>Application</Table>
                <Column>Version</Column>
                <Comparison>!VersionLowerThan</Comparison>
                <Value>@($AppVersionVariable)</Value>
              </ValueFilter>
            </Filters>
          </RootFilter>
          <ReportDefinitionTypeName>BasicReportDefinition</ReportDefinitionTypeName>
          <Columns type="list">
            <Column>
              <Column>ComputerId</Column>
              <Summary></Summary>
              <Table>Computer</Table>
              <Title></Title>
            </Column>
          </Columns>
        </ReportDefinition>
        <IsDrilldown value="false" />
        <ImportedPath></ImportedPath>
        <TypeName>DynamicCollection</TypeName>
        <Created>0001-01-01T00:00:00.0000000-07:00</Created>
        <Description>@($AppNameVariable) @($AppVersionVariable) or higher installed</Description>
        <Error></Error>
        <Id value="1342" />
        <LibraryCollectionId value="348" />
        <IsEnabled value="true" />
        <Modified>2022-09-20T16:57:23.0000000-06:00</Modified>
        <Name>$AppName LATEST VERSION INSTALLED</Name>
        <ParentId value="1341" />
        <Path>Systems with $AppName INSTALLED\$AppName LATEST VERSION INSTALLED</Path>
        <Type>DynamicCollection</Type>
        <Children type="list" />
      </Collection>
      <Collection>
        <ReportDefinition name="Definition">
          <RootFilter name="Filter">
            <Comparison>All</Comparison>
            <Filters type="list">
              <ValueFilter>
                <Table>Computer</Table>
                <Column>NeverScanned</Column>
                <Comparison>!IsTrue</Comparison>
              </ValueFilter>
              <GroupFilter>
                <Comparison>NotAny</Comparison>
                <Filters type="list">
                  <ValueFilter>
                    <Table>Application</Table>
                    <Column>Name</Column>
                    <Comparison>StartsWith</Comparison>
                    <Value>@($AppNameVariable)</Value>
                  </ValueFilter>
                </Filters>
              </GroupFilter>
            </Filters>
          </RootFilter>
          <ReportDefinitionTypeName>BasicReportDefinition</ReportDefinitionTypeName>
          <Columns type="list">
            <Column>
              <Column>ComputerId</Column>
              <Summary></Summary>
              <Table>Computer</Table>
              <Title></Title>
            </Column>
          </Columns>
        </ReportDefinition>
        <IsDrilldown value="false" />
        <ImportedPath></ImportedPath>
        <TypeName>DynamicCollection</TypeName>
        <Created>0001-01-01T00:00:00.0000000-07:00</Created>
        <Description>Systems missing @($AppNameVariable)</Description>
        <Error></Error>
        <Id value="1343" />
        <LibraryCollectionId value="349" />
        <IsEnabled value="true" />
        <Modified>2022-09-20T17:05:47.0000000-06:00</Modified>
        <Name>$AppName NOT INSTALLED</Name>
        <ParentId value="1341" />
        <Path>Systems with $AppName INSTALLED\$AppName NOT INSTALLED</Path>
        <Type>DynamicCollection</Type>
        <Children type="list">
          <Collection>
            <ReportDefinition name="Definition">
              <RootFilter name="Filter">
                <Comparison>All</Comparison>
                <Filters type="list">
                  <ValueFilter>
                    <Table>Computer</Table>
                    <Column>NeverScanned</Column>
                    <Comparison>!IsTrue</Comparison>
                  </ValueFilter>
                  <ValueFilter>
                    <Table>Computer</Table>
                    <Column>OSName</Column>
                    <Comparison>!Contains</Comparison>
                    <Value>server</Value>
                  </ValueFilter>
                  <GroupFilter>
                    <Comparison>NotAny</Comparison>
                    <Filters type="list">
                      <ValueFilter>
                        <Table>Application</Table>
                        <Column>Name</Column>
                        <Comparison>StartsWith</Comparison>
                        <Value>@($AppNameVariable)</Value>
                      </ValueFilter>
                    </Filters>
                  </GroupFilter>
                </Filters>
              </RootFilter>
              <ReportDefinitionTypeName>BasicReportDefinition</ReportDefinitionTypeName>
              <Columns type="list">
                <Column>
                  <Column>ComputerId</Column>
                  <Summary></Summary>
                  <Table>Computer</Table>
                  <Title></Title>
                </Column>
              </Columns>
            </ReportDefinition>
            <IsDrilldown value="false" />
            <ImportedPath></ImportedPath>
            <TypeName>DynamicCollection</TypeName>
            <Created>0001-01-01T00:00:00.0000000-07:00</Created>
            <Description></Description>
            <Error></Error>
            <Id value="1344" />
            <LibraryCollectionId value="350" />
            <IsEnabled value="true" />
            <Modified>2022-09-20T16:57:28.0000000-06:00</Modified>
            <Name>$AppName NOT INSTALLED (Workstations)</Name>
            <ParentId value="1343" />
            <Path>Systems with $AppName INSTALLED\$AppName NOT INSTALLED\$AppName NOT INSTALLED (Workstations)</Path>
            <Type>DynamicCollection</Type>
            <Children type="list" />
          </Collection>
        </Children>
      </Collection>
      <Collection>
        <ReportDefinition name="Definition">
          <RootFilter name="Filter">
            <Comparison>All</Comparison>
            <Filters type="list">
              <ValueFilter>
                <Table>Application</Table>
                <Column>Name</Column>
                <Comparison>StartsWith</Comparison>
                <Value>@($AppNameVariable)</Value>
              </ValueFilter>
              <ValueFilter>
                <Table>Application</Table>
                <Column>Version</Column>
                <Comparison>VersionLowerThan</Comparison>
                <Value>@($AppVersionVariable)</Value>
              </ValueFilter>
            </Filters>
          </RootFilter>
          <ReportDefinitionTypeName>BasicReportDefinition</ReportDefinitionTypeName>
          <Columns type="list">
            <Column>
              <Column>ComputerId</Column>
              <Summary></Summary>
              <Table>Computer</Table>
              <Title></Title>
            </Column>
          </Columns>
        </ReportDefinition>
        <IsDrilldown value="false" />
        <ImportedPath></ImportedPath>
        <TypeName>DynamicCollection</TypeName>
        <Created>0001-01-01T00:00:00.0000000-07:00</Created>
        <Description>@($AppNameVariable) version lower than @($AppVersionVariable)</Description>
        <Error></Error>
        <Id value="1345" />
        <LibraryCollectionId value="351" />
        <IsEnabled value="true" />
        <Modified>2022-09-20T16:57:22.0000000-06:00</Modified>
        <Name>Systems with OLD VERSION of $AppName INSTALLED</Name>
        <ParentId value="1341" />
        <Path>Systems with $AppName INSTALLED\Systems with OLD VERSION of $AppName INSTALLED</Path>
        <Type>DynamicCollection</Type>
        <Children type="list" />
      </Collection>
    </Children>
  </Collection>
</AdminArsenal.Export>
"@

$VariableXML | Out-File $ScriptPath\Variables.xml -encoding utf8
$CollectionXML | Out-File $ScriptPath\Collections.xml -encoding utf8