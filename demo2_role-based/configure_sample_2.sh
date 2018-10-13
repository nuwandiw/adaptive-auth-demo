#!/bin/bash

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


configure_sample_2() {
    echo
    echo "-------------------------------------------------------------------"
    echo "|                                                                 |"
    echo "|  We are configuring Google and Facebook as two federated        |"
    echo "|  identity providers. Therefore,                                 |"
    echo "|                                                                 |"
    echo "|  1. Register an OAuth 2.0 Application in Google API Console.    |"
    echo "|                                                                 |"
    echo "|  https://docs.wso2.com/display/IS570/Configuring+Google         |"
    echo "|                                                                 |"
    echo "|  2. Register an OAuth 2.0 Application in Facebook developers    |"
    echo "|  site.                                                          |"
    echo "|                                                                 |"
    echo "|  https://docs.wso2.com/display/IS570/Configuring+Facebook.      |"
    echo "|                                                                 |"
    echo "|  Make sure you have registered above two applications before    |"
    echo "|  continuing the script.                                         |"
    echo "|                                                                 |"
    echo "|  Do you want to continue?                                       |"
    echo "|                                                                 |"
    echo "|  Press y - YES                                                  |"
    echo "|  Press n - EXIT                                                 |"
    echo "|                                                                 |"
    echo "-------------------------------------------------------------------"
    echo
    read -r continue

    case ${continue} in
        [Yy]* )
            create_google_idp "GoogleIDP" "GoogleIDP" "${COMMON_HOME}/configs/create-google-idp.xml" admin admin
            create_fb_idp "FacebookIDP" "FacebookIDP" "${COMMON_HOME}/configs/create-fb-idp.xml" admin admin
            configure_service_provider pickup admin admin "${COMMON_HOME}/configs/get-sp.xml" "${SAMPLE_HOME}/configs/update-sp.xml"
            display_sample_info
        ;;
        [Nn]* )
            exit 1
        ;;
    esac

    return 0;
}

display_sample_info() {
    echo
    echo "----------------------------------------------------------------------"
    echo "|                                                                    |"
    echo "|    The conditional authentication enables you to add more          |"
    echo "|    control and constraints to the authentication process.          |"
    echo "|                                                                    |"
    echo "|    Here we are going to try out a conditional authentication       |"
    echo "|    scenario where users will be prompted with different login      |"
    echo "|    paths based on the roles assigned to them                       |"
    echo "|                                                                    |"
    echo "|    Use case: Internal employees login to the pickup application    |"
    echo "|    providing their local password. Other users can use a preffered |"
    echo "|    federated Idp from a given list of options when login.          |"
    echo "|                                                                    |"
    echo "|    Bob is an internal employee assigned to the role 'Manager'.     |"
    echo "|    After Bob enters his username, he is asked to provide his       |"
    echo "|    internal password in order to login.                            |"
    echo "|    Alex is an ordinary user who doesn't have any specific roles.   |"
    echo "|    After Alex enters his username, he is prompted with different   |"
    echo "|    social login options. He may use one of those to login.         |"
    echo "|                                                                    |"
    echo "|    To tryout conditional authentication please log into            |"
    echo "|    the sample applications below.                                  |"
    echo "|                                                                    |"
    echo "|    PickUp - http://localhost:8080/saml2-web-app-pickup.com/        |"
    echo "|                                                                    |"
    echo "|    Internal employee                                               |"
    echo "|      Username: bob                                                 |"
    echo "|      Password: bob123                                              |"
    echo "|                                                                    |"
    echo "|    Ordinary user                                                   |"
    echo "|      Username: alex                                                |"
    echo "|      Password: alex123                                             |"
    echo "|                                                                    |"
    echo "----------------------------------------------------------------------"
    echo
    echo "If you have finished trying out the sample, you can clean the generated artifacts now."
    echo "Do you want to clean up the setup?"
    echo
    echo "Press y - YES"
    echo "Press n - NO"
    echo

    read -r clean

    case ${clean} in
        [Yy]* )
            cleanup_sample;;
        [Nn]* )
            exit;;
        * ) echo "Please answer yes or no.";;
    esac
}

cleanup_sample() {
    echo
    echo "Removing service providers"
    delete_sp admin admin pickup "${COMMON_HOME}/cleanup/delete-sp.xml"

    echo
    echo "Removing IDPs"
    delete_idp admin admin GoogleIDP "${COMMON_HOME}/cleanup/delete-idp.xml"
    delete_idp admin admin FacebookIDP "${COMMON_HOME}/cleanup/delete-idp.xml"

    echo
    echo "Removing users"
    delete_user admin admin alex "${COMMON_HOME}/cleanup/delete-user.xml"
    delete_user admin admin bob "${COMMON_HOME}/cleanup/delete-user.xml"

    echo
    echo "Removing roles"
    delete_role admin admin Manager "${COMMON_HOME}/cleanup/delete-role.xml"

    echo
    echo "Cleaning up created temporary files"

    if [ -d "${SAMPLE_HOME}/tmp" ]
        then
            rm -r "${SAMPLE_HOME}/tmp"
    fi

    if [ -d "${COMMON_HOME}/tmp" ]
        then
            rm -r "${COMMON_HOME}/tmp"
    fi

    echo
    echo "Resources cleaning finished"

    return 0;
}

deactivate_tenant() {
    username=$1
    password=$2
    tenant_domain=$3
    config_file=$4

    auth=$(echo "${username}:${password}"|base64)

    if [ ! -d "tmp" ]
        then
            mkdir tmp
    fi

    if [ -f tmp/deactivate-tenant.xml ]
        then
            rm tmp/deactivate-tenant.xml
    fi

    cp ${config_file} tmp/deactivate-tenant.xml

    sed -i '.bak' 's/${TENANT_DOMAIN}/'${tenant_domain}'/g' tmp/deactivate-tenant.xml

    curl -s -k -d @tmp/deactivate-tenant.xml -H "Authorization: Basic ${auth}" -H "Content-Type: text/xml" \
    -H "SOAPAction: urn:deactivateTenant" -o /dev/null \
    https://localhost:9443/services/TenantMgtAdminService.TenantMgtAdminServiceHttpsSoap11Endpoint/
    res=$?
    if test "${res}" != "0";
    then
        echo "!! Problem occurred while deactivating the tenant: ${tenant_domain}. !!"
        echo "${res}"
        return 255
    fi
    echo "** Tenant ${tenant_domain} successfully deactivated. **"
    return 0;
}

export SAMPLE_HOME=$(cd `dirname $0` && pwd)

cd ${SAMPLE_HOME} || return
cd ../ || return
cd common || return

export COMMON_HOME=$(pwd)

cd ${SAMPLE_HOME} || return

. ${COMMON_HOME}/configure_samples.sh

create_user admin admin "Alex Miller" "${COMMON_HOME}/configs/user_alex.json"
create_user_with_role admin admin "Bob" "Manager_Role" "${COMMON_HOME}/configs/user_bob.json" "${COMMON_HOME}/configs/role_manager.json"
create_oidc_service_provider admin admin pickup "${COMMON_HOME}/configs/pickup-client.json"
configure_sample_2
