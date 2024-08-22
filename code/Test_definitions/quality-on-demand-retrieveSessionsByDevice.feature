Feature: CAMARA Quality On Demand API, v0.10.0-rc.1 - Operation retrieveSessionsByDevice
    # Input to be provided by the implementation to the tester
    #
    # Implementation indications:
    # * apiRoot: API root of the server URL
    # * List of device identifier types which are not supported, among: phoneNumber, ipv4Address, ipv6Address.
    #   For this version, CAMARA does not allow the use of networkAccessIdentifier, so it is considered by default as not supported.
    #
    # Testing assets:
    # * A device object applicable for Quality On Demand service with an QoS Sessions associated, and the request properties used for createSession
    # * A device object applicable for Quality On Demand service with NO QoS Sessions associated
    # * A device object identifying a device commercialized by the implementation for which the service is not applicable, if any.
    #
    # References to OAS spec schemas refer to schemas specifies in quality-on-demand.yaml, version 0.11.0-rc.1

    Background: Common retrieveSessionsByDevice setup
        Given an environment at "apiRoot"
        And the resource "/quality-on-demand/v0.11rc1/retrieve-sessions"
        And the header "Content-Type" is set to "application/json"
        And the header "Authorization" is set to a valid access token
        And the header "x-correlator" is set to a UUID value
        # Properties not explicitly overwitten in the Scenarios can take any values compliant with the schema
        And the request body is set by default to a request body compliant with the schema at "/components/schemas/RetrieveSessionsInput"

    # Success scenarios

    @quality_on_demand_retrieveSessionsByDevice_01_get_existing_session_by_device
    Scenario: Get an existing QoD session by device
        Given a valid testing device supported by the service, identified by the token or provided in the request body, with QoS active sessions associated
        When the request "retrieveSessionsByDevice" is sent
        Then the response status code is 200
        And the response header "Content-Type" is "application/json"
        And the response header "x-correlator" has same value as the request header "x-correlator"
        # The response has to comply with the generic response schema which is part of the spec
        And the response body complies with the OAS schema at "/components/schemas/RetrieveSessionsOutput"
        # Additionally any success response has to comply with some constraints beyond the schema compliance
        And the response property "$.device" exists only if provided for createSession and with the same value
        And the response property "$.applicationServer" has the same value as in the request body
        And the response property "$.qosProfile" has the value provided for createSession
        And the response property "$.devicePorts" exists only if provided for createSession and with the same value
        And the response property "$.applicationServerPorts" exists only if provided for createSession and with the same value
        And the response property "$.sink" exists only if provided for createSession and with the same value
        # sinkCredentials not explicitly mentioned to be returned if present, as this is debatible for security concerns
        And the response property "$.startedAt" exists only if "$.qosStatus" is "AVAILABLE" and the value is in the past
        And the response property "$.expiresAt" exists only if "$.qosStatus" is not "REQUESTED" and the value is later than "$.startedAt"
        And the response property "$.statusInfo" exists only if "$.qosStatus" is "UNAVAILABLE"

    @quality_on_demand_retrieveSessionsByDevice_02_sessions_not_found
    Scenario: Device has not QoS sessions
        # Valid testing device and default request body compliant with the schema
        Given a valid testing device supported by the service, identified by the token or provided in the request body with no QoS active sessions associated
        When the request "retrieveSessionsByDevice" is sent
        Then the response status code is 200
        And the response header "Content-Type" is "application/json"
        And the response header "x-correlator" has same value as the request header "x-correlator"
        And the response body is []


    # Errors 400

    @quality_on_demand_retrieveSessionsByDevice_400.1_schema_not_compliant
    Scenario: Invalid Argument. Generic Syntax Exception
        Given the request body is set to any value which is not compliant with the schema at "/components/schemas/retrieveSessionsByDevice"
        When the request "retrieveSessionsByDevice" is sent
        Then the response status code is 400
        And the response header "x-correlator" has same value as the request header "x-correlator"
        And the response header "Content-Type" is "application/json"
        And the response property "$.status" is 400
        And the response property "$.code" is "INVALID_ARGUMENT"
        And the response property "$.message" contains a user friendly text


    @quality_on_demand_retrieveSessionsByDevice_400.2_no_request_body
    Scenario: Missing request body
        Given the request body is not included
        When the request "retrieveSessionsByDevice" is sent
        Then the response status code is 400
        And the response header "x-correlator" has same value as the request header "x-correlator"
        And the response header "Content-Type" is "application/json"
        And the response property "$.status" is 400
        And the response property "$.code" is "INVALID_ARGUMENT"
        And the response property "$.message" contains a user friendly text

    @quality_on_demand_retrieveSessionsByDevice_400.3_empty_request_body
    Scenario: Empty object as request body
        Given the request body is set to {}
        When the request "retrieveSessionsByDevice" is sent
        Then the response status code is 400
        And the response header "x-correlator" has same value as the request header "x-correlator"
        And the response header "Content-Type" is "application/json"
        And the response property "$.status" is 400
        And the response property "$.code" is "INVALID_ARGUMENT"
        And the response property "$.message" contains a user friendly text

    @quality_on_demand_retrieveSessionsByDevice_400.4_empty_device
    Scenario: Error response for empty device in request body
        Given the request body property "$.device" is set to {}
        When the request "retrieveSessionsByDevice" is sent
        Then the response status code is 400
        And the response header "x-correlator" has same value as the request header "x-correlator"
        And the response header "Content-Type" is "application/json"
        And the response property "$.status" is 400
        And the response property "$.code" is "INVALID_ARGUMENT"
        And the response property "$.message" contains a user friendly text

    @quality_on_demand_retrieveSessionsByDevice_400.5_device_identifiers_not_schema_compliant
    # Test every type of identifier even if not supported by the implementation
    Scenario Outline: Some device identifier value does not comply with the schema
        Given the request body property "<device_identifier>" does not comply with the OAS schema at "<oas_spec_schema>"
        When the request "retrieveSessionsByDevice" is sent
        Then the response status code is 400
        And the response header "x-correlator" has same value as the request header "x-correlator"
        And the response header "Content-Type" is "application/json"
        And the response property "$.status" is 400
        And the response property "$.code" is "INVALID_ARGUMENT"
        And the response property "$.message" contains a user friendly text

        Examples:
            | device_identifier          | oas_spec_schema                             |
            | $.device.phoneNumber       | /components/schemas/PhoneNumber             |
            | $.device.ipv4Address       | /components/schemas/NetworkAccessIdentifier |
            | $.device.ipv6Address       | /components/schemas/DeviceIpv4Addr          |
            | $.device.networkIdentifier | /components/schemas/DeviceIpv6Address       |

    # The maximum is considered in the schema so a generic schema validator may fail and generate a 400 INVALID_ARGUMENT without further distinction,
    # and both could be accepted
    @quality_on_demand_retrieveSessionsByDevice_400.6_out_of_range_port
    Scenario: Out of range port
        Given the request body property "$.device.ipv4Address.publicPort" is set to a value not between between 0 and 65536
        When the request "retrieveSessionsByDevice" is sent
        Then the response status code is 400
        And the response header "x-correlator" has same value as the request header "x-correlator"
        And the response header "Content-Type" is "application/json"
        And the response property "$.status" is 400
        And the response property "$.code" is "OUT_OF_RANGE" or "INVALID_ARGUMENT"
        And the response property "$.message" contains a user friendly text

    # Generic 401 errors

    @quality_on_demand_retrieveSessionsByDevice_401.1_no_authorization_header
    Scenario: Error response for no header "Authorization"
        Given the header "Authorization" is not sent
        And the request body is set to a valid request body
        When the request "retrieveSessionsByDevice" is sent
        Then the response status code is 401
        And the response header "x-correlator" has same value as the request header "x-correlator"
        And the response header "Content-Type" is "application/json"
        And the response property "$.status" is 401
        And the response property "$.code" is "UNAUTHENTICATED"
        And the response property "$.message" contains a user friendly text

    # In this case both codes could make sense depending on whether the access token can be refreshed or not
    @quality_on_demand_retrieveSessionsByDevice_401.2_expired_access_token
    Scenario: Error response for expired access token
        Given the header "Authorization" is set to an expired access token
        And the request body is set to a valid request body
        When the request "retrieveSessionsByDevice" is sent
        Then the response status code is 401
        And the response header "x-correlator" has same value as the request header "x-correlator"
        And the response header "Content-Type" is "application/json"
        And the response property "$.status" is 401
        And the response property "$.code" is "UNAUTHENTICATED" or "AUTHENTICATION_REQUIRED"
        And the response property "$.message" contains a user friendly text

    @quality_on_demand_retrieveSessionsByDevice_401.3_invalid_access_token
    Scenario: Error response for invalid access token
        Given the header "Authorization" is set to an invalid access token
        And the request body is set to a valid request body
        When the request "retrieveSessionsByDevice" is sent
        Then the response status code is 401
        And the response header "x-correlator" has same value as the request header "x-correlator"
        And the response header "Content-Type" is "application/json"
        And the response property "$.status" is 401
        And the response property "$.code" is "UNAUTHENTICATED"
        And the response property "$.message" contains a user friendly text


    # Errors 403

    @quality_on_demand_retrieveSessionsByDevice_403.1_device_token_mismatch
    Scenario: Inconsistent access token context for the device
        # To test this, a token have to be obtained for a different device
        Given the request body property "$.device" is set to a valid testing device
        And the header "Authorization" is set to a valid access token emitted for a different device
        When the request "retrieveSessionsByDevice" is sent
        Then the response status code is 403
        And the response header "x-correlator" has same value as the request header "x-correlator"
        And the response header "Content-Type" is "application/json"
        And the response property "$.status" is 403
        And the response property "$.code" is "INVALID_TOKEN_CONTEXT"
        And the response property "$.message" contains a user friendly text

    # Errors 404

    # Typically with a 2-legged access token
    @quality_on_demand_retrieveSessionsByDevice_404.1_device_not_found
    Scenario: Some identifier cannot be matched to a device
        Given that the device cannot be identified from the access token
        And the request body property "$.device" is compliant with the request body schema but does not identify a valid device
        When the request "retrieveSessionsByDevice" is sent
        Then the response status code is 404
        And the response header "x-correlator" has same value as the request header "x-correlator"
        And the response header "Content-Type" is "application/json"
        And the response property "$.status" is 404
        And the response property "$.code" is "DEVICE_NOT_FOUND"
        And the response property "$.message" contains a user friendly text

    # Errors 422

    # UNSUPPORTED_DEVICE_IDENTIFIERS is in the Commonalities guidelines (document) but it is not yet considered in the API spec
    @quality_on_demand_retrieveSessionsByDevice_422.1_device_identifiers_unsupported
    Scenario: None of the provided device identifiers is supported by the implementation
        Given that some type of device identifiers are not supported by the implementation
        And the request body property "$.device" only includes device identifiers not supported by the implementation
        When the request "retrieveSessionsByDevice" is sent
        Then the response status code is 422
        And the response header "x-correlator" has same value as the request header "x-correlator"
        And the response header "Content-Type" is "application/json"
        And the response property "$.status" is 422
        And the response property "$.code" is "UNPROCESSABLE_ENTITY"
        And the response property "$.message" contains a user friendly text

    # This scenario is under discussion
    @quality_on_demand_retrieveSessionsByDevice_422.2_device_identifiers_mismatch
    Scenario: Device identifiers mismatch
        Given that al least 2 types of device identifiers are supported by the implementation
        And the request body property "$.device" includes several identifiers, each of them identifying a valid but different device
        When the request "retrieveSessionsByDevice" is sent
        Then the response status code is 422
        And the response header "x-correlator" has same value as the request header "x-correlator"
        And the response header "Content-Type" is "application/json"
        And the response property "$.status" is 422
        And the response property "$.code" is "DEVICE_IDENTIFIERS_MISMATCH"
        And the response property "$.message" contains a user friendly text

    @quality_on_demand_retrieveSessionsByDevice_422.3_device_not_supported
    Scenario: Service not available for the device
        Given that service is not supported for all devices commercialized by the operator
        And the service is not applicable for the device identified by the token or provided in the request body
        When the request "retrieveSessionsByDevice" is sent
        Then the response status code is 422
        And the response header "x-correlator" has same value as the request header "x-correlator"
        And the response header "Content-Type" is "application/json"
        And the response property "$.status" is 422
        And the response property "$.code" is "DEVICE_NOT_APPLICABLE"
        And the response property "$.message" contains a user friendly text

    # Typically with a 2-legged access token
    @quality_on_demand_retrieveSessionsByDevice_422.4_unidentifiable_device
    Scenario: Device not included and cannot be deducted from the access token
        Given the header "Authorization" is set to a valid access which does not identifiy a single device
        And the request body property "$.device" is not included
        When the request "retrieveSessionsByDevice" is sent
        Then the response status code is 422
        And the response header "x-correlator" has same value as the request header "x-correlator"
        And the response header "Content-Type" is "application/json"
        And the response property "$.status" is 422
        And the response property "$.code" is "UNIDENTIFIABLE_DEVICE"
        And the response property "$.message" contains a user friendly text