return {
    {
        "bjarneo/aether.nvim",
        name = "aether",
        priority = 1000,
        opts = {
            disable_italics = false,
            colors = {
                -- Monotone shades (base00-base07)
                base00 = "#181310", -- Default background
                base01 = "#846d62", -- Lighter background (status bars)
                base02 = "#181310", -- Selection background
                base03 = "#846d62", -- Comments, invisibles
                base04 = "#ded7d3", -- Dark foreground
                base05 = "#f4f2f1", -- Default foreground
                base06 = "#f4f2f1", -- Light foreground
                base07 = "#ded7d3", -- Light background

                -- Accent colors (base08-base0F)
                base08 = "#c0596a", -- Variables, errors, red
                base09 = "#d98291", -- Integers, constants, orange
                base0A = "#cf8677", -- Classes, types, yellow
                base0B = "#cd6a6a", -- Strings, green
                base0C = "#cdbc6a", -- Support, regex, cyan
                base0D = "#cf9b68", -- Functions, keywords, blue
                base0E = "#d6be8f", -- Keywords, storage, magenta
                base0F = "#e9c1b9", -- Deprecated, brown/yellow
            },
        },
        config = function(_, opts)
            require("aether").setup(opts)
            vim.cmd.colorscheme("aether")

            -- Enable hot reload
            require("aether.hotreload").setup()
        end,
    },
    {
        "LazyVim/LazyVim",
        opts = {
            colorscheme = "aether",
        },
    },
}
