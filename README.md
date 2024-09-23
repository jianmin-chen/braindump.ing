Static site generator for [braindump.ing](https://braindump.ing) written in Zig, with no dependencies (other than the standard lib) for generation and [Prism.js]() for code highlighting.

Pipeline: `/content` -> Zig parses Markdown in each file, generating a tree of elements -> Zig converts tree to HTML -> Zig outputs HTML for each post using template file `include/[slug].html` -> GitHub serves a static site with the output of `--build`, while no opts = spin up a server for comments and draft pages that require a password (which are left out when pushing to this public repo).

Parsing Markdown is a two step process: tokenize with `start` and `length` describing each token -> parse tokens, either placing into frontmatter or

Extra operations on tree before converting to HTML: assign unique IDs to headings

Converting tree to HTML:

A custom React library based on [this](https://pomb.us/build-your-own-react/) for fun is used for functionality of: the color picker; the comment form; the subscribe form; and the draft page.

GitHub action: runs `sass include/styles/globals.scss out/styles/globals.scss --no-source-map`.
