import Foundation

@MainActor
func run() async throws {
    let args = Args(Array(CommandLine.arguments.dropFirst()))
    switch args.next() ?? "help" {
    case "list": listCommand(args)
    case "stats": statsCommand(args)
    case "render": try await renderCommand(args)
    case "thumbs": try await thumbsCommand(args)
    case "textures": try texturesCommand(args)
    case "shaders": try await shadersCommand(args)
    case "catalog": try catalogCommand()
    case "new": try newCommand(args)
    case "bench": try await benchCommand()
    case "sky": try skyCommand(args)
    case "demo": try await demoCommand(args)
    default: print(usage)
    }
}

do { try await run() } catch { print("error: \(error)"); exit(1) }
