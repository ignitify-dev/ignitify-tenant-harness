# python-word-stats

A Python task with no network. It shows input checks (a raised error fails the run with its message), a metric and a JSON result.

```sh
ignitify task:create python-word-stats --no-scaffold --dir examples   # once: registers the slug (reserved forever)
ignitify task:validate python-word-stats --dir examples
ignitify task:deploy python-word-stats --dir examples
ignitify task:run python-word-stats --dir examples --payload '{"text":"a b a","top":1}' --wait
```
