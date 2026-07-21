Could you please audit the tests and comments in the current staged changes?
For the tests:
- Are all the tests meaningful and useful?
- Are they likely to catch real bugs?
- Are any of the tests low value?
- Are the tests testing mocks or intermediate artifacts instead of real functionality that is easily testable?
  - For queries that run against the Hightouch app database, seed the test database, call the function, and assert the returned behavior instead of asserting generated SQL text.
    SQL-text assertions are acceptable only for SQL that executes on a customer warehouse, where running it in tests is not possible.
For the comments:
- Do the comments follow the repo comment guidelines?
- It's not just accuracy and redundancy, but you should ask for each comment: if this comment were removed, would a smart dev misunderstand the code? If not, we should consider removing the comment.
- Do any have brittle references to tangentially related code or ephemeral artifacts like implementation specs?
