//
//  StaticSecrets.swift
//  broche
//  Created by Zhu Zhanyan on 2026-09-02.
//

import Foundation

struct StaticSecrets: Secrets {
    private let openRouter: String
    private let replicate: String

    init(openRouter: String, replicate: String) {
        self.openRouter = openRouter
        self.replicate = replicate
    }

    func openRouterToken() async throws -> String { openRouter }
    func replicateToken() async throws -> String { replicate }
}
