import Testing
@testable import broche

struct StaticSecretsTests {

    @Test func returnsOpenRouterToken() async throws {
        let secrets = StaticSecrets(openRouter: "or-token", replicate: "rep-token")
        #expect(try await secrets.openRouterToken() == "or-token")
    }

    @Test func returnsReplicateToken() async throws {
        let secrets = StaticSecrets(openRouter: "or-token", replicate: "rep-token")
        #expect(try await secrets.replicateToken() == "rep-token")
    }

}
