Static site generator for [braindump.ing](https://braindump.ing) written in Zig 0.13.0, with no dependencies other than [Prism.js](https://prismjs.com/) for code highlighting, and [`httpz.zig`](https://github.com/karlseguin/http.zig) as a server for subscriptions and comments (which I plan to migrate off).

Pipeline: `/content` -> Zig parses Markdown in each file, generating a tree of elements -> Zig converts tree to HTML -> Zig outputs HTML for each post using template file `include/[slug].html` -> GitHub serves a static site with the output of `--build`, while no opts = spin up a server for comments and draft pages that require a password (TODO, which are left out when pushing to this public repo).

Parsing Markdown is a three step process: tokenize with `start` and `length` describing each token -> parse tokens, either placing into frontmatter or ast -> pass through a pipeline (e.g., autolink headings).

A custom React library based on [this](https://pomb.us/build-your-own-react/) with a few tweaks for fun is used for functionality of: the color picker and the subscribe form. At some point I want to write a fully functional clone of React from scratch to understand how it works.

GitHub action: runs `sass include/styles/globals.scss docs/styles/globals.css --no-source-map`, `cd include/scripts && npm run build`, and `./zig-out/bin/blog --build` before deploying to GitHub Pages.
