-- DepHub UI theme.
--
-- Exact translation of the design tokens and component metrics from the
-- authored mockup (dephub.css). Every value here is copied from the stylesheet
-- so the in-game panel matches the preview pixel for pixel: the same palette,
-- the same box model, the same radii and the same control dimensions.
--
-- Colours use {r,g,b} in 0..255 and are converted with Theme.Color at build
-- time. Sizes are plain numbers (pixels). Timing values are seconds, matching
-- the CSS transition durations.
--
-- Kept free of engine side effects so tests and the bundler can read it.

local Theme = {}

local function rgb(r, g, b) return {r = r, g = g, b = b} end

-- :root custom properties
Theme.Accent = rgb(188, 188, 188)          -- --accent: #bcbcbc
Theme.Bg = rgb(9, 9, 9)                    -- --bg: #090909
Theme.Surface = rgb(16, 16, 16)            -- --surface: #101010
Theme.Line = rgb(37, 37, 37)               -- --line: #252525
Theme.Text = rgb(222, 222, 222)            -- --text: #dedede
Theme.Muted = rgb(154, 154, 154)           -- --muted: #9a9a9a
Theme.Quiet = rgb(119, 119, 119)           -- --quiet: #777

Theme.Left = 24                            -- --left: 24px
Theme.BrandTop = 20                        -- --brand-top: 20px
Theme.Header = 100                         -- --header: 100px
Theme.Footer = 40                          -- --footer: 40px

-- Window (--width/--height with the same clamps)
Theme.MinWidth = 840
Theme.MinHeight = 560
Theme.WindowRadius = 12
Theme.WindowBorder = rgb(44, 44, 44)       -- border: 1px solid #2c2c2c
Theme.WindowBg = rgb(0, 0, 0)              -- body background #000

-- Page background (#000) and the panel shell (#090909) differ; the shell is the
-- .rectangle, the page is behind it.

-- Header
Theme.HeaderBorder = rgb(37, 37, 37)       -- border-bottom: 1px solid var(--line)
Theme.MarkBg = rgb(209, 209, 209)          -- .header-mark background #d1d1d1
Theme.MarkInk = rgb(23, 23, 23)            -- .header-mark color #171717
Theme.MarkSize = 30                        -- .header-mark 30x30
Theme.MarkRadius = 7                       -- border-radius: 7px
Theme.MarkGlyphSize = 25                   -- svg 25x25
Theme.BrandHeight = 30                     -- header strong height:30px
Theme.BrandText = rgb(222, 222, 222)
Theme.BrandFont = 15                       -- header strong (font-size inherited 12 -> shown ~15)

-- Current game
Theme.GameTop = 64                         -- .current-game top: 64px
Theme.GameGap = 7                          -- gap: 7px
Theme.GameIndicator = 4                    -- .game-indicator 4x4
Theme.GameIndicatorColor = rgb(153, 153, 153) -- background #999
Theme.GameNameColor = rgb(160, 160, 160)   -- #current-game-name color #a0a0a0
Theme.GameNameFont = 11

-- Window buttons: 30x44 hit area, 13px dot, coloured only while hovered
Theme.WindowButtonsRight = 16             -- right: 16px
Theme.WindowButtonsTop = 13               -- top: 13px
Theme.WindowButtonW = 30
Theme.WindowButtonH = 44
Theme.WindowDot = 13                      -- ::before 13x13
Theme.CloseDot = rgb(255, 96, 88)         -- #ff6058
Theme.MinDot = rgb(254, 188, 46)          -- #febc2e
Theme.MaxDot = rgb(40, 200, 64)           -- #28c840
Theme.WindowGlyphHover = rgb(0, 0, 0, 0.67)

-- Layout: 160px nav + fluid main
Theme.NavWidth = 160                      -- grid-template-columns: 160px ...
Theme.NavBorder = rgb(28, 28, 28)         -- border-right: 1px solid #1c1c1c
Theme.NavPadV = 20                        -- padding: 20px 10px
Theme.NavPadH = 10
Theme.NavGap = 7                          -- gap: 7px
Theme.NavItemMinH = 44                    -- min-height: 44px
Theme.NavItemPadV = 11                    -- padding: 11px 10px
Theme.NavItemPadH = 10
Theme.NavItemRadius = 6                   -- border-radius: 6px
Theme.NavItemGap = 9                      -- gap: 9px
Theme.NavIdle = rgb(146, 146, 146)        -- color: #929292
Theme.NavActiveBg = rgb(26, 26, 26)       -- .active background #1a1a1a
Theme.NavActiveText = rgb(227, 227, 227)  -- .active color #e3e3e3
Theme.NavHoverBg = rgb(22, 22, 22)        -- :hover background #161616
Theme.NavHoverText = rgb(221, 221, 221)   -- :hover color #ddd
Theme.NavGlyphColor = rgb(138, 138, 138)  -- .nav-glyph color #8a8a8a
Theme.NavGlyphWidth = 20                  -- .nav-glyph width: 20px
Theme.NavGlyphFont = 17                   -- font-size: 17px
Theme.NavFont = 12
Theme.NavBg = rgb(9, 9, 9)                -- nav background #090909

-- Main content: padding 25px 26px 30px, background #0c0c0c
Theme.MainBg = rgb(12, 12, 12)            -- #0c0c0c
Theme.MainPadTop = 25
Theme.MainPadX = 26
Theme.MainPadBottom = 30
Theme.ScrollBar = rgb(58, 58, 58)         -- scrollbar-color #3a3a3a

-- Heading block (h1 + .intro) per page
Theme.H1Size = 21                         -- h1 font-size: 21px
Theme.H1Color = rgb(222, 222, 222)        -- inherits --text
Theme.H1LetterSpacing = -0.5
Theme.IntroSize = 11                      -- .intro font-size: 11px
Theme.IntroColor = rgb(150, 150, 150)     -- #969696
Theme.HeadingGap = 22                     -- .heading margin-bottom: 22px

-- Section label
Theme.SectionLabel = rgb(153, 153, 153)   -- .section-label color #999
Theme.SectionLabelSize = 9
Theme.SectionLabelMarginTop = 25          -- margin: 25px 0 11px
Theme.SectionLabelMarginBottom = 11

-- Field (input/textarea)
Theme.FieldBg = rgb(17, 17, 17)           -- #111
Theme.FieldBorder = rgb(51, 51, 51)       -- #333
Theme.FieldText = rgb(221, 221, 221)      -- #ddd
Theme.FieldPlaceholder = rgb(129, 129, 129) -- ::placeholder #818181
Theme.FieldFocusBg = rgb(22, 22, 22)      -- :focus background #161616
Theme.FieldFocusBorder = rgb(119, 119, 119) -- :focus border #777
Theme.FieldRadius = 6                     -- border-radius: 6px
Theme.FieldPadV = 11                      -- padding: 11px 12px
Theme.FieldPadH = 12
Theme.FieldMinH = 42                      -- min-height: 42px
Theme.FieldFont = 12
Theme.SearchBg = rgb(15, 15, 15)          -- .search background #0f0f0f
Theme.SearchBorder = rgb(41, 41, 41)      -- .search border #292929

-- Row (.row): flex space-between, min-height 61, padding 14, radius 6, bg #111
Theme.RowBg = rgb(17, 17, 17)             -- #111
Theme.RowHoverBg = rgb(22, 22, 22)        -- :hover #161616
Theme.RowGap = 14                         -- gap: 14px
Theme.RowMinH = 61                        -- min-height: 61px
Theme.RowPad = 14                         -- padding: 14px
Theme.RowRadius = 6
Theme.RowMarginBottom = 4                 -- margin: 0 0 4px
Theme.RowLabel = rgb(206, 206, 206)       -- .row label color #cecece
Theme.RowLabelFont = 12
Theme.HelpColor = rgb(146, 146, 146)      -- .help color #929292
Theme.HelpFont = 10                       -- font-size: 10px
Theme.HelpMarginTop = 6                   -- margin-top: 6px

-- Toggle: 34x21, radius 20, knob 13 at 3,3, shifts 13px when checked
Theme.ToggleW = 34
Theme.ToggleH = 21
Theme.ToggleRadius = 20
Theme.ToggleBg = rgb(48, 48, 48)          -- #303030
Theme.ToggleBorder = rgb(68, 68, 68)      -- #444
Theme.ToggleKnob = rgb(148, 148, 148)     -- ::after background #949494
Theme.ToggleKnobSize = 13
Theme.ToggleKnobInset = 3
Theme.ToggleKnobOn = rgb(34, 34, 34)      -- :checked::after background #222
Theme.ToggleOnBg = Theme.Accent           -- :checked background var(--accent)
Theme.ToggleShift = 13                    -- translateX(13px)

-- Checkbox: 17x17
Theme.CheckboxSize = 17

-- Range (.range): bg #111, padding 15 14 4, radius 6
Theme.RangeBg = rgb(17, 17, 17)
Theme.RangePadTop = 15
Theme.RangePadX = 14
Theme.RangePadBottom = 4
Theme.RangeRadius = 6
Theme.RangeLabel = rgb(204, 204, 204)     -- .range label color #ccc
Theme.RangeOutput = rgb(170, 170, 170)    -- .range output color #aaa
Theme.RangeOutputSize = 11
Theme.RangeTrackHeight = 5                -- input[type=range] height: 5px
Theme.RangeTrackMarginTop = 22            -- margin: 22px 0 18px
Theme.RangeTrackMarginBottom = 18

-- Input group (.input-group): bg #111, padding 14, radius 6
Theme.GroupBg = rgb(17, 17, 17)
Theme.GroupPad = 14
Theme.GroupRadius = 6
Theme.GroupLabel = rgb(176, 176, 176)     -- .input-group label color #b0b0b0
Theme.GroupLabelSize = 11
Theme.GroupLabelMargin = 9                -- margin-bottom: 9px
Theme.GroupFieldBg = rgb(12, 12, 12)      -- .input-group .field background #0c0c0c

-- Notice (.notice): bg #111, padding 14, radius 6, color #999, margin 21 0
Theme.NoticeBg = rgb(17, 17, 17)
Theme.NoticePad = 14
Theme.NoticeRadius = 6
Theme.NoticeColor = rgb(153, 153, 153)
Theme.NoticeSize = 11
Theme.NoticeLineHeight = 1.8
Theme.NoticeStrong = rgb(204, 204, 204)   -- .notice strong color #ccc
Theme.NoticeMarginY = 21

-- Action / keybind buttons
Theme.ActionBg = rgb(29, 29, 29)          -- #1d1d1d
Theme.ActionText = rgb(204, 204, 204)     -- #ccc
Theme.ActionBorder = rgb(58, 58, 58)      -- #3a3a3a
Theme.ActionHoverBg = rgb(39, 39, 39)     -- :hover #272727
Theme.ActionHoverBorder = rgb(90, 90, 90) -- :hover border #5a5a5a
Theme.ActionRadius = 6
Theme.ActionMinH = 38                     -- min-height: 38px
Theme.ActionPadV = 9                      -- padding: 9px 12px
Theme.ActionPadH = 12
Theme.ActionFont = 11
Theme.PrimaryBg = rgb(204, 204, 204)      -- .primary background #ccc
Theme.PrimaryText = rgb(22, 22, 22)       -- .primary color #161616
Theme.PrimaryHoverBg = rgb(224, 224, 224) -- .primary:hover #e0e0e0
Theme.ButtonGroupGap = 8                  -- gap: 8px
Theme.ButtonGroupMarginY = 15             -- margin: 15px 0
Theme.ButtonGroupMinW = 90                -- .button-group .action min-width: 90px

-- Collapsible (details/summary)
Theme.DetailsBg = rgb(16, 16, 16)         -- details background #101010
Theme.DetailsBorder = rgb(44, 44, 44)     -- border: 1px solid #2c2c2c
Theme.DetailsRadius = 6
Theme.DetailsPad = 14
Theme.DetailsMarginTop = 20
Theme.SummaryColor = rgb(184, 184, 184)   -- summary color #b8b8b8
Theme.SummaryMinH = 24

-- Custom choice trigger + color trigger
Theme.TriggerBg = rgb(27, 27, 27)         -- #1b1b1b
Theme.TriggerBorder = rgb(59, 59, 59)     -- #3b3b3b
Theme.TriggerText = rgb(197, 197, 197)    -- #c5c5c5
Theme.TriggerHoverBg = rgb(36, 36, 36)    -- :hover #242424
Theme.TriggerHoverBorder = rgb(85, 85, 85)
Theme.TriggerMinH = 38
Theme.TriggerRadius = 6
Theme.TriggerFont = 11
Theme.TriggerMaxWidth = 0.6               -- max-width: 60%
Theme.SwatchSize = 16                     -- .color-swatch 16x16
Theme.SwatchRadius = 4
Theme.ColorCodeFont = 10                  -- #color-code font 10 monospace

-- Choice menu (floating list)
Theme.MenuBg = rgb(23, 23, 23)            -- #171717
Theme.MenuBorder = rgb(59, 59, 59)        -- #3b3b3b
Theme.MenuRadius = 8
Theme.MenuPad = 5
Theme.MenuMinW = 155                      -- min-width: 155px
Theme.MenuMaxH = 220                      -- max-height: 220px
Theme.MenuItemMinH = 37                   -- min-height: 37px
Theme.MenuItemPadV = 10                   -- padding: 10px 11px
Theme.MenuItemPadH = 11
Theme.MenuItemColor = rgb(170, 170, 170)  -- #aaa
Theme.MenuItemSelBg = rgb(40, 40, 40)     -- :hover/[selected] background #282828
Theme.MenuItemSelText = rgb(238, 238, 238) -- color #eee
Theme.MenuFont = 11

-- Footer
Theme.FooterBorder = rgb(34, 34, 34)      -- border-top: 1px solid #222
Theme.FooterBg = rgb(9, 9, 9)             -- #090909
Theme.FooterText = rgb(139, 139, 139)     -- color #8b8b8b
Theme.FooterFont = 9                      -- font-size: 9px
Theme.FooterPadV = 11                     -- padding: 11px 22px
Theme.FooterPadH = 22
Theme.FooterBrandColor = rgb(153, 153, 153) -- .footer-brand color #999
Theme.FooterBrandSize = 8                 -- font-size: 8px
Theme.FooterBrandSpacing = 0.1            -- letter-spacing .1em
Theme.FooterKeyColor = rgb(170, 170, 170) -- .footer-key color #aaa
Theme.FooterKeyBorder = rgb(51, 51, 51)   -- border: 1px solid #333
Theme.FooterKeyRadius = 3
Theme.FooterKeyPadV = 3
Theme.FooterKeyPadH = 5

-- Toast (.toast)
Theme.ToastBg = rgb(21, 21, 21)           -- #151515 (with ee alpha -> 0.93)
Theme.ToastBgAlpha = 0.93
Theme.ToastBorder = rgb(58, 58, 58)       -- #3a3a3a
Theme.ToastErrorBorder = rgb(121, 80, 80) -- .toast.error border #795050
Theme.ToastRadius = 9
Theme.ToastPad = 16
Theme.ToastWidth = 310
Theme.ToastBottom = 22
Theme.ToastRight = 22
Theme.ToastTitleSize = 12
Theme.ToastBodySize = 11
Theme.ToastBodyColor = rgb(170, 170, 170) -- .toast p color #aaa

-- Dialog (modal)
Theme.DialogBg = rgb(18, 18, 18)          -- #121212
Theme.DialogBorder = rgb(66, 66, 66)      -- #424242
Theme.DialogRadius = 12
Theme.DialogPad = 25
Theme.DialogWidth = 390
Theme.DialogBackdrop = 0.69               -- backdrop #000b
Theme.DialogH2Size = 18                   -- h2 font-size: 18px
Theme.DialogBodyColor = rgb(170, 170, 170) -- p color #aaa
Theme.DialogBodySize = 12

-- Hub toggle pill (#hub-toggle)
Theme.HubBg = rgb(17, 17, 17)
Theme.HubBorder = rgb(51, 51, 51)         -- border: 1px solid #333
Theme.HubRadius = 10
Theme.HubPad = 8
Theme.HubLeft = 20
Theme.HubTop = 18
Theme.HubMarkSize = 29
Theme.HubMarkRadius = 7
Theme.HubNameSize = 12
Theme.HubNameColor = rgb(221, 221, 221)

-- Motion (seconds), mirroring the CSS transitions.
Theme.Duration = {
  Fast = 0.18,
  Background = 0.20,
  Transform = 0.20,
  NavBg = 0.18,
  Knob = 0.25,
  Toast = 0.30,
  ToastOpacity = 0.22,
  Modal = 0.25,
  Menu = 0.18,
  Morph = 1.05,
}

-- Convert a {r,g,b(,a)} token to Color3. A 4th value is alpha in 0..1 and is
-- returned separately through Theme.Alpha for callers that need transparency.
function Theme.Color(token)
  if token == nil then return Color3.fromRGB(255, 255, 255) end
  return Color3.fromRGB(token.r, token.g, token.b)
end

function Theme.Alpha(token)
  if type(token) ~= "table" or token[4] == nil then return 1 end
  return token[4]
end

-- UDim2 helpers used repeatedly by the layout.
function Theme.px(n) return UDim2.fromOffset(n, n) end
function Theme.off(x, y) return UDim2.fromOffset(x, y) end
function Theme.scale(x, y) return UDim2.fromScale(x, y) end

return Theme
