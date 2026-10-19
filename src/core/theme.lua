-- DepHub UI theme.
--
-- Design tokens ported from the authored interface mockup (dephub.css). Every
-- colour and metric here is a direct translation of a CSS custom property or a
-- hard-coded surface value, so the in-game panel reads the same as the preview.
--
-- Colours are expressed as {r, g, b} in 0..255. Helpers convert them to the
-- Roblox types the panel needs. Keep this file free of engine side effects so it
-- can also be read by tests.

local Theme = {}

local function rgb(r, g, b)
    return {r = r, g = g, b = b}
end

-- :root tokens
Theme.Accent = rgb(188, 188, 188)        -- --accent: #bcbcbc
Theme.Bg = rgb(9, 9, 9)                  -- --bg: #090909
Theme.Surface = rgb(16, 16, 16)          -- --surface: #101010
Theme.Line = rgb(37, 37, 37)             -- --line: #252525
Theme.Text = rgb(222, 222, 222)          -- --text: #dedede
Theme.Muted = rgb(154, 154, 154)         -- --muted: #9a9a9a
Theme.Quiet = rgb(119, 119, 119)         -- --quiet: #777

-- Panel geometry (--width/--height with the same clamps as the mockup)
Theme.PanelWidth = 840
Theme.PanelHeight = 560
Theme.PanelRadius = 12
Theme.PanelBorder = rgb(44, 44, 44)      -- border: 1px solid #2c2c2c
Theme.HeaderHeight = 100                 -- --header: 100px
Theme.FooterHeight = 40                  -- --footer: 40px
Theme.SidebarWidth = 160                 -- grid-template-columns: 160px ...

-- Header / brand
Theme.BrandAccent = rgb(209, 209, 209)   -- .header-mark background #d1d1d1
Theme.BrandInk = rgb(23, 23, 23)         -- .header-mark color #171717
Theme.LeftPad = 24                       -- --left: 24px
Theme.BrandTop = 20                      -- --brand-top: 20px

-- Window buttons (macOS traffic lights)
Theme.CloseButton = rgb(255, 96, 88)     -- #ff6058
Theme.MinButton = rgb(254, 188, 46)      -- #febc2e
Theme.MaxButton = rgb(40, 200, 64)       -- #28c840

-- Navigation
Theme.NavBorder = rgb(28, 28, 28)        -- border-right: 1px solid #1c1c1c
Theme.NavIdle = rgb(146, 146, 146)       -- nav button color #929292
Theme.NavActiveBg = rgb(26, 26, 26)      -- nav button.active background #1a1a1a
Theme.NavActiveText = rgb(227, 227, 227) -- nav button.active color #e3e3e3
Theme.NavHoverBg = rgb(22, 22, 22)       -- nav button:hover #161616

-- Main content
Theme.MainBg = rgb(12, 12, 12)           -- main background #0c0c0c
Theme.RowBg = rgb(17, 17, 17)            -- .row background #111
Theme.RowHoverBg = rgb(22, 22, 22)       -- .row:hover #161616
Theme.SectionLabel = rgb(153, 153, 153)  -- .section-label #999
Theme.Heading = rgb(222, 222, 222)       -- h1 inherits --text
Theme.HelpText = rgb(146, 146, 146)      -- .help #929292

-- Controls
Theme.FieldBg = rgb(17, 17, 17)          -- .field background #111
Theme.FieldBorder = rgb(51, 51, 51)      -- .field border #333
Theme.FieldFocusBg = rgb(22, 22, 22)     -- .field:focus #161616
Theme.ToggleOff = rgb(48, 48, 48)        -- .toggle background #303030
Theme.ToggleOffBorder = rgb(68, 68, 68)  -- .toggle border #444
Theme.ToggleKnobOff = rgb(148, 148, 148) -- .toggle::after background #949494
Theme.ToggleKnobOn = rgb(34, 34, 34)     -- .toggle:checked::after #222
Theme.ActionBg = rgb(29, 29, 29)         -- .action background #1d1d1d
Theme.ActionBorder = rgb(58, 58, 58)     -- .action border #3a3a3a
Theme.ActionHoverBg = rgb(39, 39, 39)    -- .action:hover #272727
Theme.ActionHoverBorder = rgb(90, 90, 90)-- .action:hover border #5a5a5a
Theme.PrimaryBg = rgb(204, 204, 204)     -- .primary background #ccc
Theme.PrimaryInk = rgb(22, 22, 22)       -- .primary color #161616

-- Footer
Theme.FooterBorder = rgb(34, 34, 34)     -- border-top: 1px solid #222
Theme.FooterText = rgb(139, 139, 139)    -- footer color #8b8b8b

-- Feedback
Theme.ToastBg = rgb(21, 21, 21)          -- .toast background #151515
Theme.ToastBorder = rgb(58, 58, 58)      -- .toast border #3a3a3a
Theme.ToastError = rgb(121, 80, 80)      -- .toast.error border #795050
Theme.ModalBg = rgb(18, 18, 18)          -- dialog background #121212
Theme.ModalBorder = rgb(66, 66, 66)      -- dialog border #424242
Theme.NoticeBg = rgb(17, 17, 17)         -- .notice background #111

-- Motion (ms). The mockup reduces these under prefers-reduced-motion; the panel
-- exposes Theme.Reduced so callers can honour the same intent.
Theme.Reduced = false
Theme.Duration = {
    Fast = 0.18,
    Window = 0.30,
    Enter = 0.23,
    Tab = 0.22,
    Toast = 0.30,
    Modal = 0.25,
}

-- Convert a {r,g,b} token to Color3. Kept local-free so it works whether or not
-- Color3 is present at load time.
function Theme.Color(token)
    if token == nil then return Color3.fromRGB(255, 255, 255) end
    return Color3.fromRGB(token.r, token.g, token.b)
end

-- Blend toward black by factor (0 keeps colour, 1 gives black).
function Theme.Darken(token, factor)
    local f = 1 - math.clamp(factor or 0, 0, 1)
    return Color3.fromRGB(
        math.floor(token.r * f),
        math.floor(token.g * f),
        math.floor(token.b * f)
    )
end

-- UDim2 helpers used repeatedly by the panel layout.
function Theme.px(n)
    return UDim2.fromOffset(n, n)
end

return Theme
