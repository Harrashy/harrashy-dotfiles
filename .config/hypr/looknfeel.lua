-- Change the default Omarchy look'n'feel.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
-- hl.config({
--   general = {
--     -- No gaps between windows or borders.
--     gaps_in = 0,
--     gaps_out = 0,
--     border_size = 0,
--
--     -- Change to niri-like side-scrolling layout.
--     layout = "scrolling",
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
hl.config({
  decoration = {
    -- Use round window corners for glass effect.
    rounding = 12,

    -- Window opacity for glassmorphism effect (0.0 = fully transparent, 1.0 = opaque).
    -- Active window stays mostly opaque, inactive gets glass-like dimming.
    active_opacity = 1.0,
    inactive_opacity = 1.0,

    -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
    dim_inactive = false,
    dim_strength = 0.25,

    -- Blur settings for glass effect
    blur = {
      enabled = false,
      size = 8,
      passes = 2,
      noise = 0.02,
      contrast = 1.0,
      brightness = 0.9,
      vibrancy = 0.2,
      vibrancy_darkness = 0.5,
      new_optimizations = true,
      xray = false,
    },
  },
})

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- }
