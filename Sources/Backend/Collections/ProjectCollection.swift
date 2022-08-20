import Vapor

class ProjectCollection: RouteCollection {

    private let restfulIDKey = "id"

    func boot(routes: RoutesBuilder) throws {
        let routes = routes.grouped(.constant(Project.schema))

        routes.on(.GET, use: readAll)
        routes.on(.GET, .parameter(restfulIDKey), use: read)

        let trusted = routes.grouped([
            User.authenticator(),
            Token.authenticator(),
            User.guardMiddleware(),
        ])

        trusted.on(.POST, use: create)
        trusted.on(.PUT, .parameter(restfulIDKey), use: update)
        trusted.on(.DELETE, .parameter(restfulIDKey), use: delete)
    }

    func create(_ req: Request) async throws -> Project.DTO {
        var newValue = try req.content.decode(Project.DTO.self)
        newValue.userId = try req.owner.__id

        let model = try Project(from: newValue)
        model.id = nil

        try await req.project.create(model)

        return try model.dataTransferObject()
    }

    func read(_ req: Request) async throws -> Project.DTO {
        let id = try req.parameters.require(restfulIDKey, as: Project.IDValue.self)

        let saved = try await req.project.identified(by: id)

        return try saved.dataTransferObject()
    }

    func readAll(_ req: Request) async throws -> [Project.DTO] {
        try await req.project.readAll().map {
            try $0.dataTransferObject()
        }
    }

    func update(_ req: Request) async throws -> Project.DTO {
        let id = try req.parameters.require(restfulIDKey, as: Project.IDValue.self)

        var newValue = try req.content.decode(Project.DTO.self)
        newValue.userId = try req.owner.__id

        let saved = try await req.project.identified(by: id, owned: true)
        try saved.update(with: newValue)

        precondition(saved.$user.id == newValue.userId)
        try await req.project.update(saved)

        return try saved.dataTransferObject()
    }

    func delete(_ req: Request) async throws -> HTTPResponseStatus {
        let id = try req.parameters.require(restfulIDKey, as: Project.IDValue.self)

        try await req.project.delete(id)

        return .ok
    }
}
