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


configure_sample_1() {
    echo
    echo "-------------------------------------------------------------------"
    echo "|                                                                 |"
    echo "|  We are configuring SMS OTP Identity Provider. In order to run  |"
    echo "|  the sample, a valid SMS provider is required.                  |"
    echo "|  We will prompt for necessary details for this Identity Provier |"
    echo "|  configuration. Make sure you have those information in hand    |"
    echo "|  before begining the sample. Check following doc for more info. |"
    echo "|                                                                 |"
    echo "|  https://docs.wso2.com/display/IS570/Configuring+SMS+OTP        |"
    echo "|                                                                 |"
    echo "|  So please make sure you have registered a Nexmo application    |"
    echo "|  before continuing the script.                                  |"
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
            create_smsotp_idp "SMS_OTP" "SMS_OTP" "${COMMON_HOME}/configs/create-smsotp-idp.xml" admin admin
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
    echo "|                                                                    |"
    echo "|    In this example, we demonstrate how to use adaptive             |"
    echo "|    authentication to dynamically change the strength of            |"
    echo "|    authentication according to different Authentication Context    |"
    echo "|    Class Reference (ACR) levels provided by the application        |"
    echo "|                                                                    |"
    echo "|    Story:                                                          |"
    echo "|    1. Alex login into PickUp application by entering username and  |"
    echo "|    password.                                                       |"
    echo "|    2. He can order a taxi under the “Single Ride” without further  |"
    echo "|    verifications.                                                  |"
    echo "|    3. Once he select order a taxi under the “For the whole day”,   |"
    echo "|    he needs to be verified with SMS OTP.                           |"
    echo "|    4. Once the OTP verification is successful he can continue with |"
    echo "|    the booking.                                                    |"
    echo "|                                                                    |"
    echo "|    To tryout conditional authentication please log into            |"
    echo "|    the sample applications below.                                  |"
    echo "|                                                                    |"
    echo "|    PickUp - http://localhost:8080/oidc-web-app-pickup/             |"
    echo "|                                                                    |"
    echo "|    User                                                            |"
    echo "|    username: alex                                                  |"
    echo "|    password: alex123                                               |"
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
    delete_idp admin admin SMS_OTP "${COMMON_HOME}/cleanup/delete-idp.xml"

    echo
    echo "Removing users"
    delete_user admin admin alex "${COMMON_HOME}/cleanup/delete-user.xml"

    echo
    echo "Removing claims"
    delete_claim admin admin http://wso2.org/claims/identity/smsotp_disabled "${COMMON_HOME}/cleanup/remove-claim.xml"

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

create_user_with_phone() {
    username=$1
    password=$2
    user=$3

    echo
    echo "Creating a user named ${user}..."
    echo
    echo "Please enter mobile number for ${user}"
    echo
    read -r mobile
    echo

    if [ ! -d "tmp" ]
        then
            mkdir tmp
    fi

    cp "${SAMPLE_HOME}/configs/user.json" tmp/user_"${user}".json

    sed -i '.bak' 's#${MOBILE}#'${mobile}'#g' tmp/user_"${user}".json

    curl -s -k --user "${username}":"${password}" --data-binary @tmp/user_"${user}".json \
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

add_claim() {
    username=$1
    password=$2
    config_file=$3

    echo
    echo "Adding 'Disable SMS OTP' claim.."
    echo
    curl -s -k --user ${username}:${password} -d @${config_file} -H "Content-Type: text/xml" \
    -H "SOAPAction: urn:addLocalClaim" -o /dev/null \
    https://localhost:9443/services/ClaimMetadataManagementService.ClaimMetadataManagementServiceHttpsSoap11Endpoint/
    res=$?
    if test "${res}" != "0";
        then
            echo "!! Problem occurred while adding local claim. !!"
            echo "${res}"
            return 255
    fi
    echo "** Successfully added 'Disable SMS OTP' claim. **"

    return 0;
}

export SAMPLE_HOME=$(cd `dirname $0` && pwd)

cd ${SAMPLE_HOME} || return
cd ../ || return
cd common || return

export COMMON_HOME=$(pwd)

cd ${SAMPLE_HOME} || return

. ${COMMON_HOME}/configure_samples.sh

create_user_with_phone admin admin alex
add_claim admin admin "${SAMPLE_HOME}/configs/add-sms-otp-disabled-claim.xml"
create_oidc_service_provider admin admin pickup "${SAMPLE_HOME}/configs/pickup-client.json"
configure_sample_1
