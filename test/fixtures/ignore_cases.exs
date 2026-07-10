[
  %{
    name: "negation unignores later beam",
    rules: "*.beam\n!important.beam\n",
    path: "important.beam",
    type: :file,
    expected: false
  },
  %{
    name: "parent directory exclusion wins",
    rules: "build/\n!build/keep.txt\n",
    path: "build/keep.txt",
    type: :file,
    expected: true
  },
  %{
    name: "leading slash anchors to base",
    rules: "/tmp\n",
    path: "nested/tmp",
    type: :directory,
    expected: false
  }
]
