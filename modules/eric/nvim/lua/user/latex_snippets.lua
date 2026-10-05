local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local fmta = require("luasnip.extras.fmt").fmta
local line_begin = require("luasnip.extras.conditions.expand").line_begin

-- math detection via vim syntax, matching vimtex's imaps
local function in_math()
    return vim.fn["vimtex#syntax#in_mathzone"]() == 1
end

local function in_comment()
    return vim.fn["vimtex#syntax#in_comment"]() == 1
end

-- prose: outside math and outside comments
local function in_text()
    return not in_math() and not in_comment()
end

-- false when the trigger finishes a \command name, so \lim, \hbar, \succ stay intact
local function not_in_cmd(line, matched)
    return not line:sub(1, #line - #matched):match("\\%a*$")
end

local function in_math_not_cmd(line, matched)
    return in_math() and not_in_cmd(line, matched)
end

-- math autosnippet
local function ma(trig, nodes)
    return s({ trig = trig, snippetType = "autosnippet", condition = in_math_not_cmd, wordTrig = false }, nodes)
end

-- math autosnippet with a lua-pattern trigger
-- unguarded on purpose: \alpha2 must still become \alpha_2
local function mr(trig, nodes)
    return s(
        { trig = trig, snippetType = "autosnippet", condition = in_math, wordTrig = false, trigEngine = "pattern" },
        nodes
    )
end

-- pattern autosnippet that must not fire inside a \command
local function mrc(trig, nodes)
    return s({
        trig = trig,
        snippetType = "autosnippet",
        condition = in_math_not_cmd,
        wordTrig = false,
        trigEngine = "pattern",
    }, nodes)
end

-- text autosnippet, word-boundary guarded so it can't fire inside a word
local function tx(trig, nodes)
    return s({ trig = trig, snippetType = "autosnippet", condition = in_text, wordTrig = true }, nodes)
end

-- nth capture of a pattern trigger
local function cap(n)
    return f(function(_, snip)
        return snip.captures[n]
    end)
end

ls.add_snippets("tex", {
    -- fractions
    ma("//", { t("\\frac{"), i(1), t("}{"), i(2), t("}"), i(0) }),
    mr("([%w\\^_]+)/", { t("\\frac{"), cap(1), t("}{"), i(1), t("}"), i(0) }),

    -- delimiters
    ma("lrp", fmta("\\left( <> \\right) <>", { i(1), i(0) })),
    ma("lrb", fmta("\\left[ <> \\right] <>", { i(1), i(0) })),
    ma("lrc", fmta("\\left\\{ <> \\right\\} <>", { i(1), i(0) })),

    -- sub / superscripts
    mr("([%a])(%d)", { cap(1), t("_"), cap(2) }),
    mr("([%a])_(%d%d)", { cap(1), t("_{"), cap(2), t("}") }),
    ma("sr", { t("^2") }),
    ma("cb", { t("^3") }),
    ma("compl", { t("^{c}") }),
    ma("td", { t("^{"), i(1), t("}"), i(0) }),

    -- postfix decorations
    mrc("([%a])bar", { t("\\overline{"), cap(1), t("}") }),
    mrc("([%a])hat", { t("\\hat{"), cap(1), t("}") }),
    mr("([%a]),%.", { t("\\vec{"), cap(1), t("}") }),
    mr("([%a])%.,", { t("\\vec{"), cap(1), t("}") }),

    -- symbols
    ma("->", { t("\\to") }),
    ma("!>", { t("\\mapsto") }),
    ma("=>", { t("\\implies") }),
    ma("cc", { t("\\subset") }),
    ma("ooo", { t("\\infty") }),
    ma("lim", { t("\\lim_{"), i(1, "n"), t(" \\to "), i(2, "\\infty"), t("} "), i(0) }),
    ma("sum", { t("\\sum_{"), i(1, "n=1"), t("}^{"), i(2, "\\infty"), t("} "), i(0) }),
    ma("fun", fmta("<> : <> \\to <>", { i(1, "f"), i(2, "\\R"), i(3, "\\R") })),

    -- text mode: open math / an environment, so they cannot be math-gated
    tx("mk", { t("$"), i(1), t("$"), i(0) }),
    tx("dm", { t({ "\\[", "" }), i(1), t({ "", "\\] " }), i(0) }),
    s({
        trig = "beg",
        snippetType = "autosnippet",
        wordTrig = true,
        condition = function(line, trig, captures)
            return in_text() and line_begin(line, trig, captures)
        end,
    }, {
        t("\\begin{"),
        i(1),
        t({ "}", "" }),
        i(2),
        t({ "", "\\end{" }),
        f(function(a)
            return a[1][1]
        end, { 1 }),
        t("}"),
        i(0),
    }),
})
