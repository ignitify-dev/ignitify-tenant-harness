# node-github-stars

A Node task that reads the star count of a public GitHub repository. It shows outbound network with an allow list, input checks (a thrown error fails the run with its message), a metric and a JSON result.

```sh
ignitify task:create node-github-stars --no-scaffold --dir examples   # once: registers the slug (reserved forever)
ignitify task:validate node-github-stars --dir examples
ignitify task:deploy node-github-stars --dir examples
ignitify task:run node-github-stars --dir examples --payload '{"repo":"nodejs/node"}' --wait
```

For real work, pick your own slug: rename the folder and `slug` together.

Try a host that is not allowed: change the URL in `index.ts` to another host. The task sees `ECONNRESET`.

Expected result: `{"repo": "nodejs/node", "stars": <number>, "open_issues": <number>}`. If the run fails with `fetch https://api.github.com/... failed: <code>`, the code names the network reason: `ECONNRESET` means the host is not allowed, `EAI_AGAIN` or `ENOTFOUND` means the name did not resolve.
