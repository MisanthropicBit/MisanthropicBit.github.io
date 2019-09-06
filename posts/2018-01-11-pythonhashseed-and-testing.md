---
title: Testing and PYTHONHASHSEED
date: 2018-01-11
tags: python, pytest, testing
---

This subject has been [covered
before](http://echorand.me/pythonhashseed-and-your-tests.html) (and probably in
many other places) but since it is extremely important to remember when testing
Python code, I feel like it bears repeating.

I was recently testing a lexer class in [one of my Python
projects](https://github.com/MisanthropicBit/bibpy). I was running my tests with
[`pytest`](https://docs.pytest.org/en/latest/) and
[`tox`](https://tox.readthedocs.io/en/latest/), testing Python versions 2.7,
3.3, 3.4, 3.5 and 3.6 and my lexer tests would randomly fail or pass.
Interestingly, it was one specific test that seemed to fail haphazardly, almost
as if the lexer was undeterministic. Here is a stripped-down version of the
test:

```{.python .numberLines}
def test_lex_with_comments():
   string = <something to lex containing comments>

   assert token_types(Lexer().lex(string)) == [...expected token types...]
```

The test lexes a test string and checks that the lexed token types correspdong
to what we expect. When the test failed, it would have lexed a `name` token
instead of a `number` token for something that was *clearly* a number. I started
searching for some randomness in my code which I might have accidentally
introduced during some testing but found nothing. Stumped, I continued to work
on other parts of the project coming back to this peculiar test once in a while.

After about a week, I was reminded of `PYTHONHASHSEED` which is printed out to
the console by `tox` before each set of tests are run for a specific Python
version.

```bash
   py27 installed: asn1crypto==0.23.0,bibpy==0.1.0a0,certifi==2017.11.5,cffi==1.11.2,chardet==3.0.4,coverage==4.4.2,coveralls==1.2.0,cram==0.7,cryptography==2.1.3,docopt==0.6.2,enum34==1.1.6,funcparserlib==0.3.6,idna==2.6,ipaddress==1.0.18,pep257==0.7.0,py==1.5.2,pycparser==2.18,pyOpenSSL==17.4.0,pyparsing==2.2.0,pytest==3.2.5,pytest-quickcheck==0.8.3,PyYAML==3.12,requests==2.18.4,six==1.11.0,urllib3==1.22
   py27 runtests: PYTHONHASHSEED='3752821799'
   py27 runtests: commands[0] | pytest tests/
   =========================================================================================== test session starts ============================================================================================
   platform darwin -- Python 2.7.14, pytest-3.2.5, py-1.5.2, pluggy-0.4.0
   ...
```

[`PYTHONHASHSEED`](https://docs.python.org/3.3/using/cmdline.html#envvar-PYTHONHASHSEED)
is a security measure introduced in Python 3.2.3, put in place to make it harder
to gauge information about a program by seeding the hashes of `str`, `bytes`
(Python 3+) and `datetime`. I copied the numbers for a passed and failed test
run and manually ran the tests again with each of these numbers.

```bash
   PYTHONHASHSEED=<passing_number> pytest tests
   PYTHONHASHSEED=<failing_number> pytest tests
```

The passing tests continued to pass while the failing continued to failed and my
frustration was supplanted with excitement! As it turns out, part of this
randomness affects the order in which dictionary elements are iterated so that a
malicious attacker cannot rely on a deterministic iteration across multiple
runs.

My lexer class stored a dictionary of regular expressions for each token and
iterated across them in the main lexer method to match tokens in the stream. A
different order would not be a problem, **as long as no regex could match more
than one token type**. This was exactly the problem because my regular
expressions for the `name` and `number` tokens looked like this.

```python
   'number' => '-?(0|([1-9][0-9]*))'
   'name'   => r"\s*[\w\-:?'\.]+\s*"
```

The `name` token could match the `number` token as the special sequence
[`\w`](https://docs.python.org/3.4/howto/regex.html) denotes `[a-zA-Z0-9_]`, but
which pattern would ultimately be attempted first depended on the value of
`PYTHONHASHSEED`.

My fix involved storing the keys (token names) in a separate, auxiliary list
that would ensure that the patterns would be attempted in their original order.
Alternatively, I could have used the
[`collections.OrderedDict`](https://docs.python.org/2/library/collections.html#collections.OrderedDict),
but since the lexing method was on the profiling hotpath, I decided against this
in favor of the speed of `dict` by sacrificing a small amount of memory (as an
addendum, `collections.OrderedDict` is now [implemented in
`C`](https://docs.python.org/3/whatsnew/3.5.html#whatsnew-ordereddict) in Python
3.5 and onwards).
