{
  flake.modules.homeManager.base =
    {
      config,
      lib,
      pkgs,
      repoFile,
      ...
    }:
    {
      # linked whole, so lua edits apply on :restart with no rebuild
      xdg.configFile."nvim".source = repoFile "modules/eric/nvim";

      # vim.loader trusts a cached chunk while the file's size and mtime match
      # every store file has mtime 1, so a rebuilt plugin behind the same pack/hm path keeps its old bytecode
      home.activation.clearNvimLuaCache = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD rm -rf "${config.xdg.cacheHome}/nvim/luac"
      '';

      programs.neovim = {
        enable = true;
        viAlias = true;
        vimAlias = true;
        # keep home-manager from writing ~/.config/nvim/init.lua over the linked config
        sideloadInitLua = true;
        withPython3 = false;
        withRuby = false;

        # start holds plugins with no setup call
        # opt plugins load through the lz.n specs in nvim/lua/user/plugins
        plugins =
          with pkgs.vimPlugins;
          [
            lz-n
            plenary-nvim
            nvim-lspconfig
            SchemaStore-nvim
            nvim-treesitter.withAllGrammars
            rainbow-delimiters-nvim
            vim-fugitive
          ]
          ++
            map
              (plugin: {
                inherit plugin;
                optional = true;
              })
              [
                alpha-nvim
                blink-cmp
                bufferline-nvim
                catppuccin-nvim
                cmake-tools-nvim
                # nixpkgs still lists nui.nvim, which codediff replaced with its own split, line, and tree modules
                (codediff-nvim.overrideAttrs { dependencies = [ ]; })
                conform-nvim
                copilot-lua
                dropbar-nvim
                fidget-nvim
                flash-nvim
                gitsigns-nvim
                grug-far-nvim
                indent-blankline-nvim
                luasnip
                neogit
                nvim-autopairs
                nvim-colorizer-lua
                nvim-lint
                nvim-notify
                nvim-surround
                nvim-tree-lua
                nvim-ts-autotag
                nvim-web-devicons
                render-markdown-nvim
                telescope-file-browser-nvim
                telescope-fzf-native-nvim
                telescope-nvim
                telescope-ui-select-nvim
                todo-comments-nvim
                trouble-nvim
                vimtex
                which-key-nvim
              ];

        # stable-version language servers and tools
        # project servers (clangd, pyright, ...) come from the project's devshell,
        # so their version matches the toolchain
        extraPackages = with pkgs; [
          # html, cssls, jsonls, eslint
          vscode-langservers-extracted
          bash-language-server
          # bashls lints through it
          shellcheck
          marksman
          taplo
          typos-lsp
          yaml-language-server

          # markdown, json, etc, globally
          prettier

          # nvim-lint linters
          statix
          deadnix
          hadolint
          markdownlint-cli2

          # telescope and grug-far
          ripgrep
          # fugitive, gitsigns, neogit
          git
        ];
      };

      home.sessionVariables = {
        EDITOR = "nvim";
        VISUAL = "nvim";
      };
    };
}
