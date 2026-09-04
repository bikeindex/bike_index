// highlight.js@11.11.1/lib/languages/json — the only grammar we register.
// Re-generate on version bump: curl -sL 'https://esm.sh/highlight.js@11.11.1/es2022/lib/languages/json.bundle.mjs' (prepend this header).
/* esm.sh - highlight.js@11.11.1/lib/languages/json */
function c(e){let a={className:"attr",begin:/"(\\.|[^\\"\r\n])*"(?=\s*:)/,relevance:1.01},t={match:/[{}[\],:]/,className:"punctuation",relevance:0},n=["true","false","null"],s={scope:"literal",beginKeywords:n.join(" ")};return{name:"JSON",aliases:["jsonc"],keywords:{literal:n},contains:[a,t,e.QUOTE_STRING_MODE,s,e.C_NUMBER_MODE,e.C_LINE_COMMENT_MODE,e.C_BLOCK_COMMENT_MODE],illegal:"\\S"}}export{c as default};
//# sourceMappingURL=json.bundle.mjs.map