// Type-safe path resolution relative to sourceRoot.
//
// Paths may traverse above sourceRoot. This is required when framework integrations
// report a nested source directory while the application spans parent workspaces.

module Path = FrontmanBindings.Path

type t = {path: string}

let resolve = (~sourceRoot: string, ~inputPath: string): result<t, string> => {
  let path = switch Path.isAbsolute(inputPath) {
  | true => Path.normalize(inputPath)
  | false => Path.resolve(Path.join([sourceRoot, inputPath]))
  }

  Ok({path: path})
}

let toString = (safePath: t): string => safePath.path

let dirname = (safePath: t): string => Path.dirname(safePath.path)

let join = (~sourceRoot: string, safePath: t, segments: array<string>): result<t, string> => {
  let newPath = Path.join(Array.concat([safePath.path], segments))
  resolve(~sourceRoot, ~inputPath=newPath)
}
