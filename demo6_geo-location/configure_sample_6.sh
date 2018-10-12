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

configure_sample6() {

    echo
    echo "-------------------------------------------------------------------"
    echo "|                                                                 |"
    echo "|  We are configuring SMS OTP Identity Provider. In order to run  |"
    echo "|  the sample, a valid SMS provider is required. For this example |"
    echo "|  We will use Nexmo as the SMS provider. To enable SMS OTP       |"
    echo "|  with Nexmo SMS provider, check the given doc.                  |"
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

    read -r continue

    case ${continue} in
        [Yy]* )

            create_smsotp_idp "SMS_OTP" "SMS_OTP" "${COMMON_HOME}/configs/create-smsotp-idp.xml" admin admin
            configure_service_provider pickup admin admin "${COMMON_HOME}/configs/get-sp.xml" "${SAMPLE_HOME}/configs/update-sp.xml"
            echo
            echo "Please enter mobile number for Bob (user Bob is created and may require to submit an OTP sent to his phone)"
            read -r mobile_alex
            echo 
            add_user_claim admin admin alex http://wso2.org/claims/mobile ${mobile_alex} "${COMMON_HOME}/configs/set-claim.xml"
            
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
    echo "|    In this example, we demonstrate how to strengthen authentication|"
    echo "|    according to the geo location of the user                       |"
    echo "|                                                                    |"
    echo "|    Story:                                                          |"
    echo "|    1. Bob login into PickUp application by entering username and   |"
    echo "|    password from US.                                               |"
    echo "|                                                                    |"
    echo "|    2. Bob log-out from the application.                            |"
    echo "|                                                                    |"
    echo "|    3. Someone trying to login to PickUp application using same     |"
    echo "|    credentials but from UK                                         |"
    echo "|                                                                    |"
    echo "|    4. Prompt for SMS verification as an extra security measure     |"
    echo "|                                                                    |"
    echo "|    To tryout conditional authentication please log into            |"
    echo "|    the sample applications below.                                  |"
    echo "|                                                                    |"
    echo "|    PickUp - http://localhost:8080/oidc-web-app-pickup/             |"
    echo "|                                                                    |"
    echo "|                                                                    |"
    echo "|    User                                                            |"
    echo "|    username: bob                                                   |"
    echo "|    password: bob123                                                |"
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
            cleanup_sample
            ;;
        [Nn]* )
            exit
            ;;
        * )
            echo "Please answer yes or no."
            ;;
    esac
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

cleanup_sample() {
    echo
    echo "Removing service providers"
    delete_sp admin admin pickup "${COMMON_HOME}/cleanup/delete-sp.xml"

    echo
    echo "Removing users"
    delete_user admin admin alex "${COMMON_HOME}/cleanup/delete-user.xml"

    echo
    echo "Removing IDPs"
    delete_idp admin admin SMS_OTP "${COMMON_HOME}/cleanup/delete-idp.xml"

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

start_sp_worker() {

    echo
    echo Enter directory location of "<WSO2SP_HOME>"
    read -r sp_home
    echo

    export SP_HOME=${sp_home}

    if [ -f ${sp_home}/deployment/siddhi-files/RiskBasedLogin.siddhi ]
        then
            rm ${sp_home}/deployment/siddhi-files/RiskBasedLogin.siddhi
    fi

    cp "${SAMPLE_HOME}/configs/RiskBasedLogin.siddhi" ${sp_home}/deployment/siddhi-files/RiskBasedLogin.siddhi

    $(${sp_home}/bin/worker.sh -start)
}

add_user_claim() {
    username=$1
    password=$2
    user=$3
    claim_uri=$4
    claim_value=$5
    config_file=$6

    auth=$(echo "${username}:${password}"|base64)

    if [ ! -d "tmp" ]
        then
            mkdir tmp
    fi

    if [ -f tmp/set-claim.xml ]
        then
            rm tmp/set-claim.xml
    fi

    cp ${config_file} tmp/set-claim.xml

    sed -i '.bak' 's#${USERNAME}#'${user}'#g' tmp/set-claim.xml
    sed -i '.bak' 's#${CLAIM_URI}#'${claim_uri}'#g' tmp/set-claim.xml
    sed -i '.bak' 's#${CLAIM_VALUE}#'${claim_value}'#g' tmp/set-claim.xml

    curl -s -k -d @tmp/set-claim.xml -H "Authorization: Basic ${auth}" -H "Content-Type: text/xml" \
    -H "SOAPAction: urn:setUserClaimValues" -o /dev/null \
    https://localhost:9443/services/RemoteUserStoreManagerService.RemoteUserStoreManagerServiceHttpsSoap11Endpoint/
    res=$?
    if test "${res}" != "0";
        then
            echo "!! Problem occurred adding claim ${claim_uri} to ${user}. !!"
            echo "${res}"
            return 255
    fi
    echo "** Claim ${claim_uri} added to ${user} successfully. **"
    return 0;

    return 0;
}

export SAMPLE_HOME=$(cd `dirname $0` && pwd)

cd ${SAMPLE_HOME} || return
cd ../ || return
cd common || return

export COMMON_HOME=$(pwd)

cd ${SAMPLE_HOME} || return

. ${COMMON_HOME}/configure_samples.sh

create_user admin admin "Bob Taylor" "${COMMON_HOME}/configs/user_bob.json"
add_claim admin admin "${COMMON_HOME}/configs/add-sms-otp-disabled-claim.xml"
create_oidc_service_provider admin admin pickup "${COMMON_HOME}/configs/pickup-client.json"
configure_sample6
