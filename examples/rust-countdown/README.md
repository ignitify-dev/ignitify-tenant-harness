# rust-countdown

A Rust task that streams progress with `ctx.chunk()`. Rust tasks carry the Ignitify runtime client in an `ignitify/` folder, so this example holds only the files you write. Create the rest with the CLI:

```sh
ignitify task:create rust-countdown --lang rust --local --dir my-tasks   # writes src/main.rs, Cargo.toml, Cargo.lock, ignitify/
cp examples/rust-countdown/task.yaml my-tasks/rust-countdown/
cp examples/rust-countdown/src/main.rs my-tasks/rust-countdown/src/
ignitify task:validate rust-countdown --dir my-tasks
ignitify task:create rust-countdown --no-scaffold --dir my-tasks         # once: registers the slug (reserved forever)
ignitify task:deploy rust-countdown --dir my-tasks
ignitify task:run rust-countdown --dir my-tasks --payload '{"from":3}' --wait
```

The code uses only `serde_json`, which the scaffold's `Cargo.toml` and `Cargo.lock` already have. After `cargo add <crate>`, upload both files.

Expected result of the run above: `{"counted": 3}`, after about 3 seconds. The log shows `left: 3`, `left: 2`, `left: 1`. The last chunk, `{"left": 1}`, is in `progress` of `ignitify run:get <run-id> --full`.
