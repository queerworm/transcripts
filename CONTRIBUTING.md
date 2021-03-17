Want to add a new show to the site? Read this page!

## Show Requirements

For the tools in this repository to work at all, there are two hard requirements:

1. The show has a Netflix ID and `api.netflix.com` responds to it with an
episode list.

2. It uses Netflix's standard XML-based subtitle format.

If you're able to watch the show in question on Netflix, both of these should
be true (I've yet to encounter a case where it wasn't).

I also have a few additional requirements for adding shows to this site in
particular.

1. It must be currently available on Netflix in the United States, without a
departure already announced. 

2. Its primary language must be English.

3. Non-scripted shows will generally be avoided. I'm willing to make
exceptions, but ask in an issue before creating a pull request.

These extra requirements are to keep the site and repo from being cluttered,
but shows that don't meet these requirements should still work with the tools
in this repo, so you can always create a separate site for shows in another
language or not on US Netflix.

## Software Requirements

To use the site builder and show importer tools, you'll need the latest version
of the [Dart SDK][] installed on your computer. Dart supports Windows, Mac, and
Linux, but I've only tested on Linux myself. Mac OS is similar enough that
everything should work there too, but you're likely to run into issues on
Windows. If you do, you install [WSL] to get a proper Unix environment.

[Dart SDK]: https://dart.dev/get-dart
[WSL]: https://docs.microsoft.com/en-us/windows/wsl/install-win10

You'll also want Chrome or another Chromium-based browser to get the URLs for
each episode's subtitles.

## The `transcripts` Executable

All of the tools in this repo are part of a single Dart executable. You can run
it with:

```shell
dart run transcripts
```

When you run this, you should get a help message with a list of commands that
you can run.

## Generating `manifest.json`

Each show gets one directory inside `srt`. The name of this directory
determines the path the show lives at in the built website, but it doesn't say
anything about the show itself.

For that, each show directory has a file called `manifest.json` that contains
its title, Netflix ID, and a list of episodes (each with its own name and
Netflix ID).

To generate this for a show, we need two things: the show's Netflix ID and its
episode numbers.

To find a Netflix ID, search for the show on Netflix's website and then click
on "Episodes and info". In the URL bar, the page address should now end with
`jbv=` followed by some number. That number is the show's ID.

Now you need to pass that ID, along with a small script that indicates episode
numbers to the `manifest` command.

For example, this command:

```shell
dart run transcripts manifest 80221553 ':10x3'
```

generates a `manifest.json` for Kipo and the Age of Wonderbeasts, which has
three seasons with 10 episodes each.

The last argument here is a space separated list of episode number expressions.
In its simplest form, you could just list all of the episode numbers in order,
e.g.

```
101 102 103 104 105 106 107 108 109 201 202...
```

but that would be tedious, so there are some shorthands you can use instead. A
colon followed by a number expands into a season with that number of episodes,
starting from 1. The colon syntax always starts from episode 1 of the next
season after the last episode number prior to it.


This command:

```shell
dart run transcripts manifest 80027563 ':12 :14 :13 :13'
```

generates a `manifest.json` for The Legend of Korra, which had 12 episodes in
season 1, 14 in season 2, and 13 each in its final two seasons.

If you put a lowercase `x` followed by a number after a colon expression, it
means to repeat that for that number of seasons. This means the `:10x3` we used
for Kipo is equivalent to `:10 :10 :10`.

This all works great for shows whose episode numbers are always consecutive,
but sometimes Netflix combines multi-part episodes into a single listing. For
this site, we like to number multi-part transcripts with the number of their
first part and then skip the numbers for the other parts. For example, the DS9
episode "The Visitor" is considered 403, since "The Way of the Warrior"
(numbered 401) is feature-length and counts as two episodes.

To allow for shorthand when some episode numbers are skipped, if you separate
two numbers with `...`, it expands to all of the numbers between them
(inclusive). For example, `103...106` expands to `103 104 105 106`.

Putting all these pieces together, DS9's manifest could be generated with:

```shell
dart run transcripts manifest 70158330 '101 103...120 :26x2 401 403...426 :26x2 :2'
```

Once you have your show's Netflix ID and an expression listing its episode
numbers, run the manifest tool. You don't need to save the output. The final
tool we run will do this automatically. Instead, double check that the episodes
line up. The tool will crash if the number of episodes on Netflix differs from
the number in your expression, but even if the numbers are the same, you should
check that episode titles are matched to numbers properly (especially if your
expression was fairly complex).

Once you've confirmed that, it's time to actually find the subtitles.

## Finding URLs for Netflix Subtitles

Most of the process for importing a show is fairly automated, but this part has
some inherent tediousness, since there's no way to get the subtitles for an
episode on Netflix without actually loading it. To get all the subtitles for a
show, you'll need to do the following:

1. Open Netflix in Google Chrome. If you haven't already done so, you'll want
to go to Playback Settings for your profile and make sure both autoplay options
are disabled (to prevent Netflix from loading extra subtitles that could
confuse the tools).

2. Open the info page for the show you want to rip subtitles for and get ready
to begin playing the first episode (but don't click it yet). 2. Open Chrome
DevTools (Chrome menu > More tools > Developer tools) and click on the
"Network" tab.

3. In the "Filter" search box in the network tab, enter `/?o=` which will
filter the list of requests to only show the subtitle files. Click on the clear
button (the circle with the slash through it that's immediately above the
"Filter" box) to get rid of any previously loaded requests.

4. Begin playing the first episode. You should see a single request show up in
the Network panel. If you want, you can click on it and look at the "Response"
tab to see the subtitles in Netflix's XML format (but you don't have to).

5. You can now click the next episode button. Another single item should appear
in the log. Repeat for each episode, waiting for a single new item to appear in
the filtered log before continuing to the next one (the subtitles should
generally load before the video does).

6. For shows with a relatively low episode count, you can probably do the whole
show in one batch. For longer shows, consider stopping every 50 episodes or so.

7. Once you see one item in the log for each episode, you should right click on
one of them and select "Copy > Copy all as cURL" and paste the results into a
text file (make sure to save!).

> Note: On Windows, there will be two "Copy all as cURL" options.
> Select the one marked "bash" in that case (not "cmd").

8. If you copied them all in a single batch, continue to step 9. If you have
more batches to go, go back to DevTools, click the clear button again and then
repeat steps 5-7 for your next batch of episodes. Continue until you've pasted
the requests for all episodes into a single file.

9. Our filter kept unrelated requests from being disabled in DevTools, but
unfortunately, the Copy option copies *all* requests, not just the filtered
ones. We need to do that now and get just the URLs for our subtitles. Run the
following, substituting `curl.txt` with the file you pasted the cURLs into.

```shell
dart run transcripts filter -i curl.txt -o urls.txt
```

10. Open `urls.txt` and confirm that the number of URLs (one per line) is equal
to the number of episodes. Once you've confirmed that, you can move on to
actually importing the show. Those URLs will expire after sometime in the next
day or so, so don't wait too long.

## Importing the Show

This part is much less involved. You just combine the pieces you gathered in
the previous parts. The import tool takes the following arguments:

```shell
dart run transcripts import --show <Netflix ID> --path <show path> --episodes '<episode numbers>' --urls urls.txt
```

`--show` and `--episodes` are the Netflix ID and episode numbers you passed to
the `manifest` command in the first part. `--urls` is the file with one
subtitle URL per line that you generated in the previous part. You could
instead pass `--curl` with the longer file you pasted in, but it's better to
separate this to make sure the number of URLs actually matches the number of
episodes. `--path` is the path to actually store all of a show's files in. This
should generally be `srt/abbr`, where `abbr` is an abbreviation of the show's
name (like `ds9` or `kipo`).

This command will make the new folder in `srt`, generate and save the
`manifest.json`, download all the subtitle XML files from Netflix, and convert
them into the SRT format used by the website builder. If you'd like to save the
XML files alongside the SRT files to inspect them manually, you can optionally
pass the `--save-xml` flag. They aren't used by the website builder though, so
you should delete them before committing your changes.

## Building the Website

```shell
dart run transcripts build
```

will convert the manifests and SRT files into a bunch of HTML files and put
them in the `build` folder.

You can incrementally build just a single show by passing the name of its
directory as an extra argument.

If you want to host the site locally for debugging, run:

```
dart run transcripts serve
```

This won't watch for changes though, so you'll need to re-run `build` yourself
after you make changes.

## Preparing a Pull Request

Instructions coming soon.