HUGO ?= hugo
LYCHEE ?= lychee

.PHONY: run
run:
	$(HUGO) server

# Production build with the search index (search does not work under `hugo server`).
.PHONY: build
build:
	$(HUGO) build --gc --minify
	npx pagefind

# Internal links and anchors of the built site, as in CI.
.PHONY: check
check: build
	$(LYCHEE) --config lychee.toml --offline --root-dir "$(CURDIR)/public" \
		--remap '^https://wilsonwu\.me/(.*)$$ file://$(CURDIR)/public/$$1' './public/**/*.html'

# New posts: make new SLUG=2026/my-post (English), make new SLUG=2026/my-post IN=zh (Chinese).
IN ?= en
.PHONY: new
new:
	$(HUGO) new content content/$(IN)/blog/$(SLUG)

# Move PaperMod (a Hugo module) to its latest commit.
.PHONY: update
update:
	$(HUGO) mod get -u github.com/adityatelange/hugo-PaperMod
	$(HUGO) mod tidy
