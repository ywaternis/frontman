open Vitest

module SafePath = FrontmanCore__SafePath
module Path = FrontmanBindings.Path

// ============================================
// resolve — basic behavior
// ============================================
describe("resolve", () => {
  test("resolves relative path under sourceRoot", t => {
    let result = SafePath.resolve(~sourceRoot="/project", ~inputPath="src/file.ts")
    switch result {
    | Ok(safePath) => t->expect(SafePath.toString(safePath))->Expect.toBe("/project/src/file.ts")
    | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
    }
  })

  test("resolves dot path to sourceRoot", t => {
    let result = SafePath.resolve(~sourceRoot="/project", ~inputPath=".")
    switch result {
    | Ok(safePath) => t->expect(SafePath.toString(safePath))->Expect.toBe("/project")
    | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
    }
  })

  test("resolves relative path when sourceRoot is dot", t => {
    let cwd = Path.resolve(".")
    let result = SafePath.resolve(~sourceRoot=".", ~inputPath="src/file.ts")
    switch result {
    | Ok(safePath) =>
      t->expect(SafePath.toString(safePath))->Expect.toBe(Path.join([cwd, "src/file.ts"]))
    | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
    }
  })

  test("resolves parent traversal above sourceRoot", t => {
    let result = SafePath.resolve(~sourceRoot="/project/app/src", ~inputPath="..")
    switch result {
    | Ok(safePath) => t->expect(SafePath.toString(safePath))->Expect.toBe("/project/app")
    | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
    }
  })

  test("accepts absolute path under sourceRoot", t => {
    let result = SafePath.resolve(~sourceRoot="/project", ~inputPath="/project/src/file.ts")
    switch result {
    | Ok(safePath) => t->expect(SafePath.toString(safePath))->Expect.toBe("/project/src/file.ts")
    | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
    }
  })

  test("accepts absolute path outside sourceRoot", t => {
    let result = SafePath.resolve(~sourceRoot="/project", ~inputPath="/etc/passwd")
    switch result {
    | Ok(safePath) => t->expect(SafePath.toString(safePath))->Expect.toBe("/etc/passwd")
    | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
    }
  })

  test("handles sourceRoot without trailing separator", t => {
    // Verify the separator appending logic doesn't break valid paths
    let result = SafePath.resolve(~sourceRoot="/project/src", ~inputPath="file.ts")
    switch result {
    | Ok(safePath) => t->expect(SafePath.toString(safePath))->Expect.toBe("/project/src/file.ts")
    | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
    }
  })

  test("handles sourceRoot with trailing forward slash", t => {
    let result = SafePath.resolve(~sourceRoot="/project/src/", ~inputPath="file.ts")
    switch result {
    | Ok(safePath) => t->expect(SafePath.toString(safePath))->Expect.toBe("/project/src/file.ts")
    | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
    }
  })

  test("path.sep is a valid separator character", t => {
    // Verify Path.sep is either / or \ — sanity check for the binding
    t->expect(Path.sep == "/" || Path.sep == "\\")->Expect.toBe(true)
  })
})

// ============================================
// resolve — absolute paths
// ============================================
describe("resolve - absolute paths", () => {
  test("accepts sourceRoot itself as absolute input", t => {
    let result = SafePath.resolve(~sourceRoot="/project", ~inputPath="/project")
    switch result {
    | Ok(safePath) => t->expect(SafePath.toString(safePath))->Expect.toBe("/project")
    | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
    }
  })
})

// ============================================
// dirname
// ============================================
describe("dirname", () => {
  test("returns parent directory", t => {
    switch SafePath.resolve(~sourceRoot="/project", ~inputPath="src/file.ts") {
    | Ok(safePath) => t->expect(SafePath.dirname(safePath))->Expect.toBe("/project/src")
    | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
    }
  })
})

// ============================================
// join
// ============================================
describe("join", () => {
  test("joins path segments and validates result", t => {
    switch SafePath.resolve(~sourceRoot="/project", ~inputPath="src") {
    | Ok(safePath) =>
      switch SafePath.join(~sourceRoot="/project", safePath, ["file.ts"]) {
      | Ok(joined) => t->expect(SafePath.toString(joined))->Expect.toBe("/project/src/file.ts")
      | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
      }
    | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
    }
  })

  test("joins segments above sourceRoot", t => {
    switch SafePath.resolve(~sourceRoot="/project", ~inputPath="src") {
    | Ok(safePath) =>
      switch SafePath.join(~sourceRoot="/project", safePath, ["..", "..", "etc"]) {
      | Ok(joined) => t->expect(SafePath.toString(joined))->Expect.toBe("/etc")
      | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
      }
    | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
    }
  })
})
