How you should format your comments:
- as concise as possible, these are all small recommendations. The dev understands the context, just give them the recommendation and the very short rationale for it. A few words is fine if it's clear in a few words
- every comment should be formatted with

```
nit:
> your text in a quote like this to make it clear that you are writing them, not me
```

- "nit" is for all lower priority comments, like style, almost all test and comment change recommendations, or things we don't care if the reviewer skips even looking at. Everything else, from small refactors to critical findings, does not need to labeled "nit" and should just have your quote comment.
- you should slightly soften your recommendations as review comments are always requests, not commands. For example instead of "something something -- drop" you should instead say "something something -- recommend dropping"