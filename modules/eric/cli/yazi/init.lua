require("git"):setup()

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
