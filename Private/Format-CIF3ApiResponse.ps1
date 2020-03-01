function Format-CIF3ApiResponse {
    [OutputType('CIF3.ApiResponse')]
    [CmdletBinding()]
    param (
        # The response object from CIF3 instance API.
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [object]$InputObject
    )

    begin { 
        
        if ($InputObject.message -eq 'success' -or $null -ne $InputObject.data) {
            Write-Verbose 'Received response from CIF API'
            # Check for Elasticsearch results, since they're different from sqlite returns for some reason. whut?
            # https://github.com/csirtgadgets/cifsdk-py-v3/blob/a659e84c63ff097942ed8e549340107c66886db6/cifsdk/client/http.py#L121
            if ($InputObject.data -is [string] -and $InputObject.data.StartsWith('{"hits":{"hits":[{"_source":') ) {
                $ElasticSearchResult = ConvertFrom-Json -InputObject $InputObject.data
                if ($null -eq $ElasticSearchResult.hits.hits._source) {
                    Write-Error -Message "CIF API call succeeded, but responded with incorrect Elasticsearch value: $InputObject"
                    break
                } else {
                    # set InputObject to hits.hits._sourcedata' property of Invoke-RestMethod return object for further processing
                    $InputObject = $ElasticSearchResult.hits.hits._source
                }
            } 
            else {
                # set InputObject to 'data' property of Invoke-RestMethod return object for further processing
                $InputObject = $InputObject.data
            }

        } 
        else {
            Write-Error -Message "CIF API call succeeded, but response formatter got strange input: $InputObject"
            break
        }
        # if we made it this far, go ahead and setup stuff we'll need for processing
        $TextInfo = (Get-Culture).TextInfo
    }

    process {
        foreach ($Response in $InputObject) {

            # some functions return just an integer/str indicating how many server objects were affected
            # if that's the case, just return that
            if ($Response -is [string] -or $Response -is [int]) {
                try { 
                    # try to cast to integer if we can. otherwise, just return the object
                    Write-Output ([int]$Response)
                } 
                catch { Write-Output $Response }
                break
            }
            # some functions return a True/False, so just return that if it's the case
            elseif ($Response -is [bool]) {
                Write-Output $Response
                break
            }

            # build FormattedResponse output hashtable and begin populating it with keys/values
            $FormattedResponse = @{ PSTypeName = 'CIF3.ApiResponse' }

            switch($Response | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name) {
                'reporttime'        { $FormattedResponse.Add('ReportTime', (ConvertFrom-PythonDate -Date $Response.reporttime)) }
                'firsttime'         { $FormattedResponse.Add('FirstTime', (ConvertFrom-PythonDate -Date $Response.firsttime)) }
                'lasttime'          { $FormattedResponse.Add('LastTime', (ConvertFrom-PythonDate -Date $Response.lasttime)) }
                'expires'           { $FormattedResponse.Add('Expires', (ConvertFrom-PythonDate -Date $Response.expires)) }
                'last_activity_at'  { $FormattedResponse.Add('LastActivityTime', (ConvertFrom-UnixDate -Date $Response.last_activity_at)) }
                'tags'              { $FormattedResponse.Add('Tag', $Response.tags -split ',') }
                'tlp'               { $FormattedResponse.Add('TLP', $Response.tlp) }
                'itype'             { $FormattedResponse.Add('IType', $Response.itype) }
                'groups'            { $FormattedResponse.Add('Group', $Response.groups) }
                'protocol'          { 
                    if ($null -ne $Response.protocol) {
                        $FormattedResponse.Add('Protocol', $Response.protocol.ToUpper()) 
                    }
                }
                'portlist'          { 
                    if ($Response.portlist -eq 'None') { 
                        $Response.portlist = $null 
                    }
                    $FormattedResponse.Add('Port', $Response.portlist) 
                }
                default             { $FormattedResponse.Add($TextInfo.ToTitleCase($_), $Response.$_ ) }
            }
            # convert hashtable to PSCustomObject and send to output
            New-Object -TypeName pscustomobject -Property $FormattedResponse
        }
    }

    end { }
}