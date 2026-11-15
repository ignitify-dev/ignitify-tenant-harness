// Count down from N, one step per second, and send each step as a progress chunk.
// Payload: {"from": N} with 1 <= N <= 30. Result: {"counted": N}.
// Network: none. Needs `interaction: continuous` in task.yaml for the chunks to reach the caller.
use serde_json::{json, Value};
use std::{thread, time::Duration};

const MAX_FROM: u64 = 30;

fn main() {
    ignitify_runtime::start(
        || Ok(()),
        |payload: Value, ctx| {
            let from = payload["from"].as_u64().ok_or("payload.from must be a whole number")?;
            if from == 0 || from > MAX_FROM {
                // A returned error fails the run; its text is the run error.
                return Err(format!("payload.from must be from 1 to {MAX_FROM}").into());
            }
            for left in (1..=from).rev() {
                ctx.chunk(&json!({ "left": left }));
                eprintln!("left: {left}");
                thread::sleep(Duration::from_secs(1));
            }
            Ok(json!({ "counted": from }))
        },
    )
}
