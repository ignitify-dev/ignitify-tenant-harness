# go-checksum

A Go task with no network. Go tasks carry the Ignitify runtime client in an `ignitify/` folder, so this example holds only the files you write. Create the rest with the CLI:

```sh
ignitify task:create go-checksum --lang go --local --dir my-tasks   # writes main.go, go.mod, go.sum, ignitify/
cp examples/go-checksum/task.yaml examples/go-checksum/main.go my-tasks/go-checksum/
ignitify task:validate go-checksum --dir my-tasks
ignitify task:create go-checksum --no-scaffold --dir my-tasks       # once: registers the slug (reserved forever)
ignitify task:deploy go-checksum --dir my-tasks
ignitify task:run go-checksum --dir my-tasks --payload '{"text":"hello"}' --wait
```

The code uses only the standard library, so `go.sum` stays as the scaffold wrote it. After `go get <module>`, run `go mod tidy` and upload both files.

Expected result of the run above:

```json
{"bytes": 5, "sha256": "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"}
```
