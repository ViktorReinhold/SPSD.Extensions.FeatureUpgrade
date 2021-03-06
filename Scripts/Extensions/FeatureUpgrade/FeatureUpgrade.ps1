###############################################################################
# SharePoint Solution Deployer (SPSD) Extension for SharePoint FeatureUpgrade
# Version          : 1.0.0.0
# Creator          : Viktor Reinhold
# License          : MS-PL
# File             : FeatureUpgrade.ps1
###############################################################################

function Execute-FeatureUpgradeExtension($parameters, [System.Xml.XmlElement]$data, [string]$extId, [string]$extensionPath){
	Log -message ("Extension ID: "+ $extId) -type $SPSD.LogTypes.Normal

	$WebAppUrl = $parameters["WebAppUrl"]

	$featuresNode = $data.FirstChild
	foreach($featureNode in $featuresNode.ChildNodes){
		if ($featureNode.LocalName -ne 'Feature') { continue }
		
		$feature = Get-SPFeature $featureNode.Name
		
		if ($feature -eq $null){ 
			#throw New-Object Exception('A feature with the name '+$featureNode.Name+' cannot be found') 
			Log -message ('Execute-FeatureExtension: A feature with the name '+$featureNode.Name+' cannot be found') -type $SPSD.LogTypes.Error
			break
		}
		Log -message ('Working on feature "'+$feature.DisplayName+'"') -type $SPSD.LogTypes.Information
		
		switch ($feature.Scope) {
			"Farm" {
				$url = $WebAppUrl
				
				$featuresForUpgrade = [Microsoft.SharePoint.Administration.SPWebService]::AdministrationService.QueryFeatures($feature.Id, $true)
				break
			}
			"WebApplication" {
				$url = $WebAppUrl

				$featuresForUpgrade = [Microsoft.SharePoint.Administration.SPWebService]::QueryFeaturesInAllWebServices($feature.Id, $true)
				break
			}
			"Site" { 
				$url = ($feature.Parent -as [Microsoft.SharePoint.SPSite]).Url
				
				$featuresForUpgrade = foreach($webapp in Get-SPWebApplication $WebAppUrl) {
					$webapp.QueryFeatures($feature.Id, $true)
				}
				break
			}
			"Web" {
				$url = ($feature.Parent -as [Microsoft.SharePoint.SPWeb]).Url
				
				$featuresForUpgrade = foreach($site in Get-SPSite -Limit All -WebApplication $WebAppUrl) {
					$site.QueryFeatures($feature.Id, $true)
				}
				break
			}
		}

		$featuresForUpgrade | % {
			Execute-FeatureUpgradeAction $_
		}
	}
	
	LogOutdent
}

function Execute-FeatureUpgradeAction ([Microsoft.SharePoint.SPFeature]$feature) {
	Log -message ('Working on url: "'+$feature.Parent.Url+'"') -type $SPSD.LogTypes.Information
	
	Log -message ('Version before: "'+$feature.Version+'"') -type $SPSD.LogTypes.Information
	$feature.Upgrade($true)
	Log -message ('Version after:  "'+$feature.Version+'"') -type $SPSD.LogTypes.Information
}
