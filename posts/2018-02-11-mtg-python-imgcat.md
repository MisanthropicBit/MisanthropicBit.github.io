---
title: Search and Display Magic Cards via the Command Line
date: 2018-02-11
tags: command line, imgcat, python, mtg
versions: Python 3.4
---

I have a general tendency to google if someone has made a (usually Python)
package for various things and when I recently began playing [Magic: The
Gathering](https://magic.wizards.com/en) again with some friends, I could not
resist the urge to do so. It turns out that [someone
did](https://github.com/MagicTheGathering/mtg-sdk-python) make a package and in
fact there are [quite a few language
bindings](https://github.com/MagicTheGathering) available.

Coincidentally, I remembered one of the useful tools packaged with the iTerm v3
console application for Mac: [imgcat](https://iterm2.com/utilities/imgcat)
([docs](https://iterm2.com/documentation-images.html)). It works like `cat` but
for images as you can see below.

<div id="image-container">
![imgcat in action](https://iterm2.com/images/inline_image_sparky_demo.png)
</div>

It would be kinda cool if we could combine the two to search for a given card by
name from the command line and use `imgcat` to display it through the terminal.
The following Python script does exactly this in only 22 lines (excluding
comments and error-checking). Let us start with the standard Python header stuff
(shebang and [file encoding](https://www.python.org/dev/peps/pep-0263/)) and
import the necessary packages.

```{.python .numberLines startFrom="1"}
#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""Query a Magic: The Gathering card and show it via iTerm's imgcat script."""

import mtgsdk         # The Magic: The Gathering SDK
import os             # For expanding the userpath to the imgcat script
import subprocess     # For calling imgcat
import sys            # For getting the argument (card name) from the command line
import tempfile       # For creating a temporary, named image file
import urllib.request # For downloading the card's image
```

We are using Python 3's `urllib` here since `mtgsdk` targets python 3.4+. Next,
we need two functions: One for querying the database with the card name and one
for getting the image from the card's image url. 

```{.python .numberLines startFrom="1"}
def query_by_name(card_name):
    """Query the mtg database and return the first card with a url or None."""
    return next((card for card in mtgsdk.Card.where(name=card_name).iter()
                 if card.image_url), None)
```

We use the Card API's `iter` method instead of `all` to avoid downloading all
cards associated with the name at once. Combined with a generator expression for
filtering all the cards that do not have an associated url and the
[`next`](https://docs.python.org/3.4/library/functions.html#next) function we
can get the first card that has an image url. We use the optional second
argument of `next` to return `None` if there are either no cards with the given
name or if none of them had a url associated with them. Otherwise, `next` would
throw a
[`StopIteration`](https://docs.python.org/3.4/library/exceptions.html#StopIteration)
exception.

```{.python .numberLines startFrom="1"}
def get_card_image(image_url):
    """Return the image bytes from a given image url."""
    return urllib.request.urlopen(image_url).read()
```

Getting the image contents of the card is pretty straight-forward. We use
`urlopen` and read its entire contents.

```{.python .numberLines startFrom="1"}
if __name__ == '__main__':
    card = query_by_name(sys.argv[1])

    if card:
        if not card.image_url:
            sys.exit("Error: Card has no associated image url")

        with tempfile.NamedTemporaryFile() as ntf:
            ntf.write(get_card_image(card.image_url))
            subprocess.check_call([os.path.expanduser('~/imgcat.sh'),
                                   ntf.name])
    else:
        sys.exit("Error: Unable to find card '{0}'".format(sys.argv[1]))
```

First, we query the card name and ensure that both a card was found and one of
them had an image url associated with it.  Then we create a temorary, named file
(since we need to refer to it by name for the `imgcat` script), write the image
bytes to it and finally call the script using
[`subprocess.check_call`](https://docs.python.org/3.4/library/subprocess.html#subprocess.check_call).
Notice that we also use
[`os.path.expanduser`](https://docs.python.org/3.4/library/os.path.html?highlight=os.path.expanduser#os.path.expanduser)
to expand the tilde, since I have put the script in my home directory. This is
what it looks like in my terminal:

![_The script in action_](/images/screenshots/mtg_screenshot.png)

Notice that the script is devoid of error-checking. If you want a full-blown
command line interface for querying magic cards, check
[this](https://github.com/chigby/mtg) project out.
