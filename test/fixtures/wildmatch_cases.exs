[
  %{
    name: "literal mismatch from t3070 shape",
    pattern: "foo",
    path: "bar",
    opts: [pathname: false],
    expected: false
  },
  %{
    name: "pathname star does not cross slash",
    pattern: "foo*",
    path: "foo/bar",
    opts: [pathname: true],
    expected: false
  },
  %{
    name: "casefold fixture",
    pattern: "Makefile",
    path: "makefile",
    opts: [pathname: true, casefold: true],
    expected: true
  },
  %{
    name: "middle globstar fixture",
    pattern: "foo/**/bar",
    path: "foo/a/b/bar",
    opts: [pathname: true],
    expected: true
  },
  %{
    name: "question mark does not cross slash",
    pattern: "a/?/c",
    path: "a/b/c",
    opts: [pathname: true],
    expected: true
  },
  %{
    name: "question mark slash rejection",
    pattern: "a/?/c",
    path: "a//c",
    opts: [pathname: true],
    expected: false
  },
  %{
    name: "escaped bracket literal",
    pattern: "a\\[b",
    path: "a[b",
    opts: [pathname: true],
    expected: true
  },
  %{
    name: "xdigit posix class",
    pattern: "[[:xdigit:]]",
    path: "f",
    opts: [pathname: true],
    expected: true
  },
  %{
    name: "xdigit posix class rejects g",
    pattern: "[[:xdigit:]]",
    path: "g",
    opts: [pathname: true],
    expected: false
  }
]
