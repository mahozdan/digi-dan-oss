## How to create external api docs

- [ ] You need to crawl the destination web api documentation pages or review all documentation files
    - [ ] If it's on the web make sure to use an mcp and to click all available ui components to find all data! DO NOT TRUST ANYTHING OTHER THEN THE GUI
    - [ ] Keep in mind examples and notes that are relevant to your project's tech stack
- [ ] Generate short and concise api docs named in this format: <vendor>.<api>.<segment>.md (e.g. google.drive-api.sheets.md)
- [ ] Make sure the doc includes all headers, parameters, http statuses, verbs and endpoint, notes and code examples
- [ ] If you find conflicts assume the examples are correct
- [ ] Create all doc files in ./docs/apis/<files>