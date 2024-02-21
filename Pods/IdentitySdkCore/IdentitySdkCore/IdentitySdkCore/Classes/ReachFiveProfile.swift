import Foundation
import BrightFutures

public extension ReachFive {
    func getProfile(authToken: AuthToken) -> Future<Profile, ReachFiveError> {
        reachFiveApi.getProfile(authToken: authToken)
    }
    
    func verifyPhoneNumber(
        authToken: AuthToken,
        phoneNumber: String,
        verificationCode: String
    ) -> Future<(), ReachFiveError> {
        let verifyPhoneNumberRequest = VerifyPhoneNumberRequest(
            phoneNumber: phoneNumber,
            verificationCode: verificationCode
        )
        return reachFiveApi
            .verifyPhoneNumber(authToken: authToken, verifyPhoneNumberRequest: verifyPhoneNumberRequest)
    }
    
    func updateEmail(
        authToken: AuthToken,
        email: String,
        redirectUrl: String? = nil
    ) -> Future<Profile, ReachFiveError> {
        let updateEmailRequest = UpdateEmailRequest(email: email, redirectUrl: redirectUrl)
        return reachFiveApi.updateEmail(
            authToken: authToken,
            updateEmailRequest: updateEmailRequest
        )
    }
    
    func updatePhoneNumber(
        authToken: AuthToken,
        phoneNumber: String
    ) -> Future<Profile, ReachFiveError> {
        let updatePhoneNumberRequest = UpdatePhoneNumberRequest(phoneNumber: phoneNumber)
        return reachFiveApi.updatePhoneNumber(
            authToken: authToken,
            updatePhoneNumberRequest: updatePhoneNumberRequest
        )
    }
    
    func updateProfile(
        authToken: AuthToken,
        profile: Profile
    ) -> Future<Profile, ReachFiveError> {
        reachFiveApi.updateProfile(authToken: authToken, profile: profile)
    }
    
    func updatePassword(_ updatePasswordParams: UpdatePasswordParams) -> Future<(), ReachFiveError> {
        let authToken = updatePasswordParams.getAuthToken()
        return reachFiveApi.updatePassword(
            authToken: authToken,
            updatePasswordRequest: UpdatePasswordRequest(
                updatePasswordParams: updatePasswordParams,
                sdkConfig: sdkConfig
            )
        )
    }
    
    func requestPasswordReset(
        email: String?,
        phoneNumber: String?,
        redirectUrl: String? = nil
    ) -> Future<(), ReachFiveError> {
        let requestPasswordResetRequest = RequestPasswordResetRequest(
            clientId: sdkConfig.clientId,
            email: email,
            phoneNumber: phoneNumber,
            redirectUrl: redirectUrl
        )
        return reachFiveApi.requestPasswordReset(
            requestPasswordResetRequest: requestPasswordResetRequest
        )
    }
    
    /// Lists all passkeys and other webauthn credentials the user has registered
    func listWebAuthnCredentials(authToken: AuthToken) -> Future<[DeviceCredential], ReachFiveError> {
        reachFiveApi.getWebAuthnRegistrations(authToken: authToken)
    }
    
    /// Deletes a passkey or other webauthn credentials the user has registered
    func deleteWebAuthnRegistration(id: String, authToken: AuthToken) -> Future<(), ReachFiveError> {
        reachFiveApi.deleteWebAuthnRegistration(id: id, authToken: authToken)
    }
}
