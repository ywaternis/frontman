// Type-safe path resolution relative to sourceRoot.
// Paths may traverse above sourceRoot when integrations report a nested source directory.

type t

// Resolve an absolute path or a path relative to sourceRoot.
let resolve: (~sourceRoot: string, ~inputPath: string) => result<t, string>

let toString: t => string

let dirname: t => string

let join: (~sourceRoot: string, t, array<string>) => result<t, string>
