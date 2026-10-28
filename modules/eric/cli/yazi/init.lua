local git = require("git")
git:setup()

-- the git plugin's status codes, see its main.lua
local git_status = {
    [1] = "updated",
    [2] = "deleted",
    [3] = "added",
    [4] = "staged",
    [5] = "unstaged",
    [6] = "untracked",
    [7] = "ignored",
}

-- color names by git status, except on the current row's blue bar
-- Entity:style would also color the row's padding and linemode
local entity_highlights = Entity.highlights
function Entity:highlights()
    local line = ui.Line({ entity_highlights(self) })
    if self._file.is_hovered and self._file.in_current then
        return line
    end
    local url = self._file.url
    local repo = git.dirs[tostring(url.base or url.parent)]
    -- 99 marks a directory git ignores
    local code = repo == 99 and 7 or repo and git.repos[repo] and git.repos[repo][tostring(url):sub(#repo + 2)]
    local name = git_status[code]
    if not name then
        return line
    end
    return line:style(th.git[name])
end

-- fixed column widths, leaving any extra space empty on the right
function Tab:layout()
    self._chunks = ui.Layout()
        :direction(ui.Layout.HORIZONTAL)
        :constraints({
            ui.Constraint.Length(30),
            ui.Constraint.Length(40),
            ui.Constraint.Length(80),
            ui.Constraint.Fill(1),
        })
        :split(self._area)
end

-- keep icon colors on hovered rows, except on the current row's blue bar
function Entity:icon()
    local icon = th.icon:match(self._file, { hovered = self._file.is_hovered })
    if not icon then
        return ""
    elseif self._file.is_hovered and self._file.in_current then
        return icon.text .. " "
    else
        return ui.Span(icon.text .. " "):style(icon.style)
    end
end
