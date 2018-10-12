#! /bin/bash

# ----------------------------------------------------------------------------
#  Copyright 2018 WSO2, Inc. http://www.wso2.org
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

create_user() {
    username=$1
    password=$2
    user=$3
    request_data=$4

    if [ ! -f "${request_data}" ]
        then
            echo "${request_data} File does not exists."
            return 255
    fi

    echo
    echo "Creating a user named ${user}..."

    curl -s -k --user "${username}":"${password}" --data-binary @${request_data} \
    --header "Content-Type:application/json" -o /dev/null https://localhost:9443/wso2/scim/Users
    res=$?
        if test "${res}" != "0";
            then
                echo "!! Problem occurred while creating user ${user}. !!"
                echo "${res}"
                return 255
        fi
    echo "** The user ${user} was successfully created. **"
    echo

    return 0;
}

create_user_with_role() {
    username=$1
    password=$2
    user=$3
    role=$4
    user_request_data=$5
    role_request_data=$6

    if [ ! -f "${role_request_data}" ]
        then
            echo "${role_request_data} File does not exists."
            return 255
    fi

    echo
    echo "Creating a role named ${role}..."

    content=$(curl -s -k --user "${username}":"${password}" --data-binary @${role_request_data} \
    --header "Content-Type:application/json" https://localhost:9443/scim2/Groups)

    groupid=$(eval_json "${content}" "id")
    echo "Created role with id: ${groupid}"

    if [ ! -f "${user_request_data}" ]
        then
            echo "${user_request_data} File does not exists."
            return 255
    fi

    echo
    echo "Creating a user named ${user}..."

    content=$(curl -s -k --user "${username}":"${password}" --data-binary @${user_request_data} \
    --header "Content-Type:application/json" https://localhost:9443/scim2/Users)

    userid=$(eval_json "${content}" "id")
    echo "Created user with id: ${userid}"

    echo "Assigning user ${user} to the role ${role}..."

    if [ ! -d "tmp" ]
        then
            mkdir tmp
    fi

    cp "${COMMON_HOME}/configs/user_role.json" tmp/user_role_"${user}".json

    sed -i '.bak' 's#${ROLE_NAME}#'${role}'#g' tmp/user_role_"${user}".json
    sed -i '.bak' 's#${USER_ID}#'${userid}'#g' tmp/user_role_"${user}".json
    sed -i '.bak' 's#${USERNAME}#'${user}'#g' tmp/user_role_"${user}".json

    curl -X PUT -s -k --user "${username}":"${password}" --data-binary @tmp/user_role_"${user}".json \
    --header "Content-Type:application/json" -o /dev/null https://localhost:9443/scim2/Groups/"${groupid}"
    res=$?
        if test "${res}" != "0";
            then
                echo "!! Problem occurred while assigning user to role. !!"
                echo "${res}"
                return 255
        fi

    echo "** Successfully created user ${user} with role ${role} **"
    return 0;
}

create_tenant() {
    username=$1
    password=$2
    tenant_domain=$3
    tenant_request_data=$4

    if [ ! -f "${tenant_request_data}" ]
        then
            echo "${tenant_request_data} File does not exists."
            return 255
    fi

    curl -s -k --user "${username}":"${password}" -d @${tenant_request_data} -H "Content-Type: text/xml" \
    -H "SOAPAction: urn:addTenant" -o /dev/null \
    https://localhost:9443/services/TenantMgtAdminService.TenantMgtAdminServiceHttpsSoap11Endpoint/

    res=$?
        if test "${res}" != "0";
            then
                echo "!! Problem occurred while adding the tenant: ${tenant_domain} !!"
                echo "${res}"
                return 255
        fi
    echo "** Tenant ${tenant_domain} successfully added. **"
    echo

    return 0;
}

create_service_provider() {
    sp_name=$1
    username=$2
    password=$3
    config_file=$4

    auth=$(echo "${username}:${password}"|base64)

    if [ ! -d "tmp" ]
        then
            mkdir tmp
    fi

    if [ ! -f "${config_file}" ]
        then
            echo "${config_file} File does not exists."
            return 255
    fi

    if [ -f tmp/create-sp-"${sp_name}".xml ]
        then
            rm tmp/create-sp-"${sp_name}".xml
    fi

    cp ${config_file} tmp/create-sp-"${sp_name}".xml

    sed -i '.bak' 's/${SP_NAME}/'${sp_name}'/g' tmp/create-sp-"${sp_name}".xml

    echo "Creating Service Provider ${sp_name}..."

    curl -s -k -d @tmp/create-sp-"${sp_name}".xml -H "Authorization: Basic ${auth}" -H "Content-Type: text/xml" \
    -H "SOAPAction: urn:createApplication" -o /dev/null \
    https://localhost:9443/services/IdentityApplicationManagementService.IdentityApplicationManagementServiceHttpsSoap11Endpoint/
    res=$?

    if test "${res}" != "0";
        then
            echo "!! Problem occurred while creating the service provider: ${sp_name}. !!"
            echo "${res}"
            return 255
    fi
    echo "** Service Provider ${sp_name} successfully created. **"

    return 0;
}

create_oidc_service_provider() {
    username=$1
    password=$2
    spName=$3
    request_data=$4

    if [ ! -f "${request_data}" ]
        then
            echo "${request_data} File does not exists."
            return 255
    fi

    echo
    echo "Creating a SP named ${spName}..."

    curl -s -k --user "${username}":"${password}" --data-binary @${request_data} \
    --header "Content-Type:application/json" -o /dev/null https://localhost:9443/api/identity/oauth2/dcr/v1.1/register
    res=$?
        if test "${res}" != "0";
            then
                echo "!! Problem occurred while creating user ${user}. !!"
                echo "${res}"
                return 255
        fi
    echo "** The Service Provider ${spName} was successfully created. **"
    echo

    return 0;
}

configure_service_provider() {
    sp_name=$1
    username=$2
    password=$3
    config_file1=$4
    config_file2=$5

    auth=$(echo "${username}:${password}"|base64)

    if [ ! -d "tmp" ]
        then
            mkdir tmp
    fi

    if [ -f tmp/response_unformatted.xml ]
        then
            rm tmp/response_unformatted.xml
    fi

    if [ ! -f "${config_file1}" ]
        then
            echo "${config_file1} File does not exists."
            return 255
    fi

    if [ -f tmp/get-sp-"${sp_name}".xml ]
        then
            rm tmp/get-sp-"${sp_name}".xml
    fi

    cp ${config_file1} tmp/get-sp-"${sp_name}".xml

    sed -i '.bak' 's/${SP_NAME}/'${sp_name}'/g' tmp/get-sp-"${sp_name}".xml

    touch tmp/response_unformatted.xml
    curl -s -k -d @tmp/get-sp-"${sp_name}".xml -H "Authorization: Basic ${auth}" -H "Content-Type: text/xml" \
    -H "SOAPAction: urn:getApplication" \
    https://localhost:9443/services/IdentityApplicationManagementService.IdentityApplicationManagementServiceHttpsSoap11Endpoint/ > tmp/response_unformatted.xml
    res=$?
    if test "${res}" != "0";
        then
            echo "!! Problem occurred while getting application details for ${sp_name}.... !!"
            echo "${res}"
            return 255
    fi

    xmllint --format tmp/response_unformatted.xml
    app_id=$(xmllint --xpath "//*[local-name()='applicationID']/text()" tmp/response_unformatted.xml)
    rm tmp/response_unformatted.xml

    if [ ! -f "${config_file2}" ]
        then
            echo "${config_file2} File does not exists."
            return 255
    fi

    cp ${config_file2} tmp/update-sp-"${sp_name}".xml

    sed -i '.bak' 's/${SP_NAME}/'${sp_name}'/g' tmp/update-sp-"${sp_name}".xml
    sed -i '.bak' 's/${APP_ID}/'${app_id}'/g' tmp/update-sp-"${sp_name}".xml


    curl -s -k -d @tmp/update-sp-"${sp_name}".xml -H "Authorization: Basic ${auth}" -H "Content-Type: text/xml" \
    -H "SOAPAction: urn:updateApplication" -o /dev/null \
    https://localhost:9443/services/IdentityApplicationManagementService.IdentityApplicationManagementServiceHttpsSoap11Endpoint/
    res=$?
    if test "${res}" != "0";
        then
            echo "!! Problem occurred while updating application ${sp_name}.... !!"
            echo "${res}"
            return 255
    fi
    echo "** Successfully updated the application ${sp_name}. **"

    return 0;
}

configure_service_provider_for_samlsso() {
    sp_name=$1
    issuer=$2
    acs=$3
    username=$4
    password=$5
    config_file=$6

    auth=$(echo "${username}:${password}"|base64)

    if [ ! -d "tmp" ]
        then
            mkdir tmp
    fi

    if [ ! -f "${config_file}" ]
        then
            echo "${config_file} File does not exists."
            return 255
    fi

    if [ -f tmp/sso-config-"${sp_name}".xml ]
        then
            rm tmp/sso-config-"${sp_name}".xml
    fi

    cp ${config_file} tmp/sso-config-"${sp_name}".xml

    sed -i '.bak' 's#${ISSUER}#'${issuer}'#g' tmp/sso-config-"${sp_name}".xml
    sed -i '.bak' 's#${ACS}#'${acs}'#g' tmp/sso-config-"${sp_name}".xml

    echo "Configuring SAML2 web SSO for ${sp_name}..."

    curl -s -k -d @tmp/sso-config-"${sp_name}".xml -H "Authorization: Basic ${auth}" -H "Content-Type: text/xml" \
    -H "SOAPAction: urn:addRPServiceProvider" \
    https://localhost:9443/services/IdentitySAMLSSOConfigService.IdentitySAMLSSOConfigServiceHttpsSoap11Endpoint/
    res=$?
    if test "${res}" != "0";
        then
            echo "!! Problem occurred while configuring SAML2 web SSO for ${sp_name}.... !!"
            echo "${res}"
            return 255
    fi
    echo "** Successfully configured SAML for ${sp_name}. **"
    return 0;
}

update_service_provider_with_samlsso() {
    sp_name=$1
    username=$2
    password=$3
    config_file=$4
    saasApp=$5

    auth=$(echo "${username}:${password}"|base64)

    if [ ! -d "tmp" ]
        then
            mkdir tmp
    fi

    if [ -f tmp/response_unformatted.xml ]
        then
            rm tmp/response_unformatted.xml
    fi

    if [ ! -f "${config_file}" ]
        then
            echo "${config_file} File does not exists."
            return 255
    fi

    if [ -f tmp/get-sp-"${sp_name}".xml ]
        then
            rm tmp/get-sp-"${sp_name}".xml
    fi

    cp ${config_file} tmp/get-sp-"${sp_name}".xml

    sed -i '.bak' 's/${SP_NAME}/'${sp_name}'/g' tmp/get-sp-"${sp_name}".xml

    touch tmp/response_unformatted.xml
    curl -s -k -d @tmp/get-sp-"${sp_name}".xml -H "Authorization: Basic ${auth}" -H "Content-Type: text/xml" \
    -H "SOAPAction: urn:getApplication" \
    https://localhost:9443/services/IdentityApplicationManagementService.IdentityApplicationManagementServiceHttpsSoap11Endpoint/ > tmp/response_unformatted.xml
    res=$?
    if test "${res}" != "0";
        then
            echo "!! Problem occurred while getting application details for ${sp_name}.... !!"
            echo "${res}"
            return 255
    fi

    xmllint --format tmp/response_unformatted.xml
    app_id=$(xmllint --xpath "//*[local-name()='applicationID']/text()" tmp/response_unformatted.xml)
    rm tmp/response_unformatted.xml

    if [ -f "tmp/update-sp-${sp_name}.xml" ]
        then
            rm tmp/update-sp-"${sp_name}".xml
    fi

    touch tmp/update-sp-"${sp_name}".xml
    echo "<soapenv:Envelope xmlns:soapenv="\"http://schemas.xmlsoap.org/soap/envelope/"\" xmlns:xsd="\"http://org.apache.axis2/xsd"\" xmlns:xsd1="\"http://model.common.application.identity.carbon.wso2.org/xsd"\">
        <soapenv:Header/>
        <soapenv:Body>
            <xsd:updateApplication>
                <!--Optional:-->
                <xsd:serviceProvider>
                    <!--Optional:-->
                    <xsd1:applicationID>${app_id}</xsd1:applicationID>
                    <!--Optional:-->
                    <xsd1:applicationName>${sp_name}</xsd1:applicationName>
                    <!--Optional:-->
                    <xsd1:claimConfig>
                        <!--Optional:-->
                        <xsd1:alwaysSendMappedLocalSubjectId>false</xsd1:alwaysSendMappedLocalSubjectId>
                        <!--Optional:-->
                        <xsd1:localClaimDialect>true</xsd1:localClaimDialect>
                    </xsd1:claimConfig>
                    <!--Optional:-->
                    <xsd1:description>sample service provider</xsd1:description>
                    <!--Optional:-->
                    <xsd1:inboundAuthenticationConfig>
                        <!--Zero or more repetitions:-->
                        <xsd1:inboundAuthenticationRequestConfigs>
                            <!--Optional:-->
                            <xsd1:inboundAuthKey>saml2-web-app-dispatch.com</xsd1:inboundAuthKey>
                            <!--Optional:-->
                            <xsd1:inboundAuthType>samlsso</xsd1:inboundAuthType>
                            <!--Zero or more repetitions:-->
                            <xsd1:properties>
                                <!--Optional:-->
                                <xsd1:name>attrConsumServiceIndex</xsd1:name>
                                <!--Optional:-->
                                <xsd1:value>1223160755</xsd1:value>
                            </xsd1:properties>
                        </xsd1:inboundAuthenticationRequestConfigs>
                    </xsd1:inboundAuthenticationConfig>
                    <!--Optional:-->
                    <xsd1:inboundProvisioningConfig>
                        <!--Optional:-->
                        <xsd1:provisioningEnabled>false</xsd1:provisioningEnabled>
                        <!--Optional:-->
                        <xsd1:provisioningUserStore>PRIMARY</xsd1:provisioningUserStore>
                    </xsd1:inboundProvisioningConfig>
                    <!--Optional:-->
                    <xsd1:localAndOutBoundAuthenticationConfig>
                        <!--Optional:-->
                        <xsd1:alwaysSendBackAuthenticatedListOfIdPs>false</xsd1:alwaysSendBackAuthenticatedListOfIdPs>
                        <!--Optional:-->
                        <xsd1:authenticationStepForAttributes></xsd1:authenticationStepForAttributes>
                        <!--Optional:-->
                        <xsd1:authenticationStepForSubject></xsd1:authenticationStepForSubject>
                        <xsd1:authenticationType>default</xsd1:authenticationType>
                        <!--Optional:-->
                        <xsd1:subjectClaimUri>http://wso2.org/claims/fullname</xsd1:subjectClaimUri>
                    </xsd1:localAndOutBoundAuthenticationConfig>
                    <!--Optional:-->
                    <xsd1:outboundProvisioningConfig>
                        <!--Zero or more repetitions:-->
                        <xsd1:provisionByRoleList></xsd1:provisionByRoleList>
                    </xsd1:outboundProvisioningConfig>
                    <!--Optional:-->
                    <xsd1:permissionAndRoleConfig></xsd1:permissionAndRoleConfig>
                    <!--Optional:-->
                    <xsd1:saasApp>${saasApp}</xsd1:saasApp>
                </xsd:serviceProvider>
            </xsd:updateApplication>
        </soapenv:Body>
    </soapenv:Envelope>" >> tmp/update-sp-"${sp_name}".xml

    echo
    echo "Updating application ${sp_name}..."

    curl -s -k -d @tmp/update-sp-"${sp_name}".xml -H "Authorization: Basic ${auth}" -H "Content-Type: text/xml" \
    -H "SOAPAction: urn:updateApplication" -o /dev/null \
    https://localhost:9443/services/IdentityApplicationManagementService.IdentityApplicationManagementServiceHttpsSoap11Endpoint/
    res=$?
    if test "${res}" != "0";
        then
            echo "!! Problem occurred while updating application ${sp_name}.... !!"
            echo "${res}"
            return 255
    fi
    echo
    echo "** Successfully updated the application ${sp_name}. **"

    return 0;
}

create_twitter_idp() {
    idp_name=$1
    display_name=$2
    config_file=$3
    username=$4
    password=$5

    if [ ! -d "tmp" ]
        then
            mkdir tmp
    fi

    if [ -f tmp/create-idp.xml ]
        then
            rm tmp/create-idp.xml
    fi

    echo
    echo "Please enter your API key"
    echo "(This can be found in the Keys and Access token section in the Application settings)"
    echo
    read -r key
    echo
    echo "Please enter your API secret"
    echo "(This can be found in the Keys and Access token section in the Application settings)"
    echo
    read -r secret
    echo

    cp ${config_file} tmp/create-idp.xml

    sed -i '.bak' 's/${DISPLAY_NAME}/'${display_name}'/g' tmp/create-idp.xml
    sed -i '.bak' 's/${API_KEY}/'${key}'/g' tmp/create-idp.xml
    sed -i '.bak' 's/${API_SECRET}/'${secret}'/g' tmp/create-idp.xml
    sed -i '.bak' 's/${IDP_NAME}/'${idp_name}'/g' tmp/create-idp.xml

    curl -s -k --user ${username}:${password} -d @tmp/create-idp.xml -H "Content-Type: text/xml" \
    -H "SOAPAction: urn:addIdP" -o /dev/null \
    https://localhost:9443/services/IdentityProviderMgtService.IdentityProviderMgtServiceHttpsSoap11Endpoint/
    res=$?
    if test "${res}" != "0";
        then
            echo "!! Problem occurred while creating the identity provider: ${idp_name}. !!"
            echo "${res}"
            return 255
    fi
    echo "** The identity provider ${idp_name} was successfully created. **"
    return 0;
}

create_google_idp() {
    idp_name=$1
    display_name=$2
    config_file=$3
    username=$4
    password=$5

    if [ ! -d "tmp" ]
        then
            mkdir tmp
    fi

    if [ -f tmp/create-idp.xml ]
        then
            rm tmp/create-idp.xml
    fi

    echo
    echo "Please enter your Client ID"
    echo "(This can be found in the Credentials section in the Google API Console)"
    echo
    read -r key
    echo
    echo "Please enter your Client Secret"
    echo "(This can be found in the Credentials section in the Google API Console)"
    echo
    read -r secret
    echo

    cp ${config_file} tmp/create-idp.xml

    sed -i '.bak' 's/${DISPLAY_NAME}/'${display_name}'/g' tmp/create-idp.xml
    sed -i '.bak' 's/${CLIENT_ID}/'${key}'/g' tmp/create-idp.xml
    sed -i '.bak' 's/${CLIENT_SECRET}/'${secret}'/g' tmp/create-idp.xml
    sed -i '.bak' 's/${IDP_NAME}/'${idp_name}'/g' tmp/create-idp.xml

    curl -s -k --user ${username}:${password} -d @tmp/create-idp.xml -H "Content-Type: text/xml" \
    -H "SOAPAction: urn:addIdP" -o /dev/null \
    https://localhost:9443/services/IdentityProviderMgtService.IdentityProviderMgtServiceHttpsSoap11Endpoint/
    res=$?
    if test "${res}" != "0";
        then
            echo "!! Problem occurred while creating the identity provider: ${idp_name}. !!"
            echo "${res}"
            return 255
    fi
    echo "** The identity provider ${idp_name} was successfully created. **"

    return 0;
}

create_smsotp_idp() {
    idp_name=$1
    display_name=$2
    config_file=$3
    username=$4
    password=$5

    if [ ! -d "tmp" ]
        then
            mkdir tmp
    fi

    if [ -f tmp/create-idp.xml ]
        then
            rm tmp/create-idp.xml
    fi

    echo
    echo "Please enter SMS Url"
    echo
    read -r sms_url
    echo
    echo "Please enter HTTP Method"
    echo
    read -r http_method
    echo
    echo "Please enter HTTP Payload"
    echo
    read -r http_payload
    echo
    echo "Please enter HTTP Headers"
    echo
    read -r http_headers
    echo
    echo "Please enter HTTP Respose Code"
    echo
    read -r http_response_code
 
    cp ${config_file} tmp/create-idp.xml

    escaped_payload=$(echo ${http_payload} | sed 's/\&/\&amp;/g')

    sed -i '.bak' 's/${DISPLAY_NAME}/'${display_name}'/g' tmp/create-idp.xml
    sed -i '.bak' 's/${IDP_NAME}/'${idp_name}'/g' tmp/create-idp.xml
    sed -i '.bak' 's/${HTTP_METHOD}/'${http_method}'/g' tmp/create-idp.xml
    sed -i '.bak' 's/${HEADERS}/'"${http_headers}"'/g' tmp/create-idp.xml
    sed -i '.bak' 's/${PAYLOAD}/'"${escaped_payload//&/\\&}"'/g' tmp/create-idp.xml


    sed -i '.bak' 's/${RESPONSE_CODE}/'${http_response_code}'/g' tmp/create-idp.xml
    sed -i '.bak' 's,${SMS_URL},'${sms_url}',g' tmp/create-idp.xml

    curl -s -k --user ${username}:${password} -d @tmp/create-idp.xml -H "Content-Type: text/xml" \
    -H "SOAPAction: urn:addIdP" -o /dev/null \
    https://localhost:9443/services/IdentityProviderMgtService.IdentityProviderMgtServiceHttpsSoap11Endpoint/
    res=$?
    if test "${res}" != "0";
        then
            echo "!! Problem occurred while creating the identity provider: ${idp_name}. !!"
            echo "${res}"
            return 255
    fi
    echo "** The identity provider ${idp_name} was successfully created. **"

    return 0;
}

create_fb_idp() {
    idp_name=$1
    display_name=$2
    config_file=$3
    username=$4
    password=$5

    if [ ! -d "tmp" ]
        then
            mkdir tmp
    fi

    if [ -f tmp/create-idp.xml ]
        then
            rm tmp/create-idp.xml
    fi

    echo
    echo "Please enter your Facebook application Client ID"
    echo
    read -r key
    echo
    echo "Please enter your Facebook application Client Secret"
    echo
    read -r secret
    echo

    cp ${config_file} tmp/create-idp.xml

    sed -i '.bak' 's/${DISPLAY_NAME}/'${display_name}'/g' tmp/create-idp.xml
    sed -i '.bak' 's/${CLIENT_ID}/'${key}'/g' tmp/create-idp.xml
    sed -i '.bak' 's/${CLIENT_SECRET}/'${secret}'/g' tmp/create-idp.xml
    sed -i '.bak' 's/${IDP_NAME}/'${idp_name}'/g' tmp/create-idp.xml

    curl -s -k --user ${username}:${password} -d @tmp/create-idp.xml -H "Content-Type: text/xml" \
    -H "SOAPAction: urn:addIdP" -o /dev/null \
    https://localhost:9443/services/IdentityProviderMgtService.IdentityProviderMgtServiceHttpsSoap11Endpoint/
    res=$?
    if test "${res}" != "0";
        then
            echo "!! Problem occurred while creating the identity provider: ${idp_name}. !!"
            echo "${res}"
            return 255
    fi
    echo "** The identity provider ${idp_name} was successfully created. **"

    return 0;
}

delete_user() {
    username=$1
    password=$2
    user=$3
    config_file=$4

    auth=$(echo "${username}:${password}"|base64)

    if [ ! -d "tmp" ]
        then
            mkdir tmp
    fi

    if [ -f tmp/delete-user.xml ]
        then
            rm tmp/delete-user.xml
    fi

    cp ${config_file} tmp/delete-user.xml

    sed -i '.bak' 's/${USERNAME}/'${user}'/g' tmp/delete-user.xml

    curl -s -k -d @tmp/delete-user.xml -H "Authorization: Basic ${auth}" -H "Content-Type: text/xml" \
    -H "SOAPAction: urn:deleteUser" -o /dev/null \
    https://localhost:9443/services/RemoteUserStoreManagerService.RemoteUserStoreManagerServiceHttpsSoap11Endpoint/
    res=$?
    if test "${res}" != "0";
        then
            echo "!! Problem occurred while deleting the user ${user}. !!"
            echo "${res}"
            return 255
    fi
    echo "** The user ${user} was successfully deleted. **"
    return 0;
}

delete_role() {
    username=$1
    password=$2
    role=$3
    config_file=$4

    auth=$(echo "${username}:${password}"|base64)

    if [ ! -d "tmp" ]
        then
            mkdir tmp
    fi

    if [ -f tmp/delete-role.xml ]
        then
            rm tmp/delete-role.xml
    fi

    cp ${config_file} tmp/delete-role.xml

    sed -i '.bak' 's/${ROLENAME}/'${role}'/g' tmp/delete-role.xml

    curl -s -k -d @tmp/delete-role.xml -H "Authorization: Basic ${auth}" -H "Content-Type: text/xml" \
    -H "SOAPAction: urn:deleteRole" -o /dev/null \
    https://localhost:9443/services/RemoteUserStoreManagerService.RemoteUserStoreManagerServiceHttpsSoap11Endpoint/
    res=$?
    if test "${res}" != "0";
        then
            echo "!! Problem occurred while deleting the role ${role}. !!"
            echo "${res}"
            return 255
    fi
    echo "** The role ${role} was successfully deleted. **"
    return 0;
}

delete_sp() {
    username=$1
    password=$2
    sp_name=$3
    config_file=$4

    auth=$(echo "${username}:${password}"|base64)

    if [ ! -d "tmp" ]
        then
            mkdir tmp
    fi

    if [ -f tmp/delete-sp.xml ]
        then
            rm tmp/delete-sp.xml
    fi

    cp ${config_file} tmp/delete-sp.xml

    sed -i '.bak' 's/${SP_NAME}/'${sp_name}'/g' tmp/delete-sp.xml

    curl -s -k -d @tmp/delete-sp.xml -H "Authorization: Basic ${auth}" -H "Content-Type: text/xml" \
    -H "SOAPAction: urn:deleteApplication" -o /dev/null \
    https://localhost:9443/services/IdentityApplicationManagementService.IdentityApplicationManagementServiceHttpsSoap11Endpoint/
    res=$?
    if test "${res}" != "0";
    then
        echo "!! Problem occurred while deleting the service provider: ${sp_name}. !!"
        echo "${res}"
        return 255
    fi
    echo "** Service Provider ${sp_name} successfully deleted. **"
    return 0;
}

delete_idp() {
    username=$1
    password=$2
    idp_name=$3
    config_file=$4

    auth=$(echo "${username}:${password}"|base64)

    if [ ! -d "tmp" ]
        then
            mkdir tmp
    fi

    if [ -f tmp/delete-idp.xml ]
        then
            rm tmp/delete-idp.xml
    fi

    cp ${config_file} tmp/delete-idp.xml

    sed -i '.bak' 's/${IDP_NAME}/'${idp_name}'/g' tmp/delete-idp.xml

    curl -s -k -d @tmp/delete-idp.xml -H "Authorization: Basic ${auth}" -H "Content-Type: text/xml" \
    -H "SOAPAction: urn:deleteIdP" -o /dev/null \
    https://localhost:9443/services/IdentityProviderMgtService.IdentityProviderMgtServiceHttpsSoap11Endpoint/
    res=$?
    if test "${res}" != "0";
    then
        echo "!! Problem occurred while deleting the identity provider: ${idp_name}. !!"
        echo "${res}"
        return 255
    fi
    echo "** Identity Provider ${idp_name} successfully deleted. **"
    return 0;
}

delete_claim(){
    username=$1
    password=$2
    claim=$3
    config_file=$4

    auth=$(echo "${username}:${password}"|base64)

    if [ ! -d "tmp" ]
        then
            mkdir tmp
    fi

    if [ -f tmp/remove-claim.xml ]
        then
            rm tmp/remove-claim.xml
    fi

    cp ${config_file} tmp/remove-claim.xml

    sed -i '.bak' 's,${CLAIM_URI},'${claim}',g' tmp/remove-claim.xml

    curl -s -k -d @tmp/remove-claim.xml -H "Authorization: Basic ${auth}" -H "Content-Type: text/xml" \
    -H "SOAPAction: urn:removeLocalClaim" -o /dev/null \
    https://localhost:9443/services/ClaimMetadataManagementService.ClaimMetadataManagementServiceHttpsSoap11Endpoint/
    res=$?
    if test "${res}" != "0";
    then
        echo "!! Problem occurred while deleting local claim: ${claim}. !!"
        echo "${res}"
        return 255
    fi
    echo "** Claim ${claim} successfully deleted. **"
    return 0;
}

eval_json() {
    content=$1
    prop=$2

    temp=`echo "${content}" | sed 's/\\\\\//\//g' | sed 's/[{}]//g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | sed 's/\"\:\"/\|/g' | sed 's/[\,]/ /g' | sed 's/\"//g' | grep -w $prop`
    echo "${temp##*|}"
}
