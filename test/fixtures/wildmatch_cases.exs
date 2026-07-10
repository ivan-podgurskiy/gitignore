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
  }
]
