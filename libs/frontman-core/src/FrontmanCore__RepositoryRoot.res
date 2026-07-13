// Resolve the repository containing a project so Frontman's file tools can work
// across workspace/package boundaries without gaining access to the entire host.

module Fs = FrontmanBindings.Fs
module Path = FrontmanBindings.Path

let rec findFrom = (directory: string): option<string> => {
  let directory = Path.resolve(directory)
  let gitMarker = Path.join([directory, ".git"])

  switch Fs.existsSync(gitMarker) {
  | true => Some(directory)
  | false => {
      let parent = Path.dirname(directory)
      switch parent == directory {
      | true => None
      | false => findFrom(parent)
      }
    }
  }
}

let resolve = (projectRoot: string): string => {
  let normalizedProjectRoot = Path.resolve(projectRoot)
  findFrom(normalizedProjectRoot)->Option.getOr(normalizedProjectRoot)
}
