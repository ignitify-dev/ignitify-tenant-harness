# Count the words of a text and return the most common ones.
# Payload: {"text": "...", "top": 3}. Result: {"words": N, "unique": N, "top": [[word, count], ...]}.
# Network: none. Standard library only, so requirements.txt has no lines.
import re
from collections import Counter

WORD = re.compile(r"[a-z0-9']+")
MAX_TOP = 50


def stats(text, top):
    words = WORD.findall(text.lower())
    return {
        "words": len(words),
        "unique": len(set(words)),
        "top": Counter(words).most_common(top),
    }


def run(payload, ctx):
    text = payload.get("text")
    if not isinstance(text, str):
        raise ValueError("payload.text must be a string")
    top = payload.get("top", 5)
    if not isinstance(top, int) or not 1 <= top <= MAX_TOP:
        raise ValueError(f"payload.top must be an integer from 1 to {MAX_TOP}")
    result = stats(text, top)
    ctx.metric("words", result["words"])
    print(f"counted {result['words']} words")
    return result
