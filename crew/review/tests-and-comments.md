Could you please audit the tests and comments in the current staged changes?
For the tests:
- Are all the tests meaningful and useful?
- Are they likely to catch real bugs?
- Are any of the tests low value?
- Are the tests testing mocks or intermediate artifacts instead of real functionality that is easily testable?
  - For SQL that runs against a database the project controls, connect to a seeded test database and assert returned behavior instead of asserting SQL text or mocking the query layer.
    Assert SQL text only when it executes against an external system that tests cannot run it on.
  - Do not assert the presence of specific phrases in prompts, skill descriptions, instructions, or their conditionals; this text is highly readable and product-driven, so phrase-presence tests create churn without value.
  - Do not test obvious, easily readable declarative logic such as static registration or wiring lists.
- If the tests are significantly more code than the code under test, is their maintenance cost likely to outweigh their developer-experience benefit?
  - Since most code is naturally written correctly, focus on a small happy path plus edge cases likely to be accidentally broken instead of verifying every output detail.
For the comments:
- Do the comments follow the repo comment guidelines?
- It's not just accuracy and redundancy, but you should ask for each comment: if this comment were removed, would a smart dev misunderstand the code? If not, we should consider removing the comment.
- Do any have brittle references to tangentially related code or ephemeral artifacts like implementation specs?
