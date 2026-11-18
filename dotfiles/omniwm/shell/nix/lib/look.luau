-- Default's skin with a notification badge that stays a centred circle for a
-- single character instead of a pill narrower than it is tall. Badge text is
-- monospace, so its width follows the character count.
local MONO_ADVANCE = 0.6
-- White text for the native system-red `badge` role (left unset in the Stylix
-- palette), matching the default skin's badge text. No palette role is white.
local BADGE_TEXT = "#FFFFFFFF"

return require("../lib/skin")({
    capsules = true,
    notificationBadge = function(item, mode, m)
        local dx = math.max(0, m.margin - 4)
        local dy = m.margin - math.max(2, m.icon * 0.12)
        if mode == "dot" then
            local size = math.max(6, m.icon * 0.35)
            return ui.box{ align = "topLeading", dx = dx, dy = dy, w = size, h = size, radius = size / 2, fill = "badge" }
        end
        local fit = math.min(1, m.scale)
        local height = math.max(12 * fit, m.icon * 0.55)
        local size = math.max(10 * fit, m.icon * 0.35)
        local chars = utf8.len(item.badge) or #item.badge
        local width = math.min(m.slot, math.max(height, chars * size * MONO_ADVANCE + height * 0.5))
        return ui.stack{ align = "topLeading", dx = dx, dy = dy, w = width, h = height, radius = height / 2,
            fill = "badge", center = true,
            ui.text{ text = item.badge, style = "mono", size = size, weight = "semibold", color = BADGE_TEXT,
                maxWidth = width - 2 } }
    end,
})
