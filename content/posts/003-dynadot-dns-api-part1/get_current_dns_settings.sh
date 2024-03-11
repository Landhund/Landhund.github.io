#!/bin/bash

api_key="your_API_key"
domain="your_registered_domain"
challenge_node="domain_for_txt_record"
new_challenge_key="new_txt_record_from_certbot"
set_command="set_dns2"
get_command="get_dns"
api_url="https://api.dynadot.com/api3.xml"

# Shorthand for the node-adress of the main domain records
maindomain_nodes="/GetDnsResponse/GetDnsContent/NameServerSettings/MainDomains"

# Shorthand for the node-adress of the sub-domain records
subdomain_nodes="/GetDnsResponse/GetDnsContent/NameServerSettings/SubDomains"

# Get current DNS-configuration from dynadot API and store it in a local and temporary xml-file.
# Commented out to prevent accidental API-calls/spam
#curl "https://api.dynadot.com/api3.xml?key=$api_key&command=get_dns&domain=$domain" > ./api_get_response.xml

# Extract API-response code
response_code="$(echo "cat /GetDnsResponse/GetDnsHeader/ResponseCode/text()" | xmllint --nocdata --shell api_get_response.xml | sed '1d;$d')"

# Check if API-call was successful (responsecode 0), break if not
if [ "$response_code" -ne 0 ]; then
    echo "Error: Response Code not 0, was $response_code instead!" >logfile.log
    exit 1
fi

# Count main domain records, needed to limit XML-loop
main_entries_count="$(xmllint --xpath "count($maindomain_nodes/*)" api_get_response.xml)"

# Initialize empty string for storing the previous main domain records in API-call format
main_records=""

# Iterate through main domain records
index=0
while [ $index -lt "$main_entries_count" ]; do

    # IMPORTANT: The XML-nodes index starts at 1!
    xml_index=$index+1

    # Read and store the type of the current main record
    type="$(echo "cat $maindomain_nodes/MainDomainRecord[$xml_index]/RecordType/text()" | xmllint --nocdata --shell api_get_response.xml | sed '1d;$d')"

    # Read and store the value of the current main record
    value="$(echo "cat $maindomain_nodes/MainDomainRecord[$xml_index]/Value/text()" | xmllint --nocdata --shell api_get_response.xml | sed '1d;$d')"

    # Reformat the received data into the needed API-format and append it to the main_records variable
    main_records+="&main_record_type$index=$type&main_record$index=$value"

    ((index++))
done

#echo $main_records

# Count subdomain records, needed to limit XML-loop
sub_entries_count="$(xmllint --xpath "count($subdomain_nodes/*)" api_get_response.xml)"

# Initialize empty string for storing the subdomain records in API-call format
sub_records=""

# Control flag to check if any records where actually changed
unchanged=1

# Iterate through subdomain records
index=1
while [ $index -le "$sub_entries_count" ]; do

    # IMPORTANT: The XML-nodes index starts at 1!
    xml_index=$index+1

    subhost="$(echo "cat $subdomain_nodes/SubDomainRecord[$xml_index]/Subhost/text()" | xmllint --nocdata --shell api_get_response.xml | sed '1d;$d')"
    type="$(echo "cat $subdomain_nodes/SubDomainRecord[$xml_index]/RecordType/text()" | xmllint --nocdata --shell api_get_response.xml | sed '1d;$d')"
    value="$(echo "cat $subdomain_nodes/SubDomainRecord[$xml_index]/Value/text()" | xmllint --nocdata --shell api_get_response.xml | sed '1d;$d')"

    # Check if the subdomain of the current record is the one that needs to be changed
    if [ "$subhost" = $challenge_node ]; then
        # Overwrite the value that is stored in the TXT-record to the needed challenge key
        value=$new_challenge_key

        # Unset flag to indicate that a record was indeed changed
        unchanged=0
    fi

    # Reformat the received data into the needed API-format and append it to the sub_records variable
    sub_records+="&subdomain$index=$subhost&sub_record_type$index=$type&sub_record$index=$value"

    ((index++))
done

# Throw error and abort if no records where changed
if [ $unchanged -eq 1 ]; then
    echo "Error: Challenge Node $challenge_node not found, no changes to DNS-record performed!" >logfile.log
    exit 2
fi

# Combine everything into one api command/request
api_request="key=$api_key&commad=$set_command&domain=$domain$main_records$sub_records"

# Combine api-url and -request into the finished command
full_request="$api_url?$api_request"

# Commented out to prevent accidental API-calls
# BE CAREFUL WHEN UNCOMMENTING IT!!!
# curl "$full_request" > ./api_set_response.xml

echo "$full_request"
