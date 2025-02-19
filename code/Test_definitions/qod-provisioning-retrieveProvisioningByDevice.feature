Feature: CAMARA QoD Provisioning API, vwip - Operation retrieveProvisioningByDevice
    # Input to be provided by the implementation to the tester
    #
    # Implementation indications:
    # * apiRoot: API root of the server URL
    # * List of device identifier types which are not supported, among: phoneNumber, ipv4Address, ipv6Address.
    #   For this version, CAMARA does not allow the use of networkAccessIdentifier, so it is considered by default as not supported.
    #
    # Testing assets:
    # * A device object with an existing QoD provisioning associated, and the request properties used for createProvisioning
    # * A device object with NO existing QoD provisioning associated
    # * A device object identifying a device commercialized by the implementation for which the service is not applicable, if any
    #
    # References to OAS spec schemas refer to schemas specified in qod-provisioning.yaml


    Background: Common retrieveProvisioningByDevice setup
        Given an environment at "apiRoot"
        And the resource "/qod-provisioning/vwip/retrieve-device-qos"                                                              |
        And the header "Content-Type" is set to "application/json"
        # Unless indicated otherwise the QoD provisioning must be created by the same API client given in the access token
        And the header "Authorization" is set to a valid access token granted to the same client that created the QoD provisoning
        And the header "x-correlator" is set to a UUID value

    # Success scenarios

    @qod_provisioning_retrieveProvisioningByDevice_01_get_existing_qod_provisioning_by_device
    Scenario: Get an existing QoD Provisioning by device
        Given a valid testing device with an existing QoD Provisioning, identified by the token or provided in the request body
        When the request "retrieveProvisioningByDevice" is sent
        Then the response status code is 200
        And the response header "x-correlator" has same value as the request header "x-correlator"
        And the response header "Content-Type" is "application/json"
        # The response has to comply with the generic response schema which is part of the spec
        And the response body complies with the OAS schema at "/components/schemas/ProvisioningInfo"
        # Additionally any success response has to comply with some constraints beyond the schema compliance
        And the response property "$.device" exists only if provided for createProvisioning and with the same value
        And the response property "$.qosProfile" has the value provided for createProvisioning
        And the response property "$.sink" exists only if provided for createProvisioning and with the same value
        # sinkCredentials not explicitly mentioned to be returned if present, as this is debatible for security concerns
        And the response property "$.startedAt" exists only if "$.status" is "AVAILABLE" and the value is in the past
        And the response property "$.statusInfo" exists only if "$.status" is "UNAVAILABLE"


    # Common error scenarios for management of input parameter device

    @qod_provisioning_retrieveProvisioningByDevice_C01.01_device_empty
    Scenario: The device value is an empty object
        Given the header "Authorization" is set to a valid access token which does not identify a single device
        And the request body property "$.device" is set to: {}
        When the HTTP "POST" request is sent
        Then the response status code is 400
        And the response property "$.status" is 400
        And the response property "$.code" is "INVALID_ARGUMENT"
        And the response property "$.message" contains a user friendly text


    @qod_provisioning_retrieveProvisioningByDevice_C01.02_device_identifiers_not_schema_compliant
    Scenario Outline: Some device identifier value does not comply with the schema
        Given the header "Authorization" is set to a valid access token which does not identify a single device
        And the request body property "<device_identifier>" does not comply with the OAS schema at "<oas_spec_schema>"
        When the HTTP "POST" request is sent
        Then the response status code is 400
        And the response property "$.status" is 400
        And the response property "$.code" is "INVALID_ARGUMENT"
        And the response property "$.message" contains a user friendly text
        
        Examples:
            | device_identifier          | oas_spec_schema                             |
            | $.device.phoneNumber       | /components/schemas/PhoneNumber             |
            | $.device.ipv4Address       | /components/schemas/DeviceIpv4Addr          |
            | $.device.ipv6Address       | /components/schemas/DeviceIpv6Address       |
            | $.device.networkIdentifier | /components/schemas/NetworkAccessIdentifier |

  
    # This scenario may happen e.g. with 2-legged access tokens, which do not identify a single device.
    @qod_provisioning_retrieveProvisioningByDevice_C01.03_device_not_found
    Scenario: Some identifier cannot be matched to a device
        Given the header "Authorization" is set to a valid access token which does not identify a single device
        And the request body property "$.device" is compliant with the schema but does not identify a valid device
        When the HTTP "POST" request is sent
        Then the response status code is 404
        And the response property "$.status" is 404
        And the response property "$.code" is "IDENTIFIER_NOT_FOUND"
        And the response property "$.message" contains a user friendly text


@qod_provisioning_retrieveProvisioningByDevice_C01.04_unnecessary_device
    Scenario: Device not to be included when it can be deduced from the access token
        Given the header "Authorization" is set to a valid access token identifying a device
        And the request body property "$.device" is set to a valid device
        When the HTTP "POST" request is sent
        Then the response status code is 422
        And the response property "$.status" is 422
        And the response property "$.code" is "UNNECESSARY_IDENTIFIER"
        And the response property "$.message" contains a user-friendly text


    @qod_provisioning_retrieveProvisioningByDevice_C01.05_missing_device
    Scenario: Device not included and cannot be deduced from the access token
        Given the header "Authorization" is set to a valid access token which does not identify a single device
        And the request body property "$.device" is not included
        When the HTTP "POST" request is sent
        Then the response status code is 422
        And the response property "$.status" is 422
        And the response property "$.code" is "MISSING_IDENTIFIER"
        And the response property "$.message" contains a user-friendly text


    @qod_provisioning_retrieveProvisioningByDevice_C01.06_unsupported_device
    Scenario: None of the provided device identifiers is supported by the implementation
        Given that some types of device identifiers are not supported by the implementation
        And the header "Authorization" is set to a valid access token which does not identify a single device
        And the request body property "$.device" only includes device identifiers not supported by the implementation
        When the HTTP "POST" request is sent
        Then the response status code is 422
        And the response property "$.status" is 422
        And the response property "$.code" is "UNSUPPORTED_IDENTIFIER"
        And the response property "$.message" contains a user-friendly text


    # When the service is only offered to certain types of devices or subscriptions, e.g. IoT, B2C, etc.
    @qod_provisioning_retrieveProvisioningByDevice_C01.07_device_not_supported
    Scenario: Service not available for the device
        Given that the service is not available for all devices commercialized by the operator
        And a valid device, identified by the token or provided in the request body, for which the service is not applicable
        When the HTTP "POST" request is sent
        Then the response status code is 422
        And the response property "$.status" is 422
        And the response property "$.code" is "SERVICE_NOT_APPLICABLE"
        And the response property "$.message" contains a user-friendly text


    # Several identifiers provided but they do not identify the same device
    # This scenario may happen with 2-legged access tokens, which do not identify a device
    @qod_provisioning_retrieveProvisioningByDevice_C01.08_device_identifiers_mismatch
    Scenario: Device identifiers mismatch
        Given the header "Authorization" is set to a valid access token which does not identify a single device
        And at least 2 types of device identifiers are supported by the implementation
        And the request body property "$.device" includes several identifiers, each of them identifying a valid but different device
        When the HTTP "POST" request is sent
        Then the response status code is 422
        And the response property "$.status" is 422
        And the response property "$.code" is "IDENTIFIER_MISMATCH"
        And the response property "$.message" contains a user friendly text

    # Errors 400

    @qod_provisioning_retrieveProvisioningByDevice_400.1_schema_not_compliant
    Scenario: Invalid Argument. Generic Syntax Exception
        Given the request body is set to any value which is not compliant with the schema at "/components/schemas/RetrieveProvisioningByDevice"
        When the request "retrieveProvisioningByDevice" is sent
        And the response header "x-correlator" has same value as the request header "x-correlator"
        And the response header "Content-Type" is "application/json"
        And the response property "$.status" is 400
        And the response property "$.code" is "INVALID_ARGUMENT"
        And the response property "$.message" contains a user friendly text

    @qod_provisioning_retrieveProvisioningByDevice_400.2_no_request_body
    Scenario: Missing request body
        Given the request body is not included
        When the request "retrieveProvisioningByDevice" is sent
        Then the response status code is 400
        And the response header "x-correlator" has same value as the request header "x-correlator"
        And the response header "Content-Type" is "application/json"
        And the response property "$.status" is 400
        And the response property "$.code" is "INVALID_ARGUMENT"
        And the response property "$.message" contains a user friendly text

    @qod_provisioning_retrieveProvisioningByDevice_400.3_empty_request_body
    Scenario: Empty object as request body
        Given the request body is set to {}
        When the request "retrieveProvisioningByDevice" is sent
        Then the response status code is 400
        And the response header "x-correlator" has same value as the request header "x-correlator"
        And the response header "Content-Type" is "application/json"
        And the response property "$.status" is 400
        And the response property "$.code" is "INVALID_ARGUMENT"
        And the response property "$.message" contains a user friendly text

    # Generic 401 errors

    @qod_provisioning_retrieveProvisioningByDevice_401.1_no_authorization_header
    Scenario: No Authorization header
        Given the header "Authorization" is not sent
        When the request "retrieveProvisioningByDevice" is sent
        Then the response status code is 401
        And the response header "x-correlator" has same value as the request header "x-correlator"
        And the response header "Content-Type" is "application/json"
        And the response property "$.status" is 401
        And the response property "$.code" is "UNAUTHENTICATED"
        And the response property "$.message" contains a user friendly text

    # In this case both codes could make sense depending on whether the access token can be refreshed or not
    @qod_provisioning_retrieveProvisioningByDevice_401.2_expired_access_token
    Scenario: Expired access token
        Given the header "Authorization" is set to an expired access token
        When the request "retrieveProvisioningByDevice" is sent
        Then the response status code is 401
        And the response header "x-correlator" has same value as the request header "x-correlator"
        And the response header "Content-Type" is "application/json"
        And the response property "$.status" is 401
        And the response property "$.code" is "UNAUTHENTICATED" or "AUTHENTICATION_REQUIRED"
        And the response property "$.message" contains a user friendly text

    @qod_provisioning_retrieveProvisioningByDevice_401.3_invalid_access_token
    Scenario: Invalid access token
        Given the header "Authorization" is set to an invalid access token
        When the request "retrieveProvisioningByDevice" is sent
        Then the response status code is 401
        And the response header "x-correlator" has same value as the request header "x-correlator"
        And the response header "Content-Type" is "application/json"
        And the response property "$.status" is 401
        And the response property "$.code" is "UNAUTHENTICATED"
        And the response property "$.message" contains a user friendly text

    # Errors 403

    @qod_provisioning_retrieveProvisioningByDevice_403.1_missing_access_token_scope
    Scenario: Missing access token scope
        Given the header "Authorization" is set to an access token that does not include scope qod-provisioning:device-qos:read-by-device
        When the request "retrieveProvisioningByDevice" is sent
        Then the response status code is 403
        And the response header "x-correlator" has same value as the request header "x-correlator"
        And the response header "Content-Type" is "application/json"
        And the response property "$.status" is 403
        And the response property "$.code" is "PERMISSION_DENIED"
        And the response property "$.message" contains a user friendly text

    @qod_provisioning_retrieveProvisioningByDevice_403.2_different_client_id
    Scenario: QoD provisioning not created by the API client given in the access token
        # To test this, a token have to be obtained for a different client
        Given the header "Authorization" is set to a valid access token emitted to a client which did not created the QoD provisioning
        When the request "retrieveProvisioningByDevice" is sent
        Then the response status code is 403
        And the response header "x-correlator" has same value as the request header "x-correlator"
        And the response header "Content-Type" is "application/json"
        And the response property "$.status" is 403
        And the response property "$.code" is "PERMISSION_DENIED"
        And the response property "$.message" contains a user friendly text

    # Errors 404

    @qod_provisioning_retrieveProvisioningByDevice_404.1_not_found
    Scenario: Device with no existing QoD provisioning
        Given a valid testing device without an existing QoD Provisioning, identified by the token or provided in the request body
        When the request "retrieveProvisioningByDevice" is sent
        Then the response status code is 404
        And the response header "x-correlator" has same value as the request header "x-correlator"
        And the response header "Content-Type" is "application/json"
        And the response property "$.status" is 404
        And the response property "$.code" is "NOT_FOUND"
        And the response property "$.message" contains a user friendly text
