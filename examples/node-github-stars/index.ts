// Read the public star count of one GitHub repository.
// Payload: { "repo": "owner/name" }. Result: { repo, stars, open_issues }.
// Network: outbound to api.github.com only (egress_allow in task.yaml).

type Payload = { repo?: unknown };
type Ctx = { metric(name: string, value: number): void };

const REPO_PATTERN = /^[\w.-]+\/[\w.-]+$/;

export async function run(payload: Payload, ctx: Ctx) {
  const repo = typeof payload.repo === "string" ? payload.repo : "";
  if (!REPO_PATTERN.test(repo)) {
    // A thrown error fails the run; its message is the run error.
    throw new Error(`payload.repo must look like "owner/name", got ${JSON.stringify(payload.repo)}`);
  }
  const url = `https://api.github.com/repos/${repo}`;
  let res: Response;
  try {
    res = await fetch(url, {
      headers: { accept: "application/vnd.github+json", "user-agent": "ignitify-example" },
      signal: AbortSignal.timeout(20_000),
    });
  } catch (err) {
    // fetch() says only "fetch failed"; the network reason (ECONNRESET, EAI_AGAIN, ...) is in err.cause.
    const cause = (err as { cause?: { code?: string; message?: string } }).cause;
    throw new Error(`fetch ${url} failed: ${cause?.code ?? cause?.message ?? String(err)}`);
  }
  if (!res.ok) throw new Error(`GitHub answered ${res.status} for ${repo}`);
  const body = (await res.json()) as { stargazers_count: number; open_issues_count: number };
  ctx.metric("github_calls", 1);
  console.log(JSON.stringify({ repo, status: res.status }));
  return { repo, stars: body.stargazers_count, open_issues: body.open_issues_count };
}
