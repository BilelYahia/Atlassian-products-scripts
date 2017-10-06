# Tries to comply with the JIRA REST API as defined @ https://docs.atlassian.com/jira/REST/6.2/
# Defining the Jira URL
$jiraRestUrl = "https://<your_jira_server_address>/jira/rest/api/2"
$greenhopperRestUrl = " https://<your_jira_server_address>/jira/rest/greenhopper/1.0"

function Create-WebClientWithJsonContentType($jiraAuthToken)
{
	$webclient = New-Object System.Net.WebClient
	$webclient.Headers.Add("Content-Type", "application/json")
	$webclient.Headers.Add("Authorization", "Basic $jiraAuthToken")
	return $webclient
}

function Create-WebClientWithEncoding($jiraAuthToken, $encoding)
{
	$webclient = New-Object System.Net.WebClient
	$webclient.Headers.Add("Content-Type", "application/json")
	$webclient.Headers.Add("Authorization", "Basic $jiraAuthToken")
	$webclient.Encoding = $encoding
	return $webclient
}

# Handle caught errors in a standard way.  For now, this just gets at the response stream of an HTTP-related exception and dumps it to the console.
function HandleHttpException()
{
	[System.Net.WebException] $webException = $error[0].Exception.InnerException
	$responseStream = $webException.Response.GetResponseStream()      
	$responseStream.Seek(0, [System.IO.SeekOrigin]::Begin)
	$encoding = [System.Text.Encoding]::GetEncoding("utf-8")

	try
	{
		# Pipes the stream to a higher level stream reader with the required encoding format. 
		$reader = New-Object System.IO.StreamReader( $responseStream, $encoding )
		Write-Host "Response stream received."
		Write-Host $reader.ReadToEnd()
	}
	finally
	{
		$reader.Close()
	}
}

function Post-Data($jiraAuthToken, $uri, $postProtocol, $fieldJSON)
{
	try
	{
		$webclient = Create-WebClientWithJsonContentType $jiraAuthToken
		$response = $webclient.UploadString($uri, $postProtocol, $fieldJSON)
		Write-Host $response
		return $true
	}
	catch
	{
		Write-Error "Error sending data"
		Write-Error $_
		HandleHttpException
		return $false
	}
	finally
	{
		$webclient.Dispose()
	}
}

function Get-Data($jiraAuthToken, $uri)
{
	try
	{
		$webclient = Create-WebClientWithJsonContentType $jiraAuthToken
		return $webclient.DownloadString($uri)
	}
	catch
	{
		Write-Error "Error sending data"
		Write-Error $_
		HandleHttpException
		return $null
	}
	finally
	{
		$webclient.Dispose()
	}
}

function Post-JiraData($jiraAuthToken, $uri, $postProtocol, $fieldJSON, [ref]$response)
{
	try
	{
		$uri = "$jiraRestURL$uri"
		$webclient = Create-WebClientWithJsonContentType $jiraAuthToken
		$resultJson = $webclient.UploadString($uri, $postProtocol, $fieldJSON)
		$response.Value = $resultJson
	}
	catch [Exception]
	{
		$response.Value = $_.Exception.Message
	}
	finally
	{
		$webclient.Dispose()
	}
}

function Post-EncodedJiraData($jiraAuthToken, $uri, $postProtocol, $fieldJSON, $encoding, [ref]$response)
{
	try
	{
		$uri = "$jiraRestURL$uri"
		$webclient = Create-WebClientWithEncoding $jiraAuthToken $encoding
		$resultJson = $webclient.UploadString($uri, $postProtocol, $fieldJSON)
		$response.Value = $resultJson
	}
	catch [Exception]
	{
		$response.Value = $_.Exception.Message
	}
	finally
	{
		$webclient.Dispose()
	}
}

function Get-JiraData($jiraAuthToken, $uri, [ref]$response)
{
	try
	{
		$uri = "$jiraRestURL$uri"
		$webclient = Create-WebClientWithJsonContentType $jiraAuthToken
		$resultJson = $webclient.DownloadString($uri)
		$response.Value = $resultJson
	}
	catch [Exception]
	{
		$response.Value = $_.Exception.Message
	}
	finally
	{
		$webclient.Dispose()
	}
}

function Post-GreenhopperData($jiraAuthToken, $uri, $postProtocol, $fieldJSON, [ref]$response)
{
	try
	{
		$uri = "$greenhopperRestUrl$uri"
		$webclient = Create-WebClientWithJsonContentType $jiraAuthToken
		$resultJson = $webclient.UploadString($uri, $postProtocol, $fieldJSON)
		$response.Value = $resultJson
	}
	catch [Exception]
	{
		$response.Value = $_.Exception.Message
	}
	finally
	{
		$webclient.Dispose()
	}
}

# Utility function to update one or more fields on a JIRATrain ticket.
function UpdateTicketFields($ticketId, $fieldJSON, $jiraAuthToken)
{
	Post-Data $jiraAuthToken "$jiraRestUrl/issue/$ticketId" "PUT" $fieldJSON
}

# Update the "Code Reviewer" field on a JIRA ticket.
function UpdateCodeReviewer($ticketId, $newValue, $jiraAuthToken)
{
	$fieldJSON = "{ `"fields`" : { `"customfield_10114`" : { `"name`" : `"$newValue`" } } }"
	UpdateTicketFields $ticketId $fieldJSON $jiraAuthToken
}

# Update the outcome of the code review ("Code Review" field)...
function UpdateCodeReview($ticketId, $newValue, $jiraAuthToken)
{
	$fieldJSON = "{ `"fields`" : { `"customfield_10116`" : { `"value`" : `"$newValue`" } } }"
	UpdateTicketFields $ticketId $fieldJSON $jiraAuthToken
}

# Add a comment to a JIRA ticket.
function AddCommentToTicket($ticketId, $comment, $jiraAuthToken)
{
	$fieldJSON = "{ `"body`" : `"$comment`" }"
	Post-Data $jiraAuthToken "$jiraRestUrl/issue/$ticketId/comment" "POST" $fieldJSON
}

# Base64 encode the input string.  Needed because authentication to the REST service requires a Base64'd "user:pass" string in an Authorization header on the request.
function Base64Encode($toEncode)
{
	return [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($toEncode));
}

# Update the "Release" field on a JIRATrain ticket.
function UpdateRelease($ticketId, $newValue, $jiraAuthToken)
{
	$fieldJSON = "{ `"fields`" : { `"customfield_10040`" : { `"value`" : `"$newValue`" } } }"
	UpdateTicketFields $ticketId $fieldJSON $jiraAuthToken
}

# Update the "Feature ID" field on a JIRATrain ticket.
function UpdateFeatureID($ticketId, $newValue, $jiraAuthToken)
{
	$fieldJSON = "{ `"fields`" : { `"customfield_10480`" : $newValue } }"
	UpdateTicketFields $ticketId $fieldJSON $jiraAuthToken
}

# Update the "Beneficiary" field on a JIRATrain ticket.
function UpdateBeneficiary($ticketId, $newValue, $jiraAuthToken)
{
	$fieldJSON = "{ `"fields`" : { `"customfield_10592`" : { `"value`" : `"$newValue`" } } }"
	UpdateTicketFields $ticketId $fieldJSON $jiraAuthToken
}

# Update the "Feature ID plus Beneficiary" field on a JIRATrain ticket.
function UpdateFeatureIDplusBeneficiary($ticketId, $newFeatureIDValue, $newBeneficiaryValue, $jiraAuthToken)
{
	$fieldJSON = "{ `"fields`" : { `"customfield_10480`": $newFeatureIDValue, `"customfield_10592`" : { `"value`" : `"$newBeneficiaryValue`" } } }"
	UpdateTicketFields $ticketId $fieldJSON $jiraAuthToken
}

# Update the "SubProject" field on a JIRATrain ticket.
function UpdateSubProject($ticketId, $newValue, $jiraAuthToken)
{
	$fieldJSON = "{ `"fields`" : { `"customfield_10433`" : { `"value`" : `"$newValue`" } } }"
	UpdateTicketFields $ticketId $fieldJSON $jiraAuthToken
}

# Progress or transition a JIRA ticket from one status to another.
function TransitionStatus($ticketId, $transitionId, $jiraAuthToken)
{
	$fieldJSON = "{ `"transition`" : { `"id`" : `"$transitionId`" } }"
	Post-Data $jiraAuthToken "$jiraRestUrl/issue/$ticketId/transitions" "POST" $fieldJSON
}

function Convert-JsonToXml([string]$json)
{
	Add-Type -Assembly System.ServiceModel.Web,System.Runtime.Serialization
	$bytes = [byte[]][char[]]$json
	$quotas = [System.Xml.XmlDictionaryReaderQuotas]::Max
	$jsonReader = [System.Runtime.Serialization.Json.JsonReaderWriterFactory]::CreateJsonReader($bytes,$quotas)	
	try
	{
		$xml = new-object System.Xml.XmlDocument
		$xml.Load($jsonReader)
		$xml
	}	
	finally
	{
		$jsonReader.Close()
	}
}

function Get-JiraTicket($jiraAuthToken, $ticketId)
{
	$webclient = Create-WebClientWithJsonContentType $jiraAuthToken
	$response = $webclient.DownloadString("$jiraRestUrl/issue/$ticketId")
	[xml] $xml = Convert-JsonToXml $response
	return $xml
}

function Get-JiraTicketsByKey($jiraAuthToken, $jql)
{
	$webclient = Create-WebClientWithJsonContentType $jiraAuthToken
	$response = $webclient.DownloadString("$($script:jiraRestUrl)/search?jql=$($jql)&fields=key")

	[xml] $xml = Convert-JsonToXml $response

	[array] $issuesKeys = $xml.SelectNodes("//key") | Select '#text'
	if (-not $issuesKeys)
	{
	    $issuesKeys = @()
	}
	return [array] $issuesKeys
}

function Get-JiraTicketsWithFields($jiraAuthToken, $jql, $fields)
{
	$webclient = Create-WebClientWithJsonContentType $jiraAuthToken
	$response = $webclient.DownloadString("$($script:jiraRestUrl)/search?jql=$($jql)&fields=$($fields)")

	[xml] $xml = Convert-JsonToXml $response

	$issuesKeys = $xml.SelectNodes("//item") 
	return $issuesKeys
}

function Get-Transitions($jiraAuthToken, $key)
{
	$webclient = Create-WebClientWithJsonContentType $jiraAuthToken
	$response = $webclient.DownloadString("$($script:jiraRestUrl)/issue/$key/transitions")

	[xml] $xml = Convert-JsonToXml $response

	return $xml
}

function Add-Labels($ticketId, $newValue, $jiraAuthToken)
{
	$fieldJSON = "{`"update`":{`"labels`":[{`"add`":`"$($newValue)`"}]}}"
	UpdateTicketFields $ticketId $fieldJSON $jiraAuthToken
}


function Remove-Label($ticketId, $labelName, $jiraAuthToken)
{
	$fieldJSON = "{`"update`":{`"labels`":[{`"remove`":`"$($labelName)`"}]}}"
	UpdateTicketFields $ticketId $fieldJSON $jiraAuthToken
}

function Create-Ticket($jiraAuthToken, $fieldJSON)
{
	Post-Data $jiraAuthToken "$jiraRestUrl/issue" "POST" $fieldJSON
}

export-modulemember -function AddCommentToTicket
export-modulemember -function Base64Encode
export-modulemember -function UpdateCodeReviewer
export-modulemember -function UpdateCodeReview
export-modulemember -function UpdateRelease
export-modulemember -function UpdateFeatureID
export-modulemember -function UpdateBeneficiary
export-modulemember -function UpdateFeatureIDplusBeneficiary
export-modulemember -function UpdateSubProject
export-modulemember -function TransitionStatus
export-modulemember -function Add-Labels
export-modulemember -function Remove-Label
export-modulemember -function Convert-JsonToXml
export-modulemember -function Get-JiraTicket
export-modulemember -function Get-JiraTicketsByKey
export-modulemember -function Get-JiraTicketsWithFields
export-modulemember -function Create-WebClientWithJsonContentType
export-modulemember -function Create-WebClientWithEncoding
export-modulemember -function Get-Data
export-modulemember -function Post-Data
export-modulemember -function Get-JiraData
export-modulemember -function Post-JiraData
export-modulemember -function Post-EncodedJiraData
export-modulemember -function Post-GreenhopperData
export-modulemember -function Get-Transitions
export-modulemember -function Create-Ticket