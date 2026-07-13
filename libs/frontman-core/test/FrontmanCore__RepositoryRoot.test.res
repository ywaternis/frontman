open Vitest

module Fs = FrontmanBindings.Fs
module Os = FrontmanBindings.Os
module Path = FrontmanBindings.Path
module RepositoryRoot = FrontmanCore__RepositoryRoot

let makeTmpDir = async () => {
  let dir = Path.join([Os.tmpdir(), `repository-root-test-${Date.now()->Float.toString}`])
  let _ = await Fs.Promises.mkdir(dir, {recursive: true})
  dir
}

describe("resolve", () => {
  testAsync("finds the repository root above a nested project", async t => {
    let repository = await makeTmpDir()
    let nestedProject = Path.join([repository, "apps", "web"])
    let _ = await Fs.Promises.mkdir(nestedProject, {recursive: true})
    await Fs.Promises.writeFile(Path.join([repository, ".git"]), "gitdir: test")

    t->expect(RepositoryRoot.resolve(nestedProject))->Expect.toBe(repository)
  })

  testAsync("uses the project root when no repository exists", async t => {
    let projectRoot = await makeTmpDir()

    t->expect(RepositoryRoot.resolve(projectRoot))->Expect.toBe(projectRoot)
  })
})
